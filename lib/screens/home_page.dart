// بخش 1/3

import 'dart:async';
import 'package:flutter/material.dart';
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
        title: const Text('خروج'),
        content: const Text(
          'برای خروج دوباره دکمه Back را فشار دهید.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _lastBackPress = null;
            },
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              SystemNavigator.pop();
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    _exitTimer?.cancel();

    _exitTimer = Timer(
      const Duration(seconds: 2),
      () {
        _lastBackPress = null;

        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
    );
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
        items
          ..clear()
          ..addAll(loadedItems);

        _itemIds
          ..clear()
          ..addAll(loadedIds);

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('بارگذاری داده‌ها ناموفق بود: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _exportPdf() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final children = await _repository.getCompleteTree();

      if (!mounted) return;

      final target = <String, dynamic>{
        'id': null,
        'name': 'NexVault',
        'type': 'folder',
        'children': children,
      };

      final fileUri = await _pdfExportService.exportTree(
        context: context,
        root: target,
      );

      if (!mounted) return;

      _showMessage(
        fileUri == null || fileUri.isEmpty
            ? 'ذخیره PDF لغو شد.'
            : 'PDF با موفقیت ذخیره شد.',
      );
    } catch (error) {
      _showMessage('خطا در ساخت PDF:\n$error');
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<String?> _askMasterPasswordForBackup({
    required String title,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'رمز اصلی',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('لغو'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text;
              if (value.isNotEmpty) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('ادامه'),
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
      title: 'رمز عبور برای رمزنگاری Backup',
    );

    if (password == null || password.isEmpty) return;

    final verified = await SecurityManager().unlock(password);

    if (!verified) {
      _showMessage('رمز اصلی اشتباه است.');
      return;
    }

    setState(() {
      _isBackupBusy = true;
    });

    try {
      final saved = await _backupService.createBackup(
        masterPassword: password,
        context: context,
      );

      if (!mounted) return;

      _showMessage(
        saved
            ? 'نسخه پشتیبان با موفقیت ذخیره شد.'
            : 'ذخیره نسخه پشتیبان لغو شد.',
      );
    } catch (error) {
      _showMessage('خطا در ایجاد نسخه پشتیبان: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBackupBusy = false;
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    if (_isBackupBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بازیابی نسخه پشتیبان'),
        content: const Text(
          'با بازیابی، اطلاعات فعلی برنامه حذف و اطلاعات نسخه پشتیبان جایگزین می‌شود. ادامه می‌دهید؟',
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

    if (confirmed != true) return;

    final password = await _askMasterPasswordForBackup(
      title: 'رمز عبور Backup را وارد کنید',
    );

    if (password == null || password.isEmpty) return;

    setState(() {
      _isBackupBusy = true;
    });

    try {
      await _backupService.restoreBackup(
        masterPassword: password,
      );

      await _loadItems();

      if (!mounted) return;

      _showMessage(
        'نسخه پشتیبان با موفقیت بازیابی شد. '
        'ورود بیومتریک را در صورت نیاز دوباره فعال کنید.',
      );
    } on BackupCancelledException {
    } on BackupFormatException catch (error) {
      _showMessage('خطا در بازیابی: ${error.message}');
    } catch (error) {
      _showMessage('خطا در بازیابی نسخه پشتیبان: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBackupBusy = false;
        });
      }
    }
  }

  Future<void> _configureBiometric() async {
    final supported = await _biometricService.isSupported();

    if (!mounted) return;

    if (!supported) {
      _showMessage('بیومتریک روی این دستگاه در دسترس نیست.');
      return;
    }

    final enabled = await _biometricService.isEnabled();

    if (!mounted) return;

    if (enabled) {
      final disable = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ورود بیومتریک'),
          content: const Text(
            'ورود بیومتریک فعال است. غیرفعال شود؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('لغو'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('غیرفعال کردن'),
            ),
          ],
        ),
      );

      if (disable == true) {
        await _biometricService.disable();

        if (mounted) {
          _showMessage('ورود بیومتریک غیرفعال شد.');
        }
      }

      return;
    }

    final enabledNow = await _biometricService.enable();

    if (!mounted) return;

    _showMessage(
      enabledNow
          ? 'ورود بیومتریک فعال شد.'
          : 'فعال‌سازی بیومتریک انجام نشد.',
    );
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
              title: const Text('ایجاد نسخه پشتیبان رمزنگاری‌شده'),
              onTap: () {
                Navigator.pop(sheetContext);
                _createBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('بازیابی نسخه پشتیبان'),
              onTap: () {
                Navigator.pop(sheetContext);
                _restoreBackup();
              },
            ),
            ListTile(
              leading: const Icon(Icons.fingerprint),
              title: const Text('تنظیم ورود بیومتریک'),
              onTap: () {
                Navigator.pop(sheetContext);
                _configureBiometric();
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
              title: const Text('ساخت پوشه'),
              onTap: () {
                Navigator.pop(sheetContext);
                createFolder();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('ساخت جدول'),
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
    final controller = TextEditingController(
      text: initialValue ?? '',
    );

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
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );

    controller.dispose();

    return result;
  }

  Future<void> createFolder() async {
    final name = await _askName(
      title: 'ساخت پوشه',
      label: 'نام پوشه',
    );

    if (name == null) return;

    final id = await _repository.createFolder(
      name: name,
    );

    final item = TreeItem.folder(
      name,
      id: id,
    );

    setState(() {
      items.add(item);
      _itemIds[item] = id;
    });
  }

  Future<void> createTable() async {
    final name = await _askName(
      title: 'ساخت جدول',
      label: 'نام جدول',
    );

    if (name == null) return;

    final id = await _repository.createTable(
      name: name,
    );

    final item = TreeItem.table(
      name,
      id: id,
    );

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
          ),
        ),
      );

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
                onPressed: _showSecurityMenu,
                icon: const Icon(Icons.security_outlined),
              ),
              IconButton(
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
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppLogo(height: 72),
                                SizedBox(height: 16),
                                Text(
                                  'هنوز موردی ساخته نشده',
                                  style: TextStyle(
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
