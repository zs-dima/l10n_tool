import 'dart:io';

import 'package:l10n_tool/l10n_tool.dart';
import 'package:l10n_tool/src/cli.dart';

const _kUsage = '''
usage: dart run l10n_tool:verify [--config <file>]

Proves the baseline -> sheet -> ARB round trip lost nothing. Exits 1 on any loss.''';

void main(List<String> args) {
  final cli = CliArgs.parse(args, usage: _kUsage);
  final problems = verifyRoundTrip(cli.config);
  if (problems.isEmpty) return;
  stderr.writeln('\nROUND-TRIP FAILURES (${problems.length}):');
  problems.forEach(stderr.writeln);
  exit(1);
}
