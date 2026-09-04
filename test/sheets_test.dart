import 'dart:convert';
import 'dart:io';

import 'package:l10n_tool/l10n_tool.dart';
import 'package:test/test.dart';

void main() {
  group('buildRows', () {
    late Directory dir;
    late L10nConfig config;

    void write(String path, Map<String, Object?> json) {
      File('${dir.path}/$path')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(json));
    }

    setUp(() {
      dir = Directory.systemTemp.createTempSync('l10n_tool');
      config = L10nConfig(
        sheetId: 's',
        locales: const ['en', 'ru', 'es'],
        buckets: const ['app'],
        arbDir: '${dir.path}/arb',
        baselineDir: '${dir.path}/baseline',
      );
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('one row per source key; baseline over generated; empty cells for the fill', () {
      write('baseline/app_en.arb', {
        'hello': 'Hi {name}',
        '@hello': {
          'description': 'Greeting',
          'placeholders': {
            'name': {'type': 'String'},
          },
        },
        'bye': 'Bye',
        '@bye': {'description': 'Farewell'},
      });
      write('baseline/app_ru.arb', {'hello': 'Здравствуйте {name}'});
      write('arb/app/app_ru.arb', {'hello': 'Привет {name}', 'bye': 'Пока'});

      final rows = buildRows(config)['app']!;
      expect(headerRow(config), equals(<String>['label', 'description', 'meta', 'en', 'ru', 'es']));
      expect(rows, hasLength(2));
      expect(
        rows.first,
        equals(<String>[
          'hello',
          'Greeting',
          '{"placeholders":{"name":{"type":"String"}}}',
          'Hi {name}',
          'Здравствуйте {name}',
          '',
        ]),
      );
      expect(rows[1], equals(<String>['bye', 'Farewell', '', 'Bye', 'Пока', '']));
    });

    test('refuses a key without a description', () {
      write('baseline/app_en.arb', {'hello': 'Hi', '@hello': <String, Object?>{}});
      expect(() => buildRows(config), throwsFormatException);
    });
  });
}
