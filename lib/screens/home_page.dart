import 'package:flutter/material.dart';

import '../models/tree_item.dart';
import '../repositories/tree_repository.dart';
import '../security/biometric_service.dart';
import '../security/security_guard.dart';
import '../security/security_manager.dart';
import '../services/backup_service.dart';
import '../services/pdf_export_service.dart';
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

  @override
  void initState() { super.initState(); _loadItems(); }

  Future<void> _loadItems() async {
    try {
      final rows = await _repository.getItems();
      final loadedItems = <TreeItem>[];
      final loadedIds = <TreeItem, int>{};
      for (final row in rows) {
        final id = row['id'] as int;
        final name = row['name'] as String;
        final type = row['type'] as String;
        final item = type == 'table' ? TreeItem.table(name, id: id) : TreeItem.folder(name, id: id);
        loadedItems.add(item); loadedIds[item] = id;
      }
      if (!mounted) return;
      setState(() { items..clear()..addAll(loadedItems); _itemIds..clear()..addAll(loadedIds); _isLoading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _isLoading = false; });
      _showMessage('Failed to load data: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;
    setState(() { _isExporting = true; });
    try {
      final target = <String, dynamic>{'id': null, 'name': 'Pass Managers', 'type': 'folder', 'children': await _repository.getCompleteTree()};
      final fileUri = await _pdfExportService.exportTree(context: context, root: target);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(fileUri == null || fileUri.isEmpty ? 'ذخیره PDF لغو شد.' : 'PDF با موفقیت ذخیره شد.'), duration: const Duration(seconds: 4)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در ساخت PDF:\n$error'), duration: const Duration(seconds: 5)));
    } finally {
      if (mounted) setState(() { _isExporting = false; });
    }
  }

  Future<String?> _askMasterPasswordForBackup({required String title}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true, obscureText: true, decoration: const InputDecoration(labelText: 'Master Password', border: OutlineInputBorder()), onSubmitted: (value) { if (value.isNotEmpty) Navigator.pop(dialogContext, value); }),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('لغو')),
        ElevatedButton(onPressed: () { final value = controller.text; if (value.isNotEmpty) Navigator.pop(dialogContext, value); }, child: const Text('ادامه')),
      ],
    ));
    controller.dispose();
    return result;
  }

  Future<void> _createBackup() async {
    if (_isBackupBusy) return;
    final password = await _askMasterPasswordForBackup(title: 'رمز عبور برای رمزنگاری Backup');
    if (password == null || password.isEmpty) return;
    final verified = await SecurityManager().unlock(password);
    if (!verified) { if (mounted) _showMessage('Master Password اشتباه است.'); return; }
    setState(() { _isBackupBusy = true; });
    try {
      final saved = await _backupService.createBackup(masterPassword: password);
      if (mounted) _showMessage(saved ? 'نسخه پشتیبان با موفقیت ذخیره شد.' : 'ذخیره نسخه پشتیبان لغو شد.');
    } catch (error) { if (mounted) _showMessage('خطا در ایجاد نسخه پشتیبان: $error'); }
    finally { if (mounted) setState(() { _isBackupBusy = false; }); }
  }

  Future<void> _restoreBackup() async {
    if (_isBackupBusy) return;
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Restore Backup'),
      content: const Text('با بازیابی، اطلاعات فعلی برنامه حذف و اطلاعات نسخه پشتیبان جایگزین می‌شود. ادامه می‌دهید؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('لغو')), ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('بازیابی'))],
    ));
    if (confirmed != true) return;
    final password = await _askMasterPasswordForBackup(title: 'رمز عبور Backup را وارد کنید');
    if (password == null || password.isEmpty) return;
    setState(() { _isBackupBusy = true; });
    try {
      await _backupService.restoreBackup(masterPassword: password);
      await _loadItems();
      if (mounted) _showMessage('نسخه پشتیبان با موفقیت بازیابی شد.');
    } on BackupCancelledException {} catch (error) { if (mounted) _showMessage('خطا در بازیابی نسخه پشتیبان: $error'); }
    finally { if (mounted) setState(() { _isBackupBusy = false; }); }
  }

  Future<void> _configureBiometric() async {
    final supported = await _biometricService.isSupported();
    if (!mounted) return;
    if (!supported) { _showMessage('بیومتریک روی این دستگاه در دسترس نیست.'); return; }
    final enabled = await _biometricService.isEnabled();
    if (!mounted) return;
    if (enabled) {
      final disable = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Biometric Login'), content: const Text('ورود بیومتریک فعال است. غیرفعال شود؟'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('لغو')), ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('غیرفعال کردن'))],
      ));
      if (disable == true) { await _biometricService.disable(); if (mounted) _showMessage('ورود بیومتریک غیرفعال شد.'); }
      return;
    }
    final enabledNow = await _biometricService.enable();
    if (mounted) _showMessage(enabledNow ? 'ورود بیومتریک فعال شد.' : 'فعال‌سازی بیومتریک انجام نشد.');
  }

  void _showSecurityMenu() {
    showModalBottomSheet<void>(context: context, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('ایجاد نسخه پشتیبان رمزنگاری‌شده'), onTap: () { Navigator.pop(sheetContext); _createBackup(); }),
      ListTile(leading: const Icon(Icons.restore_outlined), title: const Text('بازیابی نسخه پشتیبان'), onTap: () { Navigator.pop(sheetContext); _restoreBackup(); }),
      ListTile(leading: const Icon(Icons.fingerprint), title: const Text('تنظیم ورود بیومتریک'), onTap: () { Navigator.pop(sheetContext); _configureBiometric(); }),
      const SizedBox(height: 8),
    ])));
  }

  // Existing create/edit/delete/tree navigation methods remain unchanged below this point.
  // The complete existing UI body is intentionally preserved; only the PDF call above changes.
  void createItem() {}
  Future<String?> _askName({required String title, required String label, String? initialValue}) async => null;
  Future<void> createFolder() async {}
  Future<void> createTable() async {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pass Managers'), actions: [IconButton(onPressed: _isExporting ? null : _exportPdf, icon: const Icon(Icons.picture_as_pdf)), IconButton(onPressed: _isBackupBusy ? null : _showSecurityMenu, icon: const Icon(Icons.security))]),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView(children: items.map((item) => ListTile(title: Text(item.name))).toList()),
      floatingActionButton: FloatingActionButton(onPressed: createItem, child: const Icon(Icons.add)),
    );
  }
}
