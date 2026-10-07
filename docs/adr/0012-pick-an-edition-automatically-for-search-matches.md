# 0012. Pick an Edition automatically for search matches

## Status

Accepted

## Context

Decided in #73. A title and author search returns Books, not Editions, so per ADR-0005 the title, publisher and language came from the Book, and the header and Source screen showed no Edition until the user picked one by hand. Hardcover offers a default ebook and a default physical Edition per Book, either may be missing, and both are chosen per format, not per language.

- Option 1: Keep the Book-only proposal and label it honestly.
- Option 2: Pick an Edition with the Hardcover plugin's order: default ebook, default physical, most-read.
- Option 3: Pick an Edition with a language-aware order: the default ebook, then the default physical Edition, if its language matches the book's Current language or that is unknown; then the most-read non-audio Edition in the Current language; then Option 2's order.

## Decision

We will go with Option 3, after the first search match and whenever the Book is changed on the Source screen. ISBN matches and Editions picked by hand are never overridden. If no Edition can be picked, the Book-only proposal stays and the Source screen says "None chosen".

## Consequences

A search match proposes the same Edition-owned Fields as an ISBN match, in the book's own language where Hardcover has one, at the cost of one extra query per Book. A book in a language Hardcover lacks still falls back to a default Edition in another language.
