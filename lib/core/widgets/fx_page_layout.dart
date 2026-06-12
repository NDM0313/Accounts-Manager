import 'package:flutter/material.dart';

/// Stitch layout: max 1280px width, responsive horizontal margins.
class FxPageLayout extends StatelessWidget {
  const FxPageLayout({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  static EdgeInsets margins(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final horizontal = w >= 900 ? 32.0 : 16.0;
    return EdgeInsets.symmetric(horizontal: horizontal);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: padding ?? margins(context).copyWith(top: 16, bottom: 16),
          child: child,
        ),
      ),
    );
  }
}
