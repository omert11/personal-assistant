#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["rich>=13.0", "questionary>=2.0"]
# ///
"""
personal-assistant setup — tek komutla stack kurulumu.

Çalıştırma:
  ./setup.sh              # uv'yi kurup başlatır
  uv run scripts/setup.py # direkt uv varsa

Özellikler:
- Idempotent (tekrar çalıştırılabilir, mevcut olanı atlar)
- Renkli progress + anlık status
- Cache'li MCP list (tek network call)
- İnteraktif credential prompts
"""
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional

from rich.console import Console
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
from rich.prompt import Confirm, Prompt
from rich.table import Table
from rich.text import Text

console = Console()

HOME = Path.home()
CLAUDE_DIR = HOME / ".claude"
PLUGIN_ROOT = Path(__file__).resolve().parent.parent
LOCAL_DIR = HOME / "Desktop" / "local"
MCP_DIR = HOME / "Desktop" / "Git" / "MCP"


# ── UI ────────────────────────────────────────────────────

def section(title: str):
    console.print()
    console.rule(f"[bold cyan]{title}[/bold cyan]")

def ok(msg: str):    console.print(f"  [green]✓[/green] {msg}")
def skip(msg: str):  console.print(f"  [dim]○ {msg}[/dim]")
def warn(msg: str):  console.print(f"  [yellow]![/yellow] {msg}")
def err(msg: str):   console.print(f"  [red]✗[/red] {msg}")
def info(msg: str):  console.print(f"  [blue]→[/blue] {msg}")


# ── shell ─────────────────────────────────────────────────

def run(cmd: str, check=False, capture=True, live=False) -> subprocess.CompletedProcess:
    """Run shell command. live=True streams output, capture=True buffers."""
    if live:
        return subprocess.run(cmd, shell=True, check=check, text=True)
    return subprocess.run(cmd, shell=True, check=check, capture_output=capture, text=True)

def have(cmd: str) -> bool:
    return shutil.which(cmd) is not None


# ── cached mcp list ───────────────────────────────────────

_mcp_cache: Optional[str] = None

def mcp_list(refresh=False) -> str:
    global _mcp_cache
    if _mcp_cache is None or refresh:
        with console.status("[dim]claude mcp list...[/dim]", spinner="dots"):
            r = run("claude mcp list 2>/dev/null")
        _mcp_cache = r.stdout or ""
    return _mcp_cache

def mcp_has(name: str) -> bool:
    return f"{name}:" in mcp_list()


# ── installers ────────────────────────────────────────────

def ensure_brew(pkg: str, cmd: Optional[str] = None) -> bool:
    name = cmd or pkg
    if have(name):
        skip(f"{pkg}")
        return True
    if not have("brew"):
        err("brew yok. Kur: https://brew.sh/")
        return False
    with console.status(f"[yellow]brew install {pkg}[/yellow]"):
        run(f"brew install {pkg}")
    ok(f"{pkg} kuruldu") if have(name) else err(f"{pkg} kurulamadı")
    return have(name)

def ensure_uv_tool(pkg: str, cmd: Optional[str] = None, extras: Optional[str] = None) -> bool:
    """Install a Python CLI via `uv tool install`. Idempotent."""
    name = cmd or pkg
    if have(name):
        skip(f"{pkg}")
        return True
    if not have("uv"):
        err("uv yok — uv tool install atlandı")
        return False
    spec = f"{pkg}[{extras}]" if extras else pkg
    with console.status(f"[yellow]uv tool install {spec}[/yellow]"):
        run(f"uv tool install '{spec}'")
    if have(name):
        ok(f"{pkg} kuruldu")
        return True
    err(f"{pkg} kurulamadı")
    return False


def ensure_brew_cask(cask: str, app_path: Optional[str] = None) -> bool:
    if app_path and Path(app_path).exists():
        skip(f"{cask}")
        return True
    if not have("brew"):
        err("brew yok")
        return False
    cask_installed = run(f"brew list --cask {cask} 2>/dev/null").returncode == 0
    if cask_installed and app_path and not Path(app_path).exists():
        with console.status(f"[yellow]brew reinstall --cask {cask} (link eksik)[/yellow]"):
            run(f"brew reinstall --cask {cask}")
        ok(f"{cask} yeniden linklendi")
        return True
    if cask_installed:
        skip(f"{cask}")
        return True
    with console.status(f"[yellow]brew install --cask {cask}[/yellow]"):
        run(f"brew install --cask {cask}")
    ok(f"{cask} kuruldu")
    return True

