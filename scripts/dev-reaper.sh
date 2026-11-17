#!/usr/bin/env bash
# dev-reaper — stop dev servers nobody owns or uses any more (Linux only).
#
# Agents start `vite dev` / `pnpm dev` in background shells and rarely stop them;
# the shell exits, the server is reparented to init and keeps 1.5-2 GB for hours.
# A server is reaped when its tree root has been reparented to PID 1 and no TCP
# connection to any port its tree listens on has been seen for DEV_REAPER_IDLE
# seconds. An open browser tab (HMR websocket) or a test run keeps it alive.
#
#   dev-reaper.sh          run the loop (single instance; a second start exits)
#   dev-reaper.sh --once   one pass, then exit
set -uo pipefail

[ -d /proc ] && command -v ss >/dev/null 2>&1 && command -v flock >/dev/null 2>&1 || exit 0

IDLE="${DEV_REAPER_IDLE:-1800}"
INTERVAL="${DEV_REAPER_INTERVAL:-60}"
STATE="${HEAVY_STATE_DIR:-$HOME/.cache}/dev-reaper"
LOG="$STATE.log"
SELF=$(readlink -f "$0")
mkdir -p "$STATE"

# Dev server command lines; builds and previews are not dev servers.
DEV_RE='(vite(\.js)?|next|astro|nuxt|svelte-kit)( [^ ]*)* dev( |$)|/vite/bin/vite\.js( |$)|(npm|pnpm|yarn|bun) (run )?dev( |$)|nodemon( |$)'
SKIP_RE='( build| preview)( |$)'

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >> "$LOG"; }

is_dev() {  # $1 = args
  # Only a JS runtime or package manager can be the server; anything else (a
  # claude process whose prompt mentions `pnpm dev`) merely names it.
  exe=${1%% *}
  case ${exe##*/} in node|pnpm|npm|npx|yarn|bun|nodemon) ;; *) return 1 ;; esac
  [[ $1 =~ $DEV_RE ]] && ! [[ $1 =~ $SKIP_RE ]]
}

pass() {
  now=$(date +%s)
  table=$(ps -eo pid=,ppid=,args=)
  listen=$(ss -ltnpH 2>/dev/null)
  estab=$(ss -tnH state established 2>/dev/null | awk '{ n = split($3, a, ":"); print a[n] }' | sort -u)
  seen=" "
  while read -r pid ppid args; do
    [ "$ppid" = 1 ] || continue
    is_dev "$args" || continue
    # The whole tree: pnpm -> node vite -> esbuild.
    tree=$(printf '%s\n' "$table" | awk -v root="$pid" '
      { kids[$2] = kids[$2] " " $1 }
      END { q = root; out = root
            while (q != "") { split(q, a, " "); q = ""
              for (i in a) if (a[i] in kids) { q = q kids[a[i]]; out = out kids[a[i]] } }
            print out }')
    ports=$(printf '%s\n' "$listen" | awk -v tree=" $tree " '
      { if (match($0, /pid=[0-9]+/)) { p = substr($0, RSTART + 4, RLENGTH - 4)
          if (index(tree, " " p " ")) { n = split($4, a, ":"); print a[n] } } }' | sort -u)
    stamp="$STATE/$pid"
    active=0
    for port in $ports; do
      printf '%s\n' "$estab" | grep -qx "$port" && { active=1; break; }
    done
    if [ "$active" = 1 ] || [ ! -f "$stamp" ]; then
      echo "$now" > "$stamp"
    fi
    seen="$seen$pid "
    last=$(cat "$stamp" 2>/dev/null || echo "$now")
    if [ $((now - last)) -ge "$IDLE" ]; then
      rss=$(ps -o rss= -p "$(echo $tree | tr ' ' ,)" 2>/dev/null | awk '{ s += $1 } END { printf "%d", s / 1024 }')
      cwd=$(readlink "/proc/$pid/cwd" 2>/dev/null)
      kill -TERM $tree 2>/dev/null
      log "reaped pid=$pid idle=$((now - last))s rss=${rss}MB ports=$(echo $ports) cwd=$cwd cmd=$(printf '%s' "$args" | cut -c1-160)"
      rm -f "$stamp"
    fi
  done <<EOF
$table
EOF
  # Forget servers that are gone.
  for f in "$STATE"/*; do
    [ -f "$f" ] || continue
    case "$seen" in *" ${f##*/} "*) ;; *) rm -f "$f" ;; esac
  done
}

if [ "${1:-}" = --once ]; then
  pass
  exit 0
fi

exec 9>"$STATE.lock"
if ! flock -n 9; then
  # An older copy (pre-update path) holds the lock: replace it, else leave it be.
  read -r opid opath < "$STATE.pid" 2>/dev/null || exit 0
  [ "$opath" != "$SELF" ] || exit 0
  kill "$opid" 2>/dev/null
  flock -w 10 9 || exit 0
fi
echo "$$ $SELF" > "$STATE.pid"
while :; do
  # A plugin update moves the script; the next session start runs the new copy.
  [ -f "$SELF" ] || exit 0
  # Children must not inherit the lock fd, or a killed loop leaves it held.
  pass 9>&-
  sleep "$INTERVAL" 9>&-
done
