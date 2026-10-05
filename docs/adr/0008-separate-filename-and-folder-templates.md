# 0008. Separate filename and folder templates

## Status

Accepted

## Context

Decided while refining #27. Users want to choose how books are named and filed, for example `<title> - <series> #<index> - <author> (<year>)`. Rename and Sort are deliberately independent (ADR 0007).

- Option 1: Template the filename only, keeping the fixed `Author / Title / book` Sort layout.
- Option 2: A filename template, applied whenever Rename is on, and a separate folder template, applied when Sorting.
- Option 3: One Calibre-style path template whose `/` separates folders. Familiar, but "rename without Sort" has no clear meaning when the template contains folders.

Each template can be set in one of three ways: by choosing from a fixed list of presets, by typing a free-form template, or both.

## Decision

We will go with Option 2. Each template is chosen from built-in presets, shown with an example rendered from the current book, or written through "Custom…", which opens prefilled from a preset. The folder template replaces the `Author / Title / book` choice in the Sort dialog. "Directly in this folder" and "Keep here" stay. The default filename template is today's `<Author, surname-first> - <Title>`.

## Consequences

Users who never touch the setting see no change. The template language becomes a user-facing contract that saved custom templates depend on, so its syntax is costly to change later.