RUST_TARGET_TRIPLE_MAP = {
    ("darwin", "arm64"):   "aarch64-apple-darwin",
    ("darwin", "x86_64"):  "x86_64-apple-darwin",
    ("linux",  "aarch64"): "aarch64-unknown-linux-gnu",
    ("linux",  "x86_64"):  "x86_64-unknown-linux-gnu",
}


def rust_target_triple() -> Optional[str]:
    return RUST_TARGET_TRIPLE_MAP.get((platform.system().lower(), platform.machine()))


def ensure_rust_cli_release(name: str, owner_repo: str) -> bool:
    """Download a Rust CLI tarball from a GitHub release into ~/.local/bin."""
    bin_dst = HOME / ".local" / "bin" / name
    if have(name) or bin_dst.exists():
        skip(f"{name} kurulu")
        return True
    target = rust_target_triple()
    if not target:
        warn(f"{name} — desteklenmeyen platform: {platform.system()}/{platform.machine()}")
        return False

    url = f"https://github.com/{owner_repo}/releases/latest/download/{name}-{target}.tar.gz"
    bin_dst.parent.mkdir(parents=True, exist_ok=True)
    with console.status(f"[yellow]{name} indir ({target})[/yellow]"):
        run(
            f"curl -sL '{url}' -o /tmp/{name}.tar.gz "
            f"&& tar xzf /tmp/{name}.tar.gz -C /tmp "
            f"&& mv /tmp/{name} {bin_dst} "
            f"&& chmod +x {bin_dst}"
        )
    if bin_dst.exists():
        ok(f"{name} kuruldu: {bin_dst}")
        return True
    err(f"{name} indirilemedi")
    return False


def ensure_skill_from_repo(name: str, owner_repo: str) -> bool:
    """Copy a SKILL.md from owner/repo:skills/<name>/ into ~/.claude/skills/."""
    skill_dst = CLAUDE_DIR / "skills" / name
    if (skill_dst / "SKILL.md").exists():
        skip(f"{name} skill kurulu")
        return True
    skill_dst.mkdir(parents=True, exist_ok=True)
    with console.status(f"[yellow]{name} SKILL.md indir[/yellow]"):
        run(
            f"gh api repos/{owner_repo}/contents/skills/{name}/SKILL.md "
            f"--jq '.content' | base64 -d > {skill_dst}/SKILL.md"
        )
    if (skill_dst / "SKILL.md").stat().st_size > 0:
        ok(f"{name} skill kuruldu: {skill_dst}")
        return True
    warn(f"{name} skill indirilemedi")
    return False


def ensure_env_vars(label: str, prompts: list[tuple[str, str, bool]], comment: str) -> bool:
    """Sync env vars to ~/.zshrc and ~/.claude/settings.json.

    prompts: list of (var_name, prompt_text, is_password) tuples.
    Asks user once, writes to both targets if either is missing.
    """
    rc = HOME / ".zshrc"
    settings_path = CLAUDE_DIR / "settings.json"
    primary_var = prompts[0][0]

    has_rc = rc.exists() and primary_var in rc.read_text()
    has_claude = False
    if settings_path.exists():
        try:
            settings = json.loads(settings_path.read_text())
            has_claude = primary_var in settings.get("env", {})
        except json.JSONDecodeError:
            pass

    if has_rc and has_claude:
        skip(f"{label} env aktif (rc + Claude)")
        return True

    if not Confirm.ask(f"{label} env vars'ı şimdi yapılandırayım mı?", default=True):
        return False

    values: dict[str, str] = {}
    for var_name, prompt_text, is_password in prompts:
        v = Prompt.ask(prompt_text, default="", show_default=False, password=is_password)
        if not v:
            warn(f"{var_name} boş — env yapılandırılmadı")
            return False
        values[var_name] = v

    if not has_rc:
        with rc.open("a") as f:
            f.write(f"\n# {comment}\n")
            for k, v in values.items():
                f.write(f'export {k}="{v}"\n')
        ok("~/.zshrc'ye eklendi")

    if not has_claude and settings_path.exists():
        try:
            settings = json.loads(settings_path.read_text())
            settings.setdefault("env", {}).update(values)
            settings_path.write_text(json.dumps(settings, indent=2) + "\n")
            ok("settings.json env güncellendi")
        except (json.JSONDecodeError, OSError) as e:
            warn(f"settings.json güncellenemedi: {e}")
    return True


