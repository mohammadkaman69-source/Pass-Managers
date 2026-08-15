import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// PDF export renders Flutter's own text/layout engine into fixed A4 pages,
/// then embeds those rendered pages in the PDF. This avoids a second RTL/BiDi
/// text engine and therefore handles mixed Persian/Latin text like the app UI.
class PdfExportService {
  static const MethodChannel _channel = MethodChannel('pass_managers/file_saver');

  Future<String?> exportTree({
    BuildContext? context,
    required Map<String, dynamic> root,
  }) async {
    final model = _PdfDocumentModel.fromRoot(root);
    final pages = _paginate(model);
    for (var i = 0; i < pages.length; i++) {
      pages[i].number = i + 1;
      pages[i].total = pages.length;
    }
    final images = <ui.Image>[];

    try {
      for (final page in pages) {
        images.add(await _renderPage(context, model.title, page));
      }
      final document = pw.Document();
      for (final image in images) {
        final bytes = await _imageBytes(image);
        document.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
        ));
      }

      final savedBytes = await document.save();
      final fileName = '${_sanitizeFileName(model.title)}.pdf';
      if (Platform.isAndroid) {
        try {
          final result = await _channel.invokeMethod<String>('savePdf', <String, dynamic>{
            'fileName': fileName,
            'bytes': savedBytes,
          });
          if (result != null && result.trim().isNotEmpty) {
            try {
              await _channel.invokeMethod<bool>('openPdf', <String, dynamic>{'uri': result});
            } catch (_) {}
          }
          return result;
        } finally {
          savedBytes.fillRange(0, savedBytes.length, 0);
        }
      }
      try {
        return await FilePicker.saveFile(
          dialogTitle: 'ذخیره PDF Pass Managers',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
          bytes: savedBytes,
        );
      } finally {
        savedBytes.fillRange(0, savedBytes.length, 0);
      }
    } finally {
      for (final image in images) {
        image.dispose();
      }
    }
  }

  Future<ui.Image> _renderPage(BuildContext? suppliedContext, String title, _PdfPageData page) async {
    final hostContext = suppliedContext ?? WidgetsBinding.instance.rootElement;
    if (hostContext == null) {
      throw StateError('Flutter root context is not available for PDF rendering.');
    }
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -10000,
        top: 0,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 794,
            height: 1123,
            child: Material(
              color: Colors.white,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: _PdfPageView(title: title, page: page),
              ),
            ),
          ),
        ),
      ),
    );
    final overlay = Overlay.of(hostContext, rootOverlay: true);
    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('PDF page could not be rendered.');
      return boundary.toImage(pixelRatio: 1.0);
    } finally {
      entry.remove();
      entry.dispose();
    }
  }

  Future<Uint8List> _imageBytes(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('PDF page image encoding failed.');
    return data.buffer.asUint8List();
  }

  List<_PdfPageData> _paginate(_PdfDocumentModel model) {
    final pages = <_PdfPageData>[];
    var current = <_PdfSection>[];
    var used = 0;
    void flush() {
      if (current.isNotEmpty) {
        pages.add(_PdfPageData(List<_PdfSection>.from(current)));
        current = <_PdfSection>[];
        used = 0;
      }
    }
    void addSection(_PdfSection section) {
      final cost = section.estimatedUnits;
      if (current.isNotEmpty && used + cost > 17) flush();
      current.add(section);
      used += cost;
    }
    for (final folder in model.folders) {
      addSection(_PdfSection.folder(folder.name));
      for (final table in folder.tables) _addTablePages(addSection, flush, table);
      for (final child in folder.children) {
        addSection(_PdfSection.folder(child.name));
        for (final table in child.tables) _addTablePages(addSection, flush, table);
      }
    }
    for (final table in model.rootTables) _addTablePages(addSection, flush, table);
    if (current.isEmpty) addSection(_PdfSection.message('محتوایی برای Export وجود ندارد.'));
    flush();
    return pages;
  }

  void _addTablePages(void Function(_PdfSection) addSection, void Function() flush, _PdfTable table) {
    addSection(_PdfSection.tableTitle(table.name));
    if (table.columns.isEmpty) {
      addSection(_PdfSection.message('این جدول فیلدی ندارد.'));
      return;
    }
    if (table.rows.isEmpty) {
      addSection(_PdfSection.message('این جدول رکوردی ندارد.'));
      return;
    }
    const rowsPerPage = 10;
    for (var start = 0; start < table.rows.length; start += rowsPerPage) {
      final end = (start + rowsPerPage).clamp(0, table.rows.length);
      final rows = table.rows.sublist(start, end);
      if (start > 0) {
        flush();
        addSection(_PdfSection.tableTitle('${table.name} (ادامه)'));
      }
      addSection(_PdfSection.table(table.columns, rows, start));
      if (end < table.rows.length) flush();
    }
  }

  String _sanitizeFileName(String name) => name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim().isEmpty
      ? 'Pass-Managers'
      : name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
}

