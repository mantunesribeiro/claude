#!/usr/bin/env bash
#
# branch-guard.sh — Claude Code PreToolUse hook (matcher: Bash)
#
# Guards dangerous git operations. Behaviour is set by the BRANCH_GUARD_MODE
# env var (inherited from the process that launched Claude Code, e.g.
# `BRANCH_GUARD_MODE=alert claude`). Three levels:
#
#   alert    — never block; only WARN (ask for confirmation), even on a
#              protected branch. Lets you work straight on main with a heads-up.
#   default  — (used when the var is unset or invalid) BLOCK ops that touch a
#              PROTECTED branch (develop/release/main/master/production); only ALERT on
#              other branches.
#   strict   — BLOCK destructive ops (force push, reset --hard) on ANY branch,
#              and BLOCK any write to a protected branch (commit/merge/rebase/
#              push). Maximum safety.
#
# Operations covered:
#   - git commit       while on a protected branch (main/master/...)
#   - git merge        while on a protected branch
#   - git rebase       while on a protected branch
#   - git push         directly to a protected branch
#   - git push --force / -f / --force-with-lease (force push)
#   - git reset --hard
#
# How each op resolves per mode:
#   write to protected branch -> strict: block, default: block, alert: warn
#   destructive on other branch -> strict: block, default: warn, alert: warn
#
# This is a NARROW DENYLIST, not an allowlist: anything not matching a pattern
# above passes through untouched. Never affected (examples):
#   git status / add / diff / log / fetch / pull / stash
#   git checkout / switch / branch
#   git commit on a non-protected branch
#   git push <feature>  (no --force, non-protected target)
# And note the flip side — destructive commands OUTSIDE the list are NOT caught:
#   git clean -fdx / git branch -D / git push --delete / git checkout -- .
# Add a rule below to cover one of those if you need it.
#
# NOTE: this lives in a PreToolUse hook on purpose. A hook's "ask" decision
# overrides any "allow" permission rule (incl. a local settings.local.json
# entry written by "don't ask again"), so this guard cannot be silently
# shadowed the way the settings.json `ask` rules can.
#
# The substring-based regexes also match rtk-proxied commands
# (e.g. "rtk git push origin main"), so this works alongside the rtk hook.
#
# Hook contract (PreToolUse):
#   - stdin receives JSON with .tool_input.command
#   - to warn + confirm, print JSON on stdout and exit 0 with
#       permissionDecision:"ask"  (alert; user confirms)
#   - to block, print JSON on stdout and exit 0 with
#       permissionDecision:"deny" (the command is refused outright)
#       {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#        "permissionDecision":"ask|deny","permissionDecisionReason":"..."}}
#   - plain exit 0 (no JSON) -> allow without prompting
#
# Install: see settings.json. Remember:  chmod +x branch-guard.sh

set -euo pipefail

# Protected branches. Override by creating $HOME/.claude/.protected-branches
# (one branch name per line) — keeps this list in sync with CLAUDE.md.
PROTECTED_BRANCHES=("develop" "release" "main" "master" "production")

PROTECTED_FILE="$HOME/.claude/.protected-branches"
if [[ -f "$PROTECTED_FILE" ]]; then
  mapfile -t PROTECTED_BRANCHES < <(grep -vE '^\s*(#|$)' "$PROTECTED_FILE")
fi

# Enforcement level: strict | default | alert (see header). Unknown -> default.
GUARD_MODE="$(printf '%s' "${BRANCH_GUARD_MODE:-default}" | tr '[:upper:]' '[:lower:]')"
case "$GUARD_MODE" in
  strict|default|alert) : ;;
  *) GUARD_MODE="default" ;;
esac

# --- Read the command Claude wants to run -----------------------------------
INPUT="$(cat)"

extract_command() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r '.tool_input.command // ""'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$INPUT" | python3 -c \
      'import sys,json; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))'
  else
    # Crude fallback when neither jq nor python3 is available
    printf '%s' "$INPUT" | grep -oP '"command"\s*:\s*"\K[^"]*' | head -n1
  fi
}

CMD="$(extract_command)"

# Not a git command? let it through.
case "$CMD" in
  *git*) : ;;
  *) exit 0 ;;
esac

# --- Determine the current branch -------------------------------------------
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

is_protected() {
  local b="$1"
  for p in "${PROTECTED_BRANCHES[@]}"; do
    [[ "$b" == "$p" ]] && return 0
  done
  return 1
}

# push_targets_protected — does $CMD push to one of the protected branches?
push_targets_protected() {
  local p
  for p in "${PROTECTED_BRANCHES[@]}"; do
    echo "$CMD" | grep -Eq "git[[:space:]]+push([[:space:]].*)?[[:space:]]${p}([[:space:]]|$|:)" && return 0
    echo "$CMD" | grep -Eq "git[[:space:]]+push([[:space:]].*)?:${p}([[:space:]]|$)" && return 0
  done
  return 1
}

