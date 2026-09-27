#!/usr/bin/env python3
"""Build the omp (oh-my-pi) port of this Claude Code plugin into targets/omp/.

Claude-side sources (rules/, skills/, local-skills/, agents/) stay canonical;
omp/ holds only omp-specific overlays. See omp/translate.sed for the text
mapping. Output is gitignored because it embeds local-skills/ (credentials).

Usage: python3 scripts/build-omp.py [--link] [--quiet]
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OMP = ROOT / "omp"
TARGETS = ROOT / "targets"
OUT = TARGETS / "omp"

SKIP_NAMES = {".DS_Store", "__pycache__"}
SKIP_SUFFIXES = {".pyc"}
TEXT_SUFFIXES = {".md", ".ts", ".json", ".sh", ".py", ".js", ".mjs", ".cjs"}
DROP_SKILL_KEYS = {"allowed-tools", "effort"}

SHA_RE = re.compile(r"^<!--\s*omp-source-sha256:\s*([0-9a-fA-F]{64})\s*-->[ \t]*\r?\n?")
FM_KEY_RE = re.compile(r"^([A-Za-z0-9_-]+):(?:[ \t]+(.*))?$")
PLAIN_SCALAR_RE = re.compile(r"^(true|false|null|~|-?\d+(\.\d+)?)$")
TRIGGER_PREFIX_RE = re.compile(r"^Trigger\s*[—–:-]\s*")
SKILL_DIR_RE = re.compile(r"\$\{CLAUDE_SKILL_DIR\}|\$CLAUDE_SKILL_DIR(?![A-Za-z0-9_])")
SED_SPLIT = "@@PA-OMP-BUILD-SPLIT-7f3c1e@@"


class BuildError(Exception):
    pass


class Builder:
    def __init__(self, quiet: bool) -> None:
        self.quiet = quiet
        self.warnings: list[str] = []
        self.root_str = str(ROOT)
        # (relative output path, text, skill name or None) — pending sed translation
        self.pending: list[tuple[Path, str, str | None]] = []

    # --- reporting -------------------------------------------------------
    def warn(self, msg: str) -> None:
        self.warnings.append(msg)
        print(f"WARN {msg}", file=sys.stderr)

    def info(self, msg: str) -> None:
        if not self.quiet:
            print(msg)

    # --- helpers ---------------------------------------------------------
    @staticmethod
    def load_json(path: Path, default):
        if not path.exists():
            return default
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError) as exc:
            raise BuildError(f"invalid JSON in {path.relative_to(ROOT)}: {exc}") from exc

    def subst(self, text: str, skill: str | None) -> str:
        text = text.replace("${CLAUDE_PLUGIN_ROOT}", self.root_str).replace("@PA_ROOT@", self.root_str)
        if skill is not None:
            skill_dir = str(OUT / "skills" / skill)
            text = SKILL_DIR_RE.sub(lambda _m: skill_dir, text)
        return text

    def check_drift(self, overlay: Path, text: str, source: Path | None) -> str:
        """Verify and strip the first-line source sha comment of an override/overlay."""
        rel = overlay.relative_to(ROOT)
        m = SHA_RE.match(text)
        if m is None:
            if source is not None and source.exists():
                self.warn(f"no omp-source-sha256 comment: {rel} (ports {source.relative_to(ROOT)})")
            return text
        if source is None or not source.exists():
            self.warn(f"drift: {rel} (source missing)")
        elif hashlib.sha256(source.read_bytes()).hexdigest() != m.group(1).lower():
            self.warn(f"drift: {rel}")
        return text[m.end():]

    @staticmethod
    def iter_files(base: Path):
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = sorted(d for d in dirnames if d not in SKIP_NAMES)
            for name in sorted(filenames):
                if name in SKIP_NAMES or Path(name).suffix in SKIP_SUFFIXES:
                    continue
                yield Path(dirpath) / name

    def write(self, stage: Path, rel: Path, text: str) -> None:
        dest = stage / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(text, encoding="utf-8")

    def copy_file(self, stage: Path, rel: Path, src: Path, skill: str | None) -> None:
        dest = stage / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        if src.suffix in TEXT_SUFFIXES:
            try:
                text = src.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                shutil.copyfile(src, dest)
            else:
                dest.write_text(self.subst(text, skill), encoding="utf-8")
        else:
            shutil.copyfile(src, dest)
        shutil.copymode(src, dest)

    def run_sed(self) -> list[str]:
        """Translate all pending texts with one sed run (rules are line-local)."""
        if not self.pending:
            return []
        sed_file = OMP / "translate.sed"
        if not sed_file.exists():
            raise BuildError("omp/translate.sed missing")
        parts = []
        for _rel, text, _skill in self.pending:
            if SED_SPLIT in text:
                raise BuildError("sed split marker found in source text")
            parts.append(text if text.endswith("\n") else text + "\n")
        joined = f"{SED_SPLIT}\n".join(parts)
        env = dict(os.environ, LC_ALL="C")
        proc = subprocess.run(
            ["sed", "-E", "-f", str(sed_file)],
            input=joined.encode("utf-8"),
            capture_output=True,
            env=env,
        )
        if proc.returncode != 0:
            raise BuildError(f"sed failed: {proc.stderr.decode('utf-8', 'replace').strip()}")
        out = proc.stdout.decode("utf-8").split(f"{SED_SPLIT}\n")
        if len(out) != len(self.pending):
            raise BuildError("sed output split mismatch")
        result = []
        for (_rel, orig, _skill), text in zip(self.pending, out):
            result.append(text if orig.endswith("\n") else text[:-1])
        return result

    # --- frontmatter -----------------------------------------------------
    @staticmethod
    def split_frontmatter(text: str) -> tuple[list[str] | None, str]:
        lines = text.split("\n")
        if not lines or lines[0].rstrip() != "---":
            return None, text
        for i in range(1, len(lines)):
            if lines[i].rstrip() == "---":
                return lines[1:i], "\n".join(lines[i + 1:])
        return None, text

    @staticmethod
    def parse_entries(fm_lines: list[str]) -> list[tuple[str | None, list[str]]]:
        """Group frontmatter lines into (key, raw lines); continuation lines stay with their key."""
        entries: list[tuple[str | None, list[str]]] = []
        for line in fm_lines:
            m = FM_KEY_RE.match(line)
            if m and not line[:1].isspace():
                entries.append((m.group(1), [line]))
            elif entries:
                entries[-1][1].append(line)
            else:
                entries.append((None, [line]))
        return entries

    @staticmethod
    def scalar_value(raw_lines: list[str]) -> str:
        first = FM_KEY_RE.match(raw_lines[0]).group(2) or ""
        first = first.strip()
        rest = [l.strip() for l in raw_lines[1:]]
        if first[:1] in "|>" and re.fullmatch(r"[|>][+-]?", first or "|"):
            body = [l for l in rest]
            return ("\n" if first.startswith("|") else " ").join(body).strip()
        value = " ".join([first] + [l for l in rest if l]).strip()
        if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
            try:
                return str(json.loads(value))
            except ValueError:
                return value[1:-1]
        if len(value) >= 2 and value[0] == "'" and value[-1] == "'":
            return value[1:-1].replace("''", "'")
        return value

    @staticmethod
    def emit_value(value) -> str:
        if isinstance(value, str):
            return json.dumps(value, ensure_ascii=False)
        return json.dumps(value, ensure_ascii=False)

    def emit_scalar_line(self, key: str, raw_lines: list[str]) -> list[str]:
        """Re-emit a single-line scalar safely quoted; keep structured values verbatim."""
        if len(raw_lines) > 1:
            return raw_lines
        value = self.scalar_value(raw_lines)
        if value == "" or PLAIN_SCALAR_RE.match(value):
            return raw_lines
        return [f"{key}: {self.emit_value(value)}"]

    def transform_skill_md(self, text: str, rel: Path) -> str:
        fm, body = self.split_frontmatter(text)
        if fm is None:
            self.warn(f"no frontmatter: {rel}")
            return text
        entries = self.parse_entries(fm)
        values = {k: self.scalar_value(v) for k, v in entries if k in ("description", "when_to_use")}
        out: list[str] = []
        for key, raw in entries:
            if key is None:
                out.extend(raw)
            elif key in DROP_SKILL_KEYS:
                continue
            elif key == "description":
                desc = values["description"]
                trig = TRIGGER_PREFIX_RE.sub("", values.get("when_to_use", "")).strip()
                if trig and " Trigger: " not in desc:
                    desc = f"{desc} Trigger: {trig}"
                out.append(f"description: {self.emit_value(desc)}")
            else:
                out.extend(self.emit_scalar_line(key, raw))
        return "---\n" + "\n".join(out) + "\n---\n" + body

    def rule_frontmatter(self, meta: dict) -> str:
        lines = [f"{k}: {self.emit_value(v)}" for k, v in meta.items()]
        return "---\n" + "\n".join(lines) + "\n---\n\n"

    # --- sections --------------------------------------------------------
    def build(self) -> Path:
        cfg = self.load_json(OMP / "build.json", {})
        if not isinstance(cfg, dict):
            raise BuildError("omp/build.json must be an object")
        exclude_skills = set(cfg.get("excludeSkills", []))
        exclude_rules = set(cfg.get("excludeRules", []))
        rules_meta = self.load_json(OMP / "rules.json", {})
        if not isinstance(rules_meta, dict):
            raise BuildError("omp/rules.json must be an object")
        for name, meta in rules_meta.items():
            if not isinstance(meta, dict):
                raise BuildError(f"omp/rules.json[{name!r}] must be an object")
        plugin = self.load_json(ROOT / ".claude-plugin" / "plugin.json", None)
        pkg = self.load_json(OMP / "package.json", None)
        if not isinstance(plugin, dict) or "version" not in plugin:
            raise BuildError(".claude-plugin/plugin.json missing or without version")
        if not isinstance(pkg, dict) or not isinstance(pkg.get("omp", pkg.get("pi")), dict):
            raise BuildError("omp/package.json missing or without an `omp` manifest object")

        TARGETS.mkdir(exist_ok=True)
        stage = Path(tempfile.mkdtemp(prefix=".omp-build-", dir=TARGETS))
        try:
            pkg["version"] = plugin["version"]
            self.write(stage, Path("package.json"), json.dumps(pkg, indent=2, ensure_ascii=False) + "\n")
            self.build_rules(stage, rules_meta, exclude_rules)
            self.build_skills(stage, exclude_skills)
            self.build_agents(stage)
            self.build_hooks(stage)
        except BaseException:
            shutil.rmtree(stage, ignore_errors=True)
            raise
        return stage

    def build_rules(self, stage: Path, rules_meta: dict, exclude: set[str]) -> None:
        src_dir = ROOT / "rules"
        sources: dict[str, Path] = {f.stem: f for f in sorted(src_dir.glob("*.md"))} if src_dir.is_dir() else {}
        overrides_dir = OMP / "rules"
        overrides = {f.stem: f for f in sorted(overrides_dir.glob("*.md"))} if overrides_dir.is_dir() else {}
        for name in sorted(exclude - set(sources) - set(overrides)):
            self.warn(f"excludeRules entry matches no rule: {name}")

        bodies: dict[str, str] = {}
        translate_names: list[str] = []
        for name in sorted(set(sources) | set(overrides)):
            if name in exclude:
                continue
            if name in overrides:
                text = overrides[name].read_text(encoding="utf-8")
                bodies[name] = self.check_drift(overrides[name], text, sources.get(name))
            else:
                translate_names.append(name)

        self.pending = [(Path(n), sources[n].read_text(encoding="utf-8"), None) for n in translate_names]
        for name, text in zip(translate_names, self.run_sed()):
            fm, body = self.split_frontmatter(text)
            if fm is not None:
                self.warn(f"source frontmatter dropped: {sources[name].relative_to(ROOT)}")
                text = body.lstrip("\n")
            bodies[name] = text

        for name in sorted(bodies):
            body = bodies[name]
            fm, _ = self.split_frontmatter(body)
            if fm is not None:
                # Override written with its own omp frontmatter.
                if name in rules_meta:
                    self.warn(f"rules.json entry ignored, override has own frontmatter: {name}")
                text = body
            else:
                meta = rules_meta.get(name)
                if meta is None:
                    self.warn(f"rule not in omp/rules.json, defaulting to alwaysApply: {name}")
                    meta = {"alwaysApply": True}
                text = self.rule_frontmatter(meta) + body.lstrip("\n")
            self.write(stage, Path("rules") / f"{name}.md", self.subst(text, None))
        for name in sorted(set(rules_meta) - set(bodies) - exclude):
            self.warn(f"omp/rules.json entry matches no rule: {name}")

    def build_skills(self, stage: Path, exclude: set[str]) -> None:
        # Committed skills/ and gitignored local-skills/ share one namespace.
        bases: dict[str, Path] = {}
        for src_root in (ROOT / "skills", ROOT / "local-skills"):
            if not src_root.is_dir():
                continue
            for p in sorted(src_root.iterdir()):
                if not p.is_dir():
                    continue
                if p.name in bases:
                    raise BuildError(f"skill name collision: {p.relative_to(ROOT)} vs {bases[p.name].relative_to(ROOT)}")
                bases[p.name] = p
        skills = sorted(bases)
        ov_root = OMP / "skills"
        overlays = sorted(p.name for p in ov_root.iterdir() if p.is_dir()) if ov_root.is_dir() else []
        for name in sorted(exclude - set(skills)):
            self.warn(f"excludeSkills entry matches no skill: {name}")

        self.pending = []
        for name in skills:
            if name in exclude:
                continue
            base = bases[name]
            for f in self.iter_files(base):
                rel = Path("skills") / name / f.relative_to(base)
                if f.suffix == ".md":
                    self.pending.append((rel, f.read_text(encoding="utf-8"), name))
                else:
                    self.copy_file(stage, rel, f, name)
        pending = self.pending
        for (rel, _orig, name), text in zip(pending, self.run_sed()):
            self.write(stage, rel, self.subst(text, name))

        for name in overlays:
            if name in exclude:
                self.warn(f"overlay for excluded skill ignored: omp/skills/{name}")
                continue
            base = ov_root / name
            for f in self.iter_files(base):
                sub = f.relative_to(base)
                rel = Path("skills") / name / sub
                if f.suffix == ".md":
                    source = bases[name] / sub if name in bases else None
                    text = self.check_drift(f, f.read_text(encoding="utf-8"), source)
                    self.write(stage, rel, self.subst(text, name))
                    shutil.copymode(f, stage / rel)
                else:
                    self.copy_file(stage, rel, f, name)

        # Frontmatter transform on the final SKILL.md (translated or overlaid).
        out_root = stage / "skills"
        if out_root.is_dir():
            for skill_md in sorted(out_root.glob("*/SKILL.md")):
                rel = skill_md.relative_to(stage)
                skill_md.write_text(self.transform_skill_md(skill_md.read_text(encoding="utf-8"), rel), encoding="utf-8")

    def build_agents(self, stage: Path) -> None:
        src_dir = ROOT / "agents"
        ov_dir = OMP / "agents"
        sources = {f.stem: f for f in sorted(src_dir.glob("*.md"))} if src_dir.is_dir() else {}
        overrides = {f.stem: f for f in sorted(ov_dir.glob("*.md"))} if ov_dir.is_dir() else {}
        names = sorted(n for n in sources if n not in overrides)
        self.pending = [(Path(n), sources[n].read_text(encoding="utf-8"), None) for n in names]
        for name, text in zip(names, self.run_sed()):
            self.write(stage, Path("agents") / f"{name}.md", self.subst(text, None))
        for name, f in overrides.items():
            text = self.check_drift(f, f.read_text(encoding="utf-8"), sources.get(name))
            self.write(stage, Path("agents") / f"{name}.md", self.subst(text, None))
        (stage / "agents").mkdir(exist_ok=True)

    def build_hooks(self, stage: Path) -> None:
        base = OMP / "hooks"
        if not base.is_dir():
            return
        for f in self.iter_files(base):
            self.copy_file(stage, Path("hooks") / f.relative_to(base), f, None)


def swap_into_place(stage: Path) -> None:
    """Replace targets/omp with the staged build (two renames; old tree removed after)."""
    old = None
    if OUT.exists() or OUT.is_symlink():
        old = TARGETS / f".omp-old-{os.getpid()}"
        os.rename(OUT, old)
    try:
        os.rename(stage, OUT)
    except OSError:
        if old is not None:
            os.rename(old, OUT)
        raise
    if old is not None:
        shutil.rmtree(old, ignore_errors=True)


def link() -> None:
    proc = subprocess.run(["omp", "plugin", "link", str(OUT)], capture_output=True, text=True)
    if proc.returncode != 0:
        raise BuildError(f"omp plugin link failed: {(proc.stderr or proc.stdout).strip()}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Build the omp port into targets/omp/.")
    ap.add_argument("--link", action="store_true", help="also run `omp plugin link targets/omp`")
    ap.add_argument("--quiet", action="store_true", help="print only warnings and errors")
    args = ap.parse_args()

    builder = Builder(args.quiet)
    try:
        stage = builder.build()
        swap_into_place(stage)
        if args.link:
            link()
    except BuildError as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        return 1
    builder.info(f"built {OUT.relative_to(ROOT)} ({len(builder.warnings)} warnings)")
    if args.link:
        builder.info(f"linked {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
