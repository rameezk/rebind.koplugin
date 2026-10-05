---
name: git-branching
description: Name git branches and manage their lifecycle - the `<type>/<short-description>` convention, branching off an up-to-date default, and cleanup after merge. Use when naming, creating in the current checkout, or pruning merged branches. For new implementation work prefer git-worktree (isolation), which follows this convention.
---

# Git Branching

For starting new implementation work, prefer [[git-worktree]]: it
branches in a separate worktree so the current checkout is left untouched, and
it follows the naming convention below. Use the in-place branch creation here
only when NOT using a worktree - for example when the user explicitly asks to
work in the current checkout.

## When to use

- When naming a branch (this skill owns the convention)
- When creating a branch directly in the current checkout
- When cleaning up a branch after merge or rebase

## Branch naming

Format: `<type>/<short-kebab-description>`

Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `spike`

Rules:
- Kebab-case, lowercase, no spaces
- Short but descriptive: `fix/login-token-expiry`, not `fix/bug`
- Prefix with a ticket id when the project uses one: `feat/PROJ-123-add-export`. For a GitHub issue such as `#17`, use `feat/17-add-export`.

## Creating a branch in the current checkout

1. Check state with `git status` and `git branch --show-current`. Never assume a
   clean default branch.
2. Update the default branch to match remote, then branch off it:

   ```bash
   git fetch origin
   git switch <default-branch>
   git pull --ff-only
   git switch -c <type>/<name>
   ```

`git fetch` alone updates `origin/<default-branch>` but not your local default,
so switch to the default and fast-forward it before branching. Creating the
branch while on the updated default guarantees it starts from the default
branch regardless of where HEAD was.

## Rules

- ALWAYS branch off the default branch.
- ALWAYS update the default branch from remote before branching.

## Guardrails

- Dirty working tree when asked to branch in place: stop and report. Don't
  silently stash or discard. (For a dirty tree, [[git-worktree]] sidesteps the
  problem by branching in a separate worktree.)

## Cleanup

- After merge, offer to delete the local branch with `git branch -d <name>`
  (use `-d`, not `-D`, to protect unmerged work).
- Prune stale remote-tracking refs with `git fetch --prune` when cluttered.

## Avoid

- Speculative branches created "just in case"
- Reusing an old branch for unrelated new work
