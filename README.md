# claude

Personal [Claude Code](https://docs.claude.com/en/docs/claude-code) configuration: settings, a custom statusline, git guardrails, and enabled plugins.

## Contents

| File | Purpose |
| --- | --- |
| `settings.json` | Claude Code settings — model, permissions, hooks, plugins, theme. |
| `statusline-command.sh` | Custom statusline renderer (user, directory, git branch, model, context usage). |
| `hooks/branch-guard.sh` | `PreToolUse` hook that guards dangerous git ops (force push, push/merge/rebase/reset on protected branches). Behaviour set by `BRANCH_GUARD_MODE` (`strict`/`default`/`alert`). |
| `.protected-branches` | Single source of truth for the protected-branch list, read by `branch-guard.sh`. |
| `CLAUDE.md` | Natural-language git workflow rules (the *intent* behind the hook + permissions). |
| `install.sh` | First-time setup: symlinks everything into `~/.claude` (with backups), wires the git rules, registers plugin marketplaces, sanity-checks. |
| `update.sh` | Re-syncs `~/.claude` with the repository after you edit it (new files, plugin marketplaces). |
| `bootstrap.sh` | One-liner remote installer for machines that don't keep the repository: downloads the tarball and **copies** the configuration into `~/.claude`. Re-run to update. |
| `_lib.sh` | Shared helpers + the single file map, sourced by all scripts. |
| `tests/branch-guard.test.sh` | Test suite for the branch-guard hook — asserts deny/ask/allow across every mode in a throwaway git repository. Run it directly, or `install.sh` runs it for you. |

## Settings overview

`settings.json` configures:

- **Model**: `opus`, with `effortLevel` set to `xhigh` and the `dark-ansi` theme.
- **Privacy**: telemetry and error reporting disabled (`DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`).
- **Attribution**: empty commit/pull request trailers, so commits and pull requests are not tagged with Claude attribution.
- **Permissions**:
  - `allow` — `npm run lint`, `npm run test *`, reading `~/.zshrc`.
  - `deny` — `curl`, `rm -rf`, reading `.env` / `.env.*` files and anything under `secrets/`.
  - `ask` — confirm before `git commit` / `git push` / `git merge` / `git rebase` / `git reset --hard` (including the `rtk`-proxied variants). On top of this, `branch-guard.sh` may **block** (not just confirm) operations that touch a protected branch — see [Git guardrails](#git-guardrails) for the modes.
- **Hooks**: a `PreToolUse` hook on `Bash` runs two commands — `rtk hook claude` (token optimization, see [RTK](#rtk)) and [`branch-guard.sh`](#git-guardrails) (git safety).
- **Plugins**: five enabled — see [Plugins](#plugins).

See [Git guardrails](#git-guardrails) for the full defense layering.

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

## Git guardrails

Three layers guard risky git operations — two only warn, while the hook can also **block** depending on its mode:

| Layer | Role |
| --- | --- |
| `CLAUDE.md` | Natural-language intent: prefer a feature branch + pull request, treat protected branches as blocked by default, show `git status` / `git diff --cached` before committing. |
| `settings.json` permissions | `ask` confirms git commit/push/merge/rebase/reset --hard; `deny` covers the non-negotiables (`curl`, `rm -rf`, reading secrets). |
| `branch-guard.sh` (`PreToolUse` hook) | Deterministic guard that runs before every Bash command and **blocks or warns** (per mode). |

The hook acts on:

- a force push (`--force` / `-f` / `--force-with-lease`);
- a direct push to a protected branch (`git push origin main`, `HEAD:main`, …);
- `git commit` / `git merge` / `git rebase` while *on* a protected branch;
- `git reset --hard` on any branch.

This is a **narrow denylist, not an allowlist** — anything that doesn't match a pattern above runs untouched:

| Command | Hook behaviour |
| --- | --- |
| `git status`, `git add`, `git diff`, `git log`, `git fetch`, `git pull`, `git stash` | ✅ passes through |
| `git checkout` / `git switch` / `git branch` | ✅ passes through |
| `git commit` on a non-protected branch | ✅ passes through |
| `git push <feature>` (no `--force`, non-protected target) | ✅ passes through |
| `git clean -fdx`, `git branch -D`, `git push --delete`, `git checkout -- .` | ❗ not caught — destructive, but outside the denylist |

Add a rule to `branch-guard.sh` to cover any of the not-caught cases. The substring matching also recognises `rtk`-proxied forms such as `rtk git push origin main`.

### Modes — `BRANCH_GUARD_MODE`

Set `BRANCH_GUARD_MODE` in the environment that launches Claude Code (for example, `BRANCH_GUARD_MODE=alert claude`) to pick how strict the hook is. It applies for that whole session; when it is unset or invalid, `default` is used.

#### The two situations the hook checks

- **On a protected branch** — any write to a protected branch (`develop`, `release`, `main`, `master`, `production`): commit, push, merge, rebase, reset, or force push.
- **A destructive command on another branch** — a force push or `git reset --hard` run on a branch that is *not* protected.

#### How each mode reacts

| Mode | On a protected branch | Destructive command elsewhere | When to use |
| --- | :---: | :---: | --- |
| `alert` | ⚠️ warns | ⚠️ warns | You commit and push directly to `main` (no pull requests) and don't want to be stopped — a one-line reminder is enough. |
| `default` | 🚫 blocked | ⚠️ warns | You work on feature branches and open pull requests, so a commit or push landing on `main` is almost always a mistake — block it, but stay out of the way on feature branches. |
| `strict` | 🚫 blocked | 🚫 blocked | Same as `default`, and you also never want a force push or `git reset --hard` to slip through on *any* branch — for example a shared repository where losing someone's work would hurt. |

- 🚫 **blocked** — the command is refused and never runs (`permissionDecision: "deny"`).
- ⚠️ **warns** — Claude Code asks you to confirm first and runs it only if you approve (`permissionDecision: "ask"`).

Both decisions exit `0`; if neither `jq` nor `python3` is installed, a block falls back to exit `2`. The substring regexes also match `rtk`-proxied commands, so the guard composes with the RTK hook. Protected branches come from `.protected-branches` (falling back to `develop release main master production`).

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
