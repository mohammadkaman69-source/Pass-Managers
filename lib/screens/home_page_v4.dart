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
    final mainPasswordLabel = AppStrings.mainPassword(context);
    final cancelLabel = AppStrings.cancel(context);
    final continueLabel = AppStrings.continueText(context);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: mainPasswordLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(cancelLabel)),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) Navigator.pop(ctx, controller.text);
            },
            child: Text(continueLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _createBackup() async {
    if (_busy) return;
    final title = AppStrings.backupPasswordEncryption(context);
    final password = await _askPassword(title);
    if (password == null) return;
    final verified = await SecurityManager().unlock(password);
    if (!mounted) return;
    if (!verified) {
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
    final restoreTitle = AppStrings.restoreBackup(context);
    final restoreWarning = AppStrings.restoreWarning(context);
    final cancelLabel = AppStrings.cancel(context);
    final restoreLabel = AppStrings.restore(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(restoreTitle),
        content: Text(restoreWarning),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(restoreLabel)),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final passwordLabel = AppStrings.backupPassword(context);
    final password = await _askPassword(passwordLabel);
    if (!mounted || password == null) return;
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
      _message(AppStrings.backupRestoreError(context, error));
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
      if (!mounted) return;
      final title = AppStrings.recoveryKey(context);
      final message = AppStrings.noActiveRecoveryKey(context);
      final closeLabel = AppStrings.close(context);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(closeLabel))],
        ),
      );
      return;
    }
    if (!mounted) return;
    final title = AppStrings.recoveryKeyTitle(context);
    final description = AppStrings.recoveryKeyDescription(context);
    final copyLabel = AppStrings.copyKey(context);
    final savedLabel = AppStrings.recoveryKeySaved(context);
    final copiedMessage = AppStrings.recoveryKeyCopied(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(description),
              const SizedBox(height: 16),
              SelectableText(key, textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 0.8)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: key));
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(copiedMessage)));
            },
            child: Text(copyLabel),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: Text(savedLabel)),
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
      final title = AppStrings.biometricSettings(context);
      final question = AppStrings.biometricDisableQuestion(context);
      final cancelLabel = AppStrings.cancel(context);
      final disableLabel = AppStrings.disable(context);
      final disable = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(question),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(disableLabel)),
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
    final title = AppStrings.selectLanguage(context);
    final faLabel = AppStrings.persian(context);
    final enLabel = AppStrings.english(context);
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: RadioGroup<String>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) Navigator.pop(ctx, value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(value: 'fa', title: Text(faLabel)),
              RadioListTile<String>(value: 'en', title: Text(enLabel)),
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
