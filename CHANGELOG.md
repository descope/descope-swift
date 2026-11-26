# Changelog

## [0.13.0](https://github.com/descope/descope-swift/compare/0.12.0...0.13.0) (2026-11-26)


### Features

* **passkeys:** send authenticatorAttachment and add isExternalPasskey to AuthenticationResponse ([#166](https://github.com/descope/descope-swift/issues/166)) ([1cbd5d0](https://github.com/descope/descope-swift/commit/1cbd5d018fdc388fe77f2030c8e7e242d05e924a))
* **push:** parse CIBA and push sign-in notifications, enroll device tokens ([#165](https://github.com/descope/descope-swift/issues/165)) ([1542775](https://github.com/descope/descope-swift/commit/1542775cda3aa2b3d396259578b1d26b9a0df935))


### Bug Fixes

* **webauth:** resume web authentication continuation only once ([#162](https://github.com/descope/descope-swift/issues/162)) ([e1a45e3](https://github.com/descope/descope-swift/commit/e1a45e37604ff27c92728ec999e3e33afb24fa30))

## [0.12.0](https://github.com/descope/descope-swift/compare/0.11.2...0.12.0) (2026-10-19)


### ⚠ BREAKING CHANGES

* fold session lifecycle into the session manager ([#158](https://github.com/descope/descope-swift/issues/158))

### Features

* **flows:** include traceId in flow errors ([#159](https://github.com/descope/descope-swift/issues/159)) ([59d32e8](https://github.com/descope/descope-swift/commit/59d32e864b35f3eac5b819c39fe88d97a55f8a0a))


### Code Refactoring

* fold session lifecycle into the session manager ([#158](https://github.com/descope/descope-swift/issues/158)) ([bc5ed35](https://github.com/descope/descope-swift/commit/bc5ed35cc05e8f9753046a2a8928016fdc82efae))
