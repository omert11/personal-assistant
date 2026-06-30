#!/usr/bin/env bash
# log-triage — split a time range into N equal windows and write a stratified
# log dump per window, ready for per-angle subagent analysis.
#
# Strategy (proven, project-independent): a raw dump of every log line is
# unusable (one 15-min window can hold ~40k DEBUG lines). Instead each window
# file carries:
#   - error_warn   : ALL raw ERROR+WARN lines (the signal, usually < 1000)
#   - error_msg_agg: ERROR messages grouped by _msg
#   - warn_msg_agg : WARN messages grouped by _msg
#   - debug_msg_agg: top DEBUG messages grouped by _msg (noise / hot loops)
#   - sql_agg      : "gorm query" SQL grouped (collapse_nums) — N+1 / repeats
#   - slow_query   : raw slow-query lines, sorted by duration
#
# This shape lets one subagent per angle (errors / perf / workflow / hygiene)
# read the SAME file and pull what it needs.
#
# Usage:
#   fetch_windows.sh <project> <env> <total_minutes> <num_windows> <out_dir> [query.sh path]
#
# Example (last 60 min in 4 x 15-min windows):
#   fetch_windows.sh b2b.b2btravel.pro prod 60 4 /tmp/logwin
#
# Relative-offset windowing: VictoriaLogs accepts two relative offsets
# (start="30m" end="15m" → the slice 30..15 min ago). RFC3339 start/end is
# unreliable through this API, so we use relative offsets only.

set -uo pipefail

PROJECT="${1:?project gerekli}"
ENV="${2:-prod}"
TOTAL_MIN="${3:-60}"
NUM_WIN="${4:-4}"
OUT_DIR="${5:?out_dir gerekli}"
QS="${6:-$HOME/Desktop/Git/personal-assistant/skills/diji-logs/scripts/query.sh}"

if [[ ! -x "$QS" && ! -f "$QS" ]]; then
  echo "HATA: query.sh bulunamadı: $QS" >&2
  echo "diji-logs skill'inin scripts/query.sh yolunu 6. argümanla geç." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
if (( NUM_WIN < 1 )); then echo "HATA: pencere sayısı < 1 (NUM_WIN=$NUM_WIN)" >&2; exit 1; fi
WIN_MIN=$(( TOTAL_MIN / NUM_WIN ))
if (( WIN_MIN < 1 )); then echo "HATA: pencere boyutu < 1dk" >&2; exit 1; fi

# Run a query and emit its logs array (or [] on any failure). strict=False
# tolerates control chars embedded in log messages.
runq() {
  local start="$1" end="$2" limit="$3" pipe="$4"
  "$QS" query "$PROJECT" "$ENV" "$limit" "$pipe" "$start" "$end" 2>/dev/null \
    | python3 -c "import sys,json
try:
  d=json.load(sys.stdin); print(json.dumps(d.get('logs',[]),ensure_ascii=False))
except Exception: print('[]')" 2>/dev/null || echo '[]'
}

echo "Pencere: ${NUM_WIN} x ${WIN_MIN}dk (toplam ${TOTAL_MIN}dk) → $OUT_DIR"

for (( i=0; i<NUM_WIN; i++ )); do
  # Window i covers [start..end] minutes ago. i=0 is the most recent slice.
  start_off=$(( (i+1) * WIN_MIN ))   # older bound (minutes ago)
  end_off=$(( i * WIN_MIN ))          # newer bound (minutes ago)
  start="${start_off}m"
  end="${end_off}m"
  [[ "$end_off" -eq 0 ]] && end=""   # most-recent window: open end
  name="P$((i+1))"
  out="$OUT_DIR/${name}.json"

  {
    echo "{"
    echo "\"window\":\"$name\",\"start_offset\":\"$start\",\"end_offset\":\"${end:-now}\",\"window_min\":$WIN_MIN,"
    echo "\"error_warn\":$(runq "$start" "$end" 1000 'filter (level:ERROR OR level:WARN) | sort by (_time desc)'),"
    echo "\"error_msg_agg\":$(runq "$start" "$end" 1000 'filter level:ERROR | stats by (_msg) count() c | sort by (c desc)'),"
    echo "\"warn_msg_agg\":$(runq "$start" "$end" 1000 'filter level:WARN | stats by (_msg) count() c | sort by (c desc)'),"
    echo "\"debug_msg_agg\":$(runq "$start" "$end" 1000 'filter level:DEBUG | stats by (_msg) count() c | sort by (c desc) | limit 40'),"
    echo "\"sql_agg\":$(runq "$start" "$end" 1000 'filter _msg:"gorm query" | collapse_nums | stats by (sql) count() c | sort by (c desc) | limit 40'),"
    echo "\"slow_query\":$(runq "$start" "$end" 200 'filter _msg:"gorm slow query" | fields _time,sql,duration_ms,tenant | sort by (duration_ms desc)')"
    echo "}"
  } > "$out"

  # Normalize: re-dump clean JSON (escape embedded control chars) so subagents'
  # Read tool gets valid JSON. Report per-section counts. Path/name are passed
  # via the environment (not interpolated into the Python source), so a quote or
  # space in $OUT_DIR can never break the script.
  OUT="$out" NAME="$name" python3 -c "
import json,os,sys
out=os.environ['OUT']; name=os.environ['NAME']
try:
    d=json.loads(open(out).read(),strict=False)
    json.dump(d, open(out,'w'), ensure_ascii=False, indent=1)
    print('%s OK: EW=%d Eagg=%d Wagg=%d Dagg=%d SQL=%d slow=%d' % (
        name,len(d['error_warn']),len(d['error_msg_agg']),len(d['warn_msg_agg']),
        len(d['debug_msg_agg']),len(d['sql_agg']),len(d['slow_query'])))
except Exception as ex:
    print('%s PARSE FAIL: %s' % (name, ex), file=sys.stderr)
"
done

echo "Tüm pencereler yazıldı: $OUT_DIR"
ls -1 "$OUT_DIR"/*.json
