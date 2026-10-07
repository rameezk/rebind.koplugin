<p align="center">
  <img src="assets/rebind.svg" width="300" alt="Rebind logo: a book wrapped by a circular refresh loop">
</p>

<p align="center">
  <a href="https://github.com/rameezk/rebind.koplugin/releases/latest"><img src="https://img.shields.io/github/v/release/rameezk/rebind.koplugin" alt="Latest release"></a>
  <a href="https://github.com/rameezk/rebind.koplugin/releases"><img src="https://img.shields.io/github/downloads/rameezk/rebind.koplugin/total" alt="Downloads"></a>
  <a href="https://github.com/rameezk/rebind.koplugin/stargazers"><img src="https://img.shields.io/github/stars/rameezk/rebind.koplugin" alt="Stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/rameezk/rebind.koplugin" alt="License"></a>
</p>

# Rebind

A KOReader plugin that fixes a book's metadata on your device, using
[Hardcover](https://hardcover.app) or values you type yourself.

KOReader's own metadata editing only saves to its sidecar, so the changes stay in
KOReader. Rebind writes them into the book file itself, so they go wherever the book
goes: Calibre, other readers and other devices.

It can also rename the file and sort it into your library, using templates you
choose or write yourself.

<table>
  <tr>
    <td align="center"><img src="screenshots/picker.png" width="160" alt="The Picker, listing the fields that differ from Hardcover"><br><sub>Pick a value per field</sub></td>
    <td align="center"><img src="screenshots/editor.png" width="160" alt="Editing a field, with Start from chips"><br><sub>Edit any field</sub></td>
    <td align="center"><img src="screenshots/source.png" width="160" alt="The Source screen: book, edition and language"><br><sub>Change the edition or language</sub></td>
    <td align="center"><img src="screenshots/save-as.png" width="160" alt="The Save as screen: folder, filename and backup"><br><sub>Rename and sort</sub></td>
    <td align="center"><img src="screenshots/template-editor.png" width="160" alt="Writing a custom folder template with token chips and a live example"><br><sub>Write your own template</sub></td>
  </tr>
</table>

## Install

> **Lookups need the [Hardcover plugin](https://github.com/billiam/hardcoverapp.koplugin).**
> Install and enable it, then set an API token from <https://hardcover.app/account/api>
> by following [its setup instructions](https://github.com/billiam/hardcoverapp.koplugin#readme).
> Rebind needs the token to have the `read:catalog` and `read:me` scopes.
> Without it, Rebind lets you edit the metadata by hand.

### With a plugin manager

Install Rebind from [Storefront](https://github.com/ultimatejimmy/storefront.koplugin)
or [App Store](https://github.com/omer-faruq/appstore.koplugin). They also keep it
up to date.

### Manually

1. Download `rebind.koplugin.zip` from the
   [latest release](https://github.com/rameezk/rebind.koplugin/releases/latest).
2. Unzip it into KOReader's plugins folder:

   | Device | Plugins folder |
   |--------|----------------|
   | Kindle | `/mnt/us/koreader/plugins/` |
   | Kobo | `/mnt/onboard/.adds/koreader/plugins/` |
   | Android | `<koreader-dir>/plugins/` |
   | Desktop | `~/.config/koreader/plugins/` |

3. Restart KOReader and enable Rebind under Plugin management.

## Getting started

Long-press a book in the file browser and tap Rebind. While reading, use
Tools → Rebind, or bind "Rebind current book" to a gesture.

Rebind also works from these file browser plugins:

- [Bookshelf](https://github.com/AndyHazz/bookshelf.koplugin): long-press a book and
  tap Rebind under Plugin actions.
- [ZenOS](https://github.com/xZenLabs/zen-os): turn on Zen Settings → Library →
  Context menu → Plugin actions, then long-press a book and tap More → Rebind.

Rebind looks the book up on Hardcover and shows what differs. Pick the values
you want and tap Apply.

When Hardcover has no description or genres in the language you pick, Rebind
offers to translate them.

## Safety

Rebind rewrites the book, so it is careful about it:

- It writes the new book to a temporary file, checks that it is valid, and only
  then replaces the original.
- A backup of the original is kept as `.rebind.bak` unless you turn it off in Save as.
- Reading progress, bookmarks and highlights are kept and follow the book when it
  is renamed or moved.
- Translating a field uses KOReader's built-in translator. It needs a network
  connection and sends the text to Google.

## What's supported

### Formats

EPUB.

### Lookup providers

Hardcover.

### Fields

| Field | EPUB metadata |
|-------|---------------|
| Title | `dc:title` |
| Author(s) | `dc:creator`, one per author |
| Series | `calibre:series` and `calibre:series_index`, plus the EPUB 3 `belongs-to-collection` |
| First published | `dc:date`, as a year |
| Genre(s) | `dc:subject`, one per genre (Calibre shows these as tags) |
| Language | `dc:language` |
| Publisher | `dc:publisher` |
| Description | `dc:description` |

Existing values are updated in place, not duplicated. Clearing a field removes it
from the book.

Choosing an edition in another language also changes the book's language, which
affects hyphenation and text-to-speech.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the dev setup, tests, the emulator and releases.

## Credits and license

Rebind is released under the [MIT License](LICENSE).

- Hardcover API client: [hardcoverapp.koplugin](https://github.com/billiam/hardcoverapp.koplugin) (MIT)
- OPF parsing: [SLAXML](https://github.com/Phrogz/SLAXML) (MIT), vendored under `rebind/vendor/`
- Widget patterns modelled on [storefront.koplugin](https://github.com/ultimatejimmy/storefront.koplugin) (MIT) by ultimatejimmy
