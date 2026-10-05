---
name: code-review
description: Review a change along two independent axes - Standards (does it follow this repo's conventions and stay free of code smells?) and Spec (does it faithfully implement the ticket and spec it came from?). Runs both as parallel sub-agents when invoked directly, or as two inline passes when itself nested in a sub-agent, and reports them side by side. Read-only; reports findings and never edits code. Use to review a branch, a PR, or work in progress, or when asked to "review since X".
---

# Code Review

Review the diff between a head commit and a fixed point along two axes that are kept deliberately apart:

- **Standards** - does the change follow this repo's documented conventions and stay clear of code smells? This axis is also where the feature-wide cleanup [[tdd]] defers to review lands - cross-slice test consolidation included, since it needs the whole change in view.
- **Spec** - does the change faithfully implement the ticket it came from, and the spec behind it?

Each axis runs in isolation - as its **own sub-agent** when this skill is invoked directly, or as its **own sequential pass in one context** when this skill is itself running nested inside a sub-agent (see step 4) - so neither pollutes the other's judgement, and then this skill aggregates their findings without merging or re-ranking them. That separation is the whole point (see [Why two axes](#why-two-axes)): a change can pass one axis and fail the other, and a single blended verdict lets the pass hide the fail.

This is a read-only pass. It reports; it does not touch code. Fixing what it finds is a separate step the user chooses - a fresh [[tdd]] cycle for a real defect, a local cleanup for a smell - not something this skill folds in.

## Process

### 1. Pin the fixed point

The fixed point is whatever the user gives - a commit SHA, a branch, a tag, `main`, `HEAD~5`. If they name none, default to the branch's base - the pending change on the current branch - and ask only when that is ambiguous (detached HEAD, or already sitting on the default branch with nothing to compare). Never silently assume `main`.

The head is the commit SHA the caller passes, or `HEAD` if they pass none. Resolve both to SHAs once (`git rev-parse <fixed-point>`, `git rev-parse <head>`) and use those SHAs everywhere below, never the moving `HEAD`, so the review covers exactly one commit range and says which.

Capture the diff once, three-dot so the comparison is against the merge-base: `git diff <fixed-point>...<head>`. Note the commits too: `git log <fixed-point>..<head> --oneline`. Before spawning anything, confirm both refs resolve and the diff is non-empty - a bad ref or empty diff should fail here, in the open, not inside two sub-agents.

### 2. Find the spec source

Find what the change was *supposed* to do, in this order, resolving the tracker from `.tracker.toml` (see [[tracker-config]]):

1. The **ticket**: an issue reference in the commit messages (`#123`, `Closes #45`) fetched via `gh`, or a `local` ticket under `docs/specs/NNNN-slug/` matching the branch or feature.
2. Its **parent spec** - the ticket names it; read it for the agreed seams and the out-of-scope section.
3. A path the user passed as an argument.
4. If nothing turns up, ask the user where the spec is. If they say there is none, the Spec axis skips and reports "no spec available".

### 3. Find the standards sources

Gather what documents how code should be written *in this repo*: `CODING_STANDARDS.md`, `CONTRIBUTING.md`, or the like, plus the ADRs in the area the diff touches (see [[decision-context]]) - a change that contradicts an accepted ADR is a standards breach, and so is any edit to an existing ADR beyond its Status line, since ADRs are immutable. `docs/CONTEXT.md` is the glossary, not a standard, but the Standards axis uses it to judge whether a name matches the project's real vocabulary.

On top of whatever the repo documents, the Standards axis always carries the **Fowler smell baseline** - a fixed set of code smells (_Refactoring_, ch.3) that applies even when the repo documents nothing, with the two rules that bind it (the repo overrides; every smell is a judgement call). The full catalogue is in [`martin-fowler-code-smells.md`](martin-fowler-code-smells.md); read it here so you can hand it to the Standards axis in step 4, which has no other access to it.

### 4. Run both axes - spawned when top-level, inline when nested

Launch both in a single message so they run concurrently, each isolated from the other - **but only when this skill is the top-level orchestrator**, i.e. a human invoked it directly.

**When this skill is itself running as a sub-agent** (for example [[work-on]] spawned it as one of its parallel reviews), do **not** spawn Standards and Spec as further sub-agents - a sub-agent cannot reliably spawn its own. Instead run the two axes as **two sequential passes in this same context**, keeping their findings strictly separate and reported under their own headings exactly as below. The isolation between axes is looser this way, but the separation of findings - the whole point - is preserved.

Either way, each axis gets the same inputs and the same brief.

**Standards axis** - give it:

- The full diff command and commit list.
- The standards-source files from step 3, **plus the Fowler baseline from [`martin-fowler-code-smells.md`](martin-fowler-code-smells.md) pasted in full** (a spawned sub-agent has no other access to it; an inline pass carries it in this context).
- The brief: "Report, per file or hunk where relevant, (a) every place the diff violates a documented repo standard or an accepted ADR, or edits an existing ADR anywhere other than its Status line (always a hard violation - ADRs are immutable) - cite the standard (file plus the rule) or the ADR; and (b) any baseline smell you spot - name it and quote the hunk. Distinguish hard violations from judgement calls: documented-standard and ADR breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard or ADR overrides the baseline. You are seeing the whole change at once, which the test-driven build could not - so also own the feature-wide cleanup [[tdd]] defers to review: flag duplication that spans slices in production *and* test code (tests are code and rot the same way), and any consolidation or structural refactor that only makes sense with the full feature in view. Skip anything lint, formatter, or type-checker enforces. Under 400 words."

**Spec axis** - give it:

- The diff command and commit list.
- The ticket and its parent spec (path or fetched contents), including the agreed seams and the out-of-scope section.
- The brief: "Report: (a) requirements the ticket or spec asked for that are missing or partial; (b) behaviour in the diff that was not asked for - scope creep, especially anything the spec's out-of-scope section explicitly refused; (c) requirements that look implemented but where the implementation looks wrong. Quote the ticket or spec line for each finding. Under 400 words."

If there is no spec, skip the Spec axis and say so in the report.

### 5. Aggregate

Open the report with the reviewed range on its own first line: `Reviewed <fixed-point-sha>...<head-sha>`, both as resolved in step 1. A caller uses it to tell which commit the review covers.

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or re-rank findings across axes - the separation is the point.

End with a one-line summary: total findings per axis, and the worst issue *within each axis* (if any). Do not pick a single winner across axes; that is the re-ranking the separation exists to prevent.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every convention but implements the wrong thing -> **Standards pass, Spec fail.**
- Code that does exactly what the ticket asked but breaks the project's conventions -> **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.

## Completion

Done when the report opens with the reviewed range, both axes have reported (or the Spec axis has been recorded as skipped for want of a spec) and the findings are laid out side by side under their own headings, unmerged and un-re-ranked, with the per-axis summary line. Then stop: this skill finds; it does not fix - hand fixes to [[tdd]].
