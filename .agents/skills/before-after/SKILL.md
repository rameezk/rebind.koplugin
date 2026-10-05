---
name: before-after
description: Capture how something looked before a change and how it looks after, and present the pairs side by side in a PR body. Currently covers screenshots of UI changes. Use when a change affects anything a user sees in a UI, when opening or updating a PR for such a change, or when the user asks for before/after screenshots. Does nothing when there is nothing visual to present.
---

# Before After

Show a reviewer what a change looks like instead of making them imagine it from
the diff: capture each affected surface as it was **before** the change and as
it is **after**, then present the pairs side by side in the PR body.

The medium today is screenshots of UI. Capture mechanics live in
[`screenshots.md`](screenshots.md); everything else here - planning, the escape
hatch, the sensitive-data rule, publishing, presenting - is medium-agnostic.

## Escape hatch: nothing to present, do nothing

Check this first, and again after capturing. If there is nothing visual to
present, the skill does **nothing**: no app launched, no screenshots, no branch
pushed, no PR section. Say so in one line - `No visual change - skipping
before/after.` - and stop. A caller like [[git-pr]] then simply omits the
section.

There is nothing to present when:

- The change does not alter anything a user sees in a UI - backend, API, data
  model, CLI, infra, tests, docs, build config, or a refactor that renders
  identically.
- After capturing, every pair is pixel-identical (compare with `shasum`). Drop
  any single identical pair; if none are left, the escape hatch applies.

Being unable to capture is **not** the escape hatch. If the change is visual but
the app cannot be run, a state cannot be reached, or the base does not build,
stop and report the blocker to the user. Never fake a pair, and never quietly
publish nothing for a change that does have a visual effect.

## No sensitive data - ever

Nothing sensitive may appear in any capture. Once pushed, an image lives in git
history and may be public, so treat publishing as irreversible.

Sensitive includes: secrets, tokens, API keys, passwords, and credentials;
personal data (real names, emails, phone numbers, addresses, avatars of real
people); customer, tenant, or production data; account, organisation, or billing
identifiers; internal hostnames, IPs, and URLs; and session details exposed in
the page, URL, or devtools.

- Run the app locally or in a dev environment against seed, fixture, or
  obviously fake data (`Jane Example`, `jane@example.com`). Never capture
  production or a real user's account.
- Capture only the page viewport or the affected element - never the whole
  desktop, browser chrome, terminal, or other windows.
- Inspect every image yourself before publishing (see Review the pairs). If
  anything sensitive shows, re-capture with fake data. If that is impossible,
  drop the pair and tell the user why. Never blur or pixelate - that is
  reversible and easy to get wrong.

## Plan the shots

Read the change against its base - `git diff <base>...HEAD` - and list each
visible surface it touches. For each, define a **shot**:

