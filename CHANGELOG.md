# Changelog

## [2.0.0](https://github.com/rameezk/rebind.koplugin/compare/v1.6.0...v2.0.0) (2026-10-07)


### Features

* add a nix flake devshell as the canonical dev environment ([#42](https://github.com/rameezk/rebind.koplugin/issues/42)) ([7fb9c1a](https://github.com/rameezk/rebind.koplugin/commit/7fb9c1a4da91f270f6c0fd4b1812354807e317a3))
* add the First published field ([#44](https://github.com/rameezk/rebind.koplugin/issues/44)) ([589bd62](https://github.com/rameezk/rebind.koplugin/commit/589bd62f032822090879bace3a1601afe2500d9c))
* add the Save as summary and screen, rename-only Apply and name-clash check ([#67](https://github.com/rameezk/rebind.koplugin/issues/67)) ([664fa83](https://github.com/rameezk/rebind.koplugin/commit/664fa834dfb0bef2dc6bde8140f8128d237627a0))
* add the Source screen and the Picker without Hardcover ([#66](https://github.com/rameezk/rebind.koplugin/issues/66)) ([fc10d94](https://github.com/rameezk/rebind.koplugin/commit/fc10d94ea9502f13b48e174ba3a483a0a395355a))
* choose the filename template from Naming… ([#45](https://github.com/rameezk/rebind.koplugin/issues/45)) ([22b9214](https://github.com/rameezk/rebind.koplugin/commit/22b9214f55759fc21f4457ec3bad0b3277ac748f))
* choose the folder template from Naming… and show it in the Sort dialog ([#46](https://github.com/rameezk/rebind.koplugin/issues/46)) ([20385d8](https://github.com/rameezk/rebind.koplugin/commit/20385d822f77367bf94eb259b26bbe5435301429))
* redesign template lists and custom template editor with token chips and Help ([#63](https://github.com/rameezk/rebind.koplugin/issues/63)) ([97a2994](https://github.com/rameezk/rebind.koplugin/commit/97a299483b9c09b110ac79edf3c686e54fcd39b3))
* redesign the Picker Field list with radio values, tags, fold and bulk button ([#65](https://github.com/rameezk/rebind.koplugin/issues/65)) ([464a62e](https://github.com/rameezk/rebind.koplugin/commit/464a62e13dc3c7aaa21e7d70c8da5d8bbe50f754))
* restyle the match list and edition list ([#64](https://github.com/rameezk/rebind.koplugin/issues/64)) ([b59f2f2](https://github.com/rameezk/rebind.koplugin/commit/b59f2f259a5d3a475dfbb8a08ebac1b2265678b7))
* run the emulator from the devshell on macOS ([#43](https://github.com/rameezk/rebind.koplugin/issues/43)) ([a87ab3c](https://github.com/rameezk/rebind.koplugin/commit/a87ab3c387a9c67af89607a4d742d0566ca64c46)), closes [#40](https://github.com/rameezk/rebind.koplugin/issues/40)
* show the e-ink Rebind logo in the Picker header and lookup message ([#72](https://github.com/rameezk/rebind.koplugin/issues/72)) ([2f06f97](https://github.com/rameezk/rebind.koplugin/commit/2f06f97e21bacf0c180f8f1b39f921378a1f35cb))
* write custom filename and folder templates under Naming… ([#49](https://github.com/rameezk/rebind.koplugin/issues/49)) ([27a661b](https://github.com/rameezk/rebind.koplugin/commit/27a661bf9d7dca2bf1e3582708499bf4780f5b7f))


### Refactoring

* move the Picker's selection rules into a Picker state module ([#62](https://github.com/rameezk/rebind.koplugin/issues/62)) ([607b567](https://github.com/rameezk/rebind.koplugin/commit/607b567fd60806ad6f5999bbe029630c60d4fbff))
* rename the Sorted library to Library in UI, docs and code ([#71](https://github.com/rameezk/rebind.koplugin/issues/71)) ([d93141c](https://github.com/rameezk/rebind.koplugin/commit/d93141c95d0c2b3e6378329d93594b528ecf489e))


### Documentation

* add a domain glossary and backfill architecture decision records ([#28](https://github.com/rameezk/rebind.koplugin/issues/28)) ([e0b65b4](https://github.com/rameezk/rebind.koplugin/commit/e0b65b4f331b132f26a515b3d2c443e7d267cec9))
* add agents.md ([#37](https://github.com/rameezk/rebind.koplugin/issues/37)) ([e969fe2](https://github.com/rameezk/rebind.koplugin/commit/e969fe221bbdc7119a4d6bda492bbc8801b02da6))
* allow PRs without screenshots when the emulator cannot run ([#47](https://github.com/rameezk/rebind.koplugin/issues/47)) ([1d1fd2d](https://github.com/rameezk/rebind.koplugin/commit/1d1fd2d3e28ec745401b75ea5e47df4f6207c72f))
* explain forcing a release version through squash merges ([#75](https://github.com/rameezk/rebind.koplugin/issues/75)) ([61853d3](https://github.com/rameezk/rebind.koplugin/commit/61853d3bd6b17d0ce221409513ac872dcab44de5))
* record naming template decisions and tracker config ([#36](https://github.com/rameezk/rebind.koplugin/issues/36)) ([fc36d99](https://github.com/rameezk/rebind.koplugin/commit/fc36d99ef38ecd32ce47e0b31e2b1ff74103d9b6))
* record the nix flake devshell as the canonical dev environment ([#41](https://github.com/rameezk/rebind.koplugin/issues/41)) ([9513700](https://github.com/rameezk/rebind.koplugin/commit/95137007350964299f076a1fd0d23d1be58a62a7))
* rename Own value to Custom value in the glossary ([#58](https://github.com/rameezk/rebind.koplugin/issues/58)) ([2f9755c](https://github.com/rameezk/rebind.koplugin/commit/2f9755cb1f0f9aaf1b945fabaaf21d07129d4644))
* rename the Sorted library term to Library ([#70](https://github.com/rameezk/rebind.koplugin/issues/70)) ([d5de054](https://github.com/rameezk/rebind.koplugin/commit/d5de054acecbeb935199cb9410428e783c8fcf0a))
* rewrite the README for the redesigned Picker ([#74](https://github.com/rameezk/rebind.koplugin/issues/74)) ([cff0621](https://github.com/rameezk/rebind.koplugin/commit/cff0621ee1e83959b7d8b043a432951c2011584e))

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
