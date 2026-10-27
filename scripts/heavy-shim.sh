#!/bin/sh
# Build-tool shim (installed as ~/.local/bin/{go,pnpm,npm,npx,yarn}).
# Routes build/test/lint invocations through `heavy`, whoever starts them:
# scripts, detached background jobs and sub-shells never pass the PreToolUse
# guard, so the lock has to sit on the binary itself. Everything else, and any
# call made while a heavy slot is already held, runs the real binary directly.
set -e

name=${0##*/}
bin_dir=$HOME/.local/bin
real=$HOME/.local/share/heavy/real/$name

if [ ! -x "$real" ]; then
  # No saved original: first match on PATH outside our own bin dir.
  real=
  IFS=:
  for d in $PATH; do
    [ "$d" = "$bin_dir" ] && continue
    if [ -x "$d/$name" ]; then real=$d/$name; break; fi
  done
  unset IFS
  if [ -z "$real" ]; then
    echo "heavy-shim: real '$name' not found on PATH" >&2
    exit 127
  fi
fi

[ "${HEAVY_SLOT_HELD:-0}" = 1 ] && exec "$real" "$@"
command -v heavy >/dev/null 2>&1 || exec "$real" "$@"

is_heavy_script() {
  case "$1" in
    build|build:*|test|test:*|check|check:*|lint|lint:*|typecheck|type-check) return 0 ;;
  esac
  return 1
}

is_heavy_tool() {
  case "$1" in
    vitest|svelte-check|tsc|vue-tsc|eslint|playwright) return 0 ;;
    vite) [ "${2:-}" = build ] && return 0 ;;
  esac
  return 1
}

# Re-run the go command with `-exec true` right after the subcommand at
# position $1: go builds (and caches) the executable, then runs a no-op.
go_prebuild() {
  at=$1; shift
  n=$# i=0
  for a do
    i=$((i + 1))
    set -- "$@" "$a"
    [ "$i" = "$at" ] && set -- "$@" -exec true
  done
  shift "$n"
  heavy "$real" "$@"
}

heavy=0
go_run=0
case "$name" in
  go)
    # `go -C dir <cmd>`: -C has to come first, so the subcommand moves.
    at=1
    case "${1:-}" in
      -C|--C) at=3 ;;
      -C=*|--C=*) at=2 ;;
    esac
    eval "sub=\${$at:-}"
    case "$sub" in
      build|test|vet|install|generate) heavy=1 ;;
      run) go_run=1 ;;
    esac
    ;;
  npx)
    for a in "$@"; do
      case "$a" in -*) continue ;; esac
      shift_tool=$a; break
    done
    if [ -n "${shift_tool:-}" ]; then
      # Second word for `npx vite build`.
      second=
      seen=0
      for a in "$@"; do
        case "$a" in -*) continue ;; esac
        if [ $seen = 1 ]; then second=$a; break; fi
        [ "$a" = "$shift_tool" ] && seen=1
      done
      is_heavy_tool "$shift_tool" "$second" && heavy=1
    fi
    ;;
  pnpm|npm|yarn)
    # Non-flag words, skipping the values of flags that take one.
    w1= w2= w3= skip=0
    for a in "$@"; do
      if [ $skip = 1 ]; then skip=0; continue; fi
      case "$a" in
        -C|--dir|--prefix|--filter|-F|--workspace|-w|--cwd) skip=1; continue ;;
        -*) continue ;;
      esac
      if [ -z "$w1" ]; then w1=$a
      elif [ -z "$w2" ]; then w2=$a
      elif [ -z "$w3" ]; then w3=$a; break
      fi
    done
    case "$w1" in
      run|run-script) is_heavy_script "$w2" && heavy=1 ;;
      exec|dlx|x) is_heavy_tool "$w2" "$w3" && heavy=1 ;;
      t) heavy=1 ;;
      *) is_heavy_script "$w1" && heavy=1 ;;
    esac
    ;;
esac

# `go run` keeps running after the build (a dev server would hold the slot for
# hours), so only the build goes through the lock; the second call finds the
# executable in the go build cache and starts it outside the slot. A caller's
# own -exec would be overridden by ours, so those calls run directly.
if [ $go_run = 1 ]; then
  for a in "$@"; do
    case "$a" in -exec|-exec=*|--exec|--exec=*) exec "$real" "$@" ;; esac
  done
  go_prebuild "$at" "$@" || exit $?
  exec "$real" "$@"
fi

[ $heavy = 1 ] && exec heavy "$real" "$@"
exec "$real" "$@"
