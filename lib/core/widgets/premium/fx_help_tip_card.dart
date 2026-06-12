import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxHelpTipCard extends StatefulWidget {
  const FxHelpTipCard({
    super.key,
    required this.title,
    required this.body,
    this.initiallyExpanded = false,
  });

  final String title;
  final String body;
  final bool initiallyExpanded;

  @override
  State<FxHelpTipCard> createState() => _FxHelpTipCardState();
}

class _FxHelpTipCardState extends State<FxHelpTipCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fx.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: context.fx.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTypography.bodyMd(
                        context.fx.onSurface,
                        context: context,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: context.fx.onSurfaceVariant,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Text(
                  widget.body,
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ).copyWith(fontSize: 12, height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
