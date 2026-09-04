import 'package:l10n_tool/l10n_tool.dart';
import 'package:l10n_tool/src/cli.dart';

const _kUsage = '''
usage: dart run l10n_tool:pull_baseline [--config <file>] [--credentials=<file>]

Regenerates the source-language baseline ARBs from the sheet.''';

Future<void> main(List<String> args) async {
  final cli = CliArgs.parse(args, usage: _kUsage);
  final credentials = cli.options['credentials'] ?? 'credentials.json';
  requireFile(credentials, 'the service account shared on the sheet');
  try {
    await pullBaseline(cli.config, credentials: credentials);
  } on FormatException catch (e) {
    fail('REFUSING: ${e.message}');
  }
}
