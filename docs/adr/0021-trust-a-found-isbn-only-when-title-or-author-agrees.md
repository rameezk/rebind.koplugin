# 0021. Trust a Found ISBN only when the title or author agrees

## Status

Accepted

## Context

When an EPUB's metadata has no valid ISBN, Rebind will read one from the book's own text, searching the first 10 and last 5 documents in reading order for a labelled number with a valid check digit. ADR-0018 makes any ISBN match a Sure match, but the text can also hold other books' ISBNs, such as ads or a bibliography. In a survey of 96 real EPUBs, 41 of the 72 without a metadata ISBN had a Found ISBN, and every one that Open Library knew was the right book.

- Option 1: Treat a Found ISBN match like a metadata ISBN match, so it is always a Sure match. Most books become Sure matches, but a stray ISBN writes the wrong book unseen.
- Option 2: A Found ISBN match is a Sure match when its title or its author agrees with the book's Current values, using the clean-up of ADR-0018.
- Option 3: Require both title and author to agree. Safest, but books with one junk Current value, such as an "Unknown" author, never benefit.

## Decision

We will go with Option 2. ADR-0018 still holds for ISBNs in the metadata.

## Consequences

A stray ISBN that matches a different book is caught unless that book shares the title or an author, as a series ad might. Books with both title and author junk still go to review.
