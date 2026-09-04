import 'dart:io';

import 'package:l10n_tool/l10n_tool.dart';
import 'package:l10n_tool/src/cli.dart';

const _kUsage = '''
usage: dart run l10n_tool:generate [--config <file>] [--translate] [--model=<name>]
                                   [--credentials=<file>] [--openai-key=<file>]

Pulls the sheet into ARBs and generated Dart (sheety_localization:generate), then runs the
round-trip check. --translate fills EMPTY sheet cells first (sheety_localization:localize).''';

Future<void> main(List<String> args) async {
  final cli = CliArgs.parse(args, usage: _kUsage, flags: const <String>{'--translate'});
  final config = cli.config;
  final credentials = cli.options['credentials'] ?? 'credentials.json';

  requireFile(credentials, 'the service account shared on the sheet');

  if (cli.has('--translate')) {
    final openaiKey = cli.options['openai-key'] ?? 'openai.key';
    final model = cli.options['model'] ?? 'gpt-5.5';
    requireFile(openaiKey, 'the API key used to fill empty cells');
    await run('dart', <String>[
      'run',
      'sheety_localization:localize',
      '-c',
      credentials,
      '-s',
      config.sheetId,
      '-f',
      openaiKey,
      '--model=$model',
    ]);
  }

  await run('dart', <String>[
    'run',
    'sheety_localization:generate',
    '-c',
    credentials,
    '-s',
    config.sheetId,
    '--prefix=${config.prefix}',
    '--format',
    // Without it a row with blank trailing cells is dropped entirely, source text included.
    '--include-empty',
  ]);

  final problems = verifyRoundTrip(config);
  if (problems.isNotEmpty) {
    stderr.writeln('\nROUND-TRIP FAILURES (${problems.length}):');
    problems.forEach(stderr.writeln);
    exit(1);
  }
}
