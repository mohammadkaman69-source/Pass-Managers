import 'dart:async';

import 'package:flutter/material.dart';
import '../services/app_language.dart';
import '../services/search_service.dart';

class AppSearchBar extends StatefulWidget {
  final int? folderId;
  final int? tableId;
  final void Function(SearchHit hit)? onHitSelected;
  final ValueChanged<String>? onQueryChanged;

  const AppSearchBar({
    super.key,
    this.folderId,
    this.tableId,
    this.onHitSelected,
    this.onQueryChanged,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  final SearchService _searchService = SearchService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  bool _searching = false;
  List<SearchHit> _hits = const [];
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onQueryChanged?.call(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hits = const [];
        _lastQuery = '';
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _lastQuery = q;
    });

    try {
      final hits = await _searchService.search(
        query: q,
        folderId: widget.folderId,
        tableId: widget.tableId,
      );
      if (!mounted || _lastQuery != q) return;
      setState(() {
        _hits = hits;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || _lastQuery != q) return;
      setState(() {
        _hits = const [];
        _searching = false;
      });
    }
  }

  void _clear() {
    _controller.clear();
    widget.onQueryChanged?.call('');
    setState(() {
      _hits = const [];
      _lastQuery = '';
      _searching = false;
    });
  }

  IconData _iconFor(SearchHitKind kind) {
    switch (kind) {
      case SearchHitKind.folder:
        return Icons.folder_outlined;
      case SearchHitKind.table:
        return Icons.table_chart_outlined;
      case SearchHitKind.row:
        return Icons.view_list_outlined;
    }
  }

  String _kindLabel(SearchHitKind kind) {
    switch (kind) {
      case SearchHitKind.folder:
        return AppStrings.folder(context);
      case SearchHitKind.table:
        return AppStrings.table(context);
      case SearchHitKind.row:
        return AppStrings.row(context);
    }
  }

  String get _hint {
    if (widget.tableId != null) return AppStrings.searchInTable(context);
    if (widget.folderId != null) return AppStrings.searchInFolder(context);
    return AppStrings.searchEverywhere(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _hint,
              suffixIcon: hasQuery
                  ? IconButton(
                      onPressed: _clear,
                      icon: const Icon(Icons.close),
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
        if (_searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (hasQuery && !_searching && _hits.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                AppStrings.noResults(context),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),
        if (_hits.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              itemCount: _hits.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final hit = _hits[index];
                return ListTile(
                  dense: true,
                  leading: Icon(_iconFor(hit.kind)),
                  title: Text(
                    hit.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      _kindLabel(hit.kind),
                      if (hit.path.isNotEmpty) hit.path,
                      if (hit.snippet != null && hit.snippet!.isNotEmpty)
                        hit.snippet!,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    _focusNode.unfocus();
                    widget.onHitSelected?.call(hit);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
