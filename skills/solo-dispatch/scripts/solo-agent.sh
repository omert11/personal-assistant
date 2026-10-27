#!/bin/bash
# Solo agent sessions on the remote work container (and local Mac sessions).
#   solo-agent.sh spawn  remote|local <name> [prompt-file] [--resume <claude-session-uuid>]
#   solo-agent.sh send   <message-file> <target>...      target: $N (remote tmux id) | solo:<pid> (local)
#   solo-agent.sh status [target...]                      default: every remote session
#   solo-agent.sh watch                                   one line per question / milestone (bell hook)
#   solo-agent.sh close  <target> [solo-pid]
# Remote sessions are addressed by tmux session id ($N): names change with the task title.
set -e

SOCK=/Users/omerfarukyigin/Desktop/Git/.tmux-sock/work
BELL_LOG=/Users/omerfarukyigin/.cache/tmux-bells.log
T="podman exec -i work tmux -S $SOCK"
FOOTER="Bu mesajdaki kuralları hafızaya (memory) yazma; yalnız bu oturum için geçerli."
QUESTION_RE='Enter to select|Do you want|❯ 1\.'
MILESTONE_RE='merge edildi|PR #[0-9]+ merge|dw-share ile|hit your limit|usage limit reached|limit reached'

rt() { ssh diji-dev "$T $*" </dev/null; }

project_id() {
  root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  solo projects list --json --limit 500 | python3 -c '
import json,sys
root=sys.argv[1]
for p in json.load(sys.stdin)["data"]["projects"]:
    if p["path"]==root: print(p["id"]); break' "$root"
}

tool_id() {
  solo agents list --json | python3 -c '
import json,sys
for a in json.load(sys.stdin)["data"]["agentTools"]:
    if a["command"]==sys.argv[1] and a["enabled"]: print(a["id"]); break' "$1"
}

screen() { rt "capture-pane -p -t '$1:'" | grep -v '^[[:space:]]*$' | tail -${2:-14}; }

paste_remote() {  # paste a file into a remote session and submit it
  ssh diji-dev "$T load-buffer -b sa -" < "$2"
  rt "paste-buffer -p -d -b sa -t '$1:'"
  sleep 2
  rt "send-keys -t '$1:' Enter"
}

cmd_spawn() {
  kind=$1 name=$2 prompt=$3; shift 3 || true
  resume=
  [ "$1" = --resume ] && resume=$2
  [ "$prompt" = --resume ] && { resume=$1; prompt=; }
  pid_proj=$(project_id)
  [ -n "$pid_proj" ] || { echo "solo project not found for $(pwd)" >&2; exit 1; }
  if [ "$kind" = local ]; then
    tool=$(tool_id claude)
    args=""; [ -n "$resume" ] && args="--arg --resume --arg $resume"
    pid=$(solo processes spawn --project-id "$pid_proj" --kind agent --agent-tool-id "$tool" --name "$name" $args --json \
      | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"]["id"])')
    for i in $(seq 1 40); do solo processes output "$pid" 2>/dev/null | grep -q 'bypass permissions' && break; sleep 1; done
    [ -n "$prompt" ] && solo processes input "$pid" --text - < "$prompt" >/dev/null
    echo "solo=$pid target=solo:$pid"
    return
  fi
  tool=$(tool_id "dw claude")
  before=$(rt "ls -F '#{session_id}'" | sort)
  args=""; [ -n "$resume" ] && args="--arg --resume --arg $resume"
  pid=$(solo processes spawn --project-id "$pid_proj" --kind agent --agent-tool-id "$tool" --name "$name" $args --json \
    | python3 -c 'import json,sys;print(json.load(sys.stdin)["data"]["id"])')
  sid=
  for i in $(seq 1 40); do
    sid=$(comm -13 <(printf '%s\n' "$before") <(rt "ls -F '#{session_id}'" | sort) | head -1)
    [ -n "$sid" ] && break; sleep 1
  done
  [ -n "$sid" ] || { echo "solo=$pid: tmux session not found" >&2; exit 1; }
  for i in $(seq 1 60); do screen "$sid" 40 | grep -q 'bypass permissions' && break; sleep 1; done
  [ -n "$prompt" ] && paste_remote "$sid" "$prompt"
  echo "solo=$pid target=$sid"
}

cmd_send() {
  msg=$1; shift
  tmp=$(mktemp); { cat "$msg"; printf '\n%s\n' "$FOOTER"; } > "$tmp"
  # First words of the first line: a pane line never spans a newline, and word cuts stay UTF-8 safe.
  key=$(head -n1 "$msg" | cut -d' ' -f1-5)
  for t in "$@"; do
    case $t in
      solo:*)
        solo processes input "${t#solo:}" --text - < "$tmp" >/dev/null && echo "$t sent" ;;
      *)
        if screen "$t" | grep -q -E "$QUESTION_RE"; then echo "$t SKIP (question open)"; continue; fi
        paste_remote "$t" "$tmp"; sleep 4
        rt "capture-pane -p -S -80 -t '$t:'" | grep -qF "$key" && echo "$t sent" || echo "$t NOT CONFIRMED" ;;
    esac
  done
  rm -f "$tmp"
}

cmd_status() {
  [ $# -gt 0 ] || set -- $(rt "ls -F '#{session_id}'")
  for t in "$@"; do
    case $t in
      solo:*) scr=$(solo processes output "${t#solo:}" 2>/dev/null | grep -v '^[[:space:]]*$' | tail -14); name=$t ;;
      *) scr=$(screen "$t"); name="$t $(rt "display -p -t '$t:' '#{session_name}'")" ;;
    esac
    if printf '%s' "$scr" | grep -q -E "$QUESTION_RE"; then st=SORU
    elif printf '%s' "$scr" | grep -q -E '…|esc to interrupt|still running|Waiting for'; then st=ÇALIŞIYOR
    else st=BOŞTA; fi
    echo "=== $name [$st]"
    printf '%s\n' "$scr" | grep -v -E '^[[:space:]]*(─|⏵)' | tail -8
  done
}

cmd_watch() {
  while true; do
    ssh -o ServerAliveInterval=30 diji-dev "podman exec work tail -n0 -F $BELL_LOG" 2>/dev/null </dev/null |
    while read -r ts tty name; do
      id=$(rt "list-panes -a -F '#{session_id} #{pane_tty}'" | awk -v t="$tty" '$2==t{print $1}')
      [ -n "$id" ] || continue
      scr=$(screen "$id")
      if printf '%s' "$scr" | grep -q -E "$QUESTION_RE"; then echo "$ts SORU $id $name"
      elif printf '%s' "$scr" | grep -q -i -E "$MILESTONE_RE"; then echo "$ts OLAY $id $name"; fi
    done
    sleep 5
  done
}

cmd_close() {
  case $1 in
    solo:*) solo processes stop "${1#solo:}" >/dev/null; solo processes delete "${1#solo:}" --confirm-stop-running >/dev/null ;;
    *) name=$(rt "display -p -t '$1:' '#{session_name}'")
       ssh diji-dev "podman exec work work-kill-sessions '$name'" </dev/null
       [ -n "$2" ] && { solo processes stop "$2" >/dev/null 2>&1 || true; solo processes delete "$2" --confirm-stop-running >/dev/null 2>&1 || true; } ;;
  esac
  echo "$1 closed"
}

c=$1; shift || true
case $c in
  spawn) cmd_spawn "$@" ;;
  send) cmd_send "$@" ;;
  status) cmd_status "$@" ;;
  watch) cmd_watch ;;
  close) cmd_close "$@" ;;
  *) sed -n '2,7p' "$0"; exit 2 ;;
esac
