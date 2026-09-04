import 'dart:io';

import 'package:l10n_tool/src/config.dart';

/// Prints [message] and exits with status 2.
Never fail(String message) {
  stderr.writeln(message);
  exit(2);
}

/// The options every executable in this package shares.
final class CliArgs {
  const CliArgs._(this.config, this.flags, this.options);

  /// Parses `--config <path>`, `--key=value` options and bare `--flag`s.
  ///
  /// [usage] is printed on an unknown argument.
  factory CliArgs.parse(List<String> args, {required String usage, Set<String> flags = const <String>{}}) {
    var configPath = 'l10n_tool.json';
    final seenFlags = <String>{};
    final options = <String, String>{};

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--config') {
        if (i + 1 >= args.length) fail('--config needs a path\n$usage');
        configPath = args[++i];
      } else if (arg.startsWith('--config=')) {
        // Argument names are ASCII, so a code-unit substring is safe.
        // ignore: avoid-substring
        configPath = arg.substring('--config='.length);
      } else if (flags.contains(arg)) {
        seenFlags.add(arg);
      } else if (arg.startsWith('--') && arg.contains('=')) {
        final eq = arg.indexOf('=');
        // ignore: avoid-substring
        options[arg.substring(2, eq)] = arg.substring(eq + 1);
      } else {
        fail('unknown argument: $arg\n$usage');
      }
    }

    final L10nConfig config;
    try {
      config = L10nConfig.read(configPath);
    } on FileSystemException {
      fail('$configPath not found. Pass --config <file>; the README states the shape.');
    } on FormatException catch (e) {
      fail('$configPath: ${e.message}');
    }
    return CliArgs._(config, seenFlags, options);
  }

  /// The application's localization config.
  final L10nConfig config;

  /// Bare flags that were present.
  final Set<String> flags;

  /// `--key=value` options.
  final Map<String, String> options;

  /// Whether [flag] was passed.
  bool has(String flag) => flags.contains(flag);
}

/// Fails unless [path] exists.
void requireFile(String path, String what) {
  if (File(path).existsSync()) return;
  fail('$path is missing: $what');
}

/// Runs [executable] with [arguments], inheriting stdio, and exits on failure.
Future<void> run(String executable, List<String> arguments) async {
  stdout.writeln('* ${<String>[executable, ...arguments].join(' ')}');
  // `runInShell` because the Dart SDK on Windows is reached through a shim.
  final process = await Process.start(executable, arguments, mode: .inheritStdio, runInShell: true);
  final code = await process.exitCode;
  if (code != 0) exit(code);
}