- a short slug and a human name (`settings-save-button`, "Settings - save
  button")
- the route and the steps to reach the state (clicks, form input, seeded data)
- what to capture: the affected element when the change is contained, the
  viewport when layout moved, the full page only when the change spans it
- viewport and color scheme

Only include states the change visibly affects. Add a dark-mode shot when
theming or colors changed, and a narrow viewport (390 wide) when responsive
layout changed. A new surface has no before; a removed one has no after. Keep
the set small - a reviewer should take it in within seconds, typically one to
four pairs.

The shot definitions are written once and reused unchanged for both sides - that
is what makes each pair comparable. The only difference within a pair must be
the change itself: same data, viewport, scheme, locale, timezone, and browser.

## Capture before

Before is the change's base: the PR's base branch, or the merge-base with the
up-to-date default branch.

- **Invoked before any change is made** (for example at the start of UI work):
  capture from the current checkout now, and keep the images until after.
- **Changes already made**: never stash, reset, or check out in the user's
  working tree. Check the base out in a temporary detached worktree, run the app
  there, capture, then stop it and remove the worktree:

  ```bash
  base="$(git merge-base origin/<default-branch> HEAD)"
  before_dir="$(mktemp -d)"
  git worktree add --detach "$before_dir" "$base"
  ```

  Install dependencies there the way the repo does. If the app needs untracked
  local config to run (a `.env`, say), copy it in from the main checkout; it is
  only for running, never captured or committed. When done:
  `git worktree remove --force "$before_dir"`.

## Capture after

Capture from the change's HEAD with the same shot definitions. Run the before
and after apps one at a time to avoid port clashes and cross-talk. See
[`screenshots.md`](screenshots.md) for tooling, determinism, and the capture
script.

## Review the pairs

Open every image and look at it before publishing. Check that:

- the intended state was captured - not a spinner, skeleton, error page, login
  wall, cookie banner, or half-loaded fonts
- the pair is comparable - same size, scroll position, and data
- nothing sensitive is visible anywhere in the frame

Be picky. If the after reveals something visibly off - misalignment, clipping,
overflow, wrong spacing, broken dark mode - do not publish it as if it were
fine; stop and raise it so the change gets fixed first. Then apply the escape
hatch check: drop identical pairs, and stop if none remain.

## Publish the images

GitHub has no API for attaching images to a PR body, so the images live on a
dedicated orphan branch, `before-after-assets`, on the same remote, referenced by
commit SHA so links stay valid forever. Never commit images to the PR branch or
the default branch - they would pollute the diff and the history.

Layout: one directory per head branch, `<head-branch>/<shot-slug>-before.png`
and `<head-branch>/<shot-slug>-after.png`.

If `before-after-assets` does not yet exist on the remote, confirm with the user
before creating it - it is a new branch visible to everyone with access to the
repo. After that first time, publishing to it is part of this skill.

Publish from a temporary worktree so the user's checkout is never touched:

```bash
assets_branch=before-after-assets
head_branch="$(git branch --show-current)"
assets_dir="$(mktemp -d)"
if git ls-remote --exit-code --heads origin "$assets_branch" >/dev/null; then
  git fetch origin "$assets_branch"
  git worktree add --detach "$assets_dir" FETCH_HEAD
else
  git worktree add --orphan -b "$assets_branch" "$assets_dir"
fi
mkdir -p "$assets_dir/$head_branch"
cp <captured-images> "$assets_dir/$head_branch/"
git -C "$assets_dir" add "$head_branch"
git -C "$assets_dir" commit -m "chore: add before/after for $head_branch"
git -C "$assets_dir" push origin "HEAD:refs/heads/$assets_branch"
assets_sha="$(git -C "$assets_dir" rev-parse HEAD)"
git worktree remove "$assets_dir"
git branch -D "$assets_branch" 2>/dev/null || true
```

Reference each image by that commit SHA. This form also renders in private
repos for anyone who can see the repo:

```text
https://github.com/<owner>/<repo>/blob/<assets_sha>/<head-branch>/<shot-slug>-before.png?raw=true
```

Resolve `<owner>` and `<repo>` with
`gh repo view --json owner,name -q '.owner.login + "/" + .name'`.

## Present

Build a `## Before / After` section, one subsection per shot, pairs in a
two-column table. Markdown image syntax makes each image click-to-enlarge:

```markdown
## Before / After

### Settings - save button
| Before | After |
| --- | --- |
| ![Settings save button before](<before-url>) | ![Settings save button after](<after-url>) |
```

Use `_New_` in the before cell for a new surface and `_Removed_` in the after
cell for a removed one. Add a one-line caption under a subsection only when what
changed is not obvious at a glance.

Where the section goes:

- **Called from [[git-pr]] while drafting**: hand the section back for the PR
  description.
- **PR already open**: read the body with `gh pr view <number> --json body -q
  .body`, replace an existing `## Before / After` section or insert one before
  `## Testing`, write the result to a file, and apply it with `gh pr edit
  <number> --body-file <file>`. Never rewrite the rest of the body.
- **No PR**: show the section and the local image paths to the user.

## Cleanup

Stop every app you started, remove every temporary worktree, and prune with
`git worktree prune`. Leave the user's checkout exactly as you found it.

## Guardrails

- No sensitive data in any capture, ever.
- Nothing to present means do nothing - no section, no push.
- Never stash, reset, or check out in the user's working tree; use temporary
  worktrees.
- Never commit images to the PR branch or the default branch.
- `before-after-assets` is append-only. Never force-push or rewrite it - earlier
  PRs link to its commits.
- Never fake a side of a pair. If one cannot be captured, stop and report.
- NEVER add an agent co-author trailer, attribution, generated-by credit, or
  session link to an assets commit or the PR body.
- Missing tooling is fetched one-off with nix, never installed globally - see
  [`screenshots.md`](screenshots.md). The same goes for `gh`: `nix run
  nixpkgs#gh -- <args>`.
- Assumes `gh` is authenticated. If `gh auth status` fails, stop and ask the
  user to run `gh auth login`.

## Completion

Done when either the escape hatch fired with its one-line note, or every pair
has been captured, reviewed, and published and the section is in the PR body or
handed back to the caller. Report the shots, the assets commit SHA, and where
the section went.
