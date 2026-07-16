#!/bin/bash
# Claude Code statusline
# Format: ~/path [Model] Ctx:N% Usage Day:N% Week:N% [⎇ branch +N -N ~F]

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# Brand = which claude clone is running, derived from CLAUDE_CONFIG_DIR.
# ~/.claude -> claude (default), ~/.claude-go -> go, -z -> z, -nv -> nv.
cfg_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
cfg_base="$(basename "$cfg_dir")"
case "$cfg_base" in
  .claude)      brand="claude" ;;
  .claude-*)    brand="${cfg_base#.claude-}" ;;
  *)            brand="claude" ;;
esac

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
day_resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
week_resets_at=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' 2>/dev/null)
[ -z "$day_pct" ] || [ "$day_pct" = "null" ] && day_pct=0
[ -z "$week_pct" ] || [ "$week_pct" = "null" ] && week_pct=0

# Round to int
day_pct=$(printf "%.0f" "$day_pct" 2>/dev/null || echo 0)
week_pct=$(printf "%.0f" "$week_pct" 2>/dev/null || echo 0)

# Format a countdown "Xd Xh" / "Xh Xm" / "Xm" style string from a unix epoch reset time
format_reset() {
  local resets_at="$1"
  local max_unit="$2" # "day" allows d/h/m, "hour" allows h/m only
  if [ -z "$resets_at" ] || [ "$resets_at" = "null" ]; then
    echo ""
    return
  fi
  # Accept unix epoch or ISO 8601 (e.g. 2026-07-16T18:00:00Z)
  if ! [[ "$resets_at" =~ ^[0-9]+$ ]]; then
    resets_at=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "${resets_at%%[.Z+]*}" +%s 2>/dev/null)
    if [ -z "$resets_at" ]; then
      echo ""
      return
    fi
  fi
  local now secs
  now=$(date +%s)
  secs=$((resets_at - now))
  [ "$secs" -lt 0 ] 2>/dev/null && secs=0

  local days hours mins
  days=$((secs / 86400))
  hours=$(((secs % 86400) / 3600))
  mins=$(((secs % 3600) / 60))

  if [ "$max_unit" = "day" ] && [ "$days" -gt 0 ]; then
    if [ "$hours" -gt 0 ]; then
      echo "${days}g ${hours}s"
    else
      echo "${days}g"
    fi
  elif [ "$hours" -gt 0 ]; then
    if [ "$mins" -gt 0 ]; then
      echo "${hours}s ${mins}d"
    else
      echo "${hours}s"
    fi
  else
    echo "${mins}d"
  fi
}

day_reset_str=$(format_reset "$day_resets_at" "hour")
week_reset_str=$(format_reset "$week_resets_at" "day")

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

# Build day/week segments, appending reset countdown when available
day_seg="${DIM}Day:${RESET}${day_color}${day_pct}%${RESET}"
[ -n "$day_reset_str" ] && day_seg="${day_seg}${DIM}(${day_reset_str})${RESET}"

week_seg="${DIM}Week:${RESET}${week_color}${week_pct}%${RESET}"
[ -n "$week_reset_str" ] && week_seg="${week_seg}${DIM}(${week_reset_str})${RESET}"

# Build output
printf "%b" "${BLUE}${short_cwd}${RESET} ${DIM}[${RESET}${PURPLE}${brand}${RESET}${DIM}>${RESET}${CYAN}${model}${RESET}${DIM}]${RESET} ${DIM}Ctx:${RESET}${ctx_color}${ctx_pct}%${RESET} ${DIM}Usage${RESET} ${day_seg} ${week_seg}${git_part}"