def ensure_repo(owner_repo: str, target: Path) -> bool:
    if (target / ".git").exists():
        skip(f"{target.name} clone'lu")
        return True
    target.parent.mkdir(parents=True, exist_ok=True)
    with console.status(f"[yellow]git clone {owner_repo}[/yellow]"):
        run(f"git clone https://github.com/{owner_repo}.git {target}")
    if target.exists():
        ok(f"{target.name} clone'landı")
        return True
    err(f"{owner_repo} clone başarısız")
    return False

def ensure_node_build(path: Path) -> bool:
    dist = path / "dist" / "index.js"
    if dist.exists():
        skip(f"{path.name} build'li")
        return True
    if not (path / "package.json").exists():
        warn(f"{path.name} package.json yok")
        return False
    with console.status(f"[yellow]npm install + build {path.name}[/yellow]"):
        run(f"cd {path} && npm install && npm run build")
    return dist.exists()

def ensure_uv_sync(path: Path) -> bool:
    if not (path / "pyproject.toml").exists():
        warn(f"{path.name} pyproject.toml yok")
        return False
    if (path / ".venv").exists():
        skip(f"{path.name} synced")
        return True
    with console.status(f"[yellow]uv sync {path.name}[/yellow]"):
        run(f"cd {path} && uv sync")
    return (path / ".venv").exists()

def ensure_python_venv(path: Path) -> bool:
    if (path / ".venv").exists():
        skip(f"{path.name} venv var")
        return True
    with console.status(f"[yellow]uv venv + pip install {path.name}[/yellow]"):
        run(f"cd {path} && uv venv && (uv pip install -r requirements.txt 2>/dev/null || uv pip install -e .)")
    return (path / ".venv").exists()


# ── settings merge ────────────────────────────────────────

def deep_merge(base: dict, overlay: dict) -> dict:
    for k, v in overlay.items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            deep_merge(base[k], v)
        else:
            base[k] = v
    return base

def section_settings():
    section("~/.claude/settings.json")
    CLAUDE_DIR.mkdir(exist_ok=True)
    sp = CLAUDE_DIR / "settings.json"
    current = {}
    if sp.exists():
        try:
            current = json.loads(sp.read_text())
            ok("mevcut settings.json okundu")
        except json.JSONDecodeError:
            err("settings.json bozuk — manual düzelt")
            return

    extra_marketplaces = {
        "personal-assistant": {
            "source": {"source": "directory", "path": str(PLUGIN_ROOT)}
        }
    }
    enabled_plugins = {"personal-assistant@personal-assistant": True}

    desired = {
        "env": {"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"},
        "statusLine": {
            "type": "command",
            "command": "bash ~/.claude/scripts/statusline.sh",
            "padding": 0,
        },
        "extraKnownMarketplaces": extra_marketplaces,
        "enabledPlugins": enabled_plugins,
        "language": "Türkçe",
        "alwaysThinkingEnabled": False,
    }

    merged = deep_merge(current, desired)

    if merged.get("permissions", {}).get("defaultMode") != "bypassPermissions":
        if Confirm.ask("[yellow]bypassPermissions[/yellow] modu açılsın mı (çoğu onay prompt'unu atlar, TEHLİKELİ)?", default=False):
            merged.setdefault("permissions", {})["defaultMode"] = "bypassPermissions"
            merged["skipDangerousModePermissionPrompt"] = True
            merged["skipAutoPermissionPrompt"] = True

    sp.write_text(json.dumps(merged, indent=2) + "\n")
    ok(f"yazıldı: {sp}")


