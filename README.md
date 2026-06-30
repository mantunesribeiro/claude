# claude

Personal [Claude Code](https://docs.claude.com/en/docs/claude-code) configuration: settings, a custom statusline, git workflow rules, and enabled plugins.

## Contents

| File | Purpose |
| --- | --- |
| `settings.json` | Claude Code settings — model, permissions, hooks, plugins, theme. |
| `statusline-command.sh` | Custom statusline renderer (user, directory, git branch, model, context usage). |
| `CLAUDE.md` | Natural-language git commit rules: stage and commit only the session's files, never a blanket `git add`. Linked into `~/.claude` as `git-rules.md`. |
| `install.sh` | First-time setup: symlinks everything into `~/.claude` (with backups), wires the git rules, registers plugin marketplaces, sanity-checks. |
| `update.sh` | Re-syncs `~/.claude` with the repository after you edit it (new files, plugin marketplaces). |
| `bootstrap.sh` | One-liner remote installer for machines that don't keep the repository: downloads the tarball and **copies** the configuration into `~/.claude`. Re-run to update. |
| `_lib.sh` | Shared helpers + the single file map, sourced by all scripts. |

## Settings overview

`settings.json` configures:

- **Model**: `opus`, with `effortLevel` set to `xhigh` and the `dark-ansi` theme.
- **Privacy**: telemetry and error reporting disabled (`DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`).
- **Attribution**: empty commit/pull request trailers, so commits and pull requests are not tagged with Claude attribution.
- **Permissions**:
  - `allow` — `npm run lint`, `npm run test *`, reading `~/.zshrc`.
  - `deny` — `curl`, `rm -rf`, reading `.env` / `.env.*` files and anything under `secrets/`.
  - `ask` — confirm before `git commit` / `git push` / `git merge` / `git rebase` / `git reset --hard` (including the `rtk`-proxied variants). See [Git workflow](#git-workflow) for the conventions these back up.
- **Hooks**: a `PreToolUse` hook on `Bash` runs `rtk hook claude` (token optimization, see [RTK](#rtk)).
- **Plugins**: five enabled — see [Plugins](#plugins).

## Plugins

Enabled under `enabledPlugins`, sourced from the official marketplace plus two GitHub marketplaces (`extraKnownMarketplaces`):

| Plugin | Source | What it does |
| --- | --- | --- |
| `ui-ux-pro-max` | [`nextlevelbuilder/ui-ux-pro-max-skill`](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | UI/UX design intelligence — styles, color palettes, font pairings, UX guidelines, chart types across React, Vue, Svelte, SwiftUI, Flutter, Tailwind, shadcn/ui, and more. |
| `context7` | official | Fetches current library/framework/API documentation on demand, instead of relying on training data. |
| `frontend-design` | official | Generates distinctive, production-grade frontend UIs that avoid generic AI aesthetics. |
| `code-simplifier` | official | Simplifies and refines code for clarity and maintainability while preserving behavior. |
| `caveman` | [`JuliusBrussee/caveman`](https://github.com/JuliusBrussee/caveman) | Ultra-compressed "caveman" communication mode (~75% fewer tokens), plus commit/review/compress helpers. Toggle with `/caveman lite\|full\|ultra`. |

## Statusline

`statusline-command.sh` reads the JSON Claude Code pipes on stdin and prints a single colored line:

```
user | ~/path | git:(branch) | Model | ctx:NN% of NNNk
```

It pulls the working directory, model name, and context-window usage from the input, resolves the git branch via `git symbolic-ref`, and abbreviates `$HOME` to `~`. Requires `jq` and `git`.

## Git workflow

Two layers shape risky git operations:

| Layer | Role |
| --- | --- |
| `CLAUDE.md` | Natural-language commit discipline: stage and commit only the files changed this session, passing them explicitly (`git commit <files> -m "..."`). Never `git add -A`, `git add .`, `git commit -a`, or a bare commit, so pre-existing staged changes stay untouched. When unsure which files are yours, show `git status` and ask before committing. |
| `settings.json` permissions | `ask` confirms the history-rewriting and merge operations: git merge/rebase/reset --hard (including the `rtk`-proxied variants). Commit and push run without a prompt under `auto` mode. `deny` covers the non-negotiables (`curl`, `rm -rf`, reading secrets). |

These are conventions plus confirmation prompts, not a blocking hook. The `ask` rules surface a prompt before each risky command so nothing lands on a protected branch by accident, but the final decision is yours.

## Code reference rule

When Claude refers to code by a `path:line` location (for example `database/factories/UserFactory.php:311`), it reads those lines and includes the relevant snippet inline in its reply, so you can see the code without opening the file. This applies to every file, not just the example above. The rule lives as a memory preference under `~/.claude/projects/<project>/memory/` and is loaded into context each session.

## RTK

The Bash hook delegates to **RTK (Rust Token Killer)**, a CLI proxy that rewrites development commands (for example, `git status` → `rtk git status`) to cut token usage on tool output. Install RTK separately and verify with `rtk --version`.

## Usage

There are two ways to use this, depending on whether you want to keep the repository on the machine.

### A. Your main machine — keep the repository, symlink (live editing)

Clone once, then two idempotent commands:

```bash
git clone git@github.com:mantunesribeiro/claude.git && cd claude
./install.sh   # first-time setup
./update.sh    # re-sync ~/.claude after you change the repository
```

`install.sh` **symlinks** everything into `~/.claude` (backing up any real, pre-existing file to `*.bak` once), registers the plugin marketplaces, and checks for `rtk`. It will not overwrite an existing `~/.claude/CLAUDE.md`; it links the git rules as `~/.claude/git-rules.md` and **automatically appends** `@git-rules.md` to your `~/.claude/CLAUDE.md` so they load globally (no manual step).

Because the configuration is symlinked, editing a file in this repository takes effect immediately. `update.sh` covers what symlinks don't: newly added configuration files and refreshing plugin marketplaces (`claude plugin marketplace update`). After pulling from elsewhere, run `git pull && ./update.sh`.

### B. Other machines — no repository, copy (one-liner)

Install **and** update with the same command (re-running overwrites the copies):

```bash
curl -fsSL https://raw.githubusercontent.com/mantunesribeiro/claude/main/bootstrap.sh | bash
```

`bootstrap.sh` downloads the repository tarball to a temporary directory, **copies** the configuration into `~/.claude` (no symlinks, no repository left behind), then deletes the temporary directory. By default it tracks `main`, so you don't need to set anything. To pin to a specific point instead, set `REF` to any branch, tag, or commit: `curl -fsSL .../bootstrap.sh | REF=<branch-tag-or-commit> bash`. Edit configuration only on your main machine; re-run this to pull the latest onto the others.

After any of the above, restart Claude Code and confirm with `/status` (look for **User settings** under "Setting sources").
