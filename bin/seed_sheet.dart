import 'package:l10n_tool/l10n_tool.dart';
import 'package:l10n_tool/src/cli.dart';

const _kUsage = '''
usage: dart run l10n_tool:seed_sheet [--config <file>] [--credentials=<file>]

Pushes the authored baseline catalog into the sheet. Destructive: clears and rewrites every tab,
discarding sheet edits that no baseline pins.''';

Future<void> main(List<String> args) async {
  final cli = CliArgs.parse(args, usage: _kUsage);
  final credentials = cli.options['credentials'] ?? 'credentials.json';
  requireFile(credentials, 'the service account shared on the sheet');
  try {
    await seedSheet(cli.config, credentials: credentials);
  } on FormatException catch (e) {
    fail('REFUSING: ${e.message}');
  }
}
