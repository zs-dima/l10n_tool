import 'dart:io';

import 'package:l10n_tool/l10n_tool.dart';
import 'package:test/test.dart';

/// The generator re-emits a bare `library;` into the barrel on every pull; the line's lints reject it.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('barrel_'));
  tearDown(() => dir.deleteSync(recursive: true));

  String write(String source) {
    final file = File('${dir.path}/localization.dart')..writeAsStringSync(source);
    return file.path;
  }

  test('a bare directive is removed, and the rest is left as written', () {
    final path = write(
      "// This file is generated, do not edit it manually!\nlibrary;\n\nexport 'src/a.dart';\n",
    );

    expect(stripBareLibraryDirective(path), isTrue);
    expect(
      File(path).readAsStringSync(),
      equals("// This file is generated, do not edit it manually!\n\nexport 'src/a.dart';\n"),
    );
  });

  test('a directive under a doc comment or an annotation is kept', () {
    final documented = write("/// The catalog.\nlibrary;\n\nexport 'src/a.dart';\n");
    expect(stripBareLibraryDirective(documented), isFalse);

    final annotated = write("@internal\nlibrary;\n\nexport 'src/a.dart';\n");
    expect(stripBareLibraryDirective(annotated), isFalse);
  });

  test('a barrel without one, or no barrel at all, is left alone', () {
    expect(stripBareLibraryDirective(write("export 'src/a.dart';\n")), isFalse);
    expect(stripBareLibraryDirective('${dir.path}/absent.dart'), isFalse);
  });
}
