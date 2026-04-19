#!/bin/bash
# Claude Code statusline
# Format: ~/path [Model] Ctx:N% Usage Day:N% Week:N% [⎇ branch +N -N ~F]

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# Tilde-ify home dir
short_cwd="${cwd/#$HOME/~}"

# Context usage percentage (pre-calculated by Claude Code)
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
if [ -z "$ctx_pct" ] || [ "$ctx_pct" = "null" ]; then
  # Fallback: calculate manually from input_tokens / context_window_size
  input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0' 2>/dev/null)
  ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000' 2>/dev/null)
  if [ "$input_tokens" -gt 0 ] 2>/dev/null && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
    ctx_pct=$(awk "BEGIN { printf \"%.0f\", ($input_tokens / $ctx_size) * 100 }")
  else
    ctx_pct=0
  fi
fi
ctx_pct=$(printf "%.0f" "$ctx_pct" 2>/dev/null || echo 0)

# Rate limit usage (Claude.ai subscription: 5-hour and 7-day windows)
day_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
[ -z "$day_pct" ] || [ "$day_pct" = "null" ] && day_pct=0
[ -z "$week_pct" ] || [ "$week_pct" = "null" ] && week_pct=0

# Round to int
day_pct=$(printf "%.0f" "$day_pct" 2>/dev/null || echo 0)
week_pct=$(printf "%.0f" "$week_pct" 2>/dev/null || echo 0)

# ANSI colors (256-color)
RESET="\033[0m"
DIM="\033[2m"
GRAY="\033[38;5;245m"
CYAN="\033[38;5;75m"
GREEN="\033[38;5;114m"
YELLOW="\033[38;5;221m"
ORANGE="\033[38;5;215m"
RED="\033[38;5;204m"
PURPLE="\033[38;5;176m"
BLUE="\033[38;5;111m"

# Color picker for percentages
color_for_pct() {
  local p=$1
  if [ "$p" -ge 90 ] 2>/dev/null; then echo "$RED"
  elif [ "$p" -ge 70 ] 2>/dev/null; then echo "$ORANGE"
  elif [ "$p" -ge 40 ] 2>/dev/null; then echo "$YELLOW"
  else echo "$GREEN"
  fi
}

ctx_color=$(color_for_pct "$ctx_pct")
day_color=$(color_for_pct "$day_pct")
week_color=$(color_for_pct "$week_pct")

# Git info
git_part=""
if cd "$cwd" 2>/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git rev-parse --short HEAD 2>/dev/null)

  # Counts: added (staged new + unstaged new), deleted, modified files
  porcelain=$(git status --porcelain 2>/dev/null)
  if [ -n "$porcelain" ]; then
    # Lines starting with: A/?? = added, D = deleted, M/R = modified
    added=$(echo "$porcelain" | grep -cE '^(\?\?| A|A |AM)')
    deleted=$(echo "$porcelain" | grep -cE '^( D|D |AD)')
    modified=$(echo "$porcelain" | grep -cE '^( M|M |MM|R |RM)')

    # Also unstaged inserts/deletes from diff
    diff_stat=$(git diff --shortstat 2>/dev/null)
    diff_staged=$(git diff --cached --shortstat 2>/dev/null)

    insertions=0
    deletions=0
    for stat in "$diff_stat" "$diff_staged"; do
      ins=$(echo "$stat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
      del=$(echo "$stat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+')
      [ -n "$ins" ] && insertions=$((insertions + ins))
      [ -n "$del" ] && deletions=$((deletions + del))
    done

    # Untracked files: their full content counts as insertions
    while IFS= read -r f; do
      [ -f "$f" ] && {
        lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ' || echo 0)
        insertions=$((insertions + lines))
      }
    done < <(git ls-files --others --exclude-standard 2>/dev/null)

    changes=""
    files_total=$(echo "$porcelain" | wc -l | tr -d ' ')
    [ "$files_total" -gt 0 ] && changes="${changes} ${YELLOW}${files_total}F${RESET}"
    [ "$insertions" -gt 0 ] && changes="${changes} ${GREEN}+${insertions}${RESET}"
    [ "$deletions" -gt 0 ] && changes="${changes} ${RED}-${deletions}${RESET}"

    git_part=" ${DIM}[${RESET}${PURPLE}⎇ ${branch}${RESET}${changes}${DIM}]${RESET}"
  else
    git_part=" ${DIM}[${RESET}${PURPLE}⎇ ${branch}${RESET}${DIM}]${RESET}"
  fi
fi

# Build output
printf "%b" "${BLUE}${short_cwd}${RESET} ${DIM}[${RESET}${CYAN}${model}${RESET}${DIM}]${RESET} ${DIM}Ctx:${RESET}${ctx_color}${ctx_pct}%${RESET} ${DIM}Usage${RESET} ${DIM}Day:${RESET}${day_color}${day_pct}%${RESET} ${DIM}Week:${RESET}${week_color}${week_pct}%${RESET}${git_part}"
