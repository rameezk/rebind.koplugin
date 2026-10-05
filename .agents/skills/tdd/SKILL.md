---
name: tdd
description: Drive code changes test-first through the red-green-refactor loop, at pre-agreed seams. Use when the user or agent wants to build a feature, fix a bug, or change behaviour test-first, mentions "red-green-refactor", "write tests first", or wants tests to lead the implementation. Keeps each cycle small and the test suite lean.
---

# Test-Driven Development

TDD is the **red → green → refactor** loop. This skill is the reference that keeps the loop honest: it agrees where tests go before any are written, runs one small slice at a time, and - the part most runs skip - comes back on every cycle to clean up the slice it just wrote, the code *and* the tests, so the suite grows lean rather than as a pile of everything ever written.

When exploring the codebase, read `docs/CONTEXT.md` if it exists so test names and interface vocabulary match the project's domain language, and respect the ADRs in the area you're touching (see [[decision-context]]).

## Seams: agree before testing

A **seam** is the public boundary you test at - the interface where you observe behaviour without reaching inside. Tests live at seams, never against internals.

**Test only at pre-agreed seams.** Before writing any test, state the seams under test and confirm them with the user. No test is written at an unconfirmed seam. You cannot test everything, so agreeing the seams up front is how testing effort lands on the critical paths and complex logic instead of every edge case. Ask: "What is the public interface here, and which seams should we test?"

This agreement is the precondition [[work-on]] relies on when it drives this skill. If the seams were settled upstream in a spec, restate them and confirm; if nothing settled them, settle them here before the first test.

When a test needs to stand in for a dependency at a seam, see [`mocking.md`](mocking.md) - the default is don't, unless it's a system boundary.

## The loop

Repeat this, one small behaviour at a time:

1. **Red** - Write one failing test that expresses the next slice of desired behaviour - see [`tests.md`](tests.md) for the bar it must clear. Run it. Confirm it fails, and fails for the *right* reason: it asserts the missing behaviour, not a typo, import error, or setup mistake.
2. **Green** - Write the simplest production code that makes the test pass. The minimum. Add no behaviour a test does not yet demand.
3. **Refactor** - With tests green, improve the design. This step is not optional and it is not only about production code - see below.

Keep each cycle small: one seam, one behaviour, one minimal implementation, seconds-to-minutes per loop. Run the suite at every step and see the result before claiming red or green.

## Refactor and consolidate the slice

Refactor is the beat runs most often drop. On every green, with the suite passing, clean up **the slice you just wrote** - the code you touched this cycle and the test(s) you just added. Keep it local; a change that reaches across modules or reshapes the whole feature is not this beat's job (see Scope below).

- **The code you touched** - remove duplication, clarify names, simplify structure within this slice's blast radius. Change no observable behaviour. Re-run the suite after each change; it stays green.
- **The tests you just wrote** - test code is real code and rots the same way. Before moving to the next slice, fold down what this cycle accreted: merge tests that pin the same behaviour, delete one whose behaviour is already covered by another in the slice, and cut any that turned out tautological or coupled to internals. See [`tests.md`](tests.md) for the merge-vs-delete heuristics and the bar each surviving test must clear.

Deleting a test is safe only when the behaviour it pins is genuinely covered elsewhere, or the test was testing the wrong thing (internals, a tautology). Never delete or weaken the *only* test guarding a behaviour to make the suite smaller or greener.

## Scope: what this loop does not own

This loop refactors **locally** - the slice in front of you. It does not own **cross-cutting or structural refactor**: a restructure spanning several modules, or a consolidation sweep across the whole feature's tests once every slice is in. That work needs the full feature in view and fresh eyes on code the loop is biased toward, so it belongs to review - a future [[code-review]]/simplify pass - not to red-green-refactor. Leave it for that step rather than reaching for it mid-loop.

## Vertical slices, not horizontal

Work in **vertical slices**: one test → one implementation → refactor → repeat, each test a **tracer bullet** that responds to what the last cycle taught you. Never write all the tests first and then all the implementation. Bulk tests written up front verify *imagined* behaviour, commit you to a test structure before you understand the code, and are the main reason a suite ends up bloated with tests nobody comes back to. Slicing thin is what makes the refactor-and-consolidate beat tractable.

## Bug fixes

Always start a bug fix with a failing test that reproduces the bug **end-to-end, as close to how an end user hits it as possible**. Watch it fail before touching the fix, so you know the fix addresses the real problem and not a guess. Only then enter the loop.

## Guardrails

- NEVER write production code without a failing test that demands it. If you catch yourself writing uncovered code, stop and write the test first.
- Do not delete or weaken an assertion to force green. Fix the code, or fix a test that was genuinely wrong - and say which.
- Run the tests at every step. Never claim red or green without having run the suite and seen the result.
- If an existing, unrelated test starts failing during a change, stop and report. Do not silently edit unrelated tests to make the suite pass.
- Run single test files as you go for speed; run the full suite once the feature is complete, and report that final run.

## Completion

You are done when the behaviour is built, the full suite is green on a real run, and each slice was consolidated locally as you went, so every test earns its place within its slice. Report the final test run and what the tests now cover. Feature-wide test consolidation and any structural cleanup are review's job, not this skill's - flag them for that step rather than doing them here.
