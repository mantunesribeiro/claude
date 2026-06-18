#!/usr/bin/env bash
#
# branch-guard.test.sh — exercises hooks/branch-guard.sh across all modes.
#
# Spins up a throwaway git repo + HOME so the current branch and the
# protected-branch list are deterministic, then asserts the hook's decision
# (deny / ask / allow) for each command × mode. Exits non-zero on any failure.
#
# Run:  ./tests/branch-guard.test.sh

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../hooks/branch-guard.sh"

command -v jq  >/dev/null 2>&1 || { echo "jq required to run these tests"  >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "git required to run these tests" >&2; exit 1; }

# --- Throwaway HOME (protected list) + git repo (current branch) ------------
THOME="$(mktemp -d)"
TREPO="$(mktemp -d)"
cleanup() { rm -rf "$THOME" "$TREPO"; }
trap cleanup EXIT

mkdir -p "$THOME/.claude"
printf 'develop\nrelease\nmain\nmaster\nproduction\n' > "$THOME/.claude/.protected-branches"

git -C "$TREPO" init -q -b main
git -C "$TREPO" config user.email test@example.com
git -C "$TREPO" config user.name  test
git -C "$TREPO" commit -q --allow-empty -m init
git -C "$TREPO" branch feature
git -C "$TREPO" branch develop

pass=0 fail=0

# decision <branch> <command> <mode>  -> prints deny | ask | allow
# mode "UNSET" leaves BRANCH_GUARD_MODE unset (exercises the unset fallback).
decision() {
  local branch="$1" cmd="$2" mode="$3" out json
  git -C "$TREPO" checkout -q "$branch"
  json=$(printf '{"tool_input":{"command":"%s"}}' "$cmd")
  if [[ "$mode" == "UNSET" ]]; then
    out=$(cd "$TREPO" && printf '%s' "$json" | env HOME="$THOME" bash "$HOOK")
  else
    out=$(cd "$TREPO" && printf '%s' "$json" | env HOME="$THOME" BRANCH_GUARD_MODE="$mode" bash "$HOOK")
  fi
  if [[ -z "$out" ]]; then echo allow
  else printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision'
  fi
}

# expect <branch> <command> <mode> <expected>
expect() {
  local got; got="$(decision "$1" "$2" "$3")"
  if [[ "$got" == "$4" ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL  [%s] %-32s mode=%-7s  expected %-5s got %s\n' "$1" "$2" "$3" "$4" "$got"
  fi
}

# --- Cases: branch | command | mode | expected ------------------------------
# Writes to a protected branch -> alert: ask, default/strict: deny
expect main    "git commit -m x"               alert   ask
expect main    "git commit -m x"               default deny
expect main    "git commit -m x"               strict  deny
expect main    "git merge feature"             default deny
expect main    "git rebase feature"            default deny
expect feature "git push origin main"          alert   ask
expect feature "git push origin main"          default deny
expect feature "git push origin main"          strict  deny
expect feature "git push origin HEAD:main"     default deny
expect feature "git push --force origin main"  default deny
expect feature "git push --force origin main"  alert   ask
expect main    "git reset --hard HEAD~1"        alert   ask
expect main    "git reset --hard HEAD~1"        default deny
expect develop "git commit -m x"               default deny
expect develop "git commit -m x"               alert   ask
expect feature "git push origin develop"        default deny

# Destructive command on a non-protected branch -> alert/default: ask, strict: deny
expect feature "git push --force origin feature" alert   ask
expect feature "git push --force origin feature" default ask
expect feature "git push --force origin feature" strict  deny
expect feature "git reset --hard HEAD~1"          default ask
expect feature "git reset --hard HEAD~1"          strict  deny

# Allowed (no decision emitted)
expect feature "git commit -m x"     default allow
expect feature "git status"          default allow
expect feature "git push origin feature" default allow
expect main    "ls -la"              default allow

# Mode fallback: unset and invalid both behave like default
expect feature "git push origin main" UNSET  deny
expect feature "git push origin main" banana deny

# --- Result -----------------------------------------------------------------
echo "------------------------------------------------------------"
printf 'branch-guard: %d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
