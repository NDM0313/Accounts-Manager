import 'dart:ui';

import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Stitch glass-card: subtle blur + bordered surface.
class FxGlassCard extends StatelessWidget {
  const FxGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.stackLg),
    this.borderRadius = AppSpacing.radiusXl,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: context.fx.surfaceContainerLowest.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: context.fx.outlineVariant),
          ),
          child: child,
        ),
      ),
    );
  }
}
