import 'package:flutter/material.dart';

/// Semantic accents from the approved Light / Dark Figma modes.
/// Direction labels still carry meaning; debit is not automatically an outflow.
enum FxAccent { brand, receive, pay, scan, pending }

extension FxDesignTokens on BuildContext {
  bool get fxDark => Theme.of(this).brightness == Brightness.dark;
  Color get fxNavigation => Color(fxDark ? 0xFF09111D : 0xFF132C38);
  Color get fxNavigationText => Color(fxDark ? 0xFFC4D5EC : 0xFFD6E4EB);

  Color fxAccent(FxAccent accent) => switch (accent) {
    FxAccent.brand => Color(fxDark ? 0xFF91B9FF : 0xFF145CDE),
    FxAccent.receive => Color(fxDark ? 0xFF61D5B1 : 0xFF077563),
    FxAccent.pay => Color(fxDark ? 0xFFFF9BA4 : 0xFFBD3B44),
    FxAccent.scan => Color(fxDark ? 0xFFC4AEFF : 0xFF6C43BC),
    FxAccent.pending => Color(fxDark ? 0xFFF1C575 : 0xFF926116),
  };

  Color fxAccentSurface(FxAccent accent) => switch (accent) {
    FxAccent.brand => Color(fxDark ? 0xFF203A66 : 0xFFEAF1FF),
    FxAccent.receive => Color(fxDark ? 0xFF153D37 : 0xFFE5F6EF),
    FxAccent.pay => Color(fxDark ? 0xFF462632 : 0xFFFCECEF),
    FxAccent.scan => Color(fxDark ? 0xFF33264E : 0xFFF1EBFC),
    FxAccent.pending => Color(fxDark ? 0xFF40351E : 0xFFFFF4DC),
  };
}
