import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void dispose() {
    _credentialController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final credential = _credentialController.text.trim();
    if (credential.isEmpty) {
      setState(() {
        _error = 'رمز اصلی یا Recovery Key را وارد کنید.';
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
      final result = await widget.backupService.verifyBackup(
        credential: credential,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on BackupCancelledException {
      if (mounted) {
        setState(() => _error = 'انتخاب فایل لغو شد.');
      }
    } on BackupFormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'بررسی Backup ناموفق بود: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final credential = _credentialController.text.trim();
    if (credential.isEmpty) {
      setState(() {
        _error = 'برای Restore رمز اصلی یا Recovery Key را وارد کنید.';
        _result = null;
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بازیابی واقعی Vault'),
        content: const Text(
          'این عملیات اطلاعات فعلی Vault را با Backup انتخاب‌شده جایگزین می‌کند. '
          'اگر هر مرحله اعتبارسنجی شکست بخورد، Restore متوقف می‌شود و Vault فعلی حفظ می‌شود. ادامه می‌دهید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('بازیابی'),
          ),
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
      final result = await widget.backupService.restoreBackup(
        masterPassword: credential,
      );
      if (!mounted) return;

      setState(() => _result = result);

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('بازیابی با موفقیت تأیید شد'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Backup رمزگشایی، اعتبارسنجی، جایگزینی و پس از Restore دوباره بررسی شد.',
                ),
                const SizedBox(height: 16),
                Text('آیتم‌های درخت: ${result.treeItemCount}'),
                Text('رکوردها: ${result.rowCount}'),
                Text('فیلدها: ${result.fieldCount}'),
                Text('مقادیر: ${result.valueCount}'),
                const SizedBox(height: 12),
                const Text('یکپارچگی: موفق'),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('تأیید'),
            ),
          ],
        ),
      );
    } on BackupCancelledException {
      if (mounted) setState(() => _error = 'انتخاب فایل Backup لغو شد.');
    } on BackupFormatException catch (error) {
      if (mounted) {
        setState(() {
          _error = 'بازیابی انجام نشد:\n${error.message}';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'بازیابی انجام نشد:\n$error';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRecoveryKey() async {
    final recoveryKey = widget.backupService.lastRecoveryKey;
    if (recoveryKey == null || recoveryKey.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recovery Key'),
          content: const Text(
            'Recovery Key فعالی در این نشست وجود ندارد.\n\n'
            'Recovery Key فقط هنگام ساخت موفق Backup جدید تولید می‌شود.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('بستن'),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recovery Key'),
        content: SelectableText(
          recoveryKey,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: recoveryKey));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recovery Key کپی شد.')),
                );
              }
            },
            child: const Text('کپی'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بستن'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup و بازیابی امن')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'مرکز Backup / Restore',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'همین صفحه برای بررسی و بازیابی استفاده می‌شود. '
                    'بازیابی فقط پس از احراز هویت، اعتبارسنجی کامل و بررسی نهایی دیتابیس موفق اعلام می‌شود.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _credentialController,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'رمز اصلی یا Recovery Key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _verify,
                          icon: const Icon(Icons.verified_outlined),
                          label: const Text('بررسی'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _restore,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.restore_outlined),
                          label: const Text('بازیابی'),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Backup معتبر است',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('فرمت: v${_result!.formatVersion}'),
                    Text('اسکیما: v${_result!.schemaVersion}'),
                    Text('آیتم‌های درخت: ${_result!.treeItemCount}'),
                    Text('رکوردها: ${_result!.rowCount}'),
                    Text('فیلدها: ${_result!.fieldCount}'),
                    Text('مقادیر: ${_result!.valueCount}'),
                    const SizedBox(height: 8),
                    const Text('اعتبارسنجی یکپارچگی انجام شد.'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('مشاهده Recovery Key آخرین Backup'),
              subtitle: const Text(
                'این کلید خارج از فایل Backup نگهداری می‌شود. آن را در محل امن دیگری ذخیره کنید.',
              ),
              onTap: _showRecoveryKey,
            ),
          ),
        ],
      ),
    );
  }
}
