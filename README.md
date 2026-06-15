# claude

Personal [Claude Code](https://docs.claude.com/en/docs/claude-code) configuration: settings, a custom statusline, git guardrails, and enabled plugins.

## Contents

| File | Purpose |
| --- | --- |
| `settings.json` | Claude Code settings — model, permissions, hooks, plugins, theme. |
| `statusline-command.sh` | Custom statusline renderer (user, directory, git branch, model, context usage). |
| `hooks/branch-guard.sh` | `PreToolUse` hook that deterministically blocks dangerous git ops (force push, push/merge/rebase/reset on protected branches). |
| `.protected-branches` | Single source of truth for the protected-branch list, read by `branch-guard.sh`. |
| `CLAUDE.md` | Natural-language git workflow rules (the *intent* behind the hook + permissions). |
| `install.sh` | Symlinks everything into `~/.claude` (with backups). |

## Settings overview

`settings.json` configures:

- **Model**: `opus`, with `effortLevel` set to `xhigh` and the `dark-ansi` theme.
- **Privacy**: telemetry and error reporting disabled (`DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`).
- **Attribution**: empty commit/PR trailers, so commits and PRs are not tagged with Claude attribution.
- **Permissions**:
  - `allow` — `npm run lint`, `npm run test *`, reading `~/.zshrc`.
  - `deny` — `curl`, force pushes (`git push --force` / `-f`), `git reset --hard`, `rm -rf`, reading `.env` / `.env.*` files and anything under `secrets/`.
  - `ask` — confirm before `git commit` / `git push` / `git merge` / `git rebase` (including the `rtk`-proxied variants).
- **Hooks**: a `PreToolUse` hook on `Bash` runs two commands — `rtk hook claude` (token optimization, see [RTK](#rtk)) and [`branch-guard.sh`](#git-guardrails) (git safety).
- **Plugins**: five enabled — see [Plugins](#plugins).

See [Git guardrails](#git-guardrails) for the full defense layering.

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

## Git guardrails

Three layers, weakest to strongest, stop the agent from doing risky git operations on its own:

1. **`CLAUDE.md`** — natural-language intent. Helpful, not a guarantee.
2. **`permissions` (deny / ask)** in `settings.json` — a real gate, but Bash string matching can be dodged with odd syntax.
3. **`branch-guard.sh`** (`PreToolUse` hook) — deterministic code that runs before every Bash command. The only client-side layer that *truly* blocks.

`branch-guard.sh` reads the command from the hook's stdin JSON and blocks (exit `2`) when it sees:

- a force push (`--force` / `-f` / `--force-with-lease`) on any branch;
- a direct push to a protected branch (`git push origin main`, `HEAD:main`, …);
- `git merge` / `git rebase` / `git reset --hard` while *on* a protected branch.

Its substring regexes also match `rtk`-proxied commands, so it composes with the RTK hook. Protected branches come from `.protected-branches` (falling back to `main master production release`).

> The strongest layer lives **outside** the agent: server-side branch protection (GitHub/GitLab) requiring a PR + human review to merge. The agent can't bypass that — and what reaches `main` is what actually matters.

Test the hook directly (expect a block message and `exit: 2`):

```bash
echo '{"tool_input":{"command":"git push origin main"}}' | bash hooks/branch-guard.sh; echo "exit: $?"
```

## RTK

The Bash hook delegates to **RTK (Rust Token Killer)**, a CLI proxy that rewrites dev commands (e.g. `git status` → `rtk git status`) to cut token usage on tool output. Install RTK separately and verify with `rtk --version`.

## Usage

Run the installer — it symlinks everything into `~/.claude` (backing up any real files to `*.bak`):

```bash
./install.sh
```

It will not overwrite an existing `~/.claude/CLAUDE.md`; instead it links the git rules as `~/.claude/git-rules.md`. To load them globally, add this import line to your `~/.claude/CLAUDE.md`:

```
@git-rules.md
```

Restart Claude Code and confirm with `/status` (look for **User settings** under "Setting sources").
