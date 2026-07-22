# Rebind

Fix your EPUBs' embedded metadata — title, author, and series — from
[Hardcover](https://hardcover.app), **entirely on your KOReader device**. Long-press
a book, review the current vs. proposed values side by side, pick what to keep, and
Rebind rewrites the file in place (Calibre-style, mutating the OPF). No laptop, no
cables, no Calibre round-trip.

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
that: you edit the embedded metadata **entirely on the device**, right from
KOReader — no laptop, no cable, no round-trip.

Because it rewrites the real embedded metadata (not a KOReader-only sidecar), the
corrected title, author, and series travel with the file everywhere — other readers,
Calibre, and any device you copy it to see the same values. And with the optional
sorted-library move, you can look a book up, correct it, and file it away by author
without ever leaving the reader.

## Install

1. Copy the `rebind.koplugin` folder into your device's KOReader plugins folder:

   | Device | Plugins folder |
   |--------|----------------|
   | Kindle | `/mnt/us/koreader/plugins/` |
   | Kobo | `/mnt/onboard/.adds/koreader/plugins/` |
   | Android | `<koreader-dir>/plugins/` |
   | Desktop | `~/.config/koreader/plugins/` |

2. Restart KOReader.
3. Enable **Rebind** (menu → gear → **Plugin management**).

> **Rebind needs the [Hardcover plugin](https://github.com/billiam/hardcoverapp.koplugin)**
> (MIT) — it reuses that plugin's API client rather than talking to Hardcover
> directly. Install it, **enable** it, and configure its API token by following
> [its setup instructions](https://github.com/billiam/hardcoverapp.koplugin#readme)
> (you'll need a token from <https://hardcover.app/account/api>). If Hardcover is
> missing, disabled, or unconfigured, Rebind tells you instead of doing anything.

---

## A quick tour

### Launching Rebind

Three ways in — and the menu is a single **Rebind** entry with no submenus, because
everything else is chosen on the rebind screen itself:

- **File browser** — long-press an EPUB → **Rebind**. This works in KOReader's stock
  file browser, and if you use
  [Bookshelf](https://github.com/AndyHazz/bookshelf.koplugin), Rebind is also
  surfaced when you long-press a book (under its **Plugin actions**).
- **While reading** — top menu → **Tools → Rebind** (it sits at the top of Tools).
- **Gesture** — bind the **"Rebind current book"** action to any gesture or tap-zone
  via **Gear → Taps and gestures → Gesture manager**, for one-tap access.

<table>
  <tr>
    <td align="center"><img src="screenshots/file-browser-menu.png" width="300" alt="Rebind in KOReader's stock file browser long-press menu"><br><sub>Stock file browser</sub></td>
    <td align="center"><img src="screenshots/bookshelf-menu.png" width="300" alt="Rebind in the Bookshelf plugin book menu"><br><sub>Bookshelf book menu</sub></td>
  </tr>
</table>

Rebind looks the book up on Hardcover — by ISBN first (read from the EPUB), falling
back to a title + author search. If several matches come back, you pick the right one.

### The metadata picker

The heart of Rebind. Your book's **current** values sit on the left, Hardcover's
**new** values on the right, field by field (title, author, series). Tap **Keep
current** or **Use new** per field, or **Keep all current** / **Use all new** at the
top to decide in one go. An empty field (like a missing series) shows `(none)`, so
you can see exactly what Rebind would add.

Two toggles in the footer, remembered between runs:

- **Keep backup** — leave a `.rebind.bak` copy of the original next to the book.
- **Sort book** — move the file into your sorted library after applying (below).

Hit **Apply** and Rebind rewrites the file. The library refreshes on its own; if you
rebind the book you're reading, it offers to reopen so the new metadata takes effect.

### Sorting into folders

Turn on **Sort book** and, after applying, Rebind offers to file the book away. The
first time, it asks for a destination folder — prefilled to your KOReader home
folder, and remembered per device. Then you pick the layout:

- **Author / Title / book** — a sorted tree: `<root>/<Author, Surname-first>/<Title>/<file.epub>`
- **Directly in this folder** — just move the file into the chosen folder
- **Keep here** — don't move

The `.sdr` sidecar (reading progress, bookmarks, highlights) travels with the book.
Sort the book you're currently reading and Rebind relocates it and reopens it at the
new path, position intact. Author folders are surname-first (e.g. `Herbert, Frank`);
folder names are sanitized for filesystem-illegal characters.

## Safety

Rebind **mutates the EPUB file**, so it works carefully:

- it writes the rewritten EPUB to a temporary file,
- re-opens and validates it (the `mimetype` entry must be first and stored
  uncompressed, and the OPF must still parse),
- copies the original to `<book>.epub.rebind.bak`,
- and only then atomically replaces the original.

The original is never overwritten until the new file is confirmed valid. The backup
is always created for the duration of the swap; whether it's **kept** afterwards is
the **Keep backup** toggle on the rebind screen (on by default) — turn it off to
avoid `.rebind.bak` files piling up in your library.

Your reading progress, bookmarks, and highlights in the `.sdr` sidecar are left
untouched. After a successful write, Rebind invalidates KOReader's cached book info
(via the `InvalidateMetadataCache` / `BookMetadataChanged` events) so the file
browser shows the new values without a restart.

### What gets written

Only **title, author(s), series, and series index** (v1 scope). Series is written in
**both** conventions for maximum compatibility, updating existing tags in place
rather than duplicating them:

- Calibre: `<meta name="calibre:series" .../>` + `calibre:series_index`
- EPUB3: `belongs-to-collection` / `collection-type` / `group-position`

**EPUB only** — other formats (MOBI/AZW3/PDF) are detected and reported as not
supported yet. One book at a time; no batch mode. Cover and description are not
written yet.

## Development

The pure-logic modules (`rebind/epub.lua`, `rebind/hardcover.lua`,
`rebind/organize.lua`) have a zero-dependency test suite that runs on plain LuaJIT or
Lua 5.1 — no luarocks or busted required. It stubs KOReader's `ffi/archiver` with an
in-memory archive.

```
make test      # run the test suite
make package   # runs tests, then builds dist/rebind.koplugin.zip
make clean     # remove build artifacts
```

`./tests/run.sh` runs the suite directly (it tries `luajit`, `lua5.1`, `lua`, then
`nix run nixpkgs#luajit`). Coverage includes OPF editing (update-in-place, no
duplicate tags, both series conventions), metadata/ISBN extraction, the destination
path logic, and the Hardcover lookup/extraction. The UI modules (`main.lua`,
`rebind/ui/diffpicker.lua`) need a live KOReader runtime and are exercised on-device.
`make package` stages only the runtime files under a `rebind.koplugin/` prefix, so
the zip extracts straight into KOReader's `plugins/` directory.

## Credits & license

- Hardcover API client: [`hardcoverapp.koplugin`](https://github.com/billiam/hardcoverapp.koplugin) (MIT).
- OPF XML parsing/serialization: [SLAXML](https://github.com/Phrogz/SLAXML) (MIT),
  vendored under `rebind/vendor/`.
- The side-by-side metadata picker was modelled on the widget composition patterns in
  [`storefront.koplugin`](https://github.com/ultimatejimmy/storefront.koplugin) (MIT)
  by ultimatejimmy.
