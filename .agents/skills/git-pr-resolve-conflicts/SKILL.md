---
name: git-pr-resolve-conflicts
description: Resolve a GitHub PR's merge conflicts with its base end-to-end - merge the base into the PR's branch, resolve each conflict keeping both sides' intent, review what the resolution changed, push, see the required checks go green, and refresh the PR's before/after screenshots. Never rebases or force-pushes. Use when the user asks to "resolve the conflicts" / "fix the merge conflicts" / "update the PR with main" on a pull request that conflicts with its base.
disable-model-invocation: true
---

# Git PR Resolve Conflicts

Take a PR that already exists and conflicts with its base, and bring it back to
mergeable: merge the base into the PR's branch, resolve every conflict, review
what the resolution changed, push, and see the required checks go green. This
operates on an open PR - it does not raise one (that was [[git-pr]]) and it does
not merge one.

The base is always **merged in, never rebased onto**. A rebase rewrites commits
reviewers have already seen, orphans the inline comments anchored to them, and
needs a force-push. A merge keeps the pushed history intact and records the
resolution as one commit a reviewer can read on its own.

Each `[[name]]` here is another skill, whose file is `../<name>/SKILL.md`
beside this skill's own: when a step hands work to one, load that skill by
reading that file and follow its instructions in full before doing the step.
Never do the step from the summary here.

## When to use

- The user asks to "resolve the conflicts", "fix the merge conflicts" or "bring
  the PR up to date with main" on a pull request.
- A PR shows as conflicting with its base and cannot merge.

## Identify the target PR

Work on the PR the user names - a number or URL. If they name none, resolve it
from the current branch:

```bash
gh pr view --json number,headRefName,baseRefName,url
```

Resolve the repository's `owner` and `name` too:

```bash
gh repo view --json owner,name -q '.owner.login + " " + .name'
```

Assumes `gh` is authenticated. If `gh auth status` fails, stop and ask the user
to run `gh auth login`.

## Work in the PR branch's worktree

Do the merge in a worktree on the PR's existing branch, set up with
[[git-worktree]], so the user's current checkout is never touched. A fresh clone
an orchestrator started you in, already on the PR's branch, counts as that
worktree.

Before merging anything, check the worktree is clean (`git status --short`) and
bring it up to date with the pushed branch, which a reviewer or CI may have
added to:

```bash
git fetch origin <headRefName>
git merge --ff-only origin/<headRefName>
```

If it has uncommitted changes, or local commits that diverge from the pushed
branch, stop and report it rather than stashing, resetting or merging over
someone's work.

## Decide what to merge

**When your instructions already name what to merge** - an orchestrator that
started this run handed over the base branch, the exact commit to merge, and the
files that conflicted - that commit is the work. Merge exactly that commit, not
the base's current tip, even if the base has moved on since: the orchestrator
judges this run against the commit it gave, and a newer conflict is its next
run, not this one. Expect the listed files to conflict, but resolve whatever the
merge actually reports.

Otherwise, read the PR's mergeability:

```bash
gh pr view <number> --json mergeable,mergeStateStatus
```

- `UNKNOWN` means GitHub is still computing it - read it again.
- `MERGEABLE` means there is nothing to resolve - say so and stop.
- `CONFLICTING` (a `DIRTY` merge state) is the work. Fetch the base and merge
  its current tip:

  ```bash
  git fetch origin
  ```

## Merge the base in

```bash
git merge --no-ff --no-commit <commit or origin/<base>>
```

If the merge reports no conflicts after all - GitHub's flag was stale - conclude
it with [[git-committing]] and carry on from *Check what the merge broke*; the
PR still needed the base merged in to become mergeable. If it reports
`Already up to date`, there was nothing to merge - say so and stop.

List what conflicted:

```bash
git diff --name-only --diff-filter=U
```

## Resolve each conflict

Work one file at a time. For each conflict, understand both sides before
touching it: read what this PR changed there (`git log -p --merge -- <file>`
shows the commits from both sides that touched it) and what the base changed,
and why. Then resolve it so **both sides' intent survives**: the PR's change,
applied on top of what the base now does.

- Never resolve by taking one side wholesale - `git checkout --ours/--theirs`,
  `-X ours/theirs`, or deleting a hunk - unless reading both sides shows the
  other side's change is genuinely subsumed. Say so when you do.
- A conflict is not only its markers. When the base renamed, moved or changed
  the signature of something this PR uses, follow it through the PR's other
  changes too, conflicted or not.
- If keeping both intents would mean **choosing between two behaviours** rather
  than combining them, that is a decision, not a resolution. Abort the merge
  with `git merge --abort` so nothing half-resolved is left behind, and stop:
  report the conflict, both sides, and the choice it needs to the user.

Mark each file resolved with `git add <file>` once no markers remain, then
conclude the merge with [[git-committing]].

## Check what the merge broke

A clean textual merge can still be broken: the base may have changed something
the PR relies on without touching the same lines. The merge commit is new code.

