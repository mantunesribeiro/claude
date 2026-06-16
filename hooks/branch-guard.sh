#!/usr/bin/env bash
#
# branch-guard.sh — Claude Code PreToolUse hook (matcher: Bash)
#
# WARNS (asks for confirmation) on dangerous git operations — it does NOT block.
# The user is alerted and decides; nothing is prevented outright. Covers:
#   - git merge        while on a protected branch (main/master/...)
#   - git rebase       while on a protected branch
#   - git push         directly to a protected branch
#   - git push --force / -f / --force-with-lease (force push on any branch)
#   - git reset --hard while on a protected branch
#
# The substring-based regexes also match rtk-proxied commands
# (e.g. "rtk git push origin main"), so this works alongside the rtk hook.
#
# Hook contract (PreToolUse):
#   - stdin receives JSON with .tool_input.command
#   - to warn + confirm, print JSON on stdout and exit 0:
#       {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#        "permissionDecision":"ask","permissionDecisionReason":"..."}}
#   - plain exit 0 (no JSON) -> allow without prompting
#
# Install: see settings.json. Remember:  chmod +x branch-guard.sh

set -euo pipefail

# Protected branches. Override by creating $HOME/.claude/.protected-branches
# (one branch name per line) — keeps this list in sync with CLAUDE.md.
PROTECTED_BRANCHES=("main" "master" "production" "release")

PROTECTED_FILE="$HOME/.claude/.protected-branches"
if [[ -f "$PROTECTED_FILE" ]]; then
  mapfile -t PROTECTED_BRANCHES < <(grep -vE '^\s*(#|$)' "$PROTECTED_FILE")
fi

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

# warn — alert the user and ask them to confirm (does NOT block).
#   $1 = reason, $2 = note
warn() {
  local msg="⚠️ branch-guard: $1
   Current branch: ${CURRENT_BRANCH:-unknown}
   Command:        $CMD
   Note: $2"

  if command -v jq >/dev/null 2>&1; then
    jq -n --arg r "$msg" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  elif command -v python3 >/dev/null 2>&1; then
    MSG="$msg" python3 -c 'import os,json; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":os.environ["MSG"]}}))'
  else
    # No JSON tooling: surface the warning but allow (do not prevent).
    echo "$msg" >&2
  fi
  exit 0
}

# --- Rules (warn + confirm; never block) ------------------------------------

# 1) Force push on any branch
if echo "$CMD" | grep -Eq 'git[[:space:]]+push.*(--force([[:space:]]|$|=)|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
  warn "force push rewrites remote history (destructive)." \
       "make sure nobody else depends on the branch before confirming."
fi

# 2) Direct push to a protected branch
#    Matches: git push origin main / git push origin HEAD:main / git push origin master ...
for p in "${PROTECTED_BRANCHES[@]}"; do
  if echo "$CMD" | grep -Eq "git[[:space:]]+push([[:space:]].*)?[[:space:]]${p}([[:space:]]|$|:)"; then
    warn "direct push to protected branch '${p}'." \
         "prefer a feature branch + PR; confirm only if you intend to push straight to '${p}'."
  fi
  if echo "$CMD" | grep -Eq "git[[:space:]]+push([[:space:]].*)?:${p}([[:space:]]|$)"; then
    warn "direct push to protected branch '${p}' (refspec HEAD:${p})." \
         "prefer a feature branch + PR; confirm only if intentional."
  fi
done

# 3) merge / rebase / reset --hard while ON the protected branch
if [[ -n "$CURRENT_BRANCH" ]] && is_protected "$CURRENT_BRANCH"; then

  if echo "$CMD" | grep -Eq 'git[[:space:]]+merge([[:space:]]|$)'; then
    warn "merge while on protected branch '${CURRENT_BRANCH}'." \
         "this writes straight to '${CURRENT_BRANCH}'; confirm if that's what you want."
  fi

  if echo "$CMD" | grep -Eq 'git[[:space:]]+rebase([[:space:]]|$)'; then
    warn "rebase on protected branch '${CURRENT_BRANCH}' rewrites its history." \
         "confirm only if you understand the history rewrite."
  fi

  if echo "$CMD" | grep -Eq 'git[[:space:]]+reset.*--hard'; then
    warn "reset --hard on '${CURRENT_BRANCH}' discards uncommitted work irreversibly." \
         "confirm only if you mean to throw those changes away."
  fi
fi

# Nothing risky matched: allow without prompting.
exit 0
