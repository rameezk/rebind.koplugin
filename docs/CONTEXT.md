# Rebind

A KOReader plugin that rewrites an EPUB's embedded metadata on the device, from an online catalogue or by hand.

## Language

**Rebind**:
Replacing a book's embedded metadata with the values chosen in the Picker.
_Avoid_: fix, sync

**Book**:
A work as a Provider models it, independent of any one printing. It owns the author, series, genres and description.
_Avoid_: work

**Edition**:
One published form of a Book, such as a particular paperback or translation. It owns the title, publisher and language.
_Avoid_: version, release

**Provider**:
An online catalogue Rebind looks books up in, such as Hardcover.
_Avoid_: source, service, backend

**Provider chain**:
The user's ordered list of enabled Providers that a lookup tries in turn until one returns a Match.
_Avoid_: fallback list, provider order

**Match**:
A Book returned by a Provider lookup, before an Edition has been chosen.
_Avoid_: result

**Field**:
One piece of metadata Rebind can write: Title, Author(s), Series, Genre(s), Language, Publisher, Description or First published.
_Avoid_: tag, property

**First published**:
The year a Book was originally published, regardless of which Edition is chosen.
_Avoid_: publication date, release date, pubdate

**Current value**:
A Field's value as the EPUB holds it before the Rebind.
_Avoid_: old value

**Proposed value**:
A Field's value taken from the chosen Edition or its Book.
_Avoid_: new value, Hardcover value, provider value

**Custom value**:
A Field value the user typed in an editor.
_Avoid_: own value, manual value, mine

**Translated value**:
A Field value produced by machine translation of a Proposed or Current value, never by Hardcover.
_Avoid_: custom value

**Picker**:
The screen that shows each Field's values side by side and lets the user choose one per Field.
_Avoid_: diff picker, rebind screen

**Library**:
The user-chosen root folder that books are Sorted into.
_Avoid_: Sorted library, sorted root, sorted folder

**Sort**:
Moving a book into the Library after a Rebind.
_Avoid_: file, move

**Backup**:
The `.rebind.bak` copy of the original EPUB taken before it is replaced.

**Filename template**:
The user-chosen pattern a book's file is renamed to, built from Tokens.
_Avoid_: naming scheme, rename pattern

**Folder template**:
The user-chosen pattern for the folders a book is Sorted into under the Library, built from Tokens.
_Avoid_: structure, layout

**Token**:
A `%name` placeholder in a template that stands for one Field's value, such as `%title`.
_Avoid_: variable, placeholder

**Preset**:
A built-in template offered for the user to pick instead of writing their own.
_Avoid_: profile
