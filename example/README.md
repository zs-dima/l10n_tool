# Example

`packages/localization/l10n_tool.json`:

```json
{
  "sheetId": "1n9P-…",
  "locales": ["en", "ru"],
  "buckets": ["app", "errors", "settings"],
  "factualLabels": ["lang", "langEn", "localeTag", "localeCode"]
}
```

`packages/localization/pubspec.yaml`:

```yaml
dev_dependencies:
  l10n_tool:
    git:
      url: https://github.com/zs-dima/l10n_tool.git
      ref: v0.1.0
```

From `packages/localization`, with `credentials.json` beside the config:

```sh
dart run l10n_tool:seed_sheet          # once: authored catalog -> sheet
dart run l10n_tool:generate            # sheet -> ARBs + Dart, then the round-trip check
dart run l10n_tool:verify              # the check alone
```

`test/l10n_consistency_test.dart`:

```dart
import 'package:l10n_tool/l10n_tool.dart';
import 'package:l10n_tool/testing.dart';
import 'package:localization/localization.dart';

void main() => l10nConsistencyTests(
  L10nConfig.read('l10n_tool.json'),
  generatedLocales: Locales.values.map((l) => l.languageCode).toSet(),
);
```
