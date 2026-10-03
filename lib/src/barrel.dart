import 'dart:io';

/// Removes a bare `library;` directive from the generated localization barrel at [path].
///
/// `sheety_localization:generate` writes `library;` into the barrel on every pull, and the line's
/// lint set rejects a library directive that carries no doc comment and no annotation
/// (`unnecessary_library_directive`), so each pull landed a red analyze and was stripped by hand in
/// four apps (2026-09-20). A directive under a `///` doc or an `@` annotation is kept.
///
/// Returns whether the file changed. A missing file is not an error: an app may name its barrel
/// differently, and then there is nothing to strip.
bool stripBareLibraryDirective(String path) {
  final file = File(path);
  if (!file.existsSync()) return false;
  final lines = file.readAsLinesSync();
  final kept = <String>[];
  var changed = false;
  for (final line in lines) {
    final previous = kept.lastWhere((l) => l.trim().isNotEmpty, orElse: () => '').trim();
    final carried = previous.startsWith('///') || previous.startsWith('@');
    if (line.trim() == 'library;' && !carried) {
      changed = true;
      // The blank line the generator puts after it would double the one before it.
      continue;
    }
    kept.add(line);
  }
  if (!changed) return false;
  final collapsed = <String>[];
  for (final line in kept) {
    if (line.trim().isEmpty && collapsed.isNotEmpty && collapsed.last.trim().isEmpty) continue;
    collapsed.add(line);
  }
  file.writeAsStringSync('${collapsed.join('\n')}\n');
  return true;
}
