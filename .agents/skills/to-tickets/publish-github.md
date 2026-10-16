# Publish: github

Publish one issue per ticket via `gh` on the configured `repo`.

Join every value-taking flag to its value with `=`, as one shell word: `--parent=7`, `--blocked-by=12,15`. The shell may be zsh or fish, neither of which word-splits a variable, so a flag and value built together from a variable or conditionally reach `gh` as the single unknown flag `--blocked-by 12,15` and the issue is never created; built as `--blocked-by=12,15` they parse in every shell. Issue numbers are bare digits - never `#12`, which the shell reads as a comment.

- **Identity** - the issue number GitHub assigns. Link each ticket to its parent spec issue using GitHub's native **sub-issues** feature, so the spec becomes the parent and every ticket a sub-issue under it: `gh issue create --parent=<spec number>`. This is what naturally connects the parent spec to its child tickets - the spec issue shows the tickets nested beneath it with a completion progress bar, and closing tickets advances it. Prefer this over writing a link into the body; leave the title clean.
- **Status** - a label. Apply `ready-for-agent` or `ready-for-human` to match the quiz, ensuring each exists first and creating it only if absent so an existing label keeps its styling: `gh label list --json name -q '.[].name' | grep -qx ready-for-agent || gh label create ready-for-agent --color 0E8A16` / `gh label list --json name -q '.[].name' | grep -qx ready-for-human || gh label create ready-for-human --color FBCA04`. The colors are the defaults for a fresh repo that lacks these labels. `done` is recorded by *closing* the issue - done by the dispatch step, never here (so a PR's `Closes #NN` can do it).
- **Blocking edges** - GitHub's native **issue dependencies**: `gh issue create --blocked-by=<number>,<number>`. This relationship *is* the blocked marker - GitHub shows the issue as blocked and clears it automatically when the blocker closes, so nothing hand-maintains it. Because blockers are published first, their numbers exist by the time a later ticket needs them. Fall back to a "Blocked by" line in the body only if the tracker has no native edge.

Do not close or modify the parent spec issue.

NEVER add agent attribution, a generated-by credit, or a session link to any issue title, body, or comment you create here.
