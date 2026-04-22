#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["markitdown[all]"]
# ///
"""crawl2md.py — recursive same-host crawler → markdown via markitdown.

Usage:
    ./crawl2md.py <START_URL> <OUT_DIR> [--depth N] [--delay S] [--include-binary]

Args:
    START_URL            Starting URL (host is locked to this).
    OUT_DIR              Output directory (created if missing).
    --depth N            BFS depth limit. Default: 3
    --delay S            Per-request delay in seconds. Default: 0.5
    --include-binary     Also download PDFs/Office docs (markitdown supports them).

Runs via `uv run` (PEP 723 inline metadata). First run resolves markitdown
into a cached ephemeral venv; subsequent runs reuse the cache.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import os
import re
import sys
import time
import urllib.parse as up
import urllib.request as ur
from collections import deque
from pathlib import Path

from markitdown import MarkItDown

USER_AGENT = "Mozilla/5.0 crawl2md"
HREF_RE = re.compile(r"""href\s*=\s*["']([^"'#]+)["']""", re.IGNORECASE)
_MD = MarkItDown()

SKIP_EXT_DEFAULT = (
    ".zip", ".tar", ".gz", ".7z", ".rar",
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".ico",
    ".mp4", ".mp3", ".wav", ".avi", ".mov",
    ".css", ".js", ".woff", ".woff2", ".ttf", ".eot",
    ".xml", ".php",
)
BINARY_KEEP = (".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx")


def normalize(url: str) -> str:
    p = up.urlparse(url)
    path = re.sub(r"/+", "/", p.path) or "/"
    return up.urlunparse((p.scheme, p.netloc.lower(), path, p.params, p.query, ""))


def url_to_filepath(url: str, out_dir: Path) -> Path:
    p = up.urlparse(url)
    path = p.path.strip("/")
    if not path:
        rel = "index.md"
    elif p.path.endswith("/"):
        rel = os.path.join(path, "index.md")
    else:
        rel = path + ".md"
    if p.query:
        h = hashlib.md5(p.query.encode()).hexdigest()[:8]
        base, ext = os.path.splitext(rel)
        rel = f"{base}__{h}{ext}"
    return out_dir / rel


def fetch(url: str, timeout: int = 30) -> bytes | None:
    try:
        req = ur.Request(url, headers={"User-Agent": USER_AGENT})
        with ur.urlopen(req, timeout=timeout) as r:
            return r.read()
    except Exception as e:
        print(f"  ! fetch error: {e}", file=sys.stderr)
        return None


def extract_links(base_url: str, html: str, include_binary: bool) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    skip = SKIP_EXT_DEFAULT if include_binary else SKIP_EXT_DEFAULT + BINARY_KEEP
    for h in HREF_RE.findall(html):
        h = h.strip()
        if not h or h.startswith(("mailto:", "tel:", "javascript:", "data:")):
            continue
        absu = up.urljoin(base_url, h)
        p = up.urlparse(absu)
        if p.scheme not in ("http", "https"):
            continue
        if p.path.lower().endswith(skip):
            continue
        norm = normalize(absu)
        if norm not in seen:
            seen.add(norm)
            out.append(norm)
    return out


def content_type(url: str, body: bytes) -> str:
    lower = up.urlparse(url).path.lower()
    if lower.endswith(".pdf"):
        return ".pdf"
    if lower.endswith((".doc", ".docx")):
        return ".docx"
    if lower.endswith((".xls", ".xlsx")):
        return ".xlsx"
    if lower.endswith((".ppt", ".pptx")):
        return ".pptx"
    return ".html"


def to_markdown(body: bytes, hint: str, out_path: Path) -> bool:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        result = _MD.convert_stream(io.BytesIO(body), file_extension=hint)
        out_path.write_text(result.text_content, encoding="utf-8")
        return out_path.stat().st_size > 0
    except Exception as e:
        print(f"  ! markitdown failed: {e}", file=sys.stderr)
        return False


def crawl(start: str, out_dir: Path, max_depth: int, delay: float, include_binary: bool) -> int:
    host = up.urlparse(start).netloc.lower()
    if not host:
        print(f"Invalid URL: {start}", file=sys.stderr)
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)

    visited: set[str] = set()
    queue: deque[tuple[int, str]] = deque()
    queue.append((0, normalize(start)))
    written = 0

    while queue:
        depth, url = queue.popleft()
        if url in visited:
            continue
        visited.add(url)

        if up.urlparse(url).netloc.lower() != host:
            continue

        out_path = url_to_filepath(url, out_dir)
        print(f"→ [d={depth}] {url}")
        body = fetch(url)
        if not body:
            continue

        hint = content_type(url, body)
        if to_markdown(body, hint, out_path):
            size = out_path.stat().st_size
            print(f"  ✓ {out_path} ({size} bytes)")
            written += 1
        else:
            print(f"  ✗ conversion failed for {url}")
            if out_path.exists() and out_path.stat().st_size == 0:
                out_path.unlink()
            continue

        if depth < max_depth and hint == ".html":
            try:
                html = body.decode("utf-8", errors="replace")
            except Exception:
                html = ""
            for child in extract_links(url, html, include_binary):
                if child not in visited:
                    queue.append((depth + 1, child))

        time.sleep(delay)

    return written


def main() -> int:
    ap = argparse.ArgumentParser(description="Recursive URL → markdown crawler.")
    ap.add_argument("start_url")
    ap.add_argument("out_dir")
    ap.add_argument("--depth", type=int, default=3)
    ap.add_argument("--delay", type=float, default=0.5)
    ap.add_argument("--include-binary", action="store_true",
                    help="Also convert PDF/Office docs (off by default).")
    args = ap.parse_args()

    n = crawl(args.start_url, Path(args.out_dir), args.depth, args.delay, args.include_binary)
    print(f"---\nDone. {n} pages written to {args.out_dir}")
    return 0 if n > 0 else 1


if __name__ == "__main__":
    sys.exit(main())
