# Pass-Managers Recovery Baseline

## Purpose
This file records the exact recovery point before the file-picker API repair so repeated CI failures never force us to guess where to restart.

## Recovery point
- Branch: `main`
- Commit before this repair: `a4cdda339e1e6ebd48f5c80c27e8ed00cc5e5eaf`
- Recovery branch: `recovery/pre-file-picker-fix-2026-08-14`
- Stable reference branch: `stable-v1` — DO NOT MODIFY

## Protected areas
- `android/`: do not modify for this Windows/file-picker repair.
- `stable-v1`: read-only reference; never commit, merge, or push changes to it.
- `pubspec.yaml`: keep `file_picker: ^8.3.7` unless a separate, explicitly approved dependency migration is planned.
- Android native backup/PDF MethodChannel paths must remain unchanged.

## Known failure chain
The failed combined Android/Windows run reached `flutter analyze` and reported `file_picker` API mismatches in:
- `lib/services/backup_service.dart`
- `lib/services/pdf_export_service.dart`

The dependency actually resolved by the project is `file_picker 8.3.7`. Recent edits accidentally used newer static APIs (`FilePicker.saveFile`, `FilePicker.pickFiles`, `readAsBytes`) that do not match this dependency.

## Intended repair
Use the API that matches `file_picker 8.3.7`:
- `FilePicker.platform.saveFile(...)`
- `FilePicker.platform.pickFiles(..., withData: true)`
- `PlatformFile.bytes`

Do not change the Android native branch of these services.

## Recovery rule
If subsequent CI changes produce repeated or unrelated failures, stop. Restore/compare against `recovery/pre-file-picker-fix-2026-08-14` and this document before making another change.

## Validation order
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test` / explicit no-test handling
4. Windows build
5. Combined Android + Windows workflow
6. If both are green, create a protected green baseline branch before further work.
