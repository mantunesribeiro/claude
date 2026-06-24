# Git rules (protected workflow)

These rules apply to ALL of my projects. They complement the permissions in
`settings.json`. There is no enforcement hook: these are conventions you are
expected to follow, with the `ask` permission prompts as the only automatic
guardrail.

Philosophy: **safe by default.** Prefer a feature branch and a pull request,
and never run a destructive or history-rewriting command as a silent side
effect of another task.

## Protected branches
The following branches are **protected** and must be treated the same way
throughout these rules: `develop`, `release`, `main`, `master`, `production`.
Whenever a rule below says "a protected branch", it means any of these.

## Working on protected branches
- Prefer the safer path: open a feature branch
  `git checkout -b <prefix>/<short-description>`
  (prefixes: `feature/`, `fix/`, `docs/`, `chore/`, `refactor/`) and a pull
  request, rather than committing or pushing straight to a protected branch.
- If I ask to work directly on a protected branch, that is fine: commit and
  push to it, staging only the files I changed.
- In every case, before any commit or push, **show me `git status` and
  `git diff --cached`** so I can see exactly what is going out.

## Integrating changes
- A pull request is the preferred way to reach a protected branch. Open one
  unless I ask to go direct.
- To update a branch with its base, **prefer `git merge`** over `git rebase`.
  `rebase` rewrites history: warn me before running it.

## Destructive operations (warn + confirm, never silently)
- `git push --force` / `git push -f` / `--force-with-lease`
- `git reset --hard`
- `git rebase` (history rewrite)
- Any command that rewrites the history of a shared branch.
For each: explain what it will do and why it is risky, then run it only after I
confirm. Never run one of these as a silent side effect of another task.

## Commit rules
- There may be pre-existing staged changes that I do NOT want committed.
- Never run `git add -A`, `git add .`, `git commit -a`, or a blanket `git add`.
- To commit the session's work, use `git commit <files> -m "..."`, passing
  explicitly only the files you changed in this session.
- This ensures anything that was already staged beforehand stays untouched.
- If you are unsure which files are yours, run `git status`, show what you
  intend to include, and ask for confirmation before committing.

## Expected flow when finishing a task
1. Note the current branch.
2. Show `git status` + `git diff --cached` for the files you changed.
3. Commit the changes (no co-author; attribution is disabled).
4. Push: prefer a feature branch and a pull request, unless I ask to push
   straight to the protected branch.

# Code references

- When you refer to code by a `path:line` location (for example
  `database/factories/UserFactory.php:311`), read those lines and include the
  relevant snippet inline in the reply, so I can see the code without opening
  the file.
- This applies to every file, not just the example above. Quote a few lines of
  surrounding context, not only the single line.
