import 'dart:convert';
import 'dart:io';

import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'package:l10n_tool/src/arb.dart';
import 'package:l10n_tool/src/config.dart';

/// The header row of every tab: `label | description | meta | <locales…>`.
List<String> headerRow(L10nConfig config) => <String>['label', 'description', 'meta', ...config.locales];

/// Builds the rows of every tab from the authored baseline and the generated ARBs.
///
/// Source-language text comes from the baseline. Translated columns take the baseline where one
/// exists (authored facts and hand-written copy) and the generated ARB otherwise, so a re-seed
/// round-trips what ships instead of wiping it. An empty cell is left for the machine fill.
///
/// Throws [FormatException] on a key without a description: it is the only context a translator
/// gets, so a row without one may not reach the sheet.
Map<String, List<List<String>>> buildRows(L10nConfig config) {
  const descriptionField = 'description';
  final tabs = <String, List<List<String>>>{};
  final sourceLocale = config.source;
  for (final bucket in config.buckets) {
    final rows = tabs[bucket] = <List<String>>[];
    final source = readArb(config.baselinePath(bucket, sourceLocale));
    final translations = <String, ArbMessages>{
      for (final locale in config.translated)
        locale: <String, String>{
          ...readArb(config.arbPath(bucket, locale)).messages,
          ...readArb(config.baselinePath(bucket, locale)).messages,
        },
    };

    for (final MapEntry(:key, :value) in source.messages.entries) {
      final entry = source.meta[key] ?? const <String, Object?>{};
      final description = entry[descriptionField] as String? ?? '';
      if (description.isEmpty) throw FormatException('"$key" has no description; every row must carry one');
      final rest = <String, Object?>{
        for (final MapEntry(key: field, value: v) in entry.entries)
          if (field != descriptionField) field: v,
      };
      rows.add(<String>[
        key,
        description,
        if (rest.isEmpty) '' else jsonEncode(rest),
        value,
        for (final locale in config.translated) translations[locale]?[key] ?? '',
      ]);
    }
  }
  return tabs;
}

/// Pushes the authored catalog into the sheet, clearing and rewriting every tab.
///
/// Destructive: sheet edits and machine-filled cells that no baseline pins are discarded.
Future<void> seedSheet(L10nConfig config, {String credentials = 'credentials.json', StringSink? out}) async {
  final sink = out ?? stdout;
  final tabs = buildRows(config);
  final client = await _client(credentials, sheets.SheetsApi.spreadsheetsScope);
  try {
    final api = sheets.SheetsApi(client);
    await _ensureTabs(api, config.sheetId, tabs.keys, sink);
    for (final MapEntry(key: tab, value: rows) in tabs.entries) {
      await api.spreadsheets.values.clear(sheets.ClearValuesRequest(), config.sheetId, "'$tab'!A:Z");
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: <List<Object?>>[headerRow(config), ...rows]),
        config.sheetId,
        "'$tab'!A1",
        // RAW: ICU braces and leading +/= must never be parsed as formulas.
        valueInputOption: 'RAW',
      );
      sink.writeln('Seeded $tab: ${rows.length} rows');
    }
  } finally {
    client.close();
  }
}

/// Regenerates the source-language baseline from the sheet, so the baseline is generated output
/// and the sheet stays the only authoring surface.
///
/// Source language only: the other baselines are the authored subset that the round-trip check
/// defends against the machine fill, so pulling every cell into them would bless machine output
/// as authored.
Future<void> pullBaseline(L10nConfig config, {String credentials = 'credentials.json', StringSink? out}) async {
  final sink = out ?? stdout;
  final sourceLocale = config.source;
  final client = await _client(credentials, sheets.SheetsApi.spreadsheetsReadonlyScope);
  try {
    final api = sheets.SheetsApi(client);
    final lastColumn = String.fromCharCode('A'.codeUnitAt(0) + headerRow(config).length - 1);
    for (final bucket in config.buckets) {
      final values = await api.spreadsheets.values.get(config.sheetId, "'$bucket'!A:$lastColumn");
      final rows = values.values ?? const <List<Object?>>[];
      if (rows.isEmpty) throw FormatException('sheet tab "$bucket" is empty');

      final arb = <String, Object?>{'@@locale': sourceLocale};
      String cell(List<Object?> row, int index) => index < row.length ? (row[index]?.toString() ?? '') : '';
      for (final row in rows.skip(1)) {
        final label = cell(row, 0);
        if (label.isEmpty) continue;
        final description = cell(row, 1);
        if (description.isEmpty) throw FormatException('"$label" has no description; every row must carry one');
        final meta = cell(row, 2);
        arb[label] = cell(row, 3);
        arb['@$label'] = <String, Object?>{
          'description': description,
          if (meta.isNotEmpty) ...jsonDecode(meta) as Map<String, Object?>,
        };
      }

      final path = config.baselinePath(bucket, sourceLocale);
      File(path)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(arb)}\n');
      sink.writeln('Pulled $bucket: ${(arb.length - 1) ~/ 2} keys -> $path');
    }
  } finally {
    client.close();
  }
}

Future<AutoRefreshingAuthClient> _client(String credentials, String scope) => clientViaServiceAccount(
  ServiceAccountCredentials.fromJson(File(credentials).readAsStringSync()),
  <String>[scope],
);

Future<void> _ensureTabs(sheets.SheetsApi api, String sheetId, Iterable<String> tabs, StringSink out) async {
  final spreadsheet = await api.spreadsheets.get(sheetId);
  final existing = <String?>{for (final sheet in spreadsheet.sheets ?? <sheets.Sheet>[]) sheet.properties?.title};
  final missing = tabs.where((tab) => !existing.contains(tab)).toList();
  if (missing.isEmpty) return;
  await api.spreadsheets.batchUpdate(
    sheets.BatchUpdateSpreadsheetRequest(
      requests: <sheets.Request>[
        for (final tab in missing)
          sheets.Request(
            addSheet: sheets.AddSheetRequest(properties: sheets.SheetProperties(title: tab)),
          ),
      ],
    ),
    sheetId,
  );
  out.writeln('Created tabs: ${missing.join(', ')}');
}
