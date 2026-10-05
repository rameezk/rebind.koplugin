---
name: to-spec
description: Turn a refined piece of work into a spec - a durable record of what was decided and why - and publish it to the configured tracker. Use once shared understanding is reached and the plan needs to survive being split across sessions.
disable-model-invocation: true
---

# To Spec

Turn the conversation into a **spec**: a record of the decisions already made, in the project's own language, written to survive a context clear and be picked up by a fresh session.

By the time this runs, [[refine]] has done the deciding. Do not interview the user and do not reopen questions - synthesize what is already settled. The spec decides nothing; it captures what was decided. Anything the spec asserts that was never actually agreed is a defect.

## How it works

1. **Resolve the tracker.** Read `.tracker.toml` at the project root to learn where specs go - `local` or `github`. See [[tracker-config]] for the file's shape; if it is missing or malformed, hand off to [[tracker-config]] to set it up rather than guessing a destination.

2. **Explore the repo.** Ground the spec in how the code actually works, and speak in the project's vocabulary - use the terms from `docs/CONTEXT.md` and respect the ADRs in the area you're touching (see [[decision-context]]). Delegate the digging to a subagent rather than asking the user what you can check yourself.

3. **Sketch the seams, then confirm.** A **seam** is a place where you can alter behaviour without editing in that place (Michael Feathers, *Working Effectively with Legacy Code*) - the boundary a test plugs into. Propose the seams the feature will be tested at: prefer seams that already exist, take the highest seam you can, and aim for the fewest possible - ideally one across the whole change. Put the proposed seams to the user and hold for sign-off before writing a word.

4. **Write the spec** using the scaffold in [`spec-template.md`](spec-template.md). Decisions, not implementation: no file paths and no code snippets - they go stale fast. A durable, hard-to-reverse decision belongs in an ADR via [[decision-context]]; reference it from the spec rather than restating it. NEVER add agent attribution, a generated-by credit, or a session link to the spec's title or body.

5. **Publish** to the destination from the config:
   - **local** - write to `docs/specs/NNNN-slug/spec.md` - each spec in its own folder. Number the folder sequentially with 4-digit zero-padding: scan `docs/specs/` for the highest existing number and add one, starting at `0001` if it is empty.
   - **github** - publish as a single issue on `repo` via `gh`. Title the issue with the feature name and apply a `spec` label, so a fresh session can find it again with `gh issue list --label spec`. Ensure the label exists first, creating it only if absent so an existing `spec` label keeps its styling: `gh label list --json name -q '.[].name' | grep -qx spec || gh label create spec --color 5319E7`. The color is the default for a fresh repo that has no `spec` label yet. The issue URL is the spec's identity - GitHub assigns the number, so there is no `NNNN` to manage here.

## Completion

The spec is done when every decision in it is one the user can remember making, the out-of-scope section names the things that were deliberately refused, and the agreed seams are recorded. Stop there. This skill records the plan; it does not build it, and it does not slice it into tickets.

A spec is not a build target. Agents and humans build only from tickets, so the mandatory next step is [[to-tickets]], which turns the spec into at least one ticket - even a spec small enough to fit in one session becomes a single ticket, never a thing built straight from the spec. Point the user there.
