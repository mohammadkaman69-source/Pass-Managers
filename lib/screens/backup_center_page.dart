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
                    'Verify Backup',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'یک فایل Backup را انتخاب کنید. بررسی فقط فایل را اعتبارسنجی می‌کند و دیتابیس فعلی را تغییر نمی‌دهد.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _credentialController,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'Master Password یا Recovery Key',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _verify,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_outlined),
                    label: const Text('انتخاب و بررسی Backup'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                    Text('Format: v${_result!.formatVersion}'),
                    Text('Schema: v${_result!.schemaVersion}'),
                    Text('Tree Items: ${_result!.treeItemCount}'),
                    Text('Records: ${_result!.rowCount}'),
                    Text('Fields: ${_result!.fieldCount}'),
                    Text('Values: ${_result!.valueCount}'),
                    const SizedBox(height: 8),
                    const Text('این بررسی هیچ تغییری در Vault فعلی ایجاد نکرد.'),
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
