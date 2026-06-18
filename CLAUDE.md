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
rather than just warning. Still follow the intent below: prefer a feature
branch, and when something is blocked, explain it and suggest the feature-branch
path rather than reaching for `BRANCH_GUARD_MODE=alert` unless I ask.

## Protected branches
The following branches are **protected** and must be treated the same way
throughout these rules: `develop`, `release`, `main`, `master`, `production`.
Whenever a rule below says "a protected branch", it means any of these.
(This list must stay in sync with `.protected-branches`, which `branch-guard.sh` reads.)

## Working on protected branches (blocked by default)
- In `default`/`strict` mode the hook **blocks** committing, merging, or pushing
  directly to a protected branch. Don't try to route around it — instead:
- **Default to the safer path**: open a feature branch
  `git checkout -b <prefix>/<short-description>`
  (prefixes: `feature/`, `fix/`, `docs/`, `chore/`, `refactor/`) and a PR.
- If I genuinely want to work straight on a protected branch, the way through is
  to relaunch with `BRANCH_GUARD_MODE=alert` — only suggest that when I ask;
  don't reach for it on my behalf.
- Before any commit/push, **show me `git status` and `git diff --cached`** so I
  can see exactly what's going out.

## Integrating changes
- A Pull Request is the **preferred** way to reach a protected branch. In
  `default`/`strict` mode a direct merge/push to it is blocked; if I ask to go
  direct, point me at `BRANCH_GUARD_MODE=alert` rather than working around the
  hook.
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
1. Note the current branch. If it's a protected one, **say so and suggest** a
   feature branch — but don't force it; follow my call.
2. Show `git status` + `git diff --cached` for the files you changed.
3. Commit the changes (no co-author; attribution is disabled).
4. `git push`. If the target is a protected branch, in `default`/`strict` mode
   the hook **blocks** it — push the feature branch instead and open a PR. Only
   if I explicitly want a direct push do I relaunch with `BRANCH_GUARD_MODE=alert`.
5. Prefer opening/updating a PR.
