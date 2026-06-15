#!/usr/bin/env bash
#
# branch-guard.sh — Claude Code PreToolUse hook (matcher: Bash)
#
# Blocks dangerous git operations on protected branches:
#   - git merge        while on a protected branch (main/master/...)
#   - git rebase       while on a protected branch
#   - git push         directly to a protected branch
#   - git push --force / -f / --force-with-lease (force push on any branch)
#   - git reset --hard while on a protected branch
#
# The substring-based regexes also match rtk-proxied commands
# (e.g. "rtk git push origin main"), so this works alongside the rtk hook.
#
# Hook contract:
#   - stdin receives JSON with .tool_input.command
#   - exit 0  -> allow
#   - exit 2  -> BLOCK and return stderr to Claude as feedback
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

block() {
  # $1 = reason, $2 = suggestion
  echo "🛑 branch-guard blocked: $1" >&2
  echo "" >&2
  echo "   Current branch: ${CURRENT_BRANCH:-unknown}" >&2
  echo "   Command:        $CMD" >&2
  echo "" >&2
  echo "   Suggestion: $2" >&2
  exit 2
}

# --- Rules ------------------------------------------------------------------

# 1) Force push on any branch
if echo "$CMD" | grep -Eq 'git[[:space:]]+push.*(--force([[:space:]]|$|=)|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
  block "force push is destructive (rewrites remote history)." \
        "if you really need it, run the command yourself, manually."
fi

# 2) Direct push to a protected branch
#    Matches: git push origin main / git push origin HEAD:main / git push origin master ...
for p in "${PROTECTED_BRANCHES[@]}"; do
  if echo "$CMD" | grep -Eq "git[[:space:]]+push([[:space:]].*)?[[:space:]]${p}([[:space:]]|$|:)"; then
    block "direct push to '${p}'." \
          "open a Pull Request from a feature branch instead of pushing directly."
  fi
  if echo "$CMD" | grep -Eq "git[[:space:]]+push([[:space:]].*)?:${p}([[:space:]]|$)"; then
    block "direct push to '${p}' (refspec HEAD:${p})." \
          "open a Pull Request from a feature branch."
  fi
done

# 3) merge / rebase / reset --hard while ON the protected branch
if [[ -n "$CURRENT_BRANCH" ]] && is_protected "$CURRENT_BRANCH"; then

  if echo "$CMD" | grep -Eq 'git[[:space:]]+merge([[:space:]]|$)'; then
    block "merge while on '${CURRENT_BRANCH}'." \
          "switch to a feature branch (git checkout -b feature/x) and use a Pull Request."
  fi

  if echo "$CMD" | grep -Eq 'git[[:space:]]+rebase([[:space:]]|$)'; then
    block "rebase on '${CURRENT_BRANCH}' rewrites the main branch history." \
          "work on a separate feature branch."
  fi

  if echo "$CMD" | grep -Eq 'git[[:space:]]+reset.*--hard'; then
    block "reset --hard on '${CURRENT_BRANCH}' discards work irreversibly." \
          "if intentional, run it yourself, manually."
  fi
fi

# All good: allow execution.
exit 0