1. **Run the repo's mechanical checks.** Get the project's formatter, linter,
   and type-checker clean, however this repo runs them.
2. **Run the tests for what the merge touched**, by the repo's own rules for
   local checks - its scoped commands where it defines them, the full suite
   where it does not.
3. **Fix what went red.** A break the merge introduced is fixed as a focused
   follow-up commit, not folded into the merge commit: test-first through a
   fresh [[tdd]] cycle when there is behaviour to test, made directly when there
   is not. Say which path you took.

## Review what the resolution changed

Review the resolution, not the whole PR: the merge commit's own decisions and
any follow-up fixes. `git show --remerge-diff <merge commit>` shows exactly how
the resolution differs from git's automatic merge - the part a person or agent
chose.

Put that through [[code-review]] and [[security-review]] and drive the
review-fix-re-review loop to sign-off, as [[work-on]] does, pinning the head
review to an exact SHA. A resolution that only combined non-overlapping lines,
with no behaviour to judge, does not need both reviews; use judgement and say
what you ran.

## Push

Push the merge commit and any follow-ups to the PR branch:

```bash
git push
```

Never force-push. If the push is rejected because the branch moved, fetch it,
merge it in the same way, and go back through *Check what the merge broke*.

## Wait for the required checks - and fix what goes red

The push is not the finish line. Wait for the PR's required checks on the pushed
head exactly as [[work-on]]'s *Wait for the required checks* step does - learn
which checks are required from the base branch's rules, poll until every one has
registered on the new head (a "no checks reported" answer is never a result),
then watch them until they settle with `gh pr checks --watch --required`.

Read the PR's mergeability on every poll too. If the base moves while you wait
and the PR conflicts again:

- **When your instructions named the commit to merge**, stop waiting and report
  it: that newer conflict is the orchestrator's next run.
- **Otherwise**, resolve it the same way - merge the new base in, check, review,
  push - and wait again.

When a required check fails, read its log, then fix the cause through the same
loop as *Check what the merge broke*: test-first when there is behaviour to
test, a focused follow-up commit, and a proportional review of what the fix
changed. Push, and watch again, until every required check is green. If a check
never appears on a mergeable PR, find out why and report it rather than calling
the checks green. If the checks cannot be read at all - a token without access
to them, say - say so in the report rather than claiming they passed.

## Bring the PR's `## Reviews` section up to date

If the PR description has a `## Reviews` section, the merge has made it describe
an older head. Once the checks are green, edit it with
`gh pr edit <number> --body-file <file>` so it covers the pushed head by
[[git-pr]]'s rules: each review's last clean SHA, and for every commit after it,
the commit and why it cannot reach that review's domain. A commit you cannot
name that way for some review means that review has to run on it first - go back
to *Review what the resolution changed*, then push and wait for the checks
again. Change only that section; the rest of the description is the author's.
If the PR has no `## Reviews` section, do not add one.

## Bring the PR's `## Before / After` section up to date

The merge moved both sides of the PR's screenshots: the base is newer, and the
resolution may have changed how the PR's own UI change looks. Once the checks
are green, run [[before-after]] on the open PR - its usual before ref, the PR's
base, and the pushed head as after - by reading `../before-after/SKILL.md` and
the [`screenshots.md`](../before-after/screenshots.md) beside it and following
them in full, never a capture of your own. Its rules bind every image it
publishes, above all its no-sensitive-data rule and its review of every image
before publishing. It replaces the section, adds one when the merge made the
PR's change visible, and removes a stale one when nothing visual remains; when
the PR changes nothing a user sees, its escape hatch leaves everything as it
is. Being unable to capture a visual change is a blocker to report, never a
reason to leave stale screenshots in place.

The skill stops here. It posts no comment - the merge commit is the record. It
does not merge the PR, does not change whether it is a draft, and does not
change any ticket's status.

## Guardrails

- Never rebase the PR's branch and never force-push it.
- Never take one side of a conflict wholesale without reading both, and never
  pick between two behaviours on your own - abort the merge and ask.
- Never leave a half-resolved merge behind: either conclude it with every
  conflict resolved, or `git merge --abort`.
- NEVER add an agent co-author trailer, attribution, generated-by credit, or
  session link to a commit or the PR description.
- Assumes `gh` is authenticated. If `gh auth status` fails, stop and ask the user
  to run `gh auth login`.

## Completion

Done when the base - or exactly the commit your instructions named - is merged
into the PR's branch with every conflict resolved to keep both sides' intent,
the repo's checks are clean, the reviews that ran came back signed off, the
merge and any follow-ups are pushed without a force-push, the PR no longer
conflicts with what was merged, its required checks are green on the pushed
head, any `## Reviews` section covers that head, and any `## Before / After`
section shows that head against its base. Report the PR URL, the
commit merged, each conflicted file and how it was resolved, the merge commit
and any follow-up SHAs, the test and check results, how the review findings
were handled, the required checks' final state, and the before/after assets
commit SHA when the section was refreshed.
