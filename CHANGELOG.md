# Changelog

## [2.4.0](https://github.com/rameezk/rebind.koplugin/compare/v2.3.0...v2.4.0) (2026-11-14)


### Features

* add missing covers when rebinding sure matches ([#152](https://github.com/rameezk/rebind.koplugin/issues/152)) ([800ee82](https://github.com/rameezk/rebind.koplugin/commit/800ee82acab43cd8d2bb96db7b5c93c703146762))
* hold a cover to preview it full screen ([#150](https://github.com/rameezk/rebind.koplugin/issues/150)) ([78122ea](https://github.com/rameezk/rebind.koplugin/commit/78122eab47d48429edda5d16e20c564a7b92c24a))
* offer the Hardcover cover for a book that has none ([#148](https://github.com/rameezk/rebind.koplugin/issues/148)) ([22a614e](https://github.com/rameezk/rebind.koplugin/commit/22a614eabdeea8c665a141d9b9ec1bc1b3f759e5))
* offer the Open Library and Inventaire cover for a book that has none ([#151](https://github.com/rameezk/rebind.koplugin/issues/151)) ([e2e45ef](https://github.com/rameezk/rebind.koplugin/commit/e2e45ef967c88b5c27d990100a0df05dea3d4917))
* replace a book's cover with the Hardcover cover and keep the original ([#149](https://github.com/rameezk/rebind.koplugin/issues/149)) ([c5b2268](https://github.com/rameezk/rebind.koplugin/commit/c5b2268568e34adbe574483ba77cb395e44a6303))
* restore a book's original cover from the picker ([#153](https://github.com/rameezk/rebind.koplugin/issues/153)) ([0835c3d](https://github.com/rameezk/rebind.koplugin/commit/0835c3dcc1069abb8ed4cc4567d6dbd40b6f1fe1))


### Bug Fixes

* pass the skills-sync app's secrets to the skills sync ([#138](https://github.com/rameezk/rebind.koplugin/issues/138)) ([093174a](https://github.com/rameezk/rebind.koplugin/commit/093174a8107aae91411d3aa77306c30b3cd786ab))

## [2.3.0](https://github.com/rameezk/rebind.koplugin/compare/v2.2.0...v2.3.0) (2026-11-11)


### Features

* ask before big or unfinished batches and fail the rest when the connection drops ([#129](https://github.com/rameezk/rebind.koplugin/issues/129)) ([4ca38bf](https://github.com/rameezk/rebind.koplugin/commit/4ca38bff2e354c8a5778bc1802656f915e70e4ff))
* choose several books, look them up and review them in one list ([#126](https://github.com/rameezk/rebind.koplugin/issues/126)) ([3ca7cd1](https://github.com/rameezk/rebind.koplugin/commit/3ca7cd160d743f12ec2cfab3067a55a7e75fca31))
* keep the device awake while a batch is working ([#130](https://github.com/rameezk/rebind.koplugin/issues/130)) ([34006f4](https://github.com/rameezk/rebind.koplugin/commit/34006f44858f92a8a6815f9dca45cc0b1baab0ab))
* rebind a book from collections, history and file search ([#124](https://github.com/rameezk/rebind.koplugin/issues/124)) ([be863ab](https://github.com/rameezk/rebind.koplugin/commit/be863abc5d11e1e469f5977a63e86eccea5b5f90))
* rebind every sure match in a batch with one tap ([#127](https://github.com/rameezk/rebind.koplugin/issues/127)) ([573e93f](https://github.com/rameezk/rebind.koplugin/commit/573e93fcb79c01af677bf866a9589976456cff05))
* start rebinding several books from a folder, a selection or a gesture ([#128](https://github.com/rameezk/rebind.koplugin/issues/128)) ([e14dbcb](https://github.com/rameezk/rebind.koplugin/commit/e14dbcba2d6b7f51c1771ba56f2f8c5acdae7736))

## [2.2.0](https://github.com/rameezk/rebind.koplugin/compare/v2.1.0...v2.2.0) (2026-10-29)


### Features

* choose and order lookup providers in settings ([#99](https://github.com/rameezk/rebind.koplugin/issues/99)) ([1868981](https://github.com/rameezk/rebind.koplugin/commit/1868981fb81964616156ba315498d01a0ca7c37b))
* look a book up in one provider with edited search terms ([#103](https://github.com/rameezk/rebind.koplugin/issues/103)) ([f67e35e](https://github.com/rameezk/rebind.koplugin/commit/f67e35edfd4c5c155cf8bd68c06a932cbeace916))
* look books up in Inventaire when Hardcover and Open Library have no match ([#102](https://github.com/rameezk/rebind.koplugin/issues/102)) ([70bb756](https://github.com/rameezk/rebind.koplugin/commit/70bb756bede892252392d693083ea2ead9386e85))
* look books up in Open Library when Hardcover has no match ([#98](https://github.com/rameezk/rebind.koplugin/issues/98)) ([bea7562](https://github.com/rameezk/rebind.koplugin/commit/bea75625a599095414a34b55d7e29416d7a7a1bc))
* name the lookup provider in the picker and list fields it had nothing for separately ([#96](https://github.com/rameezk/rebind.koplugin/issues/96)) ([13f794e](https://github.com/rameezk/rebind.koplugin/commit/13f794e67abbde1b00b0ada17b41c38561db6896))


### Bug Fixes

* stop KOReader closing when opening lookup providers or rebinding a book ([#105](https://github.com/rameezk/rebind.koplugin/issues/105)) ([a2719f7](https://github.com/rameezk/rebind.koplugin/commit/a2719f78cec91c4826c76f908ecde0684621b911))

## [2.1.0](https://github.com/rameezk/rebind.koplugin/compare/v2.0.0...v2.1.0) (2026-10-07)


### Features

* pick an edition automatically when a book matches by title and author ([#85](https://github.com/rameezk/rebind.koplugin/issues/85)) ([ac567e1](https://github.com/rameezk/rebind.koplugin/commit/ac567e1a2230013439828315b3f6da7082dd421a))
* tidy the picker screens so lists close from the header and long labels fit ([#83](https://github.com/rameezk/rebind.koplugin/issues/83)) ([b4fe5ae](https://github.com/rameezk/rebind.koplugin/commit/b4fe5ae01ef728c3d16241b8c9cb050c28e43746))

## [2.0.0](https://github.com/rameezk/rebind.koplugin/compare/v1.6.0...v2.0.0) (2026-10-07)

Rebind 2.0 redesigns its interface so fixing a book takes less scrolling, fewer taps and less guessing.

- **Far less scrolling.** Each field is now a short list of values instead of rows of buttons, so a whole book fits on one or two screens of a 6" e-reader.
- **Only what needs a decision.** Fields that already match Hardcover are folded away, so you only look at the ones that differ.
- **You know where a value came from.** Each value is tagged book, Hardcover, custom, translated or removed, and machine translations are shown in italics so they stand out.
- **Mistakes are caught before anything is written.** A name clash at the destination is flagged before Apply instead of after the book is saved, and closing only asks to discard when you've changed something.
- **Renaming and sorting are in one place.** Backup, folder and filename settings moved to one Save as screen. It shows the exact destination path and remembers your choices, and the "Move into" popup after Apply is gone.
- **Templates you can judge at a glance.** Each folder and filename template is shown as it will look for this book, not just as a pattern.
- **Write your own templates.** When none of the ready-made templates fit, write a custom folder or filename template. Tap to insert tokens like Title, Author and Series #, check the Example preview as you go, and use Help to see each token's value for this book.
- **Rename or move on its own.** Apply now renames or moves a book even when its metadata doesn't change.
- **Works without Hardcover.** Choose "Don't use Hardcover", or carry on when the plugin is missing or a lookup fails, and edit every field by hand.
- **New field:** first published, saved as the book's year.

## [1.6.0](https://github.com/rameezk/rebind.koplugin/compare/v1.5.0...v1.6.0) (2026-09-03)


### Features

* rename the EPUB to "Author - Title" when filing a book ([#24](https://github.com/rameezk/rebind.koplugin/issues/24)) ([92ccd81](https://github.com/rameezk/rebind.koplugin/commit/92ccd817927262d24bd6b121118296da8620e711))


### Bug Fixes

* make the whole rebind picker scroll as one view ([#23](https://github.com/rameezk/rebind.koplugin/issues/23)) ([1df6b96](https://github.com/rameezk/rebind.koplugin/commit/1df6b96647621ffd76dab6725d9d1ccde50b2a76))

## [1.5.0](https://github.com/rameezk/rebind.koplugin/compare/v1.4.0...v1.5.0) (2026-07-30)


### Features

* get a book's metadata in another language ([#20](https://github.com/rameezk/rebind.koplugin/issues/20)) ([d27c34b](https://github.com/rameezk/rebind.koplugin/commit/d27c34bea17becc3e4079df7d1ae04a5ec6cf132)), closes [#16](https://github.com/rameezk/rebind.koplugin/issues/16)
* select another edition of book ([#18](https://github.com/rameezk/rebind.koplugin/issues/18)) ([2e2a5c3](https://github.com/rameezk/rebind.koplugin/commit/2e2a5c3a3a4cb4528125b78bb231fed67f1a3ac9))


### Bug Fixes

* make Hardcover lookups work in the macOS emulator ([#21](https://github.com/rameezk/rebind.koplugin/issues/21)) ([9a86da6](https://github.com/rameezk/rebind.koplugin/commit/9a86da65df74edddefa2a712f61e398f7df214b2))

## [1.4.0](https://github.com/rameezk/rebind.koplugin/compare/v1.3.0...v1.4.0) (2026-07-24)


### Features

* add genre ([#12](https://github.com/rameezk/rebind.koplugin/issues/12)) ([1fa3613](https://github.com/rameezk/rebind.koplugin/commit/1fa361396f25d14ffde7523fa030ed432360a962))

## [1.3.0](https://github.com/rameezk/rebind.koplugin/compare/v1.2.0...v1.3.0) (2026-07-23)


### Features

* allow for free text editing ([#7](https://github.com/rameezk/rebind.koplugin/issues/7)) ([6789b1e](https://github.com/rameezk/rebind.koplugin/commit/6789b1e0a978c02ef1b95e9d4001f5e06ad27600))

## [1.2.0](https://github.com/rameezk/rebind.koplugin/compare/v1.1.0...v1.2.0) (2026-07-23)


### Features

* sync description from hardcover ([#5](https://github.com/rameezk/rebind.koplugin/issues/5)) ([3826e7a](https://github.com/rameezk/rebind.koplugin/commit/3826e7a28d0a1deee13818106014a99682695c2a))

## [1.1.0](https://github.com/rameezk/rebind.koplugin/compare/v1.0.0...v1.1.0) (2026-07-23)


### Features

* add funding ([ce97137](https://github.com/rameezk/rebind.koplugin/commit/ce971378299cf9d0e0e6c365b999d77caa32849f))
* add funding ([6cc5e25](https://github.com/rameezk/rebind.koplugin/commit/6cc5e25105763aa2146f080c1e571c4f0473f9e5))
* remove funding ([6993a98](https://github.com/rameezk/rebind.koplugin/commit/6993a9875fad81dd1dad174629784cde48dbd04d))
* update funding information ([f04b027](https://github.com/rameezk/rebind.koplugin/commit/f04b02779f090d192d8e24a2f92686421cda06e4))

## 1.0.0 (2026-07-22)

### Features

* Initial release of Rebind — update an EPUB's embedded metadata (title, author, series) from Hardcover, rewriting the file in place.
