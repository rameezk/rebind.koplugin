# 0015. Pick an Edition by language for Providers without defaults

## Status

Accepted

## Context

ADR-0012 picks an Edition for a search Match from Hardcover's default ebook and physical Editions, then its most-read Edition. Open Library and Inventaire have neither, but give each Edition's language, and Open Library also its format and publish date.

- Option 1: Pick no Edition for these Providers and leave the Source screen at "None chosen", so the title and publisher come from the Book, often in another language.
- Option 2: Pick an Edition in the book's Current language, or the preferred language, then prefer an ebook format, then the most recent. If no Edition matches the language, keep the Book-only proposal.

## Decision

We will go with Option 2 for every Provider that has no default Editions. ADR-0012 still applies to Hardcover. ISBN Matches and Editions picked by hand are never overridden.

## Consequences

A search Match from any Provider proposes Edition-owned Fields in the book's own language when the Provider has such an Edition. Without read counts, the pick between several same-language ebook Editions rests on publish date alone, which can choose a reissue over the original.
