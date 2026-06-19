# Git Rules (protected workflow) — GLOBAL

These rules apply to ALL of my projects. They complement the `branch-guard`
hook and the permissions in `settings.json`.

Philosophy: **safe by default, with an escape hatch.** The `branch-guard` hook
has three modes, set via the `BRANCH_GUARD_MODE` env var when Claude Code is
launched:

- `alert` — never blocks; only warns and asks for confirmation, even on a
  protected branch (for committing straight to it without a pull request each
  time).
- `default` (when the var is unset) — **blocks** ops that touch a protected
  branch (commit/merge/rebase/push/reset/force push); only **alerts** on other
  branches.
- `strict` — blocks destructive ops (force push, `reset --hard`) on *any*
  branch, and blocks any write to a protected branch.

So in the usual `default` mode the hook *prevents* writes to a protected branch
rather than just warning. Follow the intent per mode:

- In `default`/`strict`: prefer a feature branch + PR, and when something is
  blocked, explain it and suggest the feature-branch path rather than reaching
  for `BRANCH_GUARD_MODE=alert` unless I ask.
- In `alert`: **no PR needed.** Committing and pushing straight to the protected
  branch is the expected flow — the hook only warns and asks me to confirm.
  Don't create a feature branch or open a PR by default; do the direct commit +
  push (staging only the files I changed) and let the hook's confirm prompt be
  the safety check. Only branch/PR if I ask for it.

## Protected branches
The following branches are **protected** and must be treated the same way
throughout these rules: `develop`, `release`, `main`, `master`, `production`.
Whenever a rule below says "a protected branch", it means any of these.
(This list must stay in sync with `.protected-branches`, which `branch-guard.sh` reads.)

## Working on protected branches
- **In `alert` mode**: working straight on a protected branch is fine and
  expected. Commit and push directly to it — no feature branch, no PR — staging
  only the files I changed. The hook's warn-and-confirm prompt is the guardrail.
- **In `default`/`strict` mode**: the hook **blocks** committing, merging, or
  pushing directly to a protected branch. Don't try to route around it — instead:
  - **Default to the safer path**: open a feature branch
    `git checkout -b <prefix>/<short-description>`
    (prefixes: `feature/`, `fix/`, `docs/`, `chore/`, `refactor/`) and a PR.
  - If I genuinely want to work straight on a protected branch, the way through
    is to relaunch with `BRANCH_GUARD_MODE=alert` — only suggest that when I
    ask; don't reach for it on my behalf.
- In every mode, before any commit/push, **show me `git status` and
  `git diff --cached`** so I can see exactly what's going out.

## Integrating changes
- In `default`/`strict` mode a Pull Request is the **preferred** way to reach a
  protected branch; a direct merge/push to it is blocked. If I ask to go direct,
  point me at `BRANCH_GUARD_MODE=alert` rather than working around the hook.
- In `alert` mode a PR is **not** required — push directly to the protected
  branch (confirm prompt aside). Open a PR only when I ask.
- To update a branch with its base, **prefer `git merge`** over `git rebase`.
  `rebase` rewrites history — warn me before running it.

## Destructive operations (warn + confirm, never silently)
- `git push --force` / `git push -f` / `--force-with-lease`
- `git reset --hard`
- `git rebase` (history rewrite)
- Any command that rewrites the history of a shared branch.
For each: explain what it will do and why it's risky, then run it only after I
confirm. Never run one of these as a silent side effect of another task.

## Commit rules
- There may be pre-existing staged changes that I do NOT want committed.
- Never run `git add -A`, `git add .`, `git commit -a`, or a blanket `git add`.
- To commit the session's work, use `git commit <files> -m "..."`, passing
  explicitly only the files you changed in this session.
- This ensures anything that was already staged beforehand stays untouched.
- If you're unsure which files are yours, run `git status`, show what you
  intend to include, and ask for confirmation before committing.

## Expected flow when finishing a task
1. Note the current branch and the active `BRANCH_GUARD_MODE`.
2. Show `git status` + `git diff --cached` for the files you changed.
3. Commit the changes (no co-author; attribution is disabled).
4. Push:
   - **`alert` mode** — commit and `git push` straight to the protected branch;
     the hook will ask me to confirm. No feature branch, no PR unless I ask.
   - **`default`/`strict` mode** — a direct push to a protected branch is
     **blocked**; push a feature branch instead and open a PR. Only if I
     explicitly want a direct push do I relaunch with `BRANCH_GUARD_MODE=alert`.