# ── statusline ────────────────────────────────────────────

def section_statusline():
    section("Statusline")
    src = PLUGIN_ROOT / "bin" / "statusline.sh"
    dst = CLAUDE_DIR / "scripts" / "statusline.sh"
    if not src.exists():
        warn(f"{src} yok")
        return
    if dst.exists() and dst.read_bytes() == src.read_bytes():
        skip(f"{dst.name} güncel")
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, dst)
    dst.chmod(0o755)
    ok(f"kopyalandı: {dst}")


# ── MCP register ──────────────────────────────────────────

def mcp_add_stdio(name: str, command: str):
    if mcp_has(name):
        skip(f"mcp {name}")
        return
    with console.status(f"[yellow]mcp add {name}[/yellow]"):
        run(f'claude mcp add --scope user {name} -- {command}')
    ok(f"mcp {name} eklendi")


# ── plugin register ───────────────────────────────────────

_plugin_cache: Optional[str] = None
_marketplace_cache: Optional[str] = None

def plugin_list(refresh=False) -> str:
    global _plugin_cache
    if _plugin_cache is None or refresh:
        _plugin_cache = run("claude plugin list 2>/dev/null").stdout or ""
    return _plugin_cache

def marketplace_list(refresh=False) -> str:
    global _marketplace_cache
    if _marketplace_cache is None or refresh:
        _marketplace_cache = run("claude plugin marketplace list 2>/dev/null").stdout or ""
    return _marketplace_cache

def plugin_has(name: str) -> bool:
    return f"{name}@" in plugin_list()

def marketplace_has(name: str) -> bool:
    return f"❯ {name}" in marketplace_list() or f"> {name}" in marketplace_list()

def plugin_install_from_github(plugin_name: str, marketplace_name: str, source: str):
    """Install a Claude Code plugin from a GitHub marketplace. Idempotent."""
    if not marketplace_has(marketplace_name):
        with console.status(f"[yellow]marketplace add {source}[/yellow]"):
            run(f"claude plugin marketplace add {source}")
        ok(f"marketplace {marketplace_name} eklendi")
        marketplace_list(refresh=True)
    else:
        skip(f"marketplace {marketplace_name}")

    if not plugin_has(plugin_name):
        with console.status(f"[yellow]plugin install {plugin_name}[/yellow]"):
            run(f"claude plugin install {plugin_name}@{marketplace_name}")
        ok(f"plugin {plugin_name} kuruldu")
        plugin_list(refresh=True)
    else:
        skip(f"plugin {plugin_name}")


# ── progress-based sections ───────────────────────────────

def with_progress(title: str, tasks: list[tuple[str, callable]]):
    """Run a list of (label, fn) tasks with a visible progress bar."""
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        TaskProgressColumn(),
        console=console,
    ) as progress:
        t = progress.add_task(title, total=len(tasks))
        for label, fn in tasks:
            progress.update(t, description=f"[cyan]{label}")
            try:
                fn()
            except Exception as e:
                err(f"{label}: {e}")
            progress.advance(t)


def section_prereq():
    section("Prerequisites (Homebrew)")
    pkgs = [("uv", "uv"), ("node", "node"), ("gh", "gh"), ("jq", "jq")]
    with_progress("Brew paketleri", [(p, (lambda p=p, c=c: ensure_brew(p, c))) for p, c in pkgs])
    if not have("docker"):
        warn("docker yok — Vikunja vb. dependency'ler için gerekli. Kurulum: https://www.docker.com/products/docker-desktop/")
    else:
        skip("docker")

    section("Python CLI tools (uv tool)")
    uv_tools = [
        ("markitdown", lambda: ensure_uv_tool("markitdown", extras="all")),
    ]
    with_progress("uv tool install", uv_tools)


