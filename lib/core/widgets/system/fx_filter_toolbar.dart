import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxFilterToolbar extends StatelessWidget {
  const FxFilterToolbar({
    super.key,
    this.searchController,
    this.searchHint = 'Search…',
    this.onSearchSubmitted,
    this.filters = const [],
    this.trailing,
  });

  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onSearchSubmitted;
  final List<Widget> filters;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: context.fx.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide(color: context.fx.outlineVariant),
                  ),
                ),
                onSubmitted: onSearchSubmitted,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.stackSm),
              trailing!,
            ],
          ],
        ),
        if (filters.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.stackSm),
          Wrap(
            spacing: AppSpacing.chipGap,
            runSpacing: AppSpacing.chipGap,
            children: filters,
          ),
        ],
      ],
    );
  }
}

class FxFilterChipButton extends StatelessWidget {
  const FxFilterChipButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: AppTypography.bodyMd(
          selected ? context.fx.onPrimary : context.fx.onSurface,
          context: context,
        ).copyWith(fontSize: 12),
      ),
      selected: selected,
      onSelected: (_) => onPressed(),
      selectedColor: context.fx.secondary,
      backgroundColor: context.fx.surfaceContainerLowest,
      side: BorderSide(color: context.fx.outlineVariant),
      visualDensity: VisualDensity.compact,
    );
  }
}
