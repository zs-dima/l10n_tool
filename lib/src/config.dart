import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

/// The shape of one application's localization: its sheet, locales and buckets.
///
/// Read from a JSON file, with these fields at the top level or under an `l10n` key, so an
/// application that already keeps its identity in one JSON file can point the tool at it:
///
/// ```json
/// { "sheetId": "1n9P-…", "locales": ["en", "ru"], "buckets": ["app", "errors"] }
/// ```
@immutable
final class L10nConfig {
  /// Creates an [L10nConfig].
  const L10nConfig({
    required this.sheetId,
    required this.locales,
    required this.buckets,
    this.factualLabels = const <String>{},
    this.prefix = 'app',
    this.arbDir = 'lib/src/l10n',
    this.baselineDir = 'tool/baseline',
  });

  /// Reads the config from [json], accepting the fields at the top level or under `l10n`.
  factory L10nConfig.fromJson(Map<String, Object?> json) {
    final section = json['l10n'];
    final doc = section is Map<String, Object?> ? section : json;

    List<String> strings(String key, {bool required = true}) {
      final value = doc[key];
      if (value is List<Object?> && value.every((e) => e is String) && (value.isNotEmpty || !required)) {
        return value.cast<String>();
      }
      if (!required && value == null) return const <String>[];
      throw FormatException('l10n config: `$key` must be a non-empty list of strings');
    }

    String string(String key, {String? fallback}) {
      final value = doc[key];
      if (value is String && value.isNotEmpty) return value;
      if (fallback != null && value == null) return fallback;
      throw FormatException('l10n config: `$key` must be a non-empty string');
    }

    return L10nConfig(
      sheetId: string('sheetId'),
      locales: strings('locales'),
      buckets: strings('buckets'),
      factualLabels: strings('factualLabels', required: false).toSet(),
      prefix: string('prefix', fallback: 'app'),
      arbDir: string('arbDir', fallback: 'lib/src/l10n'),
      baselineDir: string('baselineDir', fallback: 'tool/baseline'),
    );
  }

  /// Reads the config from the JSON file at [path].
  factory L10nConfig.read(String path) {
    final file = File(path);
    if (!file.existsSync()) throw FileSystemException('l10n config not found', path);
    return L10nConfig.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, Object?>);
  }

  /// The Google Sheet the catalog is authored in.
  final String sheetId;

  /// Locales in sheet column order. The first is the source language.
  final List<String> locales;

  /// Domain buckets: one sheet tab and one ARB set per bucket.
  final List<String> buckets;

  /// Labels whose values are per-locale facts, not translations; a value equal to the source
  /// language's is the failure.
  final Set<String> factualLabels;

  /// The ARB file prefix, `<prefix>_<locale>.arb`.
  final String prefix;

  /// Where generated ARBs live, one folder per bucket.
  final String arbDir;

  /// Where the authored baseline ARBs live, `<bucket>_<locale>.arb`.
  final String baselineDir;

  /// The source language.
  String get source => locales.first;

  /// Every locale except the source.
  Iterable<String> get translated => locales.skip(1);

  /// Path of the generated ARB for [bucket] and [locale].
  String arbPath(String bucket, String locale) => '$arbDir/$bucket/${prefix}_$locale.arb';

  /// Path of the authored baseline ARB for [bucket] and [locale].
  String baselinePath(String bucket, String locale) => '$baselineDir/${bucket}_$locale.arb';
}
