#!/usr/bin/env bash
#
# _lib.sh — shared helpers for install.sh and update.sh.
#
# Not meant to be run directly; source it:  source "$(dirname "$0")/_lib.sh"
# Single source of truth for the repo<->~/.claude file map and common steps.
#
# MODE controls how files are placed:
#   link (default) — symlink into ~/.claude; editing the repo is live.
#   copy           — copy into ~/.claude; used by bootstrap.sh on machines
#                    that don't keep the repo around.

# Guard against direct execution.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "_lib.sh is a library; source it from install.sh / update.sh" >&2
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
MODE="${MODE:-link}"
# Marker: once set, this dir is "ours" — we stop backing up files we placed.
# Only genuine pre-existing config (before the first run) gets backed up to *.bak.
MANAGED_MARKER="$CLAUDE_DIR/.claude-config-managed"

# File map: each line is "<src in repo>  <dst in ~/.claude>".
# CLAUDE.md is placed as git-rules.md so it never clobbers your own CLAUDE.md.
LINKS=(
  "settings.json|settings.json"
  "statusline-command.sh|statusline-command.sh"
  "CLAUDE.md|git-rules.md"
)

# place <src> <dst> — symlink (MODE=link) or copy (MODE=copy) into ~/.claude.
# A pre-existing real file is backed up to *.bak once (only if no .bak yet).
place() {
  local src="$REPO_DIR/$1" dst="$CLAUDE_DIR/$2"
  # Back up a real, pre-existing file only on the very first run (no marker yet).
  if [[ ! -e "$MANAGED_MARKER" && -e "$dst" && ! -L "$dst" && ! -e "$dst.bak" ]]; then
    mv "$dst" "$dst.bak"
    echo "  backed up existing $dst -> $dst.bak"
  fi
  if [[ "$MODE" == "copy" ]]; then
    rm -f "$dst"
    cp "$src" "$dst"
    echo "  copied  $dst"
  else
    ln -sfn "$src" "$dst"
    echo "  linked  $dst -> $src"
  fi
}

# place_all — (re)place every file. Idempotent.
place_all() {
  local pair src dst
  for pair in "${LINKS[@]}"; do
    src="${pair%%|*}"; dst="${pair##*|}"
    place "$src" "$dst"
  done
  chmod +x "$CLAUDE_DIR/statusline-command.sh"
  touch "$MANAGED_MARKER"
}

# ensure_git_rules_import — make ~/.claude/CLAUDE.md import the git rules.
# Idempotent: appends "@git-rules.md" only if it's not already there.
ensure_git_rules_import() {
  local md="$CLAUDE_DIR/CLAUDE.md"
  touch "$md"
  if grep -qxF "@git-rules.md" "$md"; then
    echo "  ~/.claude/CLAUDE.md already imports @git-rules.md"
  else
    printf '@git-rules.md\n' >> "$md"
    echo "  added '@git-rules.md' import to $md"
  fi
}

# check_rtk — the Bash hook delegates to rtk; warn (non-fatal) if missing.
check_rtk() {
  if command -v rtk >/dev/null 2>&1; then
    echo "  rtk present: $(rtk --version 2>/dev/null || echo 'unknown version')"
  else
    echo "  WARNING: 'rtk' not found on PATH — the PreToolUse hook expects it." >&2
    echo "           Install RTK (Rust Token Killer) and re-check with 'rtk --version'." >&2
  fi
}
