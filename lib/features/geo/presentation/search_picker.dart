import 'package:flutter/material.dart';

import '../../../core/l10n/gen/app_localizations.dart';

class PickerItem<T> {
  const PickerItem({required this.value, required this.labelBn, this.labelEn = ''});
  final T value;
  final String labelBn;
  final String labelEn;
}

/// Case-insensitive "contains" match on the Bangla and English labels.
List<PickerItem<T>> filterPickerItems<T>(List<PickerItem<T>> items, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return items;
  return items
      .where((i) => i.labelBn.contains(q) || i.labelEn.toLowerCase().contains(q))
      .toList();
}

/// Full-height bottom sheet with a search box. Returns the picked value, or null if dismissed.
Future<T?> showSearchPicker<T>(
  BuildContext context, {
  required String title,
  required List<PickerItem<T>> items,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PickerSheet<T>(title: title, items: items),
    );

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({required this.title, required this.items});
  final String title;
  final List<PickerItem<T>> items;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shown = filterPickerItems(widget.items, _query);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.searchHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text(l.noResults))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (_, i) => ListTile(
                      minVerticalPadding: 12,
                      title: Text(shown[i].labelBn),
                      subtitle: shown[i].labelEn.isEmpty ? null : Text(shown[i].labelEn),
                      onTap: () => Navigator.of(context).pop(shown[i].value),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
