# Git Rules (protected workflow) — GLOBAL

These rules apply to ALL of my projects. They complement the `branch-guard`
hook and the permissions in `settings.json`.
The hook is the real barrier; these instructions exist so you understand the *intent*.

## Protected branches
The following branches are **protected** and must be treated the same way
throughout these rules: `main`, `master`, `production`, `release`.
Whenever a rule below says "a protected branch", it means any of these.
(This list must stay in sync with `.protected-branches`, which `branch-guard.sh` reads.)

## Protected branches: never touch directly
- **Never** commit, merge, or push directly to any protected branch.
- All work happens on a feature branch:
  `git checkout -b <prefix>/<short-description>`
  Prefixes: `feature/`, `fix/`, `docs/`, `chore/`, `refactor/`.

## Integrating changes
- Changes reach a protected branch **only via Pull Request**.
- To update a branch with its base, **use `git merge`** (not `git rebase`).
  `rebase` is treated as destructive and requires my explicit approval.

## Destructive operations (forbidden unless I explicitly ask)
- `git push --force` / `git push -f` / `--force-with-lease`
- `git reset --hard`
- `git rebase` on a protected branch
- Any command that rewrites the history of a shared branch.

## Commit rules
- There may be pre-existing staged changes that I do NOT want committed.
- Never run `git add -A`, `git add .`, `git commit -a`, or a blanket `git add`.
- To commit the session's work, use `git commit <files> -m "..."`, passing
  explicitly only the files you changed in this session.
- This ensures anything that was already staged beforehand stays untouched.
- If you're unsure which files are yours, run `git status`, show what you
  intend to include, and ask for confirmation before committing.

## Expected flow when finishing a task
1. Make sure you are on a feature branch (not a protected branch).
2. Commit the changes (no co-author; attribution is disabled).
3. `git push` the feature branch (never a protected branch).
4. Open/update the Pull Request.
5. Stop there. Merging into a protected branch is done by me (or by the server-side branch protection).
