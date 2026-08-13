# Pass Managers

Pass Managers is a local-first password/vault manager built with Flutter.

## Current security and data features

- Master Password protected vault.
- Argon2id key derivation and AES-256-GCM encryption for field values.
- Automatic app locking when the application leaves the foreground.
- Optional biometric unlock on supported Android devices.
- Encrypted portable backup (`.pmb`) protected by the Master Password.
- Restore from encrypted backup with confirmation before replacing the current vault.
- PDF export from the Home page and individual tree pages.
- PDF export includes password values as requested; treat exported PDFs as sensitive plaintext copies.
- Android Storage Access Framework is used for PDF destination selection.

## Important

The Master Password is not stored as plaintext. Biometric unlock stores the current vault key in Android secure storage and requires successful device authentication before using it; disabling biometric removes that stored key.

Backup files are encrypted with a backup-specific salt and the Master Password, so they can be restored on another installation when the same Master Password is supplied.
