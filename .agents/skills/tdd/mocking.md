# When to mock

Load this when a test needs to stand in for something it should not really call. Mocking is where implementation-coupled tests are born, so the default is: don't, unless you are at a system boundary.

## Mock at system boundaries only

Mock:

- external services (payment, email, third-party APIs)
- databases - sometimes; prefer a real test database
- time and randomness
- the file system - sometimes

Do NOT mock:

- your own modules, classes, or functions
- internal collaborators
- anything you control

Mocking an internal collaborator couples the test to how the code is wired, so it breaks on refactors that change nothing observable. That is the single most common way a test suite becomes painful to change. Test through the seam and let the real internals run.

## Design boundaries to be mockable

**Inject dependencies** rather than constructing them inside:

```
# Easy to substitute at the boundary
processPayment(order, paymentClient) -> paymentClient.charge(order.total)

# Hard - reaches out and builds its own client from the environment
processPayment(order) -> new PaymentClient(env.KEY).charge(order.total)
```

**Prefer specific, SDK-style operations over one generic fetcher.** Each operation is then mockable on its own, with no conditional logic in the test setup:

```
# GOOD - each call is independently substitutable
api.getUser(id)
api.getOrders(userId)
api.createOrder(data)

# BAD - the mock needs branching to decide what to return
api.fetch(endpoint, options)
```

The SDK-style shape means each stub returns one known shape, no branching in setup, and it is obvious from the test which boundary operations a behaviour exercises.
