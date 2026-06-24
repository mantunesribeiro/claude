# Git commit rules

- Pre-existing staged changes may exist that I do NOT want committed.
- Never `git add -A`, `git add .`, `git commit -a`, or a blanket `git add`.
- Commit only the session's files explicitly: `git commit <files> -m "..."`.
  Naming the files leaves anything else already staged untouched and
  uncommitted; a bare `git commit` (no paths) commits the whole index instead.
  New files must be named too.
- If unsure which files are mine, run `git status`, show what you intend to
  include, and ask before committing.
