/// Offline consistency checks over committed localization artefacts, as a test group.
///
/// ```dart
/// void main() => l10nConsistencyTests(
///   L10nConfig.read('l10n_tool.json'),
///   generatedLocales: Locales.values.map((l) => l.languageCode).toSet(),
/// );
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:l10n_tool/src/arb.dart';
import 'package:l10n_tool/src/config.dart';
import 'package:test/test.dart';

/// Registers a `committed l10n artefacts` group over the ARBs [config] describes.
///
/// Touches no network. [generatedLocales] is the set the generated Dart exposes, so the ARBs on
/// disk, the config and the code cannot drift apart unnoticed.
// A registration function: the branches are the checks it declares.
// ignore: avoid-high-cyclomatic-complexity
void l10nConsistencyTests(L10nConfig config, {required Set<String> generatedLocales}) {
  Map<String, Object?> arb(String bucket, String locale) =>
      jsonDecode(File(config.arbPath(bucket, locale)).readAsStringSync()) as Map<String, Object?>;

  group('committed l10n artefacts', () {
    test('every bucket has an ARB for every locale', () {
      for (final bucket in config.buckets) {
        for (final locale in config.locales) {
          expect(File(config.arbPath(bucket, locale)).existsSync(), isTrue, reason: '$bucket/$locale ARB is missing');
        }
      }
    });

    test('every locale carries exactly the source key set', () {
      for (final bucket in config.buckets) {
        final source = parseArb(arb(bucket, config.source)).messages.keys.toSet();
        for (final locale in config.translated) {
          final other = parseArb(arb(bucket, locale)).messages.keys.toSet();
          expect(other.difference(source), isEmpty, reason: '$bucket: $locale has keys the source does not');
          expect(source.difference(other), isEmpty, reason: '$bucket: $locale is missing keys');
        }
      }
    });

    test('every key carries a description', () {
      final missing = <String>[];
      for (final bucket in config.buckets) {
        final parsed = parseArb(arb(bucket, config.source));
        for (final key in parsed.messages.keys) {
          // The index is the ARB metadata field name, not a position.
          // ignore: avoid-accessing-collections-by-constant-index
          final description = parsed.meta[key]?['description'] as String?;
          if (description == null || description.isEmpty) missing.add('$bucket/$key');
        }
      }
      expect(missing, isEmpty, reason: 'Keys without a description: $missing');
    });

    test('ICU placeholders survive translation', () {
      final broken = <String>[];
      for (final bucket in config.buckets) {
        final source = parseArb(arb(bucket, config.source)).messages;
        for (final locale in config.translated) {
          final translated = parseArb(arb(bucket, locale)).messages;
          for (final MapEntry(:key, :value) in source.entries) {
            final expected = placeholderNames(value);
            if (expected.isEmpty) continue;
            final actual = placeholderNames(translated[key] ?? '');
            if (!actual.containsAll(expected)) broken.add('$bucket/$key [$locale]: expected $expected, got $actual');
          }
        }
      }
      expect(broken, isEmpty, reason: broken.join('\n'));
    });

    test('factual rows are localised in every locale', () {
      if (config.factualLabels.isEmpty) return;
      final byBucket = <String, ArbMessages>{
        for (final bucket in config.buckets) bucket: parseArb(arb(bucket, config.source)).messages,
      };
      for (final locale in config.translated) {
        for (final bucket in config.buckets) {
          final messages = parseArb(arb(bucket, locale)).messages;
          for (final label in config.factualLabels) {
            final source = byBucket[bucket]![label];
            if (source == null) continue;
            expect(
              messages[label],
              isNot(equals(source)),
              reason: '$label is a per-locale fact; $locale equals the source',
            );
          }
        }
      }
    });

    test('the generated Dart exposes exactly the configured locales', () {
      expect(generatedLocales, equals(config.locales.toSet()));
    });
  });
}
