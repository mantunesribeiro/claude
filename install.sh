#!/usr/bin/env bash
#
# install.sh — symlink this repo's Claude Code config into ~/.claude.
#
# Idempotent. Real (non-symlink) files are backed up to *.bak before linking.
# Does NOT overwrite ~/.claude/CLAUDE.md (likely your own); the git rules are
# linked as ~/.claude/git-rules.md and you import them yourself (see end).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

link() {
  # $1 = source (in repo), $2 = destination (in ~/.claude)
  local src="$REPO_DIR/$1" dst="$CLAUDE_DIR/$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mv "$dst" "$dst.bak"
    echo "  backed up existing $dst -> $dst.bak"
  fi
  ln -sfn "$src" "$dst"
  echo "  linked $dst -> $src"
}

echo "Installing Claude Code config from $REPO_DIR"
mkdir -p "$CLAUDE_DIR/hooks"

link "settings.json"           "settings.json"
link "statusline-command.sh"   "statusline-command.sh"
link "hooks/branch-guard.sh"   "hooks/branch-guard.sh"
link ".protected-branches"     ".protected-branches"
link "CLAUDE.md"               "git-rules.md"

chmod +x "$REPO_DIR/hooks/branch-guard.sh" "$REPO_DIR/statusline-command.sh"

echo ""
echo "Quick test of branch-guard (expect a block + exit: 2):"
echo '{"tool_input":{"command":"git push origin main"}}' \
  | bash "$CLAUDE_DIR/hooks/branch-guard.sh" || echo "exit: $?"

echo ""
echo "Done. Final step (manual, one time):"
echo "  Add this line to ~/.claude/CLAUDE.md so the git rules load globally:"
echo "      @git-rules.md"
echo "  Then restart Claude Code and verify with /status (look for User settings)."
