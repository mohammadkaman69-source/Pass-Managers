import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/biometric_service.dart';
import '../security/security_manager.dart';
import '../services/app_language.dart';
import '../services/backup_service.dart';
import 'backup_center_page.dart';
import 'home_page.dart';

class HomePageV4 extends StatefulWidget {
  const HomePageV4({super.key});

  @override
  State<HomePageV4> createState() => _HomePageV4State();
}

class _HomePageV4State extends State<HomePageV4> {
  final BackupService _backupService = BackupService();
  final BiometricService _biometricService = BiometricService();
  bool _busy = false;

  Future<String?> _askPassword(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AppStrings.mainPassword(context),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.cancel(context))),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) Navigator.pop(ctx, controller.text);
            },
            child: Text(AppStrings.continueText(context)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _createBackup() async {
    if (_busy) return;
    final password = await _askPassword(AppStrings.backupPasswordEncryption(context));
    if (password == null) return;
    final verified = await SecurityManager().unlock(password);
    if (!verified) {
      if (!mounted) return;
      _message(AppStrings.wrongPassword(context));
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await _backupService.createBackup(masterPassword: password);
      if (!mounted) return;
      _message(saved ? AppStrings.backupSaved(context) : AppStrings.backupCancelled(context));
      if (saved) await _showRecoveryKey();
    } catch (error) {
      if (!mounted) return;
      _message(AppStrings.backupCreateError(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.restoreBackup(context)),
        content: Text(AppStrings.restoreWarning(context)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.cancel(context))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.restore(context))),
        ],
      ),
    );
    if (confirmed != true) return;
    final password = await _askPassword(AppStrings.backupPassword(context));
    if (password == null) return;
    setState(() => _busy = true);
    try {
      final result = await _backupService.restoreBackup(masterPassword: password);
      if (!mounted) return;
      _message(AppStrings.restoreSuccess(context, result.treeItemCount, result.rowCount, result.valueCount));
    } on BackupCancelledException {
      if (!mounted) return;
      _message(AppStrings.restoreCancelled(context));
    } on BackupFormatException catch (error) {
      if (!mounted) return;
      _message('Restore: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      _message(AppStrings.backupRestoreError(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showRecoveryKey() async {
    final key = _backupService.lastRecoveryKey;
    if (key == null || key.isEmpty) {
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
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.recoveryKeyTitle(context)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.recoveryKeyDescription(context)),
              const SizedBox(height: 16),
              SelectableText(key, textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 0.8)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final copiedMessage = AppStrings.recoveryKeyCopied(context);
              await Clipboard.setData(ClipboardData(text: key));
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(copiedMessage)));
            },
            child: Text(AppStrings.copyKey(context)),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.recoveryKeySaved(context))),
        ],
      ),
    );
  }

  Future<void> _configureBiometric() async {
    final supported = await _biometricService.isSupported();
    if (!mounted) return;
    if (!supported) {
      _message(AppStrings.biometricUnavailable(context));
      return;
    }
    final enabled = await _biometricService.isEnabled();
    if (!mounted) return;
    if (enabled) {
      final disable = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.biometricSettings(context)),
          content: Text(AppStrings.biometricDisableQuestion(context)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.cancel(context))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.disable(context))),
          ],
        ),
      );
      if (disable == true) {
        await _biometricService.disable();
        if (mounted) _message(AppStrings.biometricDisabled(context));
      }
      return;
    }
    final enabledNow = await _biometricService.enable();
    if (!mounted) return;
    _message(enabledNow ? AppStrings.biometricEnabled(context) : AppStrings.biometricEnableFailed(context));
  }

  Future<void> _chooseLanguage() async {
    final current = AppLanguage.instance.locale.languageCode;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.selectLanguage(context)),
        content: RadioGroup<String>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) Navigator.pop(ctx, value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(value: 'fa', title: Text(AppStrings.persian(context))),
              RadioListTile<String>(value: 'en', title: Text(AppStrings.english(context))),
            ],
          ),
        ),
      ),
    );
    if (selected != null) await AppLanguage.instance.setLanguage(selected);
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.fingerprint), title: Text(AppStrings.biometricSettings(context)), onTap: () { Navigator.pop(ctx); _configureBiometric(); }),
            ListTile(leading: const Icon(Icons.backup_outlined), title: Text(AppStrings.createEncryptedBackup(context)), onTap: () { Navigator.pop(ctx); _createBackup(); }),
            ListTile(leading: const Icon(Icons.restore_outlined), title: Text(AppStrings.restoreBackup(context)), onTap: () { Navigator.pop(ctx); _restoreBackup(); }),
            ListTile(leading: const Icon(Icons.verified_outlined), title: Text(AppStrings.backupHealth(context)), subtitle: Text(AppStrings.backupHealthSub(context)), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => BackupCenterPage(backupService: _backupService))); }),
            ListTile(leading: const Icon(Icons.key_outlined), title: Text(AppStrings.recoveryKey(context)), onTap: () { Navigator.pop(ctx); _showRecoveryKey(); }),
            ListTile(leading: const Icon(Icons.language), title: Text(AppStrings.language(context)), onTap: () { Navigator.pop(ctx); _chooseLanguage(); }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const HomePage(),
        PositionedDirectional(
          top: MediaQuery.paddingOf(context).top,
          end: 0,
          child: SizedBox(
            width: 48,
            height: 56,
            child: IconButton(
              tooltip: AppStrings.settings(context),
              onPressed: _showMenu,
              icon: const Icon(Icons.more_vert),
            ),
          ),
        ),
        if (_busy)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black12,
                child: Center(child: Card(child: Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator()))),
              ),
            ),
          ),
      ],
    );
  }
}
