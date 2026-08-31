import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_language.dart';
import '../services/backup_service.dart';

class BackupCenterPage extends StatefulWidget {
  const BackupCenterPage({super.key, required this.backupService});

  final BackupService backupService;

  @override
  State<BackupCenterPage> createState() => _BackupCenterPageState();
}

class _BackupCenterPageState extends State<BackupCenterPage> {
  final _credentialController = TextEditingController();
  bool _busy = false;
  BackupVerificationResult? _result;
  String? _error;

  bool get _fa => AppStrings.fa(context);

  String _t(String fa, String en) => _fa ? fa : en;

  @override
  void dispose() {
    _credentialController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final credential = _credentialController.text.trim();
    if (credential.isEmpty) {
      setState(() {
        _error = _t('رمز اصلی یا Recovery Key را وارد کنید.', 'Enter the master password or Recovery Key.');
        _result = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await widget.backupService.verifyBackup(credential: credential);
      if (!mounted) return;
      setState(() => _result = result);
    } on BackupCancelledException {
      if (!mounted) return;
      setState(() => _error = _t('انتخاب فایل لغو شد.', 'File selection was cancelled.'));
    } on BackupFormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _t('بررسی Backup ناموفق بود: $error', 'Backup verification failed: $error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final credential = _credentialController.text.trim();
    if (credential.isEmpty) {
      setState(() {
        _error = _t('برای Restore رمز اصلی یا Recovery Key را وارد کنید.', 'Enter the master password or Recovery Key to restore.');
        _result = null;
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('بازیابی واقعی Vault', 'Restore Vault')),
        content: Text(_t(
          'این عملیات اطلاعات فعلی Vault را با Backup انتخاب‌شده جایگزین می‌کند. اگر هر مرحله اعتبارسنجی شکست بخورد، Restore متوقف می‌شود و Vault فعلی حفظ می‌شود. ادامه می‌دهید؟',
          'This operation replaces the current Vault data with the selected Backup. If any validation step fails, Restore stops and the current Vault is preserved. Continue?',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(AppStrings.cancel(context))),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(AppStrings.restore(context))),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await widget.backupService.restoreBackup(masterPassword: credential);
      if (!mounted) return;
      setState(() => _result = result);

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_t('بازیابی با موفقیت تأیید شد', 'Restore verified successfully')),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_t('Backup رمزگشایی، اعتبارسنجی، جایگزینی و پس از Restore دوباره بررسی شد.', 'The Backup was decrypted, validated, restored, and verified again after Restore.')),
                const SizedBox(height: 16),
                Text('${_t('آیتم‌های درخت', 'Tree items')}: ${result.treeItemCount}'),
                Text('${_t('رکوردها', 'Records')}: ${result.rowCount}'),
                Text('${_t('فیلدها', 'Fields')}: ${result.fieldCount}'),
                Text('${_t('مقادیر', 'Values')}: ${result.valueCount}'),
                const SizedBox(height: 12),
                Text(_t('یکپارچگی: موفق', 'Integrity: successful')),
              ],
            ),
          ),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(dialogContext), child: Text(_t('تأیید', 'OK')))],
        ),
      );
    } on BackupCancelledException {
      if (mounted) setState(() => _error = _t('انتخاب فایل Backup لغو شد.', 'Backup file selection was cancelled.'));
    } on BackupFormatException catch (error) {
      if (mounted) setState(() => _error = '${_t('بازیابی انجام نشد', 'Restore failed')}:\n${error.message}');
    } catch (error) {
      if (mounted) setState(() => _error = '${_t('بازیابی انجام نشد', 'Restore failed')}:\n$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRecoveryKey() async {
    final recoveryKey = widget.backupService.lastRecoveryKey;
    if (recoveryKey == null || recoveryKey.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.recoveryKey(context)),
          content: Text(AppStrings.noActiveRecoveryKey(context)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.close(context)))],
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.recoveryKey(context)),
        content: SelectableText(recoveryKey, textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'monospace', fontSize: 16, letterSpacing: 1.1)),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: recoveryKey));
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppStrings.recoveryKeyCopied(context))));
            },
            child: Text(AppStrings.copy(context)),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.close(context))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('Backup و بازیابی امن', 'Secure Backup & Restore'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_t('مرکز Backup / Restore', 'Backup / Restore Center'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_t('همین صفحه برای بررسی و بازیابی استفاده می‌شود. بازیابی فقط پس از احراز هویت، اعتبارسنجی کامل و بررسی نهایی دیتابیس موفق اعلام می‌شود.', 'This page is used for verification and restore. A restore is reported successful only after authentication, full validation, and final database verification.')),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _credentialController,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: _t('رمز اصلی یا Recovery Key', 'Master Password or Recovery Key'), border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _verify, icon: const Icon(Icons.verified_outlined), label: Text(AppStrings.verify(context)))),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton.icon(onPressed: _busy ? null : _restore, icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.restore_outlined), label: Text(AppStrings.restore(context)))),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(_t('Backup معتبر است', 'Backup is valid'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Format: v${_result!.formatVersion}'),
                    Text('Schema: v${_result!.schemaVersion}'),
                    Text('${_t('آیتم‌های درخت', 'Tree items')}: ${_result!.treeItemCount}'),
                    Text('${_t('رکوردها', 'Records')}: ${_result!.rowCount}'),
                    Text('${_t('فیلدها', 'Fields')}: ${_result!.fieldCount}'),
                    Text('${_t('مقادیر', 'Values')}: ${_result!.valueCount}'),
                    const SizedBox(height: 8),
                    Text(_t('اعتبارسنجی یکپارچگی انجام شد.', 'Integrity validation completed.')),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.key_outlined),
              title: Text(_t('مشاهده Recovery Key آخرین Backup', 'View Recovery Key of latest Backup')),
              subtitle: Text(_t('این کلید خارج از فایل Backup نگهداری می‌شود. آن را در محل امن دیگری ذخیره کنید.', 'This key is kept outside the Backup file. Store it securely somewhere else.')),
              onTap: _showRecoveryKey,
            ),
          ),
        ],
      ),
    );
  }
}
