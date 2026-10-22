import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Centers content with responsive horizontal insets and optional max width.
class FxContentContainer extends StatelessWidget {
  const FxContentContainer({
    super.key,
    required this.child,
    this.maxWidth = FxLayoutBreakpoints.contentMax,
    this.padding,
    this.formWidth = false,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool formWidth;

  @override
  Widget build(BuildContext context) {
    final horizontal = context.fxHorizontalInset;
    final resolvedMax =
        formWidth ? FxLayoutBreakpoints.formMax : maxWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: resolvedMax),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: horizontal,
                vertical: AppSpacing.stackMd,
              ),
          child: child,
        ),
      ),
    );
  }
}
