# Git Rules (protected workflow) — GLOBAL

These rules apply to ALL of my projects. They complement the `branch-guard`
hook and the permissions in `settings.json`.
Philosophy: **alert, don't block.** The `branch-guard` hook and the `ask`
permissions *warn me and ask for confirmation* on risky git operations — they
do not prevent them. I stay in control and decide. These instructions exist so
you understand the intent and default to the safer choice without being forced.

## Protected branches
The following branches are **protected** and must be treated the same way
throughout these rules: `main`, `master`, `production`, `release`.
Whenever a rule below says "a protected branch", it means any of these.
(This list must stay in sync with `.protected-branches`, which `branch-guard.sh` reads.)

## Working on protected branches (warn, don't block)
- Committing, merging, or pushing directly to a protected branch is **allowed**,
  but it is risky — **warn me first**, then proceed once I confirm.
- **Default to the safer path** without forcing it: prefer a feature branch
  `git checkout -b <prefix>/<short-description>`
  (prefixes: `feature/`, `fix/`, `docs/`, `chore/`, `refactor/`) and a PR.
  Suggest it, but if I say work directly on the protected branch, do so.
- Before any commit/push, **show me `git status` and `git diff --cached`** so I
  can see exactly what's going out (this is the discipline that replaces hard
  blocking).

## Integrating changes
- A Pull Request is the **preferred** way to reach a protected branch — not the
  only one. If I ask to merge/push directly, alert me to the risk and do it.
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
4. `git push`. If the target is a protected branch, the warn+confirm fires —
   that's expected; proceed once I confirm.
5. Prefer opening/updating a PR. If I asked to go straight to the protected
   branch, that's fine — you already warned me.
