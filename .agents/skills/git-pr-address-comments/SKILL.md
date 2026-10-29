---
name: git-pr-address-comments
description: Address the open feedback on a GitHub PR end-to-end - unresolved review threads, review summaries and conversation comments - fix what each asks through a test-first loop, push, see the required checks go green, refresh before/after screenshots of any UI the fixes changed, then answer every item. Use when the user asks to "address the PR comments" / "handle review feedback" on a pull request.
disable-model-invocation: true
---

# Git PR Address Comments

Take a PR that already exists and work its open feedback to done: fetch every
open item, fix what each one asks for test-first, commit and push the fixes, see
the required checks go green, then answer each item. This operates on an open
PR - it does not raise one (that was [[git-pr]]) and it does not merge one.

Feedback comes in three kinds, and every one of them is read every time:

- **Review threads** - inline comments on the diff, which GitHub tracks as
  resolved or unresolved.
- **Review summaries** - the body a reviewer writes when submitting a review,
  with or without inline comments.
- **Conversation comments** - top-level comments on the PR, not tied to a diff
  line.

Answering is where this skill stops - it does not resolve threads. Resolving a
thread is the reviewer's call, made once they are satisfied with the reply; the
skill leaves every thread open with an answer on it.

The signal for what to act on is **whether an item is still open, not
authorship**: address every open item, whoever wrote it. A review bot
(CodeRabbit, Copilot, Claude Code's `/code-review --comment`) is treated exactly
like any other reviewer - the author never changes whether or how an item gets
addressed.

## When to use

- The user asks to "address the PR comments", "handle the review feedback", or
  "action the comments" on a pull request.
- A PR has review threads, review summaries or conversation comments left open
  that need working through.

## Identify the target PR

Work on the PR the user names - a number or URL. If they name none, resolve it
from the current branch:

```bash
gh pr view --json number,headRefName,url
```

Resolve the repository's `owner` and `name` too - the GraphQL and REST calls
below need them:

```bash
gh repo view --json owner,name -q '.owner.login + " " + .name'
```

Assumes `gh` is authenticated. If `gh auth status` fails, stop and ask the user
to run `gh auth login`.

## Work in the PR branch's worktree

Do the work in a worktree on the PR's existing branch, set up with
[[git-worktree]], so the user's current checkout is never touched. A fresh clone
an orchestrator started you in, already on the PR's branch, counts as that
worktree.

Before changing anything, check the worktree is clean (`git status --short`) and
bring it up to date with the pushed branch, which a reviewer or CI may have
added to:

```bash
git fetch origin <headRefName>
git merge --ff-only origin/<headRefName>
```

If it has uncommitted changes, or local commits that diverge from the pushed
branch, stop and report it rather than stashing, resetting or merging over
someone's work.

Note the head you start from - it is what the PR looked like before this run's
fixes, and *Show what changed in the UI* compares against it:

```bash
pre_fix_head="$(git rev-parse HEAD)"
```

## Fetch the open feedback

**When your instructions already list the feedback to address** - an
orchestrator that started this run handed over the items, each with its URL -
that list is the work. Address exactly those items, no more and no fewer, and
skip deciding what is open below. Still fetch whatever context an item needs,
such as a thread's earlier comments or the code it points at.

Otherwise fetch all three kinds. A heavily-reviewed PR can have more than one
page of each, and dropping the overflow would silently leave real feedback
unaddressed, so drain every page with `--paginate`, which follows the
`pageInfo` cursor and concatenates the results. `--paginate` follows one
connection per query, which is why each kind has its own.

### Review threads

The REST API cannot report whether a thread is resolved, so the GraphQL
`reviewThreads` connection is the source of truth for which threads are still
open:

```bash
gh api graphql --paginate -f query='
query($owner:String!, $repo:String!, $number:Int!, $endCursor:String) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviewThreads(first:100, after:$endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          isResolved
          comments(first:100) {
            nodes {
              databaseId
              url
              path
              line
              startLine
              originalLine
              diffHunk
              body
              author { login }
            }
          }
        }
      }
    }
  }
}' -f owner=<owner> -f repo=<repo> -F number=<number>
```

A thread is open while `isResolved` is `false`. A thread whose comments
themselves exceed 100 is rare; if you hit one, page its `comments` connection
the same way.

`line` is `null` for a comment on code that has since changed (an outdated
thread); fall back to `originalLine`/`startLine` and the `diffHunk` to locate
what it refers to.

### Review summaries

```bash
gh api graphql --paginate -f query='
query($owner:String!, $repo:String!, $number:Int!, $endCursor:String) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      reviews(first:100, after:$endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          url
          state
          body
          submittedAt
          author { login }
          reactions(content:THUMBS_UP, first:100) { nodes { user { login } } }
        }
      }
    }
  }
}' -f owner=<owner> -f repo=<repo> -F number=<number>
```

Keep only reviews with a non-empty `body` - a review submitted with inline
comments alone has nothing here, and its comments arrive as review threads.

### Conversation comments

```bash
gh api graphql --paginate -f query='
query($owner:String!, $repo:String!, $number:Int!, $endCursor:String) {
  repository(owner:$owner, name:$repo) {
    pullRequest(number:$number) {
      comments(first:100, after:$endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          url
          body
          createdAt
          author { login }
          reactions(content:THUMBS_UP, first:100) { nodes { user { login } } }
        }
      }
    }
  }
}' -f owner=<owner> -f repo=<repo> -F number=<number>
```

### Which summaries and comments are open

Review summaries and conversation comments have no resolved state, so their
answers mark them instead. One is **answered** - and so not open - when either:

- a later conversation comment contains its `url`, which every answer this
  skill posts does; or
- someone other than its author has reacted to it with 👍.

Every other review summary and conversation comment is open. Skip your own
answers: a conversation comment that links another item's `url` is an answer,
not feedback.

If no thread, summary or comment is open, say so and stop - there is nothing to
address.

## Triage each item

Classify every open item:

- **(a) an actionable code change** - the item asks for something concrete in
  the diff.
- **(b) a question or clarification** - answer it in the reply; may need no code.
- **(c) a note not worth acting on** - a judgement call you decline.
- **(d) an acknowledgement** - praise or agreement that asks for neither a
  change nor an answer, such as "nice" or "LGTM".

The author - human or bot - does not change the triage.

## Address end-to-end

For the actionable items, follow [[work-on]]'s recipe, driving the sibling
skills rather than reimplementing them. Work one item's concern at a time.
Each `[[name]]` here is another skill, whose file is `../<name>/SKILL.md`
beside this skill's own: when a step hands work to one, load that skill by
reading that file and follow its instructions in full before doing the step.
Never do the step from the summary here.

1. **Fix it test-first, when there is behaviour to test.** A change with a
   testable seam goes through a fresh [[tdd]] cycle - not a patch that skips the
   loop. One behaviour at a time. A change with no seam to test - docs wording, a
   config value, a comment or rename, formatting - is made directly; do not
   invent a test for it. Say which path you took.
2. **Run the repo's mechanical checks.** Before committing, get the project's
   formatter, linter, and type-checker clean, however this repo runs them.
3. **Commit the fix.** Record each fix as a focused follow-up commit via
   [[git-committing]] on the PR's branch.
4. **Review, proportionally.** For a behaviour change, put the updated diff
   through [[code-review]] and [[security-review]] and drive the
   review-fix-re-review loop to sign-off, as [[work-on]] does. A trivial fix - a
   typo, a rename, a one-line correction - does not need both reviews; use
   judgement and say what you ran.

## Push

Push the follow-up commits to the PR branch:

```bash
git push
```

## Wait for the required checks - and fix what goes red

The push is not the finish line: the repo's CI is the run that covers what this
machine could not. Wait for the PR's required checks on the pushed head exactly
as [[work-on]]'s *Wait for the required checks* step does - poll until every
check has registered on the new head (a "no checks reported" answer is never a
result), watch them until they settle the way that step does, then learn which
are required from `gh pr checks --required`, or take every reported check when
it names none. A PR that
conflicts with its base never gets its checks, so watch its mergeability on every
poll and resolve a conflict the way [[work-on]] does - merge the base in, keep
both sides' intent, run the checks and suite, review what the resolution changed,
push, and wait again. If a check never appears on a mergeable PR, find out why
and report it rather than calling the checks green.

When a required check fails, read its log, then fix the cause through the same
*Address end-to-end* loop an item goes through: test-first when there is
behaviour to test, mechanical checks clean, a focused follow-up commit, and a
proportional review of what the fix changed. Push, and watch again, until every
required check is green. A CI fix answers no item, so it gets no reply of its
own. If the checks cannot be read at all - a token without access to them, say -
say so in the report rather than claiming they passed.

## Bring the PR's `## Reviews` section up to date

If the PR description has a `## Reviews` section, the follow-up commits have
made it describe an older head. Once the checks are green, edit it with
`gh pr edit <number> --body-file <file>` so it covers the pushed head by
[[git-pr]]'s rules: each review's last clean SHA, and for every commit after it,
the commit and why it cannot reach that review's domain. A commit you cannot
name that way for some review means that review has to run on it first - go
back to *Address end-to-end*'s review step, then push and wait for the checks
again. Change only that section; the rest of the description is the author's.
If the PR has no `## Reviews` section, do not add one.

## Show what changed in the UI

A fix that changes what a user sees leaves the PR's screenshots describing an
older head, and leaves the reviewer imagining the fix from the diff. Both steps
below are [[before-after]]'s work, never a capture of your own: read
`../before-after/SKILL.md` and the [`screenshots.md`](../before-after/screenshots.md)
beside it, and follow them in full for each run, once the checks are green.
Its rules bind every image this skill posts - in the PR body or in a reply -
above all its no-sensitive-data rule and its review of every image before
publishing.

1. **Refresh the PR's `## Before / After` section.** Run [[before-after]] on the
   open PR with its usual before ref, the PR's base, and the pushed head as
   after. It replaces the section, adds one when a fix made a previously
   invisible change visible, and removes a stale one when a fix took the visual
   change back out.
2. **Capture each visual fix.** For every item whose fix changed something a
   user sees, run [[before-after]] with `pre_fix_head` as the before ref and the
   pushed head as after, limited to the surfaces that item's fix touched, and
   have it hand the pairs back for that item's answer. A surface several items'
   fixes touched shows all of them; one capture can serve each of those items.

Run both only when this run's commits changed something visual - fixes,
conflict resolutions, or CI fixes alike. Otherwise [[before-after]]'s escape
hatch applies and there is nothing to do. Being unable to capture a visual
change is a blocker to report, never a reason to answer without it.

## Answer every item

Answer only now - once the fixes are pushed, the required checks are green, and
the PR description and its screenshots are current - so the reviewer is
notified about a commit they can see on a PR that is ready to look at. Every
item gets an answer; none is left silent.

Say what was done (name the fix commit), answer the question, or - for a
declined note - say why not. An item whose fix changed the UI carries the pairs
[[before-after]] handed back for it below that line, so the reviewer sees the
fix without checking the branch out. Paste each handed-back subsection exactly
as given - never retype it or rebuild its image URLs:

```markdown
Fixed in <sha>: <short description>.

### Settings - save button
| Before | After |
| --- | --- |
| ![Settings save button before](<before-url>) | ![Settings save button after](<after-url>) |
```

An answer that carries images is written to a file first and passes
[[before-after]]'s link check before it is posted, then goes up from that file:
`-F body=@<file>` for a thread reply, `--body-file <file>` for a conversation
comment.

For a **review thread**, reply to its first comment's `databaseId`, and always
in writing, even for an acknowledgement:

```bash
gh api --method POST \
  repos/<owner>/<repo>/pulls/<number>/comments/<comment_databaseId>/replies \
  -f body='Fixed in <sha>: <short description>.'
```

For a **review summary** or **conversation comment**, post a conversation
comment that opens with the item's `url`, so the answer links what it answers:

```bash
gh pr comment <number> --body '<item url>

Fixed in <sha>: <short description>.'
```

An **acknowledgement** on a review summary or conversation comment gets a 👍
reaction instead of a comment - it needs nothing more, and a reaction does not
notify anyone:

```bash
gh api graphql -f query='
mutation($subject:ID!) {
  addReaction(input:{subjectId:$subject, content:THUMBS_UP}) { reaction { content } }
}' -f subject=<item id>
```

👍 means only "read, nothing to do". Anything that changed code, answered a
question, or was declined gets a written answer.

Then stop there. Do not resolve threads; leave that to the reviewer. The skill
does not merge the PR and does not change any ticket's status - that belongs to
merge (see [[work-on]]).

## Guardrails

- NEVER add an agent co-author trailer, attribution, generated-by credit, or
  session link to a reply body or a commit.
- Never resolve a thread - answering is where this skill stops. Resolving is the
  reviewer's call.
- Every item gets an answer - a declined item gets a reply saying why, and only
  an acknowledgement on a review summary or conversation comment is answered
  with 👍 alone. Never silence.
- Assumes `gh` is authenticated. If `gh auth status` fails, stop and ask the user
  to run `gh auth login`.
- If an item is ambiguous enough that you would have to invent a decision to
  act on it, stop and ask the user rather than guessing.

## Completion

Done when every open item - review thread, review summary and conversation
comment, or exactly the listed items when your instructions gave a list - has
been addressed and answered (fix committed, pushed, replied), explicitly
declined with a reply, or acknowledged, the repo's checks are clean, the reviews
that ran came back signed off, the PR's required checks are green on the pushed
head, any `## Reviews` section covers that head, and when the run changed the
UI, the `## Before / After` section shows that head and every visual fix's
answer carries its pairs. Threads are left open for the reviewer to resolve.
Report the PR URL, each item's disposition, the fix commit SHAs, the final test
and check results, the required checks' final state, and the before/after
assets commit SHAs.
