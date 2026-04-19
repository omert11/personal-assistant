#!/bin/bash
# Rules loader for personal-assistant plugin
# SessionStart hook — stdout is injected into Claude's context

RULES_DIR="${CLAUDE_PLUGIN_ROOT}/rules"
LOCAL_RULES_DIR="${CLAUDE_PLUGIN_ROOT}/local-rules"

echo "# Global Rules (personal-assistant plugin)"
echo ""
echo "Aşağıdaki kurallar tüm projeler için geçerlidir. Bunlara uy."
echo ""

load_dir() {
  local dir="$1"
  local label="$2"
  [ -d "$dir" ] || return 0
  for rule_file in "$dir"/*.md; do
    [ -f "$rule_file" ] || continue
    rule_name=$(basename "$rule_file" .md)
    echo "## Rule: $rule_name${label}"
    echo ""
    cat "$rule_file"
    echo ""
    echo "---"
    echo ""
  done
}

load_dir "$RULES_DIR" ""
load_dir "$LOCAL_RULES_DIR" " (local)"

exit 0
