# Rebind

A KOReader plugin that rewrites an EPUB's embedded metadata on the device, from Hardcover or by hand.

## Language

**Rebind**:
Replacing a book's embedded metadata with the values chosen in the Picker.
_Avoid_: fix, sync

**Book**:
A work as Hardcover models it, independent of any one printing. It owns the author, series, genres and description.
_Avoid_: work

**Edition**:
One published form of a Book, such as a particular paperback or translation. It owns the title, publisher and language.
_Avoid_: version, release

**Match**:
A Book returned by a Hardcover lookup, before an Edition has been chosen.
_Avoid_: result

**Field**:
One piece of metadata Rebind can write: Title, Author(s), Series, Genre(s), Language, Publisher or Description.
_Avoid_: tag, property

**Current value**:
A Field's value as the EPUB holds it before the Rebind.
_Avoid_: old value

**Proposed value**:
A Field's value taken from the chosen Edition or its Book.
_Avoid_: new value, Hardcover value

**Own value**:
A Field value the user typed in an editor.
_Avoid_: custom value, manual value

**Translated value**:
A Field value produced by machine translation of a Proposed or Current value, never by Hardcover.
_Avoid_: own value

**Picker**:
The screen that shows each Field's values side by side and lets the user choose one per Field.
_Avoid_: diff picker, rebind screen

**Sorted library**:
The user-chosen root folder that books are sorted into.
_Avoid_: sorted root, sorted folder

**Sort**:
Moving a book into the Sorted library after a Rebind.
_Avoid_: file, move

**Backup**:
The `.rebind.bak` copy of the original EPUB taken before it is replaced.
