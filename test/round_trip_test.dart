import 'dart:convert';
import 'dart:io';

import 'package:l10n_tool/l10n_tool.dart';
import 'package:test/test.dart';

void main() {
  group('checks', () {
    test('round trip reports lost, drifted and unexpected keys', () {
      final problems = checkRoundTrip({'a': 'A', 'b': 'B', 'c': 'C'}, {'a': 'A', 'b': 'changed', 'd': 'D'});
      expect(problems, hasLength(3));
      expect(problems, contains(startsWith('LOST KEY: c')));
      expect(problems, contains(startsWith('VALUE DRIFT: b')));
      expect(problems, contains(startsWith('UNEXPECTED KEY: d')));
    });

    test('authored translations must survive', () {
      expect(checkBaselinePreserved('ru', {'a': 'А'}, {'a': 'А'}), isEmpty);
      expect(checkBaselinePreserved('ru', {'a': 'А'}, {'a': 'machine'}), hasLength(1));
    });

    test('placeholders must survive in every locale', () {
      final problems = checkPlaceholders(
        {'hello': 'Hi {name}', 'plain': 'No placeholders'},
        {
          'ru': {'hello': 'Привет {name}', 'plain': 'Нет'},
          'es': {'hello': 'Hola {nombre}'},
        },
      );
      expect(problems, hasLength(1));
      expect(problems.single, contains('[es]'));
    });

    test('placeholder names include the ICU argument form', () {
      expect(placeholderNames('{count, plural, one{{count} slot} other{{count} slots}}'), equals(<String>{'count'}));
      expect(placeholderNames('Save {label} as #{number}'), equals(<String>{'label', 'number'}));
      expect(placeholderNames('nothing'), isEmpty);
    });

    test('factual rows must differ from the source', () {
      final problems = checkFactual(
        {'lang', 'localeCode'},
        {'lang': 'English', 'localeCode': 'en'},
        {
          'ru': {'lang': 'Русский', 'localeCode': 'en'},
        },
      );
      expect(problems, hasLength(1));
      expect(problems.single, contains('localeCode'));
    });
  });

  group('verifyRoundTrip', () {
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
        locales: const ['en', 'ru'],
        buckets: const ['app'],
        factualLabels: const {'lang'},
        arbDir: '${dir.path}/arb',
        baselineDir: '${dir.path}/baseline',
      );
      write('baseline/app_en.arb', {
        '@@locale': 'en',
        'hello': 'Hi {name}',
        '@hello': {'description': 'x'},
        'lang': 'English',
      });
      write('baseline/app_ru.arb', {'@@locale': 'ru', 'lang': 'Русский'});
      write('arb/app/app_en.arb', {'@@locale': 'en', 'hello': 'Hi {name}', 'lang': 'English'});
      write('arb/app/app_ru.arb', {'@@locale': 'ru', 'hello': 'Привет {name}', 'lang': 'Русский'});
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('passes over a consistent tree', () {
      final out = StringBuffer();
      expect(verifyRoundTrip(config, out: out), isEmpty);
      expect(out.toString(), contains('Round-trip OK'));
    });

    test('reports a broken placeholder and a missing ARB', () {
      File('${dir.path}/arb/app/app_ru.arb')
          .writeAsStringSync(jsonEncode({'hello': 'Привет {имя}', 'lang': 'Русский'}));
      expect(verifyRoundTrip(config, out: StringBuffer()), contains(startsWith('ICU PLACEHOLDER BROKEN: hello [ru]')));

      File('${dir.path}/arb/app/app_ru.arb').deleteSync();
      expect(verifyRoundTrip(config, out: StringBuffer()), contains('MISSING ARB: app/ru'));
    });
  });
}
