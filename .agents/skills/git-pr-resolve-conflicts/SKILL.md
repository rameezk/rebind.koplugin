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
beside this skill's own: when a step hands work to one, load that skill and
follow its instructions in full before doing the step. Loading it means reading
every line of that `SKILL.md`, and every file it links to that the step relies
on, before acting: never a `head`, a line range or any other partial read, since
the rules a skill ends on - its guardrails and its completion bar - are the ones
a truncated read drops. Never do the step from the summary here; it says only
what this skill adds.

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

Put the change through two independent reviews, run in **separate sub-agents
launched in one message** so they go concurrently in isolated contexts, each
with fresh eyes on code this session is biased toward: [[code-review]] for
standards and spec conformance, and [[security-review]] for vulnerabilities.
Each runs as a single sub-agent reporting back here; [[code-review]] folds its
own Standards and Spec axes into inline passes rather than spawning them
further, since it is nested (its step 4 covers this). Run both against the
**merged commit** - the base commit this merge brought in - and pass it to each
sub-agent as the explicit fixed point, so neither has to ask, along with the
output of `git show --remerge-diff <merge commit>` and the list of follow-up
commits: those are what the review judges, and the rest of the PR's diff is
context. Pin the other end too: pass the head as the exact commit SHA (`git
rev-parse HEAD` at launch), never a bare `HEAD`. Each review states the range it
covered on its first line; record that SHA against the review's result, because
*Push* checks it. Both are strictly read-only. Collect both reports, then triage
as the orchestrator - and treat this as a **loop, not a single pass**, the way a
human change goes back to its reviewers until they sign off:

- Fix real findings the way *Check what the merge broke* fixes a break -
  test-first through a fresh [[tdd]] cycle when there is behaviour to test, not
  a patch that skips the loop - landing each fix as its own follow-up commit.
- For a finding you judge not worth acting on, say which and why - do not
  silently drop it.
- Then hand the updated diff back for another pass. Scope the re-review to
  **what the fix commits changed, not to which review raised the finding**:
  every review whose domain those new commits could touch runs again. A fix is
  new code, and new code carries new risk - so a fix made for a [[code-review]]
  finding still gets a fresh [[security-review]], because the change you just
  wrote could introduce a vulnerability the earlier clean pass never saw. A
  review may skip re-running only when the new commits provably cannot reach its
  domain (for example, a docs-only or comment-only follow-up needs no security
  re-review); a clean prior result is never on its own a reason to skip. When
  unsure, re-run it.

Repeat until every review comes back clean - no actionable findings left beyond
the ones you have explicitly and defensibly set aside. Keep the loop honest: if
a reviewer keeps flagging the same thing and you keep declining it, stop and
surface the disagreement to the user rather than spinning.

## Push - only once every review covers the head

Before pushing, run `git rev-parse HEAD` and check each review in turn. A review
covers the head when its last clean pass was at exactly that SHA, or when every
commit after that pass provably cannot reach the review's domain, by the same
test *Review what the resolution changed* uses, and you can name each such
commit and why. If any review does not cover the head, go back to *Review what
the resolution changed* - do not push. This is the check that catches a fix
commit landing after the last review: a fix is new code, and an unreviewed fix
is an unreviewed change.

Then push the merge commit and any follow-ups to the PR branch:

```bash
git push
```

Never force-push. If the push is rejected because the branch moved, fetch it,
merge it in the same way, and go back through *Check what the merge broke* and
*Review what the resolution changed*.

## Wait for the required checks - and fix what goes red

The push is not the finish line. Wait for the PR's required checks on the pushed
head exactly as [[work-on]]'s *Wait for the required checks* step does - poll
until every check has registered on the new head (a "no checks reported" answer
is never a result), watch them until they settle the way that step does, then
learn which are required from `gh pr checks --required`, or take every reported
check when it names none.

Read the PR's mergeability on every poll too. If the base moves while you wait
and the PR conflicts again:

- **When your instructions named the commit to merge**, stop waiting and report
  it: that newer conflict is the orchestrator's next run.
- **Otherwise**, resolve it the same way - merge the new base in, check, review,
  push - and wait again.

When a required check fails, read its log, then fix the cause through the same
loop as *Check what the merge broke*: test-first when there is behaviour to
test, and a focused follow-up commit. The fix is new code: put it through
*Review what the resolution changed*, and push only once both reviews cover the
head. Then watch again, until every required check is green. If a check
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
the repo's checks are clean, [[code-review]] and [[security-review]] each ran in
its own sub-agent, were driven to sign-off, and cover the pushed head, the merge
and any follow-ups are pushed without a force-push, the PR no longer conflicts
with what was merged, its required checks are green on the pushed head, any
`## Reviews` section covers that head, and any `## Before / After` section shows
that head against its base. Report the PR URL, the commit merged, each
conflicted file and how it was resolved, the merge commit and any follow-up
SHAs, the test and check results, how the review findings were handled with each
review's last clean SHA, the required checks' final state, and the before/after
assets commit SHA when the section was refreshed.
