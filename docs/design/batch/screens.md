# Rebind several books: screens

The agreed design for rebinding a Batch. Each screen below has a PNG in this folder, rendered at the device size of `screenshots/` (1072×1448). The PNG is the visual target; this file is the contract for copy, elements, states and taps. Where the two disagree, this file wins.

Decisions behind these screens: ADR-0016 (entry points), ADR-0017 (look up first, then review), ADR-0018 (what a Sure match is). Terms: `docs/CONTEXT.md`. The editable source is the design canvas the PNGs were rendered from.

## Conventions

- Match the existing Rebind screens in `screenshots/`: black on white, bold titles, grey secondary text, bordered buttons, one black primary button at the bottom.
- Glossary terms appear in copy as plain lowercase words: "sure matches", "your library", "the batch".
- Plurals are real plurals: "Look up 1 book" and "Look up 9 books", "1 sure match" and "5 sure matches".
- Lists page the KOReader way, never scroll: « ‹ N / M › » above the bottom button, swipe left and right to turn pages, as many rows per page as fit. A section that continues onto the next page repeats its heading with "(continued)".
- Reuse what exists: the close icon (`rebind/ui/closeicon.lua`), tap rows (`rebind/ui/taprow.lua`), checkboxes (`rebind/ui/checkbox.lua`), the Logo (`rebind/ui/logo.lua`), the Save as screen (`rebind/ui/saveas.lua`), the Picker and the match chooser as they are, and KOReader's `ConfirmBox` and `InfoMessage` for dialogs.
- Every list is sorted by filename, case-insensitive, with natural number order ("Book 2" before "Book 10"). With subfolders included, it is sorted by path inside the chosen folder.

## 01 Entry points - `01-entry-points.png`

- Tools → Rebind gains "Rebind several books…" between "Rebind current book" and "Lookup providers". A Dispatcher action with the same name opens the same screen, so it can be bound to a gesture or launched from a launcher's start menu.
- Long-pressing a folder adds "Rebind books in this folder" to the folder dialog through the existing `addFileDialogButtons` row (`is_file` false). It opens screen 02 for that folder with every EPUB ticked.
- The single-book "Rebind" long-press button is also registered on Collections, History and file search, so it appears there as in the file browser.
- Nothing is patched into KOReader's select-mode dialog or any launcher.

## 02 Choose books - `02-choose-books.png`

Title "Rebind several books", close icon top right. Top to bottom:

1. Folder row: "Folder", the path in grey, "Change ▸" opens a folder chooser.
2. "Include subfolders" with an On/Off button, Off by default. On lists EPUBs in every folder below, at any depth.
3. Count and bulk actions: "N OF M EPUBS TICKED", "Select all", "Deselect all".
4. The paged checklist: one row per EPUB, checkbox and filename. Only EPUBs are listed.
5. Pager.
6. Primary button "Look up N books". Disabled when nothing is ticked.

Opening state:

- From the file browser in select mode: its selected EPUBs, ticked (see 03 when they span folders).
- From a folder long-press: that folder, every EPUB ticked.
- Otherwise: the file browser's current folder, or the open book's folder when started while reading, with nothing ticked.

## 03 Choose books: a selection, no providers - `03-choose-books-selection.png`

- A selection spanning folders shows Folder as "Selected books · N books from M folders", lists exactly those books with their folder under each filename, and hides "Include subfolders". "Change ▸" switches to an ordinary folder.
- With no lookup provider enabled, a bordered row sits at the top: "No lookup providers are enabled" / "Enable one to look these books up." with "Change ▸" opening Lookup providers. The primary button stays disabled until a provider is enabled.

## 04 Large selection - `04-large-selection.png`

Tapping "Look up N books" with more than 300 ticked shows a `ConfirmBox`:

> Look up 3,000 books?
>
> This takes about an hour, and the device is kept awake. You can stop and review what's found at any time.

Buttons "Cancel" and "Look up". The time is estimated from the lookup throttle rate. There is no cap.

## 05 Looking up - `05-looking-up.png`

Before this screen appears, KOReader's usual "Turn on Wi-Fi?" prompt runs if needed. A centred box with the Logo, then:

