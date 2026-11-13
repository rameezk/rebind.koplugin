# 0020. Embed covers in the EPUB and keep the original

## Status

Accepted

## Context

Rebind will add and replace book covers fetched from Providers, and let the user restore the cover the book had before. KOReader has its own custom covers, stored as `cover.<ext>` in the book's sidecar folder, and a built-in way to set one from an image file on the device.

Where the new cover lives:

- Option 1: KOReader sidecar cover. Simple and leaves the file alone, but only KOReader sees it, which breaks the promise of ADR-0001 that a rebound book is correct everywhere.
- Option 2: Embed the cover in the EPUB through the write path of ADR-0003. The cover travels to Calibre and other readers. Changing the file hash and Calibre owning the file are costs ADR-0001 already accepted.

Where the original cover is kept for restoring:

- Option 3: Rely on the `.rebind.bak` backup. It is optional and the next rebind overwrites it.
- Option 4: Copy the original into the sidecar folder. Lost when the book moves to another device.
- Option 5: Keep the original image inside the EPUB, marked in the OPF.

## Decision

We will go with Option 2 and Option 5. The original is the cover the book had before Rebind first changed it, so replacing a cover again keeps that first original, and restoring a book that had no cover removes Rebind's cover. Covers come only from Providers; setting a cover from a local image stays with KOReader's built-in feature.

## Consequences

Rebind's write path now edits the OPF manifest and image entries, not only `<metadata>`, and has to handle both EPUB2 and EPUB3 cover conventions. A book with a replaced cover carries an extra image. Covers apply only to EPUBs, like every other Rebind change.
