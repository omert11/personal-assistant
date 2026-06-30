#!/usr/bin/env bash
# diji-logs — scoped VictoriaLogs query wrapper.
#
# Wraps the scope (dijiscope) log API so the skill avoids curl/quoting pitfalls.
# Reads base URL + token from env so secrets never land on the command line of a
# logged shell history more than necessary:
#
#   DL_BASE   — API root, e.g. https://scope.diji.app   (no trailing /api)
#   DL_TOKEN  — caller's personal API token (Authorization: Token <key>)
#
# Subcommands:
#   projects
#   query  <project> <env> <limit> [logsql-pipe] [start] [end]
#   count  <project> <env> <step>  [logsql-pipe] [start] [end]
#
# Output is raw JSON from the API; the caller summarizes it. Non-2xx prints the
# server's JSON error body and exits non-zero (curl -w gives the HTTP status).

set -euo pipefail

# Auto-load persisted credentials so the skill never re-prompts for the token.
# Lives outside the repo (chmod 600) — see SKILL.md "Adım 0". Already-set env vars
# win, so a one-off `DL_TOKEN=... query.sh ...` still overrides the file.
DL_ENV_FILE="${DL_ENV_FILE:-$HOME/.config/diji-logs/env}"
if [[ -f "$DL_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  _prev_base="${DL_BASE:-}"; _prev_token="${DL_TOKEN:-}"
  source "$DL_ENV_FILE"
  [[ -n "$_prev_base"  ]] && DL_BASE="$_prev_base"
  [[ -n "$_prev_token" ]] && DL_TOKEN="$_prev_token"
fi

: "${DL_BASE:?DL_BASE env required (set ~/.config/diji-logs/env or export it)}"
: "${DL_TOKEN:?DL_TOKEN env required (set ~/.config/diji-logs/env or export it)}"

BASE="${DL_BASE%/}"
AUTH="Authorization: Token ${DL_TOKEN}"

# curl that surfaces the HTTP status separately from the body, so a 400/403/502
# still shows the JSON error the API returns. Body goes to a temp file; the
# status comes from -w on stdout.
_call() {
  local method="$1" url="$2"
  shift 2
  local body_file status
  body_file="$(mktemp)"
  status="$(curl -sS -X "$method" -H "$AUTH" \
    -o "$body_file" -w '%{http_code}' "$url" "$@")"
  if [[ "$status" == 2* ]]; then
    cat "$body_file"
    rm -f "$body_file"
  else
    printf 'ERROR HTTP %s\n' "$status" >&2
    cat "$body_file" >&2
    rm -f "$body_file"
    return 1
  fi
}

cmd="${1:-}"
shift || true

case "$cmd" in
  projects)
    _call GET "${BASE}/api/logs/projects/"
    ;;

  query)
    project="${1:?project gerekli}"; env="${2:-prod}"; limit="${3:-100}"
    logsql="${4:-}"; start="${5:-}"; end="${6:-}"
    # limit must be an integer — jq --argjson rejects anything else with a cryptic
    # error. Catch a shifted/typo'd arg (e.g. a logsql pipe in the limit slot) early.
    if [[ ! "$limit" =~ ^[0-9]+$ ]]; then
      echo "HATA: limit tam sayı olmalı (verilen: '$limit')" >&2
      exit 2
    fi
    # Build JSON body safely with jq (handles quoting/escaping of logsql).
    body="$(jq -nc \
      --arg project "$project" \
      --arg env "$env" \
      --argjson limit "$limit" \
      --arg logsql "$logsql" \
      --arg start "$start" \
      --arg end "$end" \
      '{project:$project, env:$env, limit:$limit}
       + (if $logsql != "" then {logsql:$logsql} else {} end)
       + (if $start  != "" then {start:$start}   else {} end)
       + (if $end    != "" then {end:$end}       else {} end)')"
    _call POST "${BASE}/api/logs/query/" -H "Content-Type: application/json" -d "$body"
    ;;

  count)
    project="${1:?project gerekli}"; env="${2:-prod}"; step="${3:-1h}"
    logsql="${4:-}"; start="${5:-}"; end="${6:-}"
    # count/ is GET with query params; build them with --data-urlencode -G.
    args=(-G
      --data-urlencode "project=${project}"
      --data-urlencode "env=${env}"
      --data-urlencode "step=${step}")
    [[ -n "$logsql" ]] && args+=(--data-urlencode "logsql=${logsql}")
    [[ -n "$start"  ]] && args+=(--data-urlencode "start=${start}")
    [[ -n "$end"    ]] && args+=(--data-urlencode "end=${end}")
    _call GET "${BASE}/api/logs/count/" "${args[@]}"
    ;;

  *)
    cat >&2 <<'USAGE'
kullanım:
  query.sh projects
  query.sh query  <project> <env> <limit> [logsql-pipe] [start] [end]
  query.sh count  <project> <env> <step>  [logsql-pipe] [start] [end]

env: DL_BASE, DL_TOKEN
örnek:
  DL_BASE=https://scope.diji.app DL_TOKEN=xxx \
    query.sh query www.voyante.com prod 100 "filter level:error" 24h
USAGE
    exit 2
    ;;
esac