def section_apps():
    section("Apps & Tools")
    tasks = [
        ("Zed editor", lambda: ensure_brew_cask("zed", "/Applications/Zed.app")),
        ("Obsidian", lambda: ensure_brew_cask("obsidian", "/Applications/Obsidian.app")),
        ("Claude Code CLI", lambda: (skip("claude CLI") if have("claude") else run("npm install -g @anthropic-ai/claude-code", live=False) and ok("claude CLI kuruldu"))),
    ]
    with_progress("Uygulamalar", tasks)

    if not (Path("/Applications/Solo.app").exists() or have("solo")):
        warn("Solo bulunamadı. İndir: https://soloterm.com/")

    if not have("docker") and Confirm.ask("Docker Desktop kurulsun mu?", default=True):
        ensure_brew_cask("docker", "/Applications/Docker.app")

    section_solo_cli()
    section_obsidian_vault()


SOLO_CLI_BINARY = "/Applications/Solo.app/Contents/MacOS/solo-cli"


def section_solo_cli():
    """Install + verify Solo's CLI.

    The CLI ships inside the Solo app bundle; we symlink it into
    ~/.local/bin/solo. It talks to the app's HTTP control plane; `solo doctor`
    confirms discovery + API connectivity. App must be running for
    project-scoped calls.
    """
    section("Solo CLI")
    if not have("solo"):
        if not Path(SOLO_CLI_BINARY).exists():
            warn("solo CLI yok ve Solo.app bulunamadı. İndir: https://soloterm.com/")
            return
        bin_dst = HOME / ".local" / "bin" / "solo"
        bin_dst.parent.mkdir(parents=True, exist_ok=True)
        with console.status("[yellow]solo CLI symlink (Solo.app bundle)[/yellow]"):
            run(f"ln -sf '{SOLO_CLI_BINARY}' '{bin_dst}'")
        if bin_dst.exists():
            ok(f"solo CLI kuruldu: {bin_dst}")
        else:
            err("solo CLI symlink başarısız")
            return

    r = run("solo doctor 2>&1")
    out = r.stdout or ""
    if "Ready: yes" in out or "HTTP API: ok" in out:
        ok("solo CLI hazır (HTTP API bağlı)")
    else:
        warn("solo CLI var ama HTTP API'ye bağlanamadı — Solo app'i aç ve tekrar dene")


def section_obsidian_vault():
    if not Path("/Applications/Obsidian.app").exists():
        return
    section("Obsidian Vault")
    default_vault = HOME / "Documents" / "ObsidianVault"
    vault_str = Prompt.ask("Vault path", default=str(default_vault))
    vault = Path(vault_str).expanduser()
    if not vault.exists():
        if not Confirm.ask(f"[yellow]{vault}[/yellow] yok. Olustursun mu?", default=True):
            skip("vault olusturulmadi")
            return
        vault.mkdir(parents=True, exist_ok=True)
        ok(f"vault olusturuldu: {vault}")
    else:
        skip(f"vault mevcut: {vault}")
    if Confirm.ask(f"Obsidian [cyan]{vault.name}[/cyan] vault ile acilsin mi?", default=True):
        run(f'open -a Obsidian "{vault}"')
        ok("Obsidian acildi")

    section_obsidian_cli()


def section_obsidian_cli():
    """Verify Obsidian's official CLI is enabled.

    Replaces the legacy mcp-obsidian (REST API) integration. The CLI ships
    with the Obsidian app — user must toggle it on once via Settings.
    """
    section("Obsidian CLI")
    if not have("obsidian"):
        warn(
            "obsidian CLI yok. Aktif et:\n"
            "  Obsidian -> Settings -> General -> Advanced -> Command line interface (toggle on)"
        )
        return
    r = run("obsidian --help 2>&1")
    if "Command line interface is not enabled" in (r.stdout or ""):
        warn(
            "obsidian binary var ama disabled.\n"
            "  Obsidian -> Settings -> General -> Advanced -> Command line interface'i aç"
        )
        return
    ok("obsidian CLI hazır")


def section_local_mcps():
    section("Local MCP repos (omert11)")
    repos = [
        ("whatsapp-mcp", "omert11/whatsapp-mcp", LOCAL_DIR / "whatsapp-mcp", lambda p: ensure_uv_sync(p / "whatsapp-mcp-server") if (p / "whatsapp-mcp-server").exists() else True),
    ]
    tasks = []
    for label, owner_repo, target, build_fn in repos:
        def job(owner_repo=owner_repo, target=target, build_fn=build_fn):
            if ensure_repo(owner_repo, target):
                build_fn(target)
        tasks.append((label, job))
    with_progress("Repo clone + build", tasks)


