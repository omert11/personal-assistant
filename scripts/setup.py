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
import shutil
import subprocess
import sys
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

    caveman_path = LOCAL_DIR / "caveman"
    if caveman_path.exists():
        extra_marketplaces["caveman"] = {
            "source": {"source": "directory", "path": str(caveman_path)}
        }
        enabled_plugins["caveman@caveman"] = True

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

def mcp_add_http(name: str, url: str):
    if mcp_has(name):
        skip(f"mcp {name}")
        return
    with console.status(f"[yellow]mcp add {name} (http)[/yellow]"):
        run(f'claude mcp add --scope user --transport http {name} {url}')
    ok(f"mcp {name} eklendi (http)")


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
        warn("docker yok — github-mcp-server çalışmayacak. Kurulum: https://www.docker.com/products/docker-desktop/")
    else:
        skip("docker")


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

    section_obsidian_vault()


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

    section_obsidian_mcp()


def section_obsidian_mcp():
    section("Obsidian MCP (mcp-obsidian)")
    if mcp_has("obsidian"):
        skip("obsidian MCP zaten register")
        return
    console.print(Panel(
        "[bold]Local REST API[/bold] community plugin gerekli.\n"
        "Adimlar:\n"
        "  1. Obsidian -> Settings -> Community plugins -> Browse\n"
        "  2. 'Local REST API' ara, kur, enable et\n"
        "  3. Plugin ayarlarindan API Key kopyala",
        border_style="cyan",
        title="Plugin Kurulumu",
    ))
    if not Confirm.ask("Plugin kuruldu ve API key hazir mi?", default=False):
        skip("obsidian MCP atlandi - plugin kurulmadi")
        return
    api_key = Prompt.ask("Obsidian API Key", password=True)
    if not api_key:
        warn("API key bos - obsidian MCP atlandi")
        return
    host = Prompt.ask("Host", default="127.0.0.1")
    port = Prompt.ask("Port", default="27124")
    with console.status("[yellow]mcp add obsidian[/yellow]"):
        run(
            f'claude mcp add --scope user obsidian '
            f'--env OBSIDIAN_API_KEY={api_key} '
            f'--env OBSIDIAN_HOST={host} '
            f'--env OBSIDIAN_PORT={port} '
            f'-- uvx mcp-obsidian'
        )
    ok("obsidian MCP eklendi")


def section_caveman():
    section("Caveman plugin (opsiyonel)")
    target = LOCAL_DIR / "caveman"
    if target.exists():
        skip(f"caveman zaten var: {target}")
        return
    if not Confirm.ask(
        "[cyan]caveman[/cyan] plugin'i kurulsun mu? (output token'larını ~75% azaltan Claude Code skill'i)",
        default=True,
    ):
        skip("caveman atlandı")
        return
    if ensure_repo("JuliusBrussee/caveman", target):
        ok(f"caveman clone'landı: {target}")
        info("settings.json'a marketplace + enabledPlugins eklenecek (sonraki adımda)")


def section_local_mcps():
    section("Local MCP repos (omert11)")
    repos = [
        ("po-mcp",       "omert11/po-mcp",       MCP_DIR / "po-mcp",         lambda p: ensure_node_build(p)),
        ("whatsapp-mcp", "omert11/whatsapp-mcp", LOCAL_DIR / "whatsapp-mcp", lambda p: ensure_uv_sync(p / "whatsapp-mcp-server") if (p / "whatsapp-mcp-server").exists() else True),
        ("zammad-mcp",   "omert11/zammad-mcp",   LOCAL_DIR / "zammad-mcp",   lambda p: ensure_uv_sync(p)),
        ("vikunja-mcp",  "omert11/vikunja-mcp",  LOCAL_DIR / "vikunja-mcp-new", lambda p: ensure_python_venv(p)),
    ]
    tasks = []
    for label, owner_repo, target, build_fn in repos:
        def job(owner_repo=owner_repo, target=target, build_fn=build_fn):
            if ensure_repo(owner_repo, target):
                build_fn(target)
        tasks.append((label, job))
    with_progress("Repo clone + build", tasks)


def section_register_mcps():
    section("Claude Code MCP servers (user scope)")
    mcp_list(refresh=True)  # prime cache once
    uv = HOME / ".local" / "bin" / "uv"
    vpy = LOCAL_DIR / "vikunja-mcp-new" / ".venv" / "bin" / "python"

    tasks = [
        ("po-mcp",    lambda: mcp_add_stdio("po-mcp",    f"node {MCP_DIR}/po-mcp/dist/index.js")),
        ("whatsapp",  lambda: mcp_add_stdio("whatsapp",  f"{uv} --directory {LOCAL_DIR}/whatsapp-mcp/whatsapp-mcp-server run main.py")),
        ("zammad",    lambda: mcp_add_stdio("zammad",    f"{uv} --directory {LOCAL_DIR}/zammad-mcp run main.py")),
        ("vikunja",   lambda: mcp_add_stdio("vikunja",   f"{vpy} {LOCAL_DIR}/vikunja-mcp-new/server.py")),
        ("context7",  lambda: mcp_add_http("context7",   "https://mcp.context7.com/mcp")),
    ]
    with_progress("MCP register", tasks)

    if not mcp_has("solo") and Confirm.ask("solo MCP eklensin mi? (Solo app localhost:45678'de çalışıyor olmalı)", default=True):
        mcp_add_http("solo", "http://localhost:45678/")


def section_credentials():
    section("Credentials (interactive)")

    # GitHub PAT
    console.print(Panel(
        "[bold]GitHub MCP[/bold] (docker) için token gerekli.\n"
        "Oluştur: [link]https://github.com/settings/tokens/new?scopes=repo,workflow,read:org[/link]\n"
        "Boş geç → atla.",
        border_style="cyan",
    ))
    tok = Prompt.ask("GitHub PAT", default="", show_default=False)
    if tok and not mcp_has("github-mcp-server"):
        if have("docker"):
            cmd = f"docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN={tok} ghcr.io/github/github-mcp-server"
            run(f'claude mcp add --scope user github-mcp-server -- {cmd}')
            ok("github-mcp-server eklendi")
        else:
            warn("docker yok — GitHub MCP atlandı")

    # Credential rehberi
    guide = Table(title="Diğer MCP'ler için credential rehberi", show_header=True, border_style="dim")
    guide.add_column("MCP", style="cyan")
    guide.add_column("Yapılacak")
    guide.add_row("WhatsApp", "github.com/omert11/whatsapp-mcp README — QR okut, bridge başlat")
    guide.add_row("Zammad",   f"{LOCAL_DIR}/zammad-mcp/.env → ZAMMAD_URL + ZAMMAD_TOKEN")
    guide.add_row("Vikunja",  f"{LOCAL_DIR}/vikunja-mcp-new/.env → VIKUNJA_URL + VIKUNJA_TOKEN")
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
    section_caveman()
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
