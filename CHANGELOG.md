# Changelog

All notable changes to this project are documented in this file (English only).

Release versions and notes are managed by [release-please](https://github.com/googleapis/release-please).
User-facing version (`MARKETING_VERSION`) is bumped when a Release PR is merged; build numbers are bumped separately by CI.

## [1.1.0](https://github.com/Juuro/LogWeight/compare/v1.0.0...v1.1.0) (2026-09-19)


### Features

* Add optional in-app tip jar ([#41](https://github.com/Juuro/LogWeight/issues/41)) ([0ddd810](https://github.com/Juuro/LogWeight/commit/0ddd81045c57ff87b28647e27398ed8b20e6a039))
* add segmented chart time-range selector ([#7](https://github.com/Juuro/LogWeight/issues/7)) ([a83c378](https://github.com/Juuro/LogWeight/commit/a83c378822e72a4fd3dd799289ddd245c37deb7a))
* add watchOS/macOS app targets and shared multiplatform views ([a9b5428](https://github.com/Juuro/LogWeight/commit/a9b542851b9aaa3d413dc1779f4c589f2f59cedd))
* add watchOS/macOS targets, shared views, and release docs ([54ba0ea](https://github.com/Juuro/LogWeight/commit/54ba0ea2584e507d2bba62ed7b8c1e8dba2fa67e))
* add weight entry editing functionality in HistoryView and Healt… ([c98b34c](https://github.com/Juuro/LogWeight/commit/c98b34c76ab4bacf84498e80e973ae7a82c88d5c))
* add weight entry editing functionality in HistoryView and HealthKitStore ([2f19506](https://github.com/Juuro/LogWeight/commit/2f195067c263c0bedd4565a57e64de93b4eaeeac))
* **entry view:** enhance weight entry functionality ([#6](https://github.com/Juuro/LogWeight/issues/6)) ([7697c94](https://github.com/Juuro/LogWeight/commit/7697c9418239b6dc2887e08f908c52c4ac60be5b))
* **history view:** enhance chart rendering by introducing off-window anchors and improving data handling ([#15](https://github.com/Juuro/LogWeight/issues/15)) ([b1fac35](https://github.com/Juuro/LogWeight/commit/b1fac3593618506906be94111e3918377e91bb40))
* **i18n:** add missing strings and wire widget localization bundles ([#29](https://github.com/Juuro/LogWeight/issues/29)) ([bc05eaa](https://github.com/Juuro/LogWeight/commit/bc05eaa1ad2e5e0e70d0928eff8984e0605c5c9c))
* implement weight deletion functionality in HistoryView and HealthKitStore ([a15b8cf](https://github.com/Juuro/LogWeight/commit/a15b8cfa129277c00774d9dc8da4c914bd105826))
* **ios:** add tab layout for entry and history ([#12](https://github.com/Juuro/LogWeight/issues/12)) ([9a3ad5e](https://github.com/Juuro/LogWeight/commit/9a3ad5e6b04bae739b830eff8440589017c9ed8f))
* persistent tip thank-you, feedback/rating rows and 1.0.0 release prep ([#43](https://github.com/Juuro/LogWeight/issues/43)) ([9127790](https://github.com/Juuro/LogWeight/commit/91277902763958ebac55d8ce178bc4e0c20a49ed))
* **reminders:** implement daily reminders and trend arrow settings ([#25](https://github.com/Juuro/LogWeight/issues/25)) ([814e70b](https://github.com/Juuro/LogWeight/commit/814e70b6431597eecae214b121bcb3ed30d22dcc))
* scaffold LogWeight Phase 1 (iOS-only multiplatform foundation) ([64b4979](https://github.com/Juuro/LogWeight/commit/64b49793ad8e7a65c1f436f9921a47490473aafd))
* **screenshots:** add watchOS screenshot capture and shorten App Store subtitles ([8df70ea](https://github.com/Juuro/LogWeight/commit/8df70ea7231c00576b838af8648a2e86dc1b48b5))
* **support:** add dedicated support instructions page ([ca1ecfa](https://github.com/Juuro/LogWeight/commit/ca1ecfa1ae99041c3b2d1265df06e2aa7afc8a01))
* **widget:** add iOS interactive weight widget with app intents ([#17](https://github.com/Juuro/LogWeight/issues/17)) ([eab6620](https://github.com/Juuro/LogWeight/commit/eab662038840b7fcb452774c4ff0ee551155f3d0))


### Bug Fixes

* **build:** align watch bundle versions with iOS app ([#27](https://github.com/Juuro/LogWeight/issues/27)) ([9853364](https://github.com/Juuro/LogWeight/commit/985336466bdde6efda4a56c42e08d733b6771d76))
* **build:** declare export compliance for TestFlight uploads ([#32](https://github.com/Juuro/LogWeight/issues/32)) ([58af962](https://github.com/Juuro/LogWeight/commit/58af962efafb8fbd12efd50482136ba808e1e9ae))
* **build:** generate Info.plist for UI-test targets and fix accessibility audit findings ([a6c1442](https://github.com/Juuro/LogWeight/commit/a6c14422c9c5d3071599722c52153f5208a919ac))
* **core:** clip trend chart line at y-axis boundary ([#22](https://github.com/Juuro/LogWeight/issues/22)) ([27122db](https://github.com/Juuro/LogWeight/commit/27122dbb417a57b92d3a89c817d6cc597d49f4c7))
* **core:** reject negative parsed weight inputs ([#19](https://github.com/Juuro/LogWeight/issues/19)) ([4874be1](https://github.com/Juuro/LogWeight/commit/4874be1e3db5f8c16b7b7ae6164e71dfd1085828))
* **entry:** ensure keyboard entry remains available for all entries ([#23](https://github.com/Juuro/LogWeight/issues/23)) ([29b6db1](https://github.com/Juuro/LogWeight/commit/29b6db1e77b9cb7dd308f01e1eabf474bedfc601))
* **entry:** keep keyboard editing available for first entry ([#21](https://github.com/Juuro/LogWeight/issues/21)) ([9a67310](https://github.com/Juuro/LogWeight/commit/9a673100d95e658bddcb4327713e12f33f1d2259))
* request HealthKit authorization before save ([c1f96ed](https://github.com/Juuro/LogWeight/commit/c1f96edd6bdb46c93f30297b45aa349de20c6dcb))
* restore HealthKit usage strings in Info.plist ([f482af1](https://github.com/Juuro/LogWeight/commit/f482af1ae85851b0b34657f6377662ce6a67f0a1))
* **support:** add direct email and stable instructions link ([50579a0](https://github.com/Juuro/LogWeight/commit/50579a0dbffd390413f0cac3f88539c3735f6168))
* **support:** clarify contact copy and instruction link text ([de7938d](https://github.com/Juuro/LogWeight/commit/de7938db4f74746efa7f3fd4515f1fc6d9d808be))
* **support:** clarify support promise and export wording ([60c71bc](https://github.com/Juuro/LogWeight/commit/60c71bc0052d2d82ac23fb75fa33edf72bf46c7b))
* **support:** improve external-link and navigation copy ([f3d4191](https://github.com/Juuro/LogWeight/commit/f3d41911c7f72b2570701dc41e3980ac071615cd))
* Swift 6 concurrency warnings and flaky CI timing assertion ([#28](https://github.com/Juuro/LogWeight/issues/28)) ([0a36482](https://github.com/Juuro/LogWeight/commit/0a36482df74e3e3ae96d26b63697955bed8f162b))
* update watchOS app icon sizes and add missing asset ([303d634](https://github.com/Juuro/LogWeight/commit/303d6346b6331054cb9cd450a2b36d3868da05bb))

## [0.5.0](https://github.com/Juuro/LogWeight/compare/v0.4.0...v0.5.0) (2026-09-18)


### Features

* Add optional in-app tip jar ([#41](https://github.com/Juuro/LogWeight/issues/41)) ([0ddd810](https://github.com/Juuro/LogWeight/commit/0ddd81045c57ff87b28647e27398ed8b20e6a039))
* **screenshots:** add watchOS screenshot capture and shorten App Store subtitles ([8df70ea](https://github.com/Juuro/LogWeight/commit/8df70ea7231c00576b838af8648a2e86dc1b48b5))
* **support:** add dedicated support instructions page ([ca1ecfa](https://github.com/Juuro/LogWeight/commit/ca1ecfa1ae99041c3b2d1265df06e2aa7afc8a01))


### Bug Fixes

* **build:** generate Info.plist for UI-test targets and fix accessibility audit findings ([a6c1442](https://github.com/Juuro/LogWeight/commit/a6c14422c9c5d3071599722c52153f5208a919ac))
* **support:** add direct email and stable instructions link ([50579a0](https://github.com/Juuro/LogWeight/commit/50579a0dbffd390413f0cac3f88539c3735f6168))
* **support:** clarify contact copy and instruction link text ([de7938d](https://github.com/Juuro/LogWeight/commit/de7938db4f74746efa7f3fd4515f1fc6d9d808be))
* **support:** clarify support promise and export wording ([60c71bc](https://github.com/Juuro/LogWeight/commit/60c71bc0052d2d82ac23fb75fa33edf72bf46c7b))
* **support:** improve external-link and navigation copy ([f3d4191](https://github.com/Juuro/LogWeight/commit/f3d41911c7f72b2570701dc41e3980ac071615cd))

## [0.4.0](https://github.com/Juuro/LogWeight/compare/v0.3.0...v0.4.0) (2026-05-18)


### Features

* **i18n:** add missing strings and wire widget localization bundles ([#29](https://github.com/Juuro/LogWeight/issues/29)) ([bc05eaa](https://github.com/Juuro/LogWeight/commit/bc05eaa1ad2e5e0e70d0928eff8984e0605c5c9c))


### Bug Fixes

* **build:** align watch bundle versions with iOS app ([#27](https://github.com/Juuro/LogWeight/issues/27)) ([9853364](https://github.com/Juuro/LogWeight/commit/985336466bdde6efda4a56c42e08d733b6771d76))
* **build:** declare export compliance for TestFlight uploads ([#32](https://github.com/Juuro/LogWeight/issues/32)) ([58af962](https://github.com/Juuro/LogWeight/commit/58af962efafb8fbd12efd50482136ba808e1e9ae))

## [0.3.0](https://github.com/Juuro/LogWeight/releases/tag/v0.3.0) (2026-05-18)

### Baseline

- Versioning baseline aligned with git tag `v0.3.0` and `MARKETING_VERSION` in `project.yml`.
