# 0014. Providers use official APIs only

## Status

Accepted

## Context

Several catalogues users ask for, such as Goodreads, Amazon, the Kobo store, Douban and Babelio, have no public API, and tools like calibre reach them by scraping their pages. Rebind runs on e-readers whose plugins are updated rarely.

- Option 1: Add any catalogue with useful data, scraping where there is no API. Widest coverage, but a page change or bot block breaks lookups silently, often against the site's terms.
- Option 2: Add only catalogues with an official or openly published API. Undocumented JSON endpoints, such as Audible's, count as scraping.

## Decision

We will go with Option 2.

## Consequences

Lookups keep working across catalogue site changes, and no Provider breaks a site's terms. Goodreads, Amazon, StoryGraph and the Kobo store stay out until they publish an API, so some regional and indie coverage is left to Providers with open data.