class _PdfPageView extends StatelessWidget {
  const _PdfPageView({required this.title, required this.page});
  final String title;
  final _PdfPageData page;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 794,
        height: 1123,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(38, 34, 38, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title.isEmpty ? 'Pass Managers' : title, textAlign: TextAlign.right, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: page.sections.map((section) => _PdfSectionView(section: section)).toList(),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 7),
              Text('صفحه ${page.number} از ${page.total}', textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
}

class _PdfSectionView extends StatelessWidget {
  const _PdfSectionView({required this.section});
  final _PdfSection section;

  @override
  Widget build(BuildContext context) {
    switch (section.kind) {
      case _PdfSectionKind.folder:
        return Container(margin: const EdgeInsets.only(top: 8, bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), color: const Color(0xFFECECEC), child: Text('پوشه: ${section.title}', textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
      case _PdfSectionKind.tableTitle:
        return Padding(padding: const EdgeInsets.only(top: 8, bottom: 5), child: Text('جدول: ${section.title}', textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)));
      case _PdfSectionKind.message:
        return Padding(padding: const EdgeInsets.only(bottom: 7), child: Text(section.title, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12)));
      case _PdfSectionKind.table:
        return _PdfTableView(section: section);
    }
  }
}

class _PdfTableView extends StatelessWidget {
  const _PdfTableView({required this.section});
  final _PdfSection section;

  @override
  Widget build(BuildContext context) {
    final columns = section.columns;
    return Table(
      border: TableBorder.all(color: Colors.black54, width: 0.5),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {0: const FlexColumnWidth(0.45), for (var i = 1; i <= columns.length; i++) i: const FlexColumnWidth(1.0)},
      children: [
        TableRow(decoration: const BoxDecoration(color: Color(0xFFE0E0E0)), children: [_cell('#', ltr: true, bold: true), ...columns.map((column) => _cell(column, bold: true))]),
        ...section.rows.asMap().entries.map((entry) {
          final rowIndex = section.startIndex + entry.key + 1;
          final row = entry.value;
          return TableRow(children: [_cell('$rowIndex', ltr: true), ...columns.map((column) => _cell(row.values[column] ?? '—'))]);
        }),
      ],
    );
  }

  Widget _cell(String value, {bool bold = false, bool ltr = false}) {
    final direction = ltr ? TextDirection.ltr : (_containsRtl(value) ? TextDirection.rtl : TextDirection.ltr);
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Text(value, textDirection: direction, textAlign: direction == TextDirection.rtl ? TextAlign.right : TextAlign.left, maxLines: 3, overflow: TextOverflow.clip, style: TextStyle(fontSize: bold ? 10 : 9, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: Colors.black)),
    );
  }

  bool _containsRtl(String value) => RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]').hasMatch(value);
}

enum _PdfSectionKind { folder, tableTitle, table, message }