# emit — print the PreToolUse decision JSON and exit.
#   $1 = decision (ask|deny), $2 = message
emit() {
  local decision="$1" msg="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg d "$decision" --arg r "$msg" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
    exit 0
  elif command -v python3 >/dev/null 2>&1; then
    DEC="$decision" MSG="$msg" python3 -c \
      'import os,json; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":os.environ["DEC"],"permissionDecisionReason":os.environ["MSG"]}}))'
    exit 0
  fi
  # No JSON tooling: cannot express "ask". Surface the message; a "deny" still
  # blocks via exit code 2, an "ask" degrades to allow (exit 0).
  echo "$msg" >&2
  [[ "$decision" == "deny" ]] && exit 2
  exit 0
}

build_msg() {  # $1 = label, $2 = reason, $3 = note
  printf '%s: %s\n   Mode:           %s\n   Current branch: %s\n   Command:        %s\n   Note: %s' \
    "$1" "$2" "$GUARD_MODE" "${CURRENT_BRANCH:-unknown}" "$CMD" "$3"
}

# warn — alert + ask for confirmation (does NOT block). $1 reason, $2 note
warn() { emit "ask" "$(build_msg "⚠️ branch-guard (alert)" "$1" "$2")"; }

# block — refuse the command outright. $1 reason, $2 note
block() { emit "deny" "$(build_msg "⛔ branch-guard (blocked)" "$1" "$2")"; }

# act_protected — op that writes to a PROTECTED branch.
#   strict, default -> block ;  alert -> warn
act_protected() { case "$GUARD_MODE" in alert) warn "$1" "$2";; *) block "$1" "$2";; esac; }

# act_destructive — destructive op (force push / reset --hard) on a
# NON-protected branch.  strict -> block ;  default, alert -> warn
act_destructive() { case "$GUARD_MODE" in strict) block "$1" "$2";; *) warn "$1" "$2";; esac; }

# --- Rules ------------------------------------------------------------------
# Decisions route through act_protected / act_destructive, which resolve to
# block or warn based on $GUARD_MODE (see header).

CURRENT_PROTECTED=0
if [[ -n "$CURRENT_BRANCH" ]] && is_protected "$CURRENT_BRANCH"; then
  CURRENT_PROTECTED=1
fi

# 1) Force push (--force / -f / --force-with-lease)
if echo "$CMD" | grep -Eq 'git[[:space:]]+push.*(--force([[:space:]]|$|=)|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
  if push_targets_protected || [[ "$CURRENT_PROTECTED" == "1" ]]; then
    act_protected "force push onto a protected branch rewrites its remote history (destructive)." \
                  "open a feature branch instead. Set BRANCH_GUARD_MODE=alert to allow with a warning."
  else
    act_destructive "force push rewrites remote history (destructive)." \
                    "make sure nobody else depends on this branch. BRANCH_GUARD_MODE=strict blocks this."
  fi
fi

# 2) Direct push to a protected branch
#    Matches: git push origin main / git push origin HEAD:main / git push origin master ...
for p in "${PROTECTED_BRANCHES[@]}"; do
  if echo "$CMD" | grep -Eq "git[[:space:]]+push([[:space:]].*)?[[:space:]]${p}([[:space:]]|$|:)"; then
    act_protected "direct push to protected branch '${p}'." \
                  "open a feature branch + PR. Set BRANCH_GUARD_MODE=alert to push straight to '${p}'."
  fi
  if echo "$CMD" | grep -Eq "git[[:space:]]+push([[:space:]].*)?:${p}([[:space:]]|$)"; then
    act_protected "direct push to protected branch '${p}' (refspec HEAD:${p})." \
                  "open a feature branch + PR. Set BRANCH_GUARD_MODE=alert to push straight to '${p}'."
  fi
done

# 3) reset --hard (destructive on any branch)
if echo "$CMD" | grep -Eq 'git[[:space:]]+reset.*--hard'; then
  if [[ "$CURRENT_PROTECTED" == "1" ]]; then
    act_protected "reset --hard on protected branch '${CURRENT_BRANCH}' discards work irreversibly." \
                  "Set BRANCH_GUARD_MODE=alert if you mean to throw those changes away."
  else
    act_destructive "reset --hard on '${CURRENT_BRANCH}' discards uncommitted work irreversibly." \
                    "BRANCH_GUARD_MODE=strict blocks this; alert/default warn only."
  fi
fi

# 4) commit / merge / rebase while ON a protected branch
if [[ "$CURRENT_PROTECTED" == "1" ]]; then

  if echo "$CMD" | grep -Eq 'git[[:space:]]+commit([[:space:]]|$)'; then
    act_protected "commit while on protected branch '${CURRENT_BRANCH}'." \
                  "open a feature branch (git checkout -b ...). Set BRANCH_GUARD_MODE=alert to commit straight to '${CURRENT_BRANCH}', staging only the files you intend."
  fi

  if echo "$CMD" | grep -Eq 'git[[:space:]]+merge([[:space:]]|$)'; then
    act_protected "merge while on protected branch '${CURRENT_BRANCH}'." \
                  "this writes straight to '${CURRENT_BRANCH}'. Set BRANCH_GUARD_MODE=alert to allow."
  fi

  if echo "$CMD" | grep -Eq 'git[[:space:]]+rebase([[:space:]]|$)'; then
    act_protected "rebase on protected branch '${CURRENT_BRANCH}' rewrites its history." \
                  "Set BRANCH_GUARD_MODE=alert if you understand the history rewrite."
  fi
fi

# Nothing risky matched: allow without prompting.
exit 0
