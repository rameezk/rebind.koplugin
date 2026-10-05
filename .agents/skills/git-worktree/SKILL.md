---
name: git-worktree
description: Create an isolated Git worktree and do all implementation work there, keeping the user's current working tree and uncommitted changes untouched. Use before making ANY code changes in a Git repository - new features, bug fixes, refactors, tests, or experiments. Skip only when the task is read-only, the user explicitly asks to work in the current checkout, or no Git repository exists.
---

# Git Worktree

Create a dedicated Git worktree before making implementation changes. Keep the user's current working tree and any uncommitted changes untouched.

## Use this skill when

- Starting a new feature, bug fix, refactor, or experiment
- The current working tree contains unrelated or uncommitted work
- Multiple tasks need to proceed in parallel
- Isolation makes the work safer or easier to review

## Do not use this skill when

- The task is read-only (for example, explanation, investigation, or code review)
- The user explicitly asks to work in the current checkout
- The current checkout is already a dedicated worktree for this task
- The directory is not in a Git repository
- The requested change depends on uncommitted files in the current worktree; ask the user how to handle that dependency instead

## Workflow

1. Before editing files, inspect the repository:

   ```bash
   git status --short --branch
   git worktree list
   git branch --show-current
   ```

2. Determine:
   - the base commit or branch (use the user's requested base; otherwise infer the repository's normal base branch)
   - ensure the base branch is up to date
   - a short, descriptive branch name following [[git-branching]]'s naming convention (`<type>/<short-description>`, for example `feat/add-search`, `fix/null-pointer-crash`, `refactor/extract-utils`), unless the repository defines its own naming convention
   - a worktree path inside a `.worktree/` directory at the repository root, named after the branch (for example `.worktree/feat/add-search`)

   Do not fetch, pull, stash, reset, or modify existing changes unless the user explicitly approves it.

3. Ensure `.worktree/` is excluded from Git so the nested worktree never appears as untracked content or is accidentally committed. Use `.git/info/exclude` (local to the clone) rather than the tracked `.gitignore`, so the user's working tree is left untouched:

   ```bash
   exclude_file="$(git rev-parse --git-common-dir)/info/exclude"
   grep -qxF '.worktree/' "$exclude_file" 2>/dev/null || echo '.worktree/' >> "$exclude_file"
   ```

4. If the branch does not exist, create the worktree and branch together:

   ```bash
   git worktree add -b <branch-name> <worktree-path> <base>
   ```

   If the branch already exists and is not checked out elsewhere:

   ```bash
   git worktree add <worktree-path> <branch-name>
   ```

5. Change into the new worktree and verify it before doing any work:

   ```bash
   cd <worktree-path>
   git status --short --branch
   ```

6. Perform all subsequent edits, builds, and tests in the new worktree, and clearly report the worktree path and branch name to the user. Committing, merging, and cleanup are handled by their own skills - when a unit of work is ready to record, hand off to [[git-committing]] rather than running `git commit` ad hoc.

## Cleaning up a worktree

When the user explicitly asks to remove or clean up a worktree, follow [`CLEANUP.md`](CLEANUP.md): verify the work is preserved, remove the worktree, delete the branch, and prune metadata. Do not start cleanup on your own.

## Safety rules

- Never discard, move, or overwrite uncommitted user changes.
- Never reuse a non-empty directory as a new worktree path.
- Do not guess when the correct base branch is materially ambiguous; ask the user.
