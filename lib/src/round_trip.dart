import 'dart:io';

import 'package:l10n_tool/src/arb.dart';
import 'package:l10n_tool/src/config.dart';

/// Every authored source key must come back byte-identical, and nothing may appear in the
/// generated ARBs that was not authored.
List<String> checkRoundTrip(ArbMessages baseline, ArbMessages generated) => <String>[
  for (final MapEntry(:key, :value) in baseline.entries)
    if (!generated.containsKey(key))
      'LOST KEY: $key missing from the generated ARBs'
    else if (generated[key] != value)
      'VALUE DRIFT: $key, baseline "$value" vs generated "${generated[key]}"',
  for (final key in generated.keys)
    if (!baseline.containsKey(key)) 'UNEXPECTED KEY: $key (in the sheet but not in the baseline)',
];

/// Values authored for a locale must survive the machine fill pass untouched.
List<String> checkBaselinePreserved(String locale, ArbMessages baseline, ArbMessages generated) => <String>[
  for (final MapEntry(:key, :value) in baseline.entries)
    if (generated[key] != value) 'LOST ${locale.toUpperCase()} VALUE: $key, expected "$value", got "${generated[key]}"',
];

/// ICU placeholders are code, not prose: `{name}` must stay `{name}` in every locale.
List<String> checkPlaceholders(ArbMessages source, Map<String, ArbMessages> byLocale) => <String>[
  for (final MapEntry(:key, :value) in source.entries)
    for (final MapEntry(key: locale, value: messages) in byLocale.entries)
      if (messages[key] case final translated?)
        if (placeholderNames(value) case final expected when expected.isNotEmpty)
          if (placeholderNames(translated) case final actual when !actual.containsAll(expected))
            'ICU PLACEHOLDER BROKEN: $key [$locale], expected ${expected.toList()}, got ${actual.toList()}',
];

/// A factual row that still equals the source language was copied, not localised.
List<String> checkFactual(Set<String> labels, ArbMessages source, Map<String, ArbMessages> byLocale) => <String>[
  for (final label in labels)
    for (final MapEntry(key: locale, value: messages) in byLocale.entries)
      if (messages[label] case final value? when value == source[label])
        'FACTUAL ROW NOT LOCALISED: $label is "$value" in $locale, same as the source language',
];

/// Runs every round-trip check over the files on disk and prints coverage. Returns the problems
/// found; an empty list is a pass.
List<String> verifyRoundTrip(L10nConfig config, {StringSink? out}) {
  final sink = out ?? stdout;
  final problems = <String>[];

  // bucket -> locale -> messages
  final generated = <String, Map<String, ArbMessages>>{};
  for (final bucket in config.buckets) {
    generated[bucket] = <String, ArbMessages>{};
    for (final locale in config.locales) {
      final path = config.arbPath(bucket, locale);
      if (!File(path).existsSync()) {
        problems.add('MISSING ARB: $bucket/$locale');
        continue;
      }
      generated[bucket]![locale] = readArb(path).messages;
    }
  }

  // Baselines: the source is complete by construction; other locales hold only what was authored.
  final baselines = <String, ArbMessages>{for (final locale in config.locales) locale: <String, String>{}};
  for (final bucket in config.buckets) {
    for (final locale in config.locales) {
      baselines[locale]!.addAll(readArb(config.baselinePath(bucket, locale)).messages);
    }
  }

  final unions = <String, ArbMessages>{
    for (final locale in config.locales)
      locale: <String, String>{for (final bucket in config.buckets) ...?generated[bucket]?[locale]},
  };
  final sourceUnion = unions[config.source]!;
  final translatedUnions = <String, ArbMessages>{for (final locale in config.translated) locale: unions[locale]!};

  final sourceBaseline = baselines[config.source]!;
  problems.addAll(<String>[
    ...checkRoundTrip(sourceBaseline, sourceUnion),
    for (final locale in config.translated) ...checkBaselinePreserved(locale, baselines[locale]!, unions[locale]!),
    ...checkPlaceholders(sourceBaseline, translatedUnions),
    ...checkFactual(config.factualLabels, sourceUnion, translatedUnions),
  ]);

  sink.writeln('Coverage (translated keys per bucket/locale):');
  for (final bucket in config.buckets) {
    final counts = config.locales.map((l) => '$l=${generated[bucket]?[l]?.length ?? 0}').join(' ');
    sink.writeln('  $bucket: $counts');
  }
  if (problems.isEmpty) {
    sink.writeln('Round-trip OK: ${baselines[config.source]!.length} authored keys accounted for.');
  }
  return problems;
}