- "Looking up your books… X of N"
- A progress bar.
- The current filename, grey.
- "S sure matches · R to review so far"
- "Stop and review what's found": stops after the current lookup and opens 06 with what has been found. Books not yet looked up are left out of the batch.

Lookups are throttled to respect each Provider's rate limits. If the connection drops, the books still to go are tagged "Lookup failed".

## 06 Review list - `06-review-list.png`

Title "Review N books", close icon top right. Top to bottom:

1. Provider notice, only when a Provider was skipped: one line per Provider, "<Provider> was skipped for N books: <reason>."
2. "TO REVIEW · N · TAP TO OPEN" and its rows.
3. "SURE MATCHES · N · TAP TO CHECK" and its rows.
4. "DONE · N" and its rows, once anything is done (see 10).
5. Pager.
6. Save as row: "Save as for this batch" plus the backup state on the first line, a summary of folder and filename on the second, ▶. Opens the existing Save as screen with the remembered settings; changes are remembered as they are today.
7. Primary button "Rebind N sure matches". Absent when there are none.

A section with no rows is not shown. Each row shows the book's title and author in bold (the Proposed values for a sure match, the Current values otherwise), the filename in grey, and a tag on the right.

| Tag | Section | Tap |
|-----|---------|-----|
| `N matches` | To review | The match chooser, then the Picker for the book picked |
| `Check match` | To review | The Picker with that one Match, whose title or author did not agree with the book's |
| `No match` | To review | The Picker for editing by hand |
| `Lookup failed` | To review | Retries the lookup, then behaves as the new outcome |
| `Open in the reader` | To review | 07 |
| `Write failed` | To review | Shows the error, then the Picker |
| `Not moved` | To review | Shows why the move failed, then the Picker, which shows no changes so Save as can be adjusted |
| `<Provider> · N changes` | Sure matches | The Picker, to check before rebinding |
| `ISBN · <Provider> · N changes` | Sure matches | The same, for an ISBN match |
| `No changes` | Sure matches | The same |
| `✓ Rebound` or `✓ Sorted` | Done | Nothing |

A Picker opened from a row starts its Save as from the batch's; a change there applies to that book only. Applying moves the row to Done; closing the Picker without applying leaves the row where it was.

A sure match writes exactly what its Picker would apply untouched: the Proposed value for each Field that is not empty and differs, otherwise the Current value. No translation is offered. A sure match with no changes is not rewritten but still follows Save as.

## 07 Tapping the open book - `07-open-book.png`

An `InfoMessage`:

> <Title> is open in the reader.
>
> Close the batch and rebind it on its own from the reader.

The open book is never written as part of a batch and never counts towards "Rebind N sure matches".

## 08 Closing with unfinished books - `08-close-batch.png`

Closing the review list while any row other than the open book is not done shows a `ConfirmBox`:

> Close the batch?
>
> N books haven't been rebound. Their lookups will be lost.

Buttons "Keep reviewing" and "Close". No question when everything is done. A batch never survives a restart.

## 09 Rebinding sure matches - `09-rebinding.png`

Same box as 05: "Rebinding your books… X of N", progress bar, current filename, and "Stop after this book", which finishes the book in progress and returns to the review list. Unwritten sure matches stay under Sure matches. A failed write does not stop the batch.

## 10 After rebinding - `10-after-rebinding.png`

The review list again, with a bordered summary under the title, built from the outcomes, for example:

> ✓ 3 books rebound and sorted into your library. 1 could not be written. 1 was rebound but not moved.

Written books move to Done with their new path in grey. A failed write moves back to To review as `Write failed`, unchanged on disk. A rewrite whose move failed moves back as `Not moved`. The primary button becomes a bordered "Close" when no sure matches are left, including a batch that never had any. It closes the same way as the close icon, asking first as in 08 when anything is unfinished.

## Keeping the device awake

Not drawn, but part of 05 and 09. One keep-awake guard per batch holds `UIManager:preventStandby()` and `PluginShare.pause_auto_suspend` only while looking up or writing, never while waiting on the user. It is released on every way out: normal end, either Stop button, any error (each per-book step runs in `xpcall`), closing any batch screen, KOReader suspending, closing or exiting, and a watchdog when no book has finished for 2 minutes. Release is idempotent, and the suspend flag is restored to its value before the batch, not set to false. Tests cover every release path and assert the standby counter ends where it started.
