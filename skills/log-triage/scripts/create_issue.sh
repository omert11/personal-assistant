#!/usr/bin/env bash
# log-triage — create a single Plane issue from an HTML description file.
#
# WHY a file: plane-cli --description-html breaks when the HTML contains shell-
# hostile chars (<, ", parentheses) passed inline. Writing the (html.escape'd)
# body to a file and reading it back avoids both quoting bugs and HTML parser
# breakage. Proven in the b2b-dmc log-triage run (inline create FAILed, file
# create succeeded).
#
# Usage:
#   create_issue.sh <project_uuid> <state_uuid> <priority> <html_file> "<title>" [label_uuid]
#
# priority: urgent | high | medium | low | none
# label_uuid (optional): attaches the "log-triage" label so future runs can
#   filter-match only this skill's own issues. STRONGLY recommended — pass it.
# Requires PLANE_URL, PLANE_API_KEY, PLANE_WORKSPACE_SLUG in env.
# Prints "<PROJ>-<n> OK | <title>" or "FAIL | <title> :: <reason>". The issue
# identifier is read from the API response (project_identifier + sequence_id),
# so it is correct for any project — never hardcoded.

set -uo pipefail

PROJ="${1:?project uuid gerekli}"
STATE="${2:?state uuid gerekli}"
PRIO="${3:?priority gerekli}"
HTML_FILE="${4:?html dosyası gerekli}"
TITLE="${5:?title gerekli}"
LABEL="${6:-}"

if [[ ! -f "$HTML_FILE" ]]; then echo "FAIL | $TITLE :: html dosyası yok: $HTML_FILE"; exit 1; fi

HTML="$(cat "$HTML_FILE")"
LABEL_ARGS=()
[[ -n "$LABEL" ]] && LABEL_ARGS=(--labels "$LABEL")

RES="$(plane-cli --json issue create "$TITLE" \
  --project "$PROJ" --state "$STATE" --priority "$PRIO" \
  "${LABEL_ARGS[@]}" \
  --description-html "$HTML" 2>&1)"

# Parse with jq so $TITLE is passed as data (--arg), never interpolated into
# source — a title with quotes/newlines/$ can't break the parser. The human
# identifier is built from the API response: "<PROJECT_IDENTIFIER>-<seq>" when
# both are present, else a bare "<seq>". On any non-JSON body or a JSON object
# without sequence_id (e.g. a plane-cli error), jq exits non-zero and the shell
# fallback prints FAIL with the first 120 chars of the raw response.
printf '%s' "$RES" | jq -er --arg title "$TITLE" '
  (.sequence_id // empty) as $seq
  | ((.project_identifier // "") as $p
     | (if $p == "" then "" else $p + "-" end) + ($seq|tostring))
    + " OK | " + $title
' 2>/dev/null || printf 'FAIL | %s :: %s\n' "$TITLE" "${RES:0:120}"
