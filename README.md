# claude

Personal [Claude Code](https://docs.claude.com/en/docs/claude-code) configuration: settings, a custom statusline, and enabled plugins.

## Contents

| File | Purpose |
| --- | --- |
| `settings.json` | Claude Code settings — model, permissions, hooks, plugins, theme. |
| `statusline-command.sh` | Custom statusline renderer (user, directory, git branch, model, context usage). |

## Settings overview

`settings.json` configures:

- **Model**: `opus`, with `effortLevel` set to `xhigh` and the `dark-ansi` theme.
- **Privacy**: telemetry and error reporting disabled (`DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`).
- **Attribution**: empty commit/PR trailers, so commits and PRs are not tagged with Claude attribution.
- **Permissions**:
  - `allow` — `npm run lint`, `npm run test *`, reading `~/.zshrc`.
  - `deny` — `curl`, reading `.env` / `.env.*` files and anything under `secrets/`.
  - `ask` — confirm before `git commit` / `git push` (including the `rtk`-proxied variants).
- **Hooks**: a `PreToolUse` hook on `Bash` runs `rtk hook claude`, routing shell commands through [RTK](#rtk) for token-optimized output.
- **Plugins**: five enabled — see [Plugins](#plugins).

## Plugins

Enabled under `enabledPlugins`, sourced from the official marketplace plus two GitHub marketplaces (`extraKnownMarketplaces`):

| Plugin | Source | What it does |
| --- | --- | --- |
| `ui-ux-pro-max` | [`nextlevelbuilder/ui-ux-pro-max-skill`](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | UI/UX design intelligence — styles, color palettes, font pairings, UX guidelines, chart types across React, Vue, Svelte, SwiftUI, Flutter, Tailwind, shadcn/ui, and more. |
| `context7` | official | Fetches current library/framework/API docs on demand, instead of relying on training data. |
| `frontend-design` | official | Generates distinctive, production-grade frontend UIs that avoid generic AI aesthetics. |
| `code-simplifier` | official | Simplifies and refines code for clarity and maintainability while preserving behavior. |
| `caveman` | [`JuliusBrussee/caveman`](https://github.com/JuliusBrussee/caveman) | Ultra-compressed "caveman" communication mode (~75% fewer tokens), plus commit/review/compress helpers. Toggle with `/caveman lite\|full\|ultra`. |

## Statusline

`statusline-command.sh` reads the JSON Claude Code pipes on stdin and prints a single colored line:

```
user | ~/path | git:(branch) | Model | ctx:NN% of NNNk
```

It pulls the working directory, model name, and context-window usage from the input, resolves the git branch via `git symbolic-ref`, and abbreviates `$HOME` to `~`. Requires `jq` and `git`.

## RTK

The Bash hook delegates to **RTK (Rust Token Killer)**, a CLI proxy that rewrites dev commands (e.g. `git status` → `rtk git status`) to cut token usage on tool output. Install RTK separately and verify with `rtk --version`.

## Usage

Symlink or copy these files into your Claude Code config directory (typically `~/.claude/`):

```bash
ln -s "$PWD/settings.json"          ~/.claude/settings.json
ln -s "$PWD/statusline-command.sh"  ~/.claude/statusline-command.sh
```

Adjust the absolute path in `settings.json` under `statusLine.command` to match where the script lives.
