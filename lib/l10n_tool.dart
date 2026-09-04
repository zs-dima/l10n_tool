/// The Google Sheets → ARB → gen-l10n pipeline around `sheety_localization`, with the checks
/// that keep an authored catalog and a committed one in agreement.
///
/// Executables: `generate`, `verify`, `seed_sheet`, `pull_baseline`. Test helpers:
/// `package:l10n_tool/testing.dart`.
library;

export 'src/arb.dart';
export 'src/config.dart';
export 'src/round_trip.dart';
export 'src/sheets.dart' show buildRows, headerRow, pullBaseline, seedSheet;