def section_app_store_mcp():
    section("app-store-mcp plugin (omert11)")
    plugin_install_from_github(
        plugin_name="app-store-mcp",
        marketplace_name="app-store-mcp",
        source="omert11/app-store-mcp",
    )
    info("Fastlane gerekli — eksikse: brew install fastlane")


def section_vikunja_cli():
    """Install vikunja-cli + skill, replacing legacy vikunja-mcp."""
    section("vikunja-cli (Vikunja task management)")
    if not ensure_rust_cli_release("vikunja-cli", "omert11/vikunja-cli"):
        return
    ensure_skill_from_repo("vikunja-cli", "omert11/vikunja-cli")
    ensure_env_vars(
        "VIKUNJA",
        [
            ("VIKUNJA_API_URL", "VIKUNJA_API_URL", False),
            ("VIKUNJA_API_TOKEN", "VIKUNJA_API_TOKEN", True),
        ],
        "Vikunja CLI (replaces vikunja-mcp)",
    )


def section_zammad_cli():
    """Install zammad-cli + skill, replacing legacy zammad-mcp."""
    section("zammad-cli (Zammad helpdesk)")
    if not ensure_rust_cli_release("zammad-cli", "omert11/zammad-cli"):
        return
    ensure_skill_from_repo("zammad-cli", "omert11/zammad-cli")
    ensure_env_vars(
        "ZAMMAD",
        [
            ("ZAMMAD_URL", "ZAMMAD_URL (örn. https://support.example.com)", False),
            ("ZAMMAD_TOKEN", "ZAMMAD_TOKEN", True),
        ],
        "Zammad CLI (replaces zammad-mcp)",
    )


def section_po_cli():
    """Install po-cli + skill, replacing legacy po-mcp."""
    section("po-cli (Django gettext)")
    if not ensure_rust_cli_release("po-cli", "omert11/po-cli"):
        return
    ensure_skill_from_repo("po-cli", "omert11/po-cli")


def section_playwright_cli():
    """Install @playwright/cli globally and copy skills to user-level.

    Replaces the legacy @playwright/mcp transport. CLI is token-efficient and
    Microsoft's officially recommended path for coding agents.
    """
    section("Playwright CLI (@playwright/cli)")
    if have("playwright-cli"):
        skip("playwright-cli kurulu")
    else:
        if not have("npm"):
            err("npm yok — playwright-cli atlandı")
            return
        with console.status("[yellow]npm install -g @playwright/cli@latest[/yellow]"):
            run("npm install -g @playwright/cli@latest")
        if have("playwright-cli"):
            ok("playwright-cli kuruldu")
        else:
            err("playwright-cli kurulamadı")
            return

    skill_dst = CLAUDE_DIR / "skills" / "playwright-cli"
    if (skill_dst / "SKILL.md").exists():
        skip("playwright-cli skill kurulu")
        return

    # `playwright-cli install --skills` writes to ./.claude/skills/, so install
    # in a temp workspace then move to user-level for cross-project access.
    with tempfile.TemporaryDirectory() as tmp:
        with console.status("[yellow]playwright-cli install --skills[/yellow]"):
            run(f"cd {tmp} && playwright-cli install --skills")
        src = Path(tmp) / ".claude" / "skills" / "playwright-cli"
        if src.exists():
            skill_dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(src), str(skill_dst))
            ok(f"playwright-cli skill kuruldu: {skill_dst}")
        else:
            warn("playwright-cli skill bulunamadı — manuel: playwright-cli install --skills")


