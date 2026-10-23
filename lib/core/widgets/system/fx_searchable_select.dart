import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FxSearchableOption<T> {
  const FxSearchableOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.searchText,
  });

  final T value;
  final String label;
  final String? subtitle;
  final String? searchText;

  String get haystack =>
      (searchText ?? '$label ${subtitle ?? ''}').toLowerCase();
}

/// Single searchable selector (replaces separate search + dropdown).
class FxSearchableSelect<T> extends StatefulWidget {
  const FxSearchableSelect({
    super.key,
    required this.options,
    required this.onSelected,
    this.value,
    this.labelText = 'Select',
    this.hintText = 'Search…',
    this.enabled = true,
    this.onAddNew,
    this.addNewLabel = 'Add new',
    this.emptyMessage = 'No matches',
    this.selectedBuilder,
  });

  final List<FxSearchableOption<T>> options;
  final T? value;
  final ValueChanged<T?> onSelected;
  final String labelText;
  final String hintText;
  final bool enabled;
  final VoidCallback? onAddNew;
  final String addNewLabel;
  final String emptyMessage;
  final Widget Function(BuildContext context, FxSearchableOption<T> option)?
      selectedBuilder;

  @override
  State<FxSearchableSelect<T>> createState() => _FxSearchableSelectState<T>();
}

class _FxSearchableSelectState<T> extends State<FxSearchableSelect<T>> {
  final _searchCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _open = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  FxSearchableOption<T>? get _selected {
    if (widget.value == null) return null;
    for (final o in widget.options) {
      if (o.value == widget.value) return o;
    }
    return null;
  }

  List<FxSearchableOption<T>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((o) => o.haystack.contains(q)).toList();
  }

  void _select(T? value) {
    widget.onSelected(value);
    setState(() {
      _open = false;
      _query = '';
      _searchCtrl.clear();
    });
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final selected = _selected;
    final filtered = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected != null && !_open) ...[
          Material(
            color: fx.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.enabled
                  ? () => setState(() {
                        _open = true;
                        _focus.requestFocus();
                      })
                  : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: widget.selectedBuilder?.call(context, selected) ??
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.labelText,
                                style: AppTypography.bodySm(
                                  fx.onSurfaceVariant,
                                  context: context,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selected.label,
                                style: AppTypography.bodyMd(
                                  fx.onSurface,
                                  context: context,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (selected.subtitle != null)
                                Text(
                                  selected.subtitle!,
                                  style: AppTypography.bodySm(
                                    fx.onSurfaceVariant,
                                    context: context,
                                  ),
                                ),
                            ],
                          ),
                    ),
                    if (widget.enabled)
                      IconButton(
                        tooltip: 'Clear',
                        onPressed: () => _select(null),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    Icon(
                      Icons.expand_more,
                      color: fx.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          TextField(
            controller: _searchCtrl,
            focusNode: _focus,
            enabled: widget.enabled,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear, size: 20),
                    ),
                  if (widget.onAddNew != null)
                    IconButton(
                      tooltip: widget.addNewLabel,
                      onPressed: widget.enabled ? widget.onAddNew : null,
                      icon: const Icon(Icons.add),
                    ),
                ],
              ),
            ),
            onTap: () => setState(() => _open = true),
            onChanged: (v) => setState(() {
              _query = v;
              _open = true;
            }),
            onSubmitted: (_) {
              if (filtered.length == 1) _select(filtered.first.value);
            },
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: Material(
                color: fx.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: fx.outlineVariant),
                ),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          widget.emptyMessage,
                          style: AppTypography.bodySm(
                            fx.onSurfaceVariant,
                            context: context,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: fx.outlineVariant),
                        itemBuilder: (context, i) {
                          final o = filtered[i];
                          final isSel = o.value == widget.value;
                          return ListTile(
                            dense: true,
                            selected: isSel,
                            title: Text(
                              o.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: o.subtitle == null
                                ? null
                                : Text(
                                    o.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: widget.enabled
                                ? () {
                                    HapticFeedback.selectionClick();
                                    _select(o.value);
                                  }
                                : null,
                          );
                        },
                      ),
              ),
            ),
          ],
        ],
        if (!_open && selected == null && widget.onAddNew != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.enabled ? widget.onAddNew : null,
              icon: const Icon(Icons.add, size: 18),
              label: Text(widget.addNewLabel),
            ),
          ),
      ],
    );
  }
}
