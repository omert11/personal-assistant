#!/usr/bin/env bash
# deslop-sources.sh — fetch the live AI-writing-signal sources into a shared cache.
#
# The deslop rule set (skills/do-deslop/references/ai-writing-rules.md, BÖLÜM 0) forbids
# keeping word lists, swap tables and numeric thresholds in the repo: they go stale silently.
# They are read live from upstream on every run instead.
#
# Several do-deslop sessions run in parallel, so each fetch is cached on disk with a TTL and
# written atomically (temp file + mv) — concurrent writers cannot produce a half file.
#
# Usage:
#   deslop-sources.sh              # fetch/refresh, print manifest
#   deslop-sources.sh --extended   # also fetch the optional S6 Wikipedia pages
#   deslop-sources.sh --force      # ignore TTL, refetch everything
#
# Exit codes: 0 all mandatory sources available, 1 a mandatory source is missing entirely.

set -uo pipefail

CACHE_DIR="${DESLOP_CACHE:-$HOME/.cache/deslop-sources}"
TTL="${DESLOP_TTL:-86400}"   # 24h
EXTENDED=0
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --extended) EXTENDED=1 ;;
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$CACHE_DIR"

WIKI_BASE='https://en.wikipedia.org/w/index.php?action=raw&title='
GH_RAW='https://raw.githubusercontent.com'

# key|mandatory(1/0)|url
SOURCES=(
  "s1-wikipedia-signs|1|${WIKI_BASE}Wikipedia:Signs_of_AI_writing"
  "s2-humanizer|1|${GH_RAW}/jooray/humanizer/main/SKILL.md"
  "s2-humanizer-mirror|0|${GH_RAW}/blader/humanizer/main/SKILL.md"
  "s3-anti-slop|0|${GH_RAW}/jalaalrd/anti-ai-slop-writing/main/skills/anti-ai-slop-writing/SKILL.md"
  "s3-banned-words|0|${GH_RAW}/jalaalrd/anti-ai-slop-writing/main/skills/anti-ai-slop-writing/references/banned-words.md"
  "s4-humanise|0|${GH_RAW}/bharvey2026/humanise-skill/main/SKILL.md"
  "s5-skill|0|${GH_RAW}/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/SKILL.md"
  "s5-ai-tells|1|${GH_RAW}/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/references/ai-tells.md"
  "s5-rewrite-rules|1|${GH_RAW}/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/references/rewrite-rules.md"
  "s5-checklist|1|${GH_RAW}/haidrrrry/humanize-ai-writing/main/humanize-ai-writing/assets/checklist.md"
  "s5-prompt|0|${GH_RAW}/haidrrrry/humanize-ai-writing/main/PROMPT.md"
)

EXTENDED_SOURCES=(
  "s6-ai-comments|0|${WIKI_BASE}Wikipedia:Signs_of_AI-generated_comments"
  "s6-cleanup-guide|0|${WIKI_BASE}Wikipedia:WikiProject_AI_Cleanup/Guide_and_resources"
  "s6-unblock-requests|0|${WIKI_BASE}Wikipedia:Identifying_LLM_unblock_requests"
)

[ "$EXTENDED" -eq 1 ] && SOURCES+=("${EXTENDED_SOURCES[@]}")

# Probe the stat flavour once. GNU stat accepts -c; BSD stat rejects it. Do NOT probe the other
# way round: GNU's -f means --file-system and exits 0 with non-numeric output, so `stat -f %m`
# would look like it worked and poison the arithmetic below.
if stat -c %Y . >/dev/null 2>&1; then
  stat_mtime() { stat -c %Y "$1"; }
else
  stat_mtime() { stat -f %m "$1"; }
fi

file_age() {
  # seconds since mtime; huge number when the file is absent or mtime is unreadable
  [ -f "$1" ] || { echo 999999999; return; }
  local mtime
  mtime=$(stat_mtime "$1" 2>/dev/null)
  case "$mtime" in ''|*[!0-9]*) echo 999999999; return ;; esac
  echo $(( $(date +%s) - mtime ))
}

missing_mandatory=0

printf '%-24s %-9s %-8s %s\n' KEY STATUS BYTES PATH

for entry in "${SOURCES[@]}"; do
  IFS='|' read -r key mandatory url <<<"$entry"
  dest="$CACHE_DIR/$key.md"
  age=$(file_age "$dest")

  if [ "$FORCE" -eq 0 ] && [ "$age" -lt "$TTL" ]; then
    printf '%-24s %-9s %-8s %s\n' "$key" cached "$(wc -c <"$dest" | tr -d ' ')" "$dest"
    continue
  fi

  tmp="$dest.tmp.$$"
  if curl -sSL --fail --max-time 45 -A 'deslop-sources/1 (+claude-code)' "$url" -o "$tmp" 2>/dev/null \
     && [ -s "$tmp" ]; then
    mv -f "$tmp" "$dest"
    printf '%-24s %-9s %-8s %s\n' "$key" fresh "$(wc -c <"$dest" | tr -d ' ')" "$dest"
  else
    rm -f "$tmp"
    if [ -f "$dest" ]; then
      printf '%-24s %-9s %-8s %s\n' "$key" stale "$(wc -c <"$dest" | tr -d ' ')" "$dest"
    else
      printf '%-24s %-9s %-8s %s\n' "$key" MISSING - "$url"
      [ "$mandatory" -eq 1 ] && missing_mandatory=1
    fi
  fi
done

echo
echo "cache: $CACHE_DIR (ttl ${TTL}s)"

if [ "$missing_mandatory" -eq 1 ]; then
  cat >&2 <<'EOF'

ERROR: a mandatory source could not be fetched and no cached copy exists.
Do NOT fall back to remembered word lists (rule BÖLÜM 0 / S7.7).
A 404 usually means the file moved — list the repo tree to find it:
  curl -sL https://api.github.com/repos/<owner>/<repo>/git/trees/HEAD?recursive=1
EOF
  exit 1
fi
