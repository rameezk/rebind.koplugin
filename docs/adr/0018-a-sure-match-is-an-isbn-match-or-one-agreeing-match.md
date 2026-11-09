# 0018. A Sure match is an ISBN match or one agreeing Match

## Status

Accepted

## Context

ADR-0017 writes Sure matches in a Batch without opening the Picker, so the rule for what counts as one decides which books can be overwritten unseen.

- Option 1: ISBN matches only. Very safe, but many EPUBs carry no ISBN, so most of a Batch would need review.
- Option 2: An ISBN match, or a lookup whose Provider chain returns exactly one Match whose title and author agree with the book's Current values. Titles agree when equal after ignoring case, punctuation, accents and a leading "The", "A" or "An". Authors agree when at least one name is the same on both sides after the same clean-up, in either "First Last" or "Last, First" order.
- Option 3: The first Match from any lookup. Fast, but it writes wrong Matches unseen.

## Decision

We will go with Option 2. Several Matches, or one Match that does not agree, goes to review. The Edition is then picked as ADR-0012 describes.

## Consequences

Well-tagged libraries are mostly written in one tap, while books with junk Current values such as "Unknown" or a filename always reach the Picker. A book whose own title or author is wrong in a way the clean-up cannot see still goes to review, even when the Match is right.
