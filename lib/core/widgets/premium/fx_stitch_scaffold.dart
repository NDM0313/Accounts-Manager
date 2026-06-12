import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Canonical Stitch page wrapper: warm background, white cards, no Obsidian chrome.
class FxStitchScaffold extends StatelessWidget {
  const FxStitchScaffold({
    super.key,
    required this.child,
    this.padding,
    this.scrollable = true,
    this.bottomPadding = 88,
  });

  final Widget child;
  final EdgeInsets? padding;
  final bool scrollable;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final horizontal = w >= 900
        ? AppSpacing.marginDesktop
        : AppSpacing.marginMobile;
    final resolved = padding ??
        EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottomPadding);

    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.containerMax),
        child: Padding(padding: resolved, child: child),
      ),
    );

    return ColoredBox(
      color: context.fx.background,
      child: scrollable
          ? SingleChildScrollView(child: content)
          : content,
    );
  }
}

/// White bordered card surface per Stitch DESIGN.md (Level 1).
class FxStitchCard extends StatelessWidget {
  const FxStitchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.highlighted = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool highlighted;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ??
            (highlighted
                ? context.fx.tertiaryContainer
                : context.fx.surfaceContainerLowest),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: highlighted
              ? context.fx.tertiaryFixedDim.withValues(alpha: 0.2)
              : context.fx.outlineVariant,
        ),
      ),
      child: child,
    );

    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: panel,
      ),
    );
  }
}
