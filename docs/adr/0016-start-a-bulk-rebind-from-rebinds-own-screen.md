# 0016. Start a bulk Rebind from Rebind's own screen

## Status

Accepted

## Context

Users want to Rebind several books at once and reach Rebind from different file browsers: the stock one, Project: Title, SimpleUI, ZenOS and Bookshelf. None of them gives plugins a hook for acting on a multi-selection or on a folder or group. The stock select-mode dialog has hard-coded buttons, ZenOS replaces that dialog with its own fixed menu, and Bookshelf keeps its selection private. The one shared surface is the single-item long-press row, which the stock browser, Project: Title, SimpleUI and ZenOS (when plugin actions are on) also call for real folders.

- Option 1: Patch `FileManager.getPlusDialogButtons` to add a Rebind button to the stock select-mode dialog. Shows up in stock, Project: Title and SimpleUI only, and can break on any KOReader release.
- Option 2: Reach into each launcher's private selection. Fragile and per-launcher.
- Option 3: A Rebind-owned selection screen, opened from Tools and a Dispatcher action, that pre-ticks the file browser's select-mode selection when there is one, plus a folder long-press row that opens it for that folder.

## Decision

We will go with Option 3. Rebind will not patch KOReader or launcher internals to add bulk entry points.

## Consequences

Bulk Rebind works the same in every launcher, including Bookshelf through its start menu, and survives KOReader updates. Starting from a selection takes a trip through the Tools menu instead of a button in the select-mode dialog. Bookshelf users pick books on Rebind's screen because their selection cannot be read.
