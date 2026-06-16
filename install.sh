#!/usr/bin/env bash
#
# install.sh — first-time setup: symlink this repo's Claude Code config into
# ~/.claude, wire up the git rules, register plugin marketplaces, sanity-check.
#
# Idempotent and safe to re-run. Real (non-symlink) files are backed up to *.bak
# before linking. For day-to-day re-syncing after repo edits, use ./update.sh.

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

echo "Installing Claude Code config from $REPO_DIR"

echo "Placing config files (mode: $MODE):"
place_all

echo "Wiring git rules into ~/.claude/CLAUDE.md:"
ensure_git_rules_import

echo "Registering plugin marketplaces (from extraKnownMarketplaces):"
if command -v claude >/dev/null 2>&1; then
  claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill 2>/dev/null \
    && echo "  added marketplace ui-ux-pro-max-skill" || echo "  marketplace ui-ux-pro-max-skill already known"
  claude plugin marketplace add JuliusBrussee/caveman 2>/dev/null \
    && echo "  added marketplace caveman" || echo "  marketplace caveman already known"
else
  echo "  'claude' CLI not found — skipping; plugins load from settings.json on next launch."
fi

echo "Checking RTK (used by the Bash PreToolUse hook):"
check_rtk

echo ""
echo "Quick test of branch-guard (expect a block + exit: 2):"
echo '{"tool_input":{"command":"git push origin main"}}' \
  | bash "$CLAUDE_DIR/hooks/branch-guard.sh" || echo "exit: $?"

echo ""
echo "Done. Restart Claude Code, then verify with /status (look for User settings)."
