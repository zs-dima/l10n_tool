# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **`generate` no longer leaves a bare `library;` in the localization barrel.**
  `sheety_localization:generate` writes one on every pull, and the line's lint set rejects a library
  directive with no doc comment or annotation, so each pull landed a red analyze and was stripped by
  hand in four apps. `stripBareLibraryDirective` removes it from `lib/localization.dart` after the
  pull; a documented or annotated directive is kept.

## [0.1.1] - 2026-09-05

### Added

- `l10nConsistencyTests` takes `requireDescriptions`, so a catalog whose rows predate the rule
  can adopt the rest of the gate and turn the description check on when its rows carry one.

## [0.1.0] - 2026-09-04

### Added

- First released version: `generate`, `verify`,
  `seed_sheet` and `pull_baseline` executables driven by one JSON config, the round-trip checks as
  a library, and `package:l10n_tool/testing.dart` with the offline consistency group.
