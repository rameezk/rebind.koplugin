---
name: git-pr
description: Prepare and open a GitHub pull request cleanly and consistently. Use when the user or agent asks to open a PR or raise a pull request. Enforces a PR title and description convention.
---

# Git PR

## When to use

- The user asks to "open a PR" or "raise a pull request"
- A branch has one or more committed changes ready to be reviewed

Assumes commits are already made via [[git-committing]] and the branch
follows [[git-branching]]'s naming convention.

Each `[[name]]` here is another skill: when a step hands work to one, load that
skill and follow its instructions in full before doing the step. Never do the
step from the summary here.

## Title format

Match the branch's Conventional Commit style: `<type>(<optional-scope>): <subject>`

- Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `spike`
- Imperative mood, lowercase subject, no trailing period
- For a single-commit PR, reuse the commit subject
- For a multi-commit PR, write a subject that summarises the whole change

## Description format

Use these sections, in this order, with these exact headings. Drop a section
only when it genuinely does not apply, and add no others: anything that fits
nowhere else goes in `## Notes`. This is the only PR description format; a
skill that opens a PR through this one fills these sections rather than
bringing its own.

```markdown
## What
What this change does, in a few sentences. 

## Why
Why this change is needed, in a few sentences. Explain intent, not a diff. 

## Changes
- Bullet the notable changes a reviewer should look for

## Before / After
Side-by-side screenshots of UI changes, produced by [[before-after]].

## Testing
How it was verified: commands run, tests added, manual checks. State honestly what was and was not tested.

## Reviews
- code-review: clean at a1b2c3d (HEAD)
- security-review: clean at 9f8e7d6. After it: a1b2c3d (README wording only, cannot reach security)

## Notes
Anything else: follow-ups, trade-offs, risks, review findings set aside and why. Link issues with `Closes #17` when a github issue was implemented.
```

`## Reviews` applies only when reviews ran on the branch. List each review's
last clean SHA, and for any commit after it, name the commit and why it cannot
reach that review's domain, so a reader can see at a glance that the reviews
cover the PR's head. Write only what happened: a SHA here is a claim about which
commit a review saw, so never write one a review did not report.

## Workflow

1. Confirm state: `git status` (clean tree), `git branch --show-current` (not the
   default branch), and `git log <default>..HEAD --oneline` to see the commits
   the PR will contain.
2. Review the diff: `git diff <default>...HEAD` so the title and description
   reflect what actually changed. Never write a PR description blind.
3. Run [[before-after]] and include the `## Before / After` section it returns.
   It returns nothing when the change has no visual effect; drop the section
   then.
4. Draft the title and description following the formats above.
5. Push the branch: `git push -u origin <branch>` (skip only if it is already
   pushed and up to date). `gh` needs the branch on the remote.
6. Using the github cli `gh`, create the PR
   for example:

   ```bash
   gh pr create --base <default-branch> \
     --title "<title>" \
     --body "<description>"
   ```
7. Once the PR exists, report its URL.

## Guardrails

- NEVER add an agent co-author trailer, attribution, generated-by credit, or
  session link to the PR title or body.
- Base the PR on the default branch unless the user names a different base.
- Assumes `gh` is authenticated. If `gh auth status` fails, stop and ask the
  user to run `gh auth login`.
- Dirty tree or unpushed uncertainty: stop and report. Don't stash, reset, or force anything.

## Avoid

- Vague titles: `fix: bug`, `update`, `changes`
- Empty or one-word descriptions that make reviewers reverse-engineer intent
- Bundling unrelated commits into one PR
