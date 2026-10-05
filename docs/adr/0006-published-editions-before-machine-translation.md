# 0006. Published Editions first, machine translation as an opt-in fallback

## Status

Accepted

## Context

Recorded retroactively; decided in #20 (d27c34b). Users want a book's metadata in another language, but per ADR-0005 Hardcover has translated titles and publishers only per Edition, and no translated description or genres.

- Option 1: Machine-translate every Field. Always available, but translators mangle proper nouns and invent titles that were never published.
- Option 2: Use only a published Edition in that language. Accurate, but leaves the description and genres untranslated, and gives nothing when no such Edition exists.
- Option 3: Use a published Edition for what it owns, and offer to machine-translate only the remaining Fields, through KOReader's built-in translator.

## Decision

We will go with Option 3: titles, publishers and languages are never machine-translated, and translation runs only when the user accepts the offer.

## Consequences

Titles are the ones translators actually published. Translated values appear separately in the Picker and nothing is written until Apply. Translation needs a network connection, and the text is sent to Google through KOReader's translator, which the user must agree to each time.
