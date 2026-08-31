import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_language.dart';
import 'package:flutter/services.dart';

import '../models/tree_item.dart';
import '../repositories/tree_repository.dart';
import '../security/biometric_service.dart';
import '../security/security_guard.dart';
import '../security/security_manager.dart';
import '../services/backup_service.dart';
import '../services/pdf_export_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_search_bar.dart';
import '../services/search_service.dart';
import 'backup_center_page.dart';
import 'table_page.dart';
import 'tree_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TreeRepository _repository = TreeRepository();
  final List<TreeItem> items = <TreeItem>[];
  final Map<TreeItem, int> _itemIds = <TreeItem, int>{};
  final PdfExportService _pdfExportService = PdfExportService();
  final BackupService _backupService = BackupService();
  final BiometricService _biometricService = BiometricService();

  bool _isLoading = true;
  bool _isExporting = false;
  bool _isBackupBusy = false;

  DateTime? _lastBackPress;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  void _handleExitRequest() {
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) <= const Duration(seconds: 2)) {
      _exitTimer?.cancel();
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.exit(context)),
        content: Text(AppStrings.exitHint(context)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _lastBackPress = null;
            },
            child: Text(AppStrings.cancel(context)),
          ),
          ElevatedButton(
            onPressed: () => SystemNavigator.pop(),
            child: Text(AppStrings.exit(context)),
          ),
        ],
      ),
    );
    _exitTimer?.cancel();
    _exitTimer = Timer(const Duration(seconds: 2), () {
      _lastBackPress = null;
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    });
  }

  Future<void> _loadItems() async {
    try {
      final rows = await _repository.getItems();
      final loadedItems = <TreeItem>[];
      final loadedIds = <TreeItem, int>{};
      for (final row in rows) {
        final id = row['id'] as int;
        final name = row['name'] as String;
        final type = row['type'] as String;
        final item = type == 'table'
            ? TreeItem.table(name, id: id)
            : TreeItem.folder(name, id: id);
        loadedItems.add(item);
        loadedIds[item] = id;
      }
      if (!mounted) return;
      setState(() {
        items..clear()..addAll(loadedItems);
        _itemIds..clear()..addAll(loadedIds);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(AppStrings.loadDataFailed(context, error));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final children = await _repository.getCompleteTree();
      if (!mounted) return;
      final target = <String, dynamic>{
        'id': null,
        'name': 'NexVault',
        'type': 'folder',
        'children': children,
      };
      final fileUri = await _pdfExportService.exportTree(context: context, root: target);
      if (!mounted) return;
      _showMessage(
        fileUri == null || fileUri.isEmpty
            ? AppStrings.pdfCancelled(context)
            : AppStrings.pdfSaved(context),
      );
    } catch (error) {
      _showMessage(AppStrings.pdfError(context, error));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<String?> _askMasterPasswordForBackup({required String title}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppStrings.cancel(context)),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text;
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
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
    if (_isBackupBusy) return;
    final password = await _askMasterPasswordForBackup(
      title: AppStrings.backupPasswordEncryption(context),
    );
    if (password == null || password.isEmpty) return;
    final verified = await SecurityManager().unlock(password);
    if (!verified) {
      _showMessage(AppStrings.wrongPassword(context));
      return;
    }
    if (!mounted) return;
    setState(() => _isBackupBusy = true);
    try {
      final saved = await _backupService.createBackup(masterPassword: password);
      if (!mounted) return;
      _showMessage(
        saved ? AppStrings.backupSaved(context) : AppStrings.backupCancelled(context),
      );
      if (saved) await _showRecoveryKeyAfterBackup();
    } catch (error) {
      _showMessage(AppStrings.backupCreateError(context, error));
    } finally {
      if (mounted) setState(() => _isBackupBusy = false);
    }
  }

  Future<void> _showRecoveryKeyAfterBackup() async {
    final recoveryKey = _backupService.lastRecoveryKey;
    if (recoveryKey == null || recoveryKey.isEmpty || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.recoveryKeyTitle(context)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(AppStrings.recoveryKeyDescription(context)),
              const SizedBox(height: 16),
              SelectableText(
                recoveryKey,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 15,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: recoveryKey));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(AppStrings.recoveryKeyCopied(context))),
                );
              }
            },
            child: Text(AppStrings.copyKey(context)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppStrings.recoveryKeySaved(context)),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup() async {
    if (_isBackupBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.restoreBackup(context)),
        content: Text(AppStrings.restoreWarning(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.cancel(context)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppStrings.restore(context)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final password = await _askMasterPasswordForBackup(
      title: AppStrings.backupPassword(context),
    );
    if (password == null || password.isEmpty) return;
    setState(() => _isBackupBusy = true);
    try {
      final result = await _backupService.restoreBackup(masterPassword: password);
      await _loadItems();
      if (!mounted) return;
      _showMessage(
        AppStrings.restoreSuccess(
          context,
          result.treeItemCount,
          result.rowCount,
          result.valueCount,
        ),
      );
    } on BackupCancelledException {
      _showMessage(AppStrings.restoreCancelled(context));
    } on BackupFormatException catch (error) {
      _showMessage(AppStrings.backupRestoreError(context, error.message));
    } catch (error) {
      _showMessage(AppStrings.backupRestoreError(context, error));
    } finally {
      if (mounted) setState(() => _isBackupBusy = false);
    }
  }

  void _openBackupCenter() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BackupCenterPage(backupService: _backupService),
      ),
    );
  }

  Future<void> _showRecoveryKeyFromMenu() async {
    final recoveryKey = _backupService.lastRecoveryKey;
    if (recoveryKey == null || recoveryKey.isEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Recovery Key'),
          content: Text(AppStrings.noActiveRecoveryKey(context)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.close(context)),
            ),
          ],
        ),
      );
      return;
    }
    await _showRecoveryKeyAfterBackup();
  }

  Future<void> _configureBiometric() async {
    final supported = await _biometricService.isSupported();
    if (!mounted) return;
    if (!supported) {
      _showMessage(AppStrings.biometricUnavailable(context));
      return;
    }
    final enabled = await _biometricService.isEnabled();
    if (!mounted) return;
    if (enabled) {
      final disable = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(AppStrings.biometricLogin(context)),
          content: Text(AppStrings.biometricDisableQuestion(context)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(AppStrings.cancel(context)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(AppStrings.disable(context)),
            ),
          ],
        ),
      );
      if (disable == true) {
        await _biometricService.disable();
        if (mounted) _showMessage(AppStrings.biometricDisabled(context));
      }
      return;
    }
    final enabledNow = await _biometricService.enable();
    if (!mounted) return;
    _showMessage(
      enabledNow
          ? AppStrings.biometricEnabled(context)
          : AppStrings.biometricEnableFailed(context),
    );
  }

  Future<void> _chooseLanguage() async {
    final current = AppLanguage.instance.locale.languageCode;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.selectLanguage(ctx)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text(AppStrings.persian(ctx)),
              value: 'fa',
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
            RadioListTile<String>(
              title: Text(AppStrings.english(ctx)),
              value: 'en',
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await AppLanguage.instance.setLanguage(selected);
      if (mounted) setState(() {});
    }
  }

  void _showSecurityMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: Text(AppStrings.createEncryptedBackup(context)),
              onTap: () {
                Navigator.pop(sheetContext);
                _createBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: Text(AppStrings.restoreBackup(context)),
              onTap: () {
                Navigator.pop(sheetContext);
                _restoreBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: Text(AppStrings.backupHealth(context)),
              subtitle: Text(AppStrings.backupHealthSub(context)),
              onTap: () {
                Navigator.pop(sheetContext);
                _openBackupCenter();
              },
            ),
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: Text(AppStrings.recoveryKey(context)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRecoveryKeyFromMenu();
              },
            ),
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: Text(AppStrings.biometricSettings(context)),
              onTap: () {
                Navigator.pop(sheetContext);
                _configureBiometric();
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(AppStrings.language(context)),
              onTap: () {
                Navigator.pop(sheetContext);
                _chooseLanguage();
              },
            ),
          ],
        ),
      ),
    );
  }

  void createItem() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(AppStrings.createFolder(context)),
              onTap: () {
                Navigator.pop(sheetContext);
                createFolder();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text(AppStrings.createTable(context)),
              onTap: () {
                Navigator.pop(sheetContext);
                createTable();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askName({
    required String title,
    required String label,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppStrings.cancel(context)),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: Text(AppStrings.save(context)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> createFolder() async {
    final name = await _askName(
      title: AppStrings.createFolder(context),
      label: AppStrings.folderName(context),
    );
    if (name == null) return;
    final id = await _repository.createFolder(name: name);
    final item = TreeItem.folder(name, id: id);
    setState(() {
      items.add(item);
      _itemIds[item] = id;
    });
  }

  Future<void> createTable() async {
    final name = await _askName(
      title: AppStrings.createTable(context),
      label: AppStrings.tableName(context),
    );
    if (name == null) return;
    final id = await _repository.createTable(name: name);
    final item = TreeItem.table(name, id: id);
    setState(() {
      items.add(item);
      _itemIds[item] = id;
    });
  }

  Future<void> _onSearchHit(SearchHit hit) async {
    if (hit.kind == SearchHitKind.folder) {
      final item = TreeItem.folder(hit.title, id: hit.itemId);
      _itemIds[item] = hit.itemId;
      openItem(item);
      return;
    }
    final item = TreeItem.table(hit.title, id: hit.itemId);
    _itemIds[item] = hit.itemId;
    openItem(item);
  }

  void openItem(TreeItem item) {
    final id = _itemIds[item];
    if (id == null) return;
    if (item.type == TreeItemType.table) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TablePage(
            table: item,
            tableId: id,
            onDelete: () {
              setState(() {
                items.remove(item);
                _itemIds.remove(item);
              });
            },
            onRenamed: (name) {
              setState(() => item.name = name);
            },
          ),
        ),
      ).then((_) async {
        if (mounted) await _loadItems();
      });
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TreePage(
          item: item,
          itemId: id,
          onDelete: () async {
            await _repository.deleteItem(id);
            if (!mounted) return;
            setState(() {
              items.remove(item);
              _itemIds.remove(item);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SecurityGuard(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleExitRequest();
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLogo.small(height: 26),
                SizedBox(width: 10),
                Text('NexVault'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: AppStrings.settings(context),
                onPressed: _showSecurityMenu,
                icon: const Icon(Icons.more_vert),
              ),
              IconButton(
                tooltip: AppStrings.pdfExport(context),
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              AppSearchBar(onHitSelected: _onSearchHit),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AppLogo(height: 72),
                                const SizedBox(height: 16),
                                Text(
                                  AppStrings.noItems(context),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Card(
                                child: ListTile(
                                  title: Text(item.name),
                                  leading: Icon(
                                    item.type == TreeItemType.table
                                        ? Icons.table_chart
                                        : Icons.folder,
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => openItem(item),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: createItem,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
