/// Offline consistency checks over committed localization artefacts, as a test group.
///
/// ```dart
/// void main() => l10nConsistencyTests(
///   L10nConfig.read('l10n_tool.json'),
///   generatedLocales: Locales.values.map((l) => l.languageCode).toSet(),
/// );
/// ```
///
/// A catalog that is still being written can turn the description rule off with
/// `requireDescriptions: false` until its rows carry one, and the same for
/// `requirePlaceholderDeclarations: false` while its multi-placeholder rows are being given a
/// `placeholders` block.
library;

import 'dart:convert';
import 'dart:io';

import 'package:l10n_tool/src/arb.dart';
import 'package:l10n_tool/src/config.dart';
import 'package:test/test.dart';

/// Registers a `committed l10n artefacts` group over the ARBs [config] describes.
///
/// Touches no network. [generatedLocales] is the set the generated Dart exposes, so the ARBs on
/// disk, the config and the code cannot drift apart unnoticed. [requireDescriptions] fails a source
/// key that carries none; a catalog authored before the rule existed sets it to false and turns it
/// on once the rows are written.
// A registration function: the branches are the checks it declares.
// ignore: avoid-high-cyclomatic-complexity
void l10nConsistencyTests(
  L10nConfig config, {
  required Set<String> generatedLocales,
  bool requireDescriptions = true,
  bool requirePlaceholderDeclarations = true,
}) {
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
      if (!requireDescriptions) return;
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

    test('a row with two or more placeholders declares them', () {
      if (!requirePlaceholderDeclarations) return;
      // gen-l10n orders the generated parameters ALPHABETICALLY unless the row declares a
      // `placeholders` block, which fixes both the order and the types. With no block every
      // parameter is `Object`, so a call site that passes them in SENTENCE order type-checks and
      // ships the values swapped — silently, in whatever language reads left to right.
      // Two rows shipped that way in one app and neither was caught by a test or a walk: a version
      // line printed "1.0.0 app.example · AppName", and a locked setup line printed its two halves
      // the wrong way round while a device walk recorded the reversed sentence as correct
      // (leaksonar, 2026-09-19 and 2026-09-20). Requiring the block is what makes the sentence and
      // the signature the same statement.
      final undeclared = <String>[];
      for (final bucket in config.buckets) {
        final parsed = parseArb(arb(bucket, config.source));
        for (final MapEntry(:key, :value) in parsed.messages.entries) {
          if (placeholderNames(value).length < 2) continue;
          // The index is the ARB metadata field name, not a position.
          // ignore: avoid-accessing-collections-by-constant-index
          final declared = parsed.meta[key]?['placeholders'];
          if (declared is! Map || declared.isEmpty) undeclared.add('$bucket/$key');
        }
      }
      expect(
        undeclared,
        isEmpty,
        reason:
            'These rows take more than one placeholder and declare none, so the generated argument '
            'order is alphabetical rather than the order the sentence reads: $undeclared',
      );
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
