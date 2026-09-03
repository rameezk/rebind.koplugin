<p align="center">
  <img src="assets/rebind.svg" width="300" alt="Rebind logo: a book wrapped by a circular refresh loop">
</p>

# Rebind

Fix your EPUBs' embedded metadata from [Hardcover](https://hardcover.app), or by typing
it yourself, **entirely on your KOReader device**. Long-press a book, review the current
vs. proposed values side by side, pick the right edition, pick what to keep, edit any
field by hand or pull the book up
[in another language](#getting-a-book-in-another-language), and Rebind rewrites the file
in place (Calibre-style, mutating the OPF).
No laptop, no cables, no Calibre round-trip.
See [what gets written](#what-gets-written) for the fields it touches.

<table>
  <tr>
    <td align="center"><img src="screenshots/file-browser-menu.png" width="200" alt="Rebind in the file browser long-press dialog"><br><sub><b>Long-press → Rebind</b></sub></td>
    <td align="center"><img src="screenshots/reader-tools-menu.png" width="200" alt="Rebind at the top of the reader Tools menu"><br><sub><b>Reader → Tools</b></sub></td>
    <td align="center"><img src="screenshots/diff-picker.png" width="200" alt="Side-by-side metadata picker"><br><sub><b>Pick per field</b></sub></td>
    <td align="center"><img src="screenshots/sort-move-dialog.png" width="200" alt="Choose how to file the book"><br><sub><b>File it away</b></sub></td>
  </tr>
</table>

## Why this is useful

Fixing a book's metadata usually means booting up Calibre on a computer, connecting
or syncing the device, editing there, and copying the file back. Rebind skips all of
that. You edit the embedded metadata **entirely on the device**, right from KOReader,
with no laptop, no cable, and no round-trip.

Because it rewrites the real embedded metadata (not a KOReader-only sidecar), the
corrected title, author, and series travel with the file everywhere: other readers,
Calibre, and any device you copy it to see the same values. And with the optional
sorted-library move, you can look a book up, correct it, and file it away by author
without ever leaving the reader.

## Install

> **Required for lookups: the [Hardcover plugin](https://github.com/billiam/hardcoverapp.koplugin).**
> Rebind reuses that plugin's API client instead of talking to Hardcover directly, so
> to look books up you must install it, **enable** it, and configure its API token by
> following
> [its setup instructions](https://github.com/billiam/hardcoverapp.koplugin#readme)
> (you'll need a token from <https://hardcover.app/account/api>). If Hardcover is
> missing, disabled, or unconfigured, Rebind says so and offers to let you edit the
> book's metadata by hand instead.

1. Copy the `rebind.koplugin` folder into your device's KOReader plugins folder:

   | Device | Plugins folder |
   |--------|----------------|
   | Kindle | `/mnt/us/koreader/plugins/` |
   | Kobo | `/mnt/onboard/.adds/koreader/plugins/` |
   | Android | `<koreader-dir>/plugins/` |
   | Desktop | `~/.config/koreader/plugins/` |

2. Restart KOReader.
3. Enable **Rebind** (menu → gear → **Plugin management**).

Prefer a plugin manager? You can also install and update Rebind from inside KOReader
with [Storefront](https://github.com/ultimatejimmy/storefront.koplugin) or
[App Store](https://github.com/omer-faruq/appstore.koplugin).

---

## A quick tour

### Launching Rebind

There are three ways in, and the menu is a single **Rebind** entry with no submenus,
because everything else is chosen on the rebind screen itself:

- **File browser**: long-press an EPUB → **Rebind**. This works in KOReader's stock
  file browser, and if you use
  [Bookshelf](https://github.com/AndyHazz/bookshelf.koplugin), Rebind is also
  surfaced when you long-press a book (under its **Plugin actions**).
- **While reading**: top menu → **Tools → Rebind** (it sits at the top of Tools).
- **Gesture**: bind the **"Rebind current book"** action to any gesture or tap-zone
  via **Gear → Taps and gestures → Gesture manager**, for one-tap access.

<table>
  <tr>
    <td align="center"><img src="screenshots/file-browser-menu.png" width="300" alt="Rebind in KOReader's stock file browser long-press menu"><br><sub>Stock file browser</sub></td>
    <td align="center"><img src="screenshots/bookshelf-menu.png" width="300" alt="Rebind in the Bookshelf plugin book menu"><br><sub>Bookshelf book menu</sub></td>
  </tr>
</table>

Rebind looks the book up on Hardcover, by ISBN first (read from the EPUB), falling
back to a title + author search. If several matches come back, you pick the right one,
or choose **None of these, edit myself** to fill the fields in by hand instead.

### Choosing an edition

A book on Hardcover usually has many editions, and they disagree about the things
Rebind writes: the title (subtitles and series suffixes come and go), the publisher,
the language of a translation. Rebind starts from the edition your ISBN matched, or
from Hardcover's default edition when the match came from a search, and lets you
switch:

- **From the match list**: tap **Editions** next to any result to see that book's
  editions before committing to one.
- **From the metadata picker**: the **Edition:** button under the header shows the
  edition currently feeding the Hardcover column. Tap it to swap to another one; the
  proposed values update in place, and any values you typed yourself are kept.

Editions are listed most-popular first and labelled with what tells them apart -
format, year, publisher, page count and language (`Paperback · 2010 · Penguin ·
412pp · en`). The title, publisher and language come from the edition. The author,
series, genres and description come from the book, because Hardcover stores those
per work rather than per edition - so a translated edition keeps the original-language
description. Picking the Spanish edition of an English novel gets you a Spanish title
and publisher, but the English blurb, and the same author spelling as before.

Switching to a translated edition also proposes a new `dc:language`, which changes how
KOReader hyphenates the text and which voice reads it aloud. Leave that row on
**◂ Keep current** if you only wanted the edition's title.

Rebind asks Hardcover for the 30 most popular editions, skipping audiobooks, and says
so in the dialog title when a book has more.

### The metadata picker

The heart of Rebind. Your book's **current** values sit on the left, Hardcover's
**new** values on the right, one row per field. Tap
**Keep current** or **Use new** per field, or **Keep all current** / **Use all new**
at the top to decide in one go. An empty field (like a missing series) shows `(none)`,
so you can see exactly what Rebind would add. Long descriptions are shortened to a
preview in the picker; the full text is what gets written.

Neither value right? Type your own. **Tap any value** to edit it, or use the **Edit**
button under a field. The editor opens seeded with the value you tapped: a name + index
pair for series, a full-screen editor for the description, and a single line for
everything else (separate multiple authors or genres with commas).
Your text then appears as a third
value under the field, with a **Use mine** button to select it, so all three values
stay visible and switchable. Clearing an editor and saving **removes** that metadata
from the book.

### Getting a book in another language

Tap **Another language** and pick one. Rebind asks Hardcover for a real published
edition in that language, so you get the title a translator actually chose:
*Harry Potter y la piedra filosofal* in Spanish, *Harry Potter à l'école des sorciers*
in French. Title, publisher and language always come from the edition, never from a
translator, which is what keeps proper nouns intact.

<table>
  <tr>
    <td align="center"><img src="screenshots/language-picker.png" width="230" alt="Language list"><br><sub><b>Pick a language</b></sub></td>
    <td align="center"><img src="screenshots/language-editions.png" width="230" alt="Spanish editions of the book"><br><sub><b>Pick an edition</b></sub></td>
    <td align="center"><img src="screenshots/translate-gaps.png" width="230" alt="Prompt offering to translate the remaining fields"><br><sub><b>Translate the rest</b></sub></td>
  </tr>
</table>

Hardcover stores descriptions and genres per *book*, not per edition, so those stay
English however many editions a book has. Rebind says so and offers to run just those
two fields through KOReader's built-in translator:

> Hardcover has no Spanish description or genres. Those exist per book, not per edition.
> Translate Genre(s), Description with Google Translate instead?

The same offer appears when Hardcover has no edition in that language at all. The picker
marks which is which: **Use new** is Hardcover's, **Use mine** is machine-translated, and
nothing is written until you hit **Apply**.

<p align="center">
  <img src="screenshots/language-result.png" width="320" alt="Translated genres beside a language and publisher taken from the Spanish edition">
</p>

Genres are translated one at a time so the list stays a list, and long descriptions are
split on paragraph and sentence boundaries before being sent. Translation uses
KOReader's built-in translator: no API key, but it needs a network connection and the
text goes to Google. It is a fallback for text Hardcover does not have, not an
improvement on text it does.

The same editors work whenever Hardcover has nothing useful to offer, so no path
dead-ends:

- **No match**: Rebind offers to let you edit the metadata yourself.
- **Wrong matches**: the match list carries a **None of these, edit myself** option.
- **Lookup failed** (no network, API error): choose **Retry** or **Edit myself**.
- **Hardcover plugin missing or unconfigured**: Rebind says what to install and offers
  hand-editing in the meantime.

In each case you get the picker with an empty Hardcover column and every field
editable.

Three toggles in the footer, remembered between runs:

- **Keep backup**: leave a `.rebind.bak` copy of the original next to the book.
- **Sort book**: move the file into your sorted library after applying (below).
- **Rename file**: rename the book to `<Author, Surname-first> - <Title>.epub` (on by default), whether or not it's sorted - with **Sort book** off it's renamed in place.

Hit **Apply** and Rebind rewrites the file. The library refreshes on its own. If you
rebind the book you're reading, it offers to reopen so the new metadata takes effect.

<p align="center">
  <img src="screenshots/diff-picker.png" width="320" alt="The metadata picker: current values on the left, new Hardcover values on the right">
</p>

### Sorting into folders

Turn on **Sort book** and, after applying, Rebind offers to file the book away. The
first time, it asks for a destination folder, prefilled to your KOReader home folder
and remembered per device. Then you pick the layout:

- **Author / Title / book**: a sorted tree, `<root>/<Author, Surname-first>/<Title>/<file.epub>`
- **Directly in this folder**: just move the file into the chosen folder
- **Keep here**: don't move

With **Rename file** on (the default), the book is renamed to
`<Author, Surname-first> - <Title>.epub`, keeping its original extension; turn it off to
keep the source filename. Rename is independent of sorting: with **Sort book** off, the
book is renamed in place in its current folder. The `.sdr` sidecar (reading progress,
bookmarks, highlights) travels with the book and follows the new name. Rename or sort the
book you're currently reading and Rebind relocates it and reopens it at the new path,
position intact. Author folders and filenames are surname-first (e.g. `Herbert, Frank`),
sanitized for filesystem-illegal characters.

<p align="center">
  <img src="screenshots/sort-move-dialog.png" width="320" alt="The move prompt: file the book by Author/Title, directly in the folder, or keep it">
</p>

## Safety

Rebind **mutates the EPUB file**, so it works carefully:

- it writes the rewritten EPUB to a temporary file,
- re-opens and validates it (the `mimetype` entry must be first and stored
  uncompressed, and the OPF must still parse),
- copies the original to `<book>.epub.rebind.bak`,
- and only then atomically replaces the original.

The original is never overwritten until the new file is confirmed valid. The backup
is always created for the duration of the swap. Whether it's **kept** afterwards is
the **Keep backup** toggle on the rebind screen (on by default). Turn it off to avoid
`.rebind.bak` files piling up in your library.

Your reading progress, bookmarks, and highlights in the `.sdr` sidecar are left
untouched. After a successful write, Rebind invalidates KOReader's cached book info
(via the `InvalidateMetadataCache` / `BookMetadataChanged` events) so the file
browser shows the new values without a restart.

### What gets written

These fields, and nothing else:

| Field | Written as | Notes |
|-------|-----------|-------|
| Title | `dc:title` | |
| Author(s) | `dc:creator`, one per author | Comma-separated in the editor; the same for every edition |
| Series + index | `calibre:series` + `calibre:series_index`, **and** `belongs-to-collection` / `collection-type` / `group-position` | Both conventions, for maximum compatibility |
| Genre(s) | `dc:subject`, one per genre | What Calibre shows under **Tags**; Hardcover's top 5 by popularity |
| Language | `dc:language` | From the chosen edition, as a two-letter code (`en`, `fr`); edit by hand for `en-GB` |
| Publisher | `dc:publisher` | From the chosen edition |
| Description | `dc:description` | From the book, not the edition |

Existing tags are updated **in place** rather than duplicated, and emptying a field in
the editor removes its tags instead of writing them. `dc:title` and `dc:language` are
required by the EPUB spec, so a book you deliberately leave title-less or language-less
is technically non-conformant (readers fall back to the filename, and to guessing the
language).

The Hardcover plugin's own queries don't return descriptions or genres, so Rebind asks
Hardcover for them itself in a single extra query per lookup. If that query fails,
the rest of the lookup still works, and those fields just show as `(none)`. The edition
list is a separate query, made only when you ask for it and limited to the editions the
list can actually show - a popular book can have hundreds, and fetching them all is slow
enough to notice on an e-reader.

**EPUB only.** Other formats (MOBI/AZW3/PDF) are detected and reported as not
supported yet. One book at a time, no batch mode. Covers are not written yet.

## Development

The pure-logic modules (`rebind/epub.lua`, `rebind/fields.lua`, `rebind/hardcover.lua`,
`rebind/organize.lua`) have a zero-dependency test suite that runs on plain LuaJIT or
Lua 5.1, with no luarocks or busted required. It stubs KOReader's `ffi/archiver` with
an in-memory archive, and `gettext` with an identity function.

```
make test      # run the test suite
make package   # run tests, then build dist/rebind.koplugin.zip
make clean     # remove build artifacts
```

`./tests/run.sh` runs the suite directly (it tries `luajit`, `lua5.1`, `lua`, then
`nix run nixpkgs#luajit`). Coverage includes OPF editing (update-in-place, no
duplicate tags, both series conventions, clearing a field), metadata/ISBN extraction,
the field value parsing/formatting behind the editors, the destination path logic, and
the Hardcover lookup/extraction/edition listing. The UI modules (`main.lua`,
`rebind/ui/diffpicker.lua`) need a live KOReader runtime and are exercised on-device.
`make package` stages only the runtime files under a `rebind.koplugin/` prefix, so
the zip extracts straight into KOReader's `plugins/` directory.

### Releasing

Releases are automated with
[release-please](https://github.com/googleapis/release-please) and driven by
[conventional commits](https://www.conventionalcommits.org/). Merging a commit into
`main` opens a `chore(main): release X.Y.Z` pull request carrying the version bump
and the generated [`CHANGELOG.md`](CHANGELOG.md) entries; merging *that* tags the
release, publishes it, and attaches `dist/rebind.koplugin.zip` to it.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the commit conventions and how each
prefix affects the version.

## Credits & license

Rebind is released under the [MIT License](LICENSE).

- Hardcover API client: [`hardcoverapp.koplugin`](https://github.com/billiam/hardcoverapp.koplugin) (MIT).
- OPF XML parsing/serialization: [SLAXML](https://github.com/Phrogz/SLAXML) (MIT),
  vendored under `rebind/vendor/`.
- The side-by-side metadata picker was modelled on the widget composition patterns in
  [`storefront.koplugin`](https://github.com/ultimatejimmy/storefront.koplugin) (MIT)
  by ultimatejimmy.
