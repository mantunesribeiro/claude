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
| `install.sh` | First-time setup: symlinks everything into `~/.claude` (with backups), wires the git rules, registers plugin marketplaces, sanity-checks. |
| `update.sh` | Re-syncs `~/.claude` with the repo after you edit it (new files, plugin marketplaces). |
| `bootstrap.sh` | One-liner remote installer for machines that don't keep the repo: downloads the tarball and **copies** the config into `~/.claude`. Re-run to update. |
| `_lib.sh` | Shared helpers + the single file map, sourced by all scripts. |

## Settings overview

`settings.json` configures:

- **Model**: `opus`, with `effortLevel` set to `xhigh` and the `dark-ansi` theme.
- **Privacy**: telemetry and error reporting disabled (`DISABLE_TELEMETRY`, `DISABLE_ERROR_REPORTING`).
- **Attribution**: empty commit/PR trailers, so commits and PRs are not tagged with Claude attribution.
- **Permissions**:
  - `allow` — `npm run lint`, `npm run test *`, reading `~/.zshrc`.
  - `deny` — `curl`, `rm -rf`, reading `.env` / `.env.*` files and anything under `secrets/`.
  - `ask` — confirm before `git commit` / `git push` / `git merge` / `git rebase` / `git reset --hard` (including the `rtk`-proxied variants). Force pushes fall under `git push` and are confirmed, not blocked.
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

Philosophy: **alert, don't block.** Three layers warn about risky git operations and ask for confirmation — the user stays in control and nothing is prevented outright:

1. **`CLAUDE.md`** — natural-language intent. Tells the agent to warn first, prefer a feature branch + PR, and show `git status` / `git diff --cached` before committing — without forcing it.
2. **`permissions` (deny / ask)** in `settings.json` — `ask` confirms git commit/push/merge/rebase/reset --hard. `deny` is reserved for the few non-negotiables (`curl`, `rm -rf`, reading secrets).
3. **`branch-guard.sh`** (`PreToolUse` hook) — deterministic code that runs before every Bash command and **asks for confirmation** (it returns `permissionDecision: "ask"`, exit `0`) when it sees:

- a force push (`--force` / `-f` / `--force-with-lease`) on any branch;
- a direct push to a protected branch (`git push origin main`, `HEAD:main`, …);
- `git merge` / `git rebase` / `git reset --hard` while *on* a protected branch.

Its substring regexes also match `rtk`-proxied commands, so it composes with the RTK hook. Protected branches come from `.protected-branches` (falling back to `main master production release`).

> If you want a hard, undodgeable boundary, put it **outside** the agent: an OS-level sandbox (e.g. [`ai-jail`](https://github.com/akitaonrails/ai-jail)) and/or server-side branch protection. These client-side layers are tripwires that alert you — they are not a cage.

Test the hook directly (expect a JSON `permissionDecision: "ask"` and `exit: 0`):

```bash
echo '{"tool_input":{"command":"git push origin main"}}' | bash hooks/branch-guard.sh; echo "exit: $?"
```

## RTK

The Bash hook delegates to **RTK (Rust Token Killer)**, a CLI proxy that rewrites dev commands (e.g. `git status` → `rtk git status`) to cut token usage on tool output. Install RTK separately and verify with `rtk --version`.

## Usage

There are two ways to use this, depending on whether you want to keep the repo on the machine.

### A. Your main machine — keep the repo, symlink (live editing)

Clone once, then two idempotent commands:

```bash
git clone git@github.com:mantunesribeiro/claude.git && cd claude
./install.sh   # first-time setup
./update.sh    # re-sync ~/.claude after you change the repo
```

`install.sh` **symlinks** everything into `~/.claude` (backing up any real, pre-existing file to `*.bak` once), registers the plugin marketplaces, and checks for `rtk`. It will not overwrite an existing `~/.claude/CLAUDE.md`; it links the git rules as `~/.claude/git-rules.md` and **automatically appends** `@git-rules.md` to your `~/.claude/CLAUDE.md` so they load globally (no manual step).

Because the config is symlinked, editing a file in this repo takes effect immediately. `update.sh` covers what symlinks don't: newly added config files and refreshing plugin marketplaces (`claude plugin marketplace update`). After pulling from elsewhere, run `git pull && ./update.sh`.

### B. Other machines — no repo, copy (one-liner)

Install **and** update with the same command (re-running overwrites the copies):

```bash
curl -fsSL https://raw.githubusercontent.com/mantunesribeiro/claude/main/bootstrap.sh | bash
```

`bootstrap.sh` downloads the repo tarball to a temp dir, **copies** the config into `~/.claude` (no symlinks, no repo left behind), then deletes the temp dir. Pin a version with `REF`: `curl -fsSL .../bootstrap.sh | REF=v1.0.0 bash`. Edit config only on your main machine; re-run this to pull the latest onto the others.

After any of the above, restart Claude Code and confirm with `/status` (look for **User settings** under "Setting sources").
