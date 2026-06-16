#!/usr/bin/env bash
#
# bootstrap.sh — install/update the Claude config on a machine WITHOUT keeping
# the repo around. Downloads the repo tarball to a temp dir, copies the config
# into ~/.claude (MODE=copy), then deletes the temp dir.
#
# Same command both installs and updates (re-running overwrites the copies):
#
#   curl -fsSL https://raw.githubusercontent.com/mantunesribeiro/claude/main/bootstrap.sh | bash
#
# Pin to a tag/commit instead of 'main' by setting REF, e.g.:
#   curl -fsSL .../bootstrap.sh | REF=v1.0.0 bash

set -euo pipefail

REPO="${REPO:-mantunesribeiro/claude}"
REF="${REF:-main}"

for bin in curl tar; do
  command -v "$bin" >/dev/null 2>&1 || { echo "missing required tool: $bin" >&2; exit 1; }
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Fetching $REPO@$REF ..."
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" \
  | tar xz -C "$tmp" --strip-components=1

echo "Installing into ~/.claude (copy mode) ..."
MODE=copy bash "$tmp/install.sh"
