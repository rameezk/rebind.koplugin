# 0005. Field ownership follows Hardcover's Book and Edition split

## Status

Accepted

## Context

Recorded retroactively; decided in #18 (2e2a5c3). Hardcover stores some data per Edition and some per Book, and the user can now pick an Edition.

- Option 1: Take every Field from the chosen Edition. Hardcover has no per-Edition author, series, genres or description, so those Fields would be empty.
- Option 2: Take every Field from the Book and ignore the Edition. Translated titles and publishers would be lost.
- Option 3: Take each Field from where Hardcover owns it: title, publisher and language from the Edition; author, series, genres and description from the Book.

## Decision

We will go with Option 3.

## Consequences

Switching Edition changes only the title, publisher and language, so a translated Edition keeps the original-language description and genres, which surprises users and is explained in the README. That gap is what ADR-0006 fills.
