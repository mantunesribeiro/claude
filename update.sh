#!/usr/bin/env bash
#
# update.sh — re-sync ~/.claude with this repo after you change it.
#
# Symlinks make file edits live immediately, so this mainly: picks up newly
# added config files, re-asserts the @git-rules.md import, and refreshes plugin
# marketplaces to match settings.json. Idempotent; no backups (already linked).

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_lib.sh"

echo "Re-syncing Claude Code config from $REPO_DIR"

echo "Re-placing config files (mode: $MODE):"
place_all

echo "Ensuring git-rules import:"
ensure_git_rules_import

echo "Updating plugin marketplaces:"
if command -v claude >/dev/null 2>&1; then
  claude plugin marketplace update || echo "  marketplace update reported an issue (non-fatal)"
else
  echo "  'claude' CLI not found — skipping."
fi

echo "Checking RTK:"
check_rtk

echo ""
echo "Synced. Restart Claude Code to pick up settings.json changes."