def section_context7_cli():
    """Install ctx7 CLI globally and configure Claude Code in CLI+Skills mode.

    Replaces the legacy MCP HTTP transport. CLI mode keeps the MCP slot free
    while still giving the agent live docs via `ctx7 library` / `ctx7 docs`.
    """
    section("Context7 CLI (ctx7)")
    if have("ctx7"):
        skip("ctx7 CLI kurulu")
    else:
        if not have("npm"):
            err("npm yok — node prerequisite atlandı, ctx7 atlanıyor")
            return
        with console.status("[yellow]npm install -g ctx7[/yellow]"):
            run("npm install -g ctx7")
        if have("ctx7"):
            ok("ctx7 CLI kuruldu")
        else:
            err("ctx7 kurulamadı")
            return

    # Skill + rule already present? `ctx7 setup` is idempotent but we skip
    # the prompt when the marker file is in place to keep reruns silent.
    skill_marker = CLAUDE_DIR / "skills" / "find-docs" / "SKILL.md"
    if skill_marker.exists():
        skip("find-docs skill kurulu")
        return

    console.print(Panel(
        "[bold]Context7 CLI mode[/bold]\n"
        "API key context7.com/dashboard'dan alınır. Boş geç → anonymous rate limit.",
        border_style="cyan",
    ))
    api_key = Prompt.ask("Context7 API Key", default="", show_default=False, password=True)
    args = "--claude --cli --yes"
    if api_key:
        args += f" --api-key {api_key}"
    else:
        args += " --oauth"
    with console.status("[yellow]ctx7 setup --claude --cli[/yellow]"):
        run(f"ctx7 setup {args}")
    if skill_marker.exists():
        ok("find-docs skill ve rule kuruldu")
    else:
        warn("ctx7 setup tamamlanmadı — manuel: ctx7 setup --claude --cli")


def section_register_mcps():
    section("Claude Code MCP servers (user scope)")
    mcp_list(refresh=True)  # prime cache once
    uv = HOME / ".local" / "bin" / "uv"

    tasks = [
        ("whatsapp",   lambda: mcp_add_stdio("whatsapp",   f"{uv} --directory {LOCAL_DIR}/whatsapp-mcp/whatsapp-mcp-server run main.py")),
    ]
    with_progress("MCP register", tasks)


def section_credentials():
    section("Credentials (interactive)")

    # GitHub: gh CLI kullanılıyor, MCP yok
    if have("gh"):
        gh_status = run("gh auth status 2>&1").stdout or ""
        if "Logged in" in gh_status:
            ok("gh CLI authenticated")
        else:
            info("gh CLI auth gerekli: gh auth login")
    else:
        warn("gh yok — brew install gh")

    # Credential rehberi
    guide = Table(title="MCP'ler için credential rehberi", show_header=True, border_style="dim")
    guide.add_column("MCP", style="cyan")
    guide.add_column("Yapılacak")
    guide.add_row("WhatsApp", "github.com/omert11/whatsapp-mcp README — QR okut, bridge başlat")
    guide.add_row("Zammad",   "~/.zshrc → ZAMMAD_URL + ZAMMAD_TOKEN (zammad-cli kullanır)")
    guide.add_row("Vikunja",  "~/.zshrc → VIKUNJA_API_URL + VIKUNJA_API_TOKEN (vikunja-cli kullanır)")
    guide.add_row("Google",   "Claude Code → /mcp → claude.ai servisi seç → Authenticate")
    console.print(guide)


def section_summary():
    section("Özet")
    mcp_list(refresh=True)
    console.print(_mcp_cache)
    console.print(Panel(
        "[bold]Sonraki adımlar:[/bold]\n"
        "1. Terminali kapat/aç (PATH güncelle)\n"
        "2. Claude Code başlat → [cyan]/reload-plugins[/cyan]\n"
        "3. Eksik credential'ları doldur (.env dosyaları)",
        border_style="green",
    ))


def main():
    console.print(Panel(
        f"[bold]personal-assistant setup[/bold]\n{PLUGIN_ROOT}",
        border_style="cyan",
    ))
    if sys.platform != "darwin":
        warn(f"Test platform: macOS. Şu an: {sys.platform}")
        if not Confirm.ask("Devam?", default=False):
            return

    section_prereq()
    section_apps()
    section_local_mcps()
    section_app_store_mcp()
    section_context7_cli()
    section_playwright_cli()
    section_po_cli()
    section_vikunja_cli()
    section_zammad_cli()
    section_settings()
    section_statusline()
    section_register_mcps()
    section_credentials()
    section_summary()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        console.print("\n[red]İptal edildi.[/red]")
        sys.exit(1)