class _PdfSection {
  const _PdfSection._({required this.kind, this.title = '', this.columns = const [], this.rows = const [], this.startIndex = 0});
  factory _PdfSection.folder(String name) => _PdfSection._(kind: _PdfSectionKind.folder, title: name);
  factory _PdfSection.tableTitle(String name) => _PdfSection._(kind: _PdfSectionKind.tableTitle, title: name);
  factory _PdfSection.message(String text) => _PdfSection._(kind: _PdfSectionKind.message, title: text);
  factory _PdfSection.table(List<String> columns, List<_PdfRow> rows, int startIndex) => _PdfSection._(kind: _PdfSectionKind.table, columns: columns, rows: rows, startIndex: startIndex);
  final _PdfSectionKind kind;
  final String title;
  final List<String> columns;
  final List<_PdfRow> rows;
  final int startIndex;
  int get estimatedUnits => switch (kind) {
        _PdfSectionKind.folder => 2,
        _PdfSectionKind.tableTitle => 1,
        _PdfSectionKind.message => 1,
        _PdfSectionKind.table => rows.length + 2,
      };
}

class _PdfPageData {
  _PdfPageData(this.sections);
  final List<_PdfSection> sections;
  int number = 0;
  int total = 0;
}

class _PdfDocumentModel {
  const _PdfDocumentModel({required this.title, required this.folders, required this.rootTables});
  final String title;
  final List<_PdfFolder> folders;
  final List<_PdfTable> rootTables;

  factory _PdfDocumentModel.fromRoot(Map<String, dynamic> root) {
    final folders = <_PdfFolder>[];
    final rootTables = <_PdfTable>[];
    final children = root['children'];
    if (children is List) {
      for (final child in children) {
        if (child is! Map) continue;
        final map = Map<String, dynamic>.from(child);
        switch (map['type']?.toString()) {
          case 'folder': folders.add(_PdfFolder.fromMap(map));
          case 'table': rootTables.add(_PdfTable.fromMap(map));
        }
      }
    }
    return _PdfDocumentModel(title: root['name']?.toString() ?? 'Pass Managers', folders: folders, rootTables: rootTables);
  }
}

class _PdfFolder {
  const _PdfFolder({required this.name, required this.tables, required this.children});
  final String name;
  final List<_PdfTable> tables;
  final List<_PdfFolder> children;

  factory _PdfFolder.fromMap(Map<String, dynamic> map) {
    final tables = <_PdfTable>[];
    final children = <_PdfFolder>[];
    final raw = map['children'];
    if (raw is List) {
      for (final child in raw) {
        if (child is! Map) continue;
        final childMap = Map<String, dynamic>.from(child);
        switch (childMap['type']?.toString()) {
          case 'table': tables.add(_PdfTable.fromMap(childMap));
          case 'folder': children.add(_PdfFolder.fromMap(childMap));
        }
      }
    }
    return _PdfFolder(name: map['name']?.toString() ?? '', tables: tables, children: children);
  }
}

class _PdfTable {
  const _PdfTable({required this.name, required this.columns, required this.rows});
  final String name;
  final List<String> columns;
  final List<_PdfRow> rows;

  factory _PdfTable.fromMap(Map<String, dynamic> map) {
    final rawRows = map['rows'];
    final positions = <String, int>{};
    final parsedRows = <_PdfRow>[];
    if (rawRows is List) {
      for (final rawRow in rawRows) {
        if (rawRow is! Map) continue;
        final fields = rawRow['fields'];
        if (fields is List) {
          for (final rawField in fields) {
            if (rawField is! Map) continue;
            final name = rawField['name']?.toString() ?? '';
            if (name.isEmpty) continue;
            final rawPosition = rawField['position'];
            final position = rawPosition is int ? rawPosition : 999999;
            final old = positions[name];
            if (old == null || position < old) positions[name] = position;
          }
        }
        final values = <String, String>{};
        final rawValues = rawRow['values'];
        if (rawValues is Map) rawValues.forEach((key, value) { values[key.toString()] = value?.toString() ?? ''; });
        parsedRows.add(_PdfRow(values));
      }
    }
    final columns = positions.keys.toList()..sort((a, b) { final c = positions[a]!.compareTo(positions[b]!); return c == 0 ? a.compareTo(b) : c; });
    return _PdfTable(name: map['name']?.toString() ?? '', columns: columns, rows: parsedRows);
  }
}

class _PdfRow {
  const _PdfRow(this.values);
  final Map<String, String> values;
}
