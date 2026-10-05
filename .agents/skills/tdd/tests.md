# What a good test is, and which tests to keep

Load this during **red** (to write a test worth keeping) and during **refactor** (to decide which tests to merge or delete). Examples are pseudocode; translate to the project's language and test framework.

## The bar every surviving test must clear

- **Tests behaviour through the public interface**, not internals. Code can change entirely; the test should not. A good test reads like a specification - "user can checkout with a valid cart" tells you what capability exists, and survives refactors because it does not care about internal structure.
- **One reason to fail.** Assert one behaviour. A test that can fail for three unrelated reasons hides which one broke.
- **Named for the behaviour**, in given/when/then form: `given_expired_token_when_validating_then_rejects`, not `test_validate`. State only the parts that carry meaning - drop an implied Given. Keep the setup (Given), the action (When), and the assertion (Then) visibly separate in the body too.
- **Readable failure.** A failing message should point at the cause without reaching for a debugger.
- **Fast and deterministic.** No reliance on wall-clock time, network, or test ordering.

## Good vs bad

**Behaviour through the interface** - not the internals:

```
# GOOD - observable behaviour
given a cart with one product
when checkout runs with a valid payment method
then the result status is "confirmed"

# BAD - couples to an internal collaborator, breaks on any refactor
when checkout runs
then paymentService.process was called once with cart.total
```

**Verify through the interface**, not a side channel:

```
# BAD - bypasses the interface to inspect state directly
when createUser({name: "Alice"}) runs
then a SELECT on the users table returns a row for "Alice"

# GOOD - round-trips through the public API
when createUser({name: "Alice"}) runs
then getUser(id) returns a user whose name is "Alice"
```

**Not tautological** - the expected value must come from an independent source of truth (a known-good literal, a worked example, the spec), never recomputed the way the code computes it:

```
# BAD - expected value restates the implementation, so it can never disagree
expected = items.reduce(sum)
assert calculateTotal(items) == expected

# GOOD - expected value is an independent literal
assert calculateTotal([{price: 10}, {price: 5}]) == 15
```

## The anti-patterns that bloat a suite

- **Implementation-coupled**: mocks internal collaborators, tests private methods, or verifies through a side channel. The tell: it breaks when you refactor but behaviour has not changed. Delete or rewrite at a real seam.
- **Tautological**: passes by construction (see above). It can never catch a bug. Delete.
- **Horizontal slicing**: all tests written first, then all implementation. Verifies imagined behaviour and is the main source of tests nobody revisits. Prevent it by slicing vertically in the first place.

## Consolidation: merge vs delete

During **refactor**, read the tests you just wrote for this slice together and pay down what the cycle accreted. Keep this local to the slice - consolidating across the whole feature needs fresh eyes and is review's job, not the loop's (see the skill's Scope note). For each test you added this cycle:

**Delete it when** -
- another test already exercises the same behaviour through the same seam (redundant),
- it is tautological, or coupled to internals rather than a seam,
- it pins a behaviour the spec explicitly put out of scope.

**Merge it when** -
- several tests share almost all their Given/When and differ only in one input → a single table/parametrised test over those inputs reads better and fails more precisely,
- setup is duplicated across tests → lift it to a shared fixture, not into the assertions.

**Keep it, untouched, when** it is the only test guarding a behaviour - even if that makes the suite larger. Coverage of behaviour is the thing being protected; test count is not.

The rule that resolves ties: **would a reader learn something new from this test that no other test tells them?** If yes, keep it. If no, it is redundant - merge or delete. Never trade away the coverage of a real behaviour to shrink the suite.
