import 'dart:convert';
import 'dart:io';

/// Messages of one ARB file, key to text.
typedef ArbMessages = Map<String, String>;

/// `@key` metadata of one ARB file, key (without the sigil) to its block.
typedef ArbMeta = Map<String, Map<String, Object?>>;

/// An ARB file split into its messages and their metadata. `@@` directives are dropped.
typedef Arb = ({ArbMessages messages, ArbMeta meta});

/// Parses ARB [json] into messages and metadata.
Arb parseArb(Map<String, Object?> json) {
  final messages = <String, String>{};
  final meta = <String, Map<String, Object?>>{};
  for (final MapEntry(:key, :value) in json.entries) {
    if (key.startsWith('@@')) continue;
    if (key.startsWith('@')) {
      // ARB keys are ASCII identifiers; dropping the sigil is unit-safe.
      // ignore: avoid-substring
      if (value is Map<String, Object?>) meta[key.substring(1)] = value;
    } else if (value is String) {
      messages[key] = value;
    }
  }
  return (messages: messages, meta: meta);
}

/// Reads and parses the ARB at [path]. A missing file reads as empty.
Arb readArb(String path) {
  final file = File(path);
  if (!file.existsSync()) return (messages: <String, String>{}, meta: <String, Map<String, Object?>>{});
  return parseArb(jsonDecode(file.readAsStringSync()) as Map<String, Object?>);
}

/// The ICU placeholder names in [message]: `{name}` and `{name, type…}`.
///
/// `\w` is ASCII, so a plural branch whose body opens with a word and a comma
/// (`=0{Notifications, …}`) reads as a placeholder: write each branch to start with the
/// placeholder itself.
Set<String> placeholderNames(String message) => _placeholder.allMatches(message).map((m) => m.group(1)!).toSet();

final RegExp _placeholder = RegExp(r'\{(\w+)[,}]');
