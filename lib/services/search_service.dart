import '../repositories/tree_repository.dart';

enum SearchHitKind { folder, table, row }

class SearchHit {
  final SearchHitKind kind;
  final int itemId;
  final String title;
  final String path;
  final String? snippet;
  final int? rowId;
  final String? tableName;

  const SearchHit({
    required this.kind,
    required this.itemId,
    required this.title,
    required this.path,
    this.snippet,
    this.rowId,
    this.tableName,
  });
}

/// جستجو در vault با محدودهٔ اختیاری (کل vault / یک پوشه / یک جدول).
class SearchService {
  SearchService({TreeRepository? repository})
      : _repository = repository ?? TreeRepository();

  final TreeRepository _repository;

  Future<List<SearchHit>> search({
    required String query,
    int? folderId,
    int? tableId,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final hits = <SearchHit>[];

    if (tableId != null) {
      await _searchTable(
        hits: hits,
        tableId: tableId,
        tableName: '',
        path: '',
        query: q,
      );
      return hits;
    }

    if (folderId != null) {
      final root = await _repository.getCompleteTreeItem(folderId);
      if (root == null) return const [];
      await _walkNode(
        hits: hits,
        node: root,
        pathParts: [],
        query: q,
        includeRootName: false,
      );
      return hits;
    }

    final roots = await _repository.getCompleteTree();
    for (final node in roots) {
      await _walkNode(
        hits: hits,
        node: node,
        pathParts: [],
        query: q,
        includeRootName: true,
      );
    }
    return hits;
  }

  Future<void> _walkNode({
    required List<SearchHit> hits,
    required Map<String, dynamic> node,
    required List<String> pathParts,
    required String query,
    required bool includeRootName,
  }) async {
    final id = node['id'];
    final name = (node['name'] ?? '').toString();
    final type = (node['type'] ?? '').toString();
    if (id is! int) return;

    final nextPath = [...pathParts, if (name.isNotEmpty) name];
    final pathLabel = nextPath.join(' › ');

    if (includeRootName && name.toLowerCase().contains(query)) {
      hits.add(
        SearchHit(
          kind: type == 'table' ? SearchHitKind.table : SearchHitKind.folder,
          itemId: id,
          title: name,
          path: pathParts.isEmpty ? 'خانه' : pathParts.join(' › '),
        ),
      );
    }

    if (type == 'folder') {
      final children = node['children'];
      if (children is List) {
        for (final child in children) {
          if (child is Map) {
            await _walkNode(
              hits: hits,
              node: Map<String, dynamic>.from(child),
              pathParts: nextPath,
              query: query,
              includeRootName: true,
            );
          }
        }
      }
      return;
    }

    if (type == 'table') {
      await _searchTableFromNode(
        hits: hits,
        tableId: id,
        tableName: name,
        path: pathLabel,
        node: node,
        query: query,
      );
    }
  }

  Future<void> _searchTable({
    required List<SearchHit> hits,
    required int tableId,
    required String tableName,
    required String path,
    required String query,
  }) async {
    final node = await _repository.getCompleteTreeItem(tableId);
    if (node == null) return;
    final name = (node['name'] ?? tableName).toString();
    await _searchTableFromNode(
      hits: hits,
      tableId: tableId,
      tableName: name,
      path: path.isEmpty ? name : path,
      node: node,
      query: query,
    );
  }

  Future<void> _searchTableFromNode({
    required List<SearchHit> hits,
    required int tableId,
    required String tableName,
    required String path,
    required Map<String, dynamic> node,
    required String query,
  }) async {
    final rows = node['rows'];
    if (rows is! List) return;

    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final rowId = row['id'];
      if (rowId is! int) continue;

      final fields = row['fields'];
      final values = row['values'];
      if (fields is! List) continue;

      final matchedSnippets = <String>[];
      for (final rawField in fields) {
        if (rawField is! Map) continue;
        final fieldName = (rawField['name'] ?? '').toString();
        final fieldId = rawField['id'];
        var value = '';
        if (values is Map && fieldId != null) {
          value =
              (values[fieldId.toString()] ?? values[fieldId] ?? '').toString();
        }

        final nameMatch = fieldName.toLowerCase().contains(query);
        final valueMatch = value.toLowerCase().contains(query);
        if (nameMatch || valueMatch) {
          final displayValue =
              value.length > 40 ? '${value.substring(0, 40)}…' : value;
          matchedSnippets.add(
            displayValue.isEmpty ? fieldName : '$fieldName: $displayValue',
          );
        }
      }

      if (matchedSnippets.isNotEmpty) {
        hits.add(
          SearchHit(
            kind: SearchHitKind.row,
            itemId: tableId,
            title: tableName.isEmpty ? 'جدول' : tableName,
            path: path,
            snippet: matchedSnippets.take(3).join(' · '),
            rowId: rowId,
            tableName: tableName,
          ),
        );
      }
    }
  }
}
