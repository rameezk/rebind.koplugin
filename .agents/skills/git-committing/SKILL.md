---
name: git-committing
description: Create clear, consistent git commits. Use whenever a commit is about to be made - both when the user asks to "commit"/"stage"/"save work" and when you the agent reach a committable unit of change mid-task. Never run `git commit` directly instead of invoking this skill. Enforces a commit-message convention and keeps commits focused.
---

# Git Committing

## When to use

- The user asks to "commit", "stage", "save work", or "make a commit"
- After finishing a logical unit of change worth recording

## Message format

Follow Conventional Commits: `<type>(<optional-scope>): <subject>`

Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `spike`.

Rules:
- Subject in imperative mood, lowercase, no trailing period: `fix: handle expired login token`
- Keep the subject under ~72 characters
- Add a body when the "why" is non-obvious. Separate it from the subject with a
  blank line. Explain intent and context, not a line-by-line diff.
- Reference issues in the body or footer when relevant: `Closes #17`

## Workflow

1. Check state: `git status`, `git branch --show-current`, and `git diff` (plus
   `git diff --staged`) to see exactly what will be committed. Never commit
   blind. If HEAD is on the default branch or a stale, already-merged feature
   branch, resolve that per the guardrails below before staging.
2. Stage deliberately: stage only the files that belong to this change. Prefer
   explicit paths over `git add -A` / `git add .`.
3. Group logically: one coherent change per commit. Split unrelated work into
   separate commits.
4. Commit: `git commit -m "<subject>"` (add `-m` body lines as needed, or use
   `git commit -F -` for a multi-paragraph body). Respect the repo's signing
   config; never disable signing with `--no-gpg-sign`.
5. Report the resulting commit (`git log -1 --oneline`).

## Guardrails

- NEVER commit directly on the default branch. If HEAD is on it, stop and
  switch to (or create) a feature branch following `<type>/<short-description>`
  before committing - [[git-branching]] covers the full convention and
  how to branch off an up-to-date default.
- NEVER add an agent co-author trailer, attribution, generated-by credit, or
  session link to the message.
- NEVER manually edit `CHANGELOG.md` or other auto-generated files as part of a
  commit.
- If a pre-commit hook fails, fix the underlying issue. Never bypass it with
  `--no-verify`.
- Dirty or unexpected state (unresolved merge, unrelated staged changes): stop
  and report. Don't silently reset, stash, or amend.
- If currently on a feature branch, ensure the branch name matches the context.
  It may still be on a previous, already-merged feature branch. If so, inform
  the user or agent.

## Avoid

- Vague subjects: `fix: bug`, `chore: stuff`, `update`
- Catch-all commits that bundle unrelated changes
- Committing generated artifacts, secrets, or debug leftovers
