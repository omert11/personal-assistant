#!/bin/sh
# SessionStart hook (Claude Code) / session hook (omp): when the session cwd is a
# Django project, print the django skill body so it lands in the model context.
# Detection: manage.py at the project root or one level below (e.g. djangomain/).
# Prints nothing outside Django projects, so other sessions pay no context cost.
set -e

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
SKILL="$ROOT/skills/django/SKILL.md"

[ -f "$SKILL" ] || exit 0

found=""
if [ -f "$PROJECT/manage.py" ]; then
  found="manage.py"
else
  for f in "$PROJECT"/*/manage.py; do
    [ -f "$f" ] && { found="${f#"$PROJECT"/}"; break; }
  done
fi
[ -n "$found" ] || exit 0

printf 'Django projesi tespit edildi (%s) — `django` skill kurallari yuklendi:\n\n' "$found"
# Strip the YAML frontmatter; the body is the rule set.
awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; next} !fm' "$SKILL"
