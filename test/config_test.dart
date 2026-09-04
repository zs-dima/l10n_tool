import 'dart:convert';
import 'dart:io';

import 'package:l10n_tool/l10n_tool.dart';
import 'package:test/test.dart';

void main() {
  group('L10nConfig', () {
    const minimal = <String, Object?>{
      'sheetId': 'sheet-1',
      'locales': <String>['en', 'ru'],
      'buckets': <String>['app'],
    };

    test('reads top-level fields with defaults', () {
      final config = L10nConfig.fromJson(minimal);
      expect(config.sheetId, equals('sheet-1'));
      expect(config.source, equals('en'));
      expect(config.translated, equals(<String>['ru']));
      expect(config.factualLabels, isEmpty);
      expect(config.prefix, equals('app'));
      expect(config.arbPath('app', 'ru'), equals('lib/src/l10n/app/app_ru.arb'));
      expect(config.baselinePath('app', 'en'), equals('tool/baseline/app_en.arb'));
    });

    test('reads the l10n section of a larger identity file', () {
      final config = L10nConfig.fromJson(const <String, Object?>{
        'slug': 'demo',
        'l10n': <String, Object?>{
          ...minimal,
          'factualLabels': <String>['lang'],
          'prefix': 'ui',
        },
      });
      expect(config.factualLabels, equals(<String>{'lang'}));
      expect(config.arbPath('app', 'en'), equals('lib/src/l10n/app/ui_en.arb'));
    });

    test('rejects a missing or empty required field', () {
      Map<String, Object?> without(String key) => Map<String, Object?>.of(minimal)..remove(key);
      Map<String, Object?> withValue(String key, Object value) => Map<String, Object?>.of(minimal)..[key] = value;

      expect(() => L10nConfig.fromJson(withValue('locales', <String>[])), throwsFormatException);
      expect(() => L10nConfig.fromJson(without('sheetId')), throwsFormatException);
      expect(() => L10nConfig.fromJson(withValue('buckets', 'app')), throwsFormatException);
    });

    test('reads a file', () {
      final dir = Directory.systemTemp.createTempSync('l10n_tool');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/l10n_tool.json')..writeAsStringSync(jsonEncode(minimal));
      expect(L10nConfig.read(file.path).sheetId, equals('sheet-1'));
      expect(() => L10nConfig.read('${dir.path}/missing.json'), throwsA(isA<FileSystemException>()));
    });
  });
}
