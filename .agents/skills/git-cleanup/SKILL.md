---
name: git-cleanup
description: Remove stale worktrees and local branches - those whose work is already merged - after a single confirmation. Sweeps the whole repository, or just the branches or worktree paths given as arguments. Use when the user asks to "clean up stale worktrees and branches", or to clean up a specific one.
disable-model-invocation: true
---

# Git Cleanup

Find every worktree and local branch whose work is already preserved on the
default branch, show the user one plan, and on a single confirmation remove
them all. Anything that is not provably merged is reported and left alone.

## Scope

With no arguments, consider every worktree and local branch. With arguments,
consider only those - each is a branch name or a worktree path, and a worktree
brings its branch with it (and vice versa). An argument that matches nothing is
reported, not guessed at.

## Gather state

Assumes `gh` is authenticated. If `gh auth status` fails, continue without PR
evidence - only ancestry-merged branches will qualify - and say so in the plan.

```bash
git fetch --prune origin
default=$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||')
git worktree list --porcelain
git for-each-ref --format='%(refname:short) %(objectname) %(upstream:short) %(upstream:track)' refs/heads
gh pr list --state merged --limit 200 --json number,headRefName,headRefOid,mergedAt
```

If `origin/HEAD` is not set, run `git remote set-head origin --auto` first.

## Classify each local branch

Never consider the default branch, or the branch checked out in the main
worktree or in the worktree this session is running in.

A branch is **merged** when either holds:

- **Ancestry** - `git merge-base --is-ancestor <branch> origin/<default>`
  succeeds (a merge commit or fast-forward).
- **PR record** - a merged PR has `headRefName` equal to the branch and the
  branch tip is that PR's `headRefOid`, or an ancestor of it. This is what
  catches squash and rebase merges, which `git branch -d` cannot see.

Do not try to infer a squash merge by comparing content against the default
branch; it gives false negatives as soon as the default moves on, and false
positives are worse. No ancestry and no matching PR means not merged.

Everything else is **unmerged**. Note why, since the user decides on these:

- upstream `[gone]` with no matching merged PR (closed unmerged, or merged
  from a different tip - local commits were added after the PR merged)
- local commits not on any remote (`git log <branch> --not --remotes`)
- an open PR (`gh pr list --state open --head <branch>`)

## Classify each worktree

Skip the main worktree, the worktree this session is running in, and any
worktree marked `locked`. Worktrees marked `prunable` (directory already gone)
are cleared by `git worktree prune`.

For every other worktree, a removal candidate needs both:

- its branch is **merged** (above), or it is a detached HEAD whose commit is an
  ancestor of `origin/<default>`
- it is clean: `git -C <path> status --porcelain` is empty

A dirty worktree on a merged branch is reported with its dirty files and kept.
Also list ignored files that would be lost (`git -C <path> status --short
--ignored`, filtering `!!` lines) so the user sees things like `.env` before
confirming - `git worktree remove` deletes them without complaint.

## Present the plan

Show one table, grouped:

1. **Will remove** - each worktree path and/or branch, with the evidence
   (`ancestor of origin/main`, or `PR #12 merged, tip matches`)
2. **Kept, needs a decision** - unmerged branches and dirty worktrees, each with
   its reason and what would be lost (commit count and subjects, dirty files)
3. **Skipped** - default branch, current worktree, locked worktrees

Ask once for confirmation of the "Will remove" group. If the user also wants
items from the "Kept" group removed, they must name them explicitly; that is
the approval for `--force` / `-D` on those items only.

If nothing qualifies, say so and stop.

## Execute

From the main worktree, never from inside a worktree being removed:

```bash
git worktree remove <path>
git branch -D <branch>
git worktree prune
```

`-D` is correct here because every branch in "Will remove" was already proven
merged, and squash-merged branches would make `-d` refuse. For a branch proven
by ancestry, `-d` works too.

Do not delete remote branches. The PR merge normally deletes them, and a
remote branch that survives is someone else's call.

Remove empty parent directories left under `.worktree/` (for example
`.worktree/feat/` after its last worktree goes), then report what was removed,
what was kept and why.

## Safety rules

- Never remove anything not shown in the confirmed plan.
- Never `--force` a worktree removal or `-D` an unmerged branch unless the user
  named that specific item after seeing what would be lost.
- If state changed between the plan and execution (a git command fails, a
  worktree became dirty), stop on that item, report it, and continue with the
  rest.
