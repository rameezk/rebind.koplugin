# Cleaning up a worktree

Run cleanup only when the user explicitly asks, and only after confirming the work is preserved (merged, pushed, or explicitly not wanted).

1. Verify the worktree is safe to remove:

   ```bash
   cd <worktree-path>
   git status --short          # should be empty; list anything dirty for the user
   git log <base>..<branch>     # confirm this work is merged or otherwise preserved
   ```

2. Remove the worktree from its parent directory (not from inside it):

   ```bash
   git worktree remove <worktree-path>
   ```

   Git refuses if the worktree is dirty. Never use `--force` without explicit user approval after listing the files that would be lost.

3. Delete the branch only if the work is merged:

   ```bash
   git branch -d <branch-name>
   ```

   `-d` fails safely if the branch is unmerged. Use `-D` only with explicit user approval after showing what would be lost.

4. Prune stale worktree metadata:

   ```bash
   git worktree prune
   ```

## Safety rules

- Never discard, move, or overwrite uncommitted user changes.
- Do not remove the worktree or delete its branch automatically. Cleanup requires explicit user approval and must follow the procedure above, and must happen only after confirming that all wanted work is preserved.
