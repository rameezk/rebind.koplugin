# When to mock

Load this when a test needs to stand in for something it should not really call. Mocking is where implementation-coupled tests are born, so the default is: don't, unless the dependency's kind calls for a test adapter at its seam. A mock or fake is an adapter in the sense [[codebase-design]] gives the word.

## Where to mock

Whether a dependency gets a seam, and what fills it in a test, follows its kind in [[codebase-design]]'s guide to deepening a module:

- **In-process** - logic that never leaves the process, reading and writing nothing outside it, such as the internal collaborators behind a module's interface: never mock. There is no seam to fill.
- **Local, with a stand-in** - a database or the file system that a test can run a faithful local copy of: don't mock either. Run the faithful stand-in, such as a throwaway database or a temporary directory.
- **Across the network, and yours** - another of your own programs, an internal endpoint: fill the seam at the transport's edge with an in-memory adapter.
- **Third-party** - payment, email, a vendor's hosted platform: fill the seam with a fake that does only what the provider documents.

The clock and the source of randomness are read from outside the process too, and no stand-in makes them repeatable, so give each a seam: inject it, the real one for live use and a fixed adapter in tests, so the test stays deterministic.

Mocking an internal collaborator couples the test to how the code is wired, so it breaks on refactors that change nothing observable. That is the single most common way a test suite becomes painful to change. Test through the interface at the seam and let the real implementation run.

## Shape seams so a test adapter fits

**Inject dependencies** rather than constructing them inside:

```
# Easy to fill the seam with a test adapter
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

The SDK-style shape means each stub returns one known shape, no branching in setup, and it is obvious from the test which operations across the seam a behaviour exercises.
