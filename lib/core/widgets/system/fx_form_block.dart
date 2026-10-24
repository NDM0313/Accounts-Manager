import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Lightweight form section without nested card chrome (approved density).
class FxFormBlock extends StatelessWidget {
  const FxFormBlock({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.optional = false,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final bool optional;
  final bool dense;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final gap = dense ? 8.0 : AppSpacing.stackSm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.headlineSm(
                  fx.onSurface,
                  context: context,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: dense ? 15 : null),
              ),
            ),
            if (optional)
              Text(
                'Optional',
                style: AppTypography.bodySm(
                  fx.onSurfaceVariant,
                  context: context,
                ),
              ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: AppTypography.bodySm(fx.onSurfaceVariant, context: context),
          ),
        ],
        SizedBox(height: gap),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ],
    );
  }
}
