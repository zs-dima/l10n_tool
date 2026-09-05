# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-09-05

### Added

- `l10nConsistencyTests` takes `requireDescriptions`, so a catalog whose rows predate the rule
  can adopt the rest of the gate and turn the description check on when its rows carry one.

## [0.1.0] - 2026-09-04

### Added

- First released version: `generate`, `verify`,
  `seed_sheet` and `pull_baseline` executables driven by one JSON config, the round-trip checks as
  a library, and `package:l10n_tool/testing.dart` with the offline consistency group.
