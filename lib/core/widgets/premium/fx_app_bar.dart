import 'package:accounts_manager/core/widgets/system/fx_appearance_button.dart';
import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared AppBar leading for child/detail/form routes (never for tab roots).
class FxAppBar {
  FxAppBar._();

  /// Always-visible Back with [fxSafePop] fallback for deep links.
  static Widget leadingBack(
    BuildContext context, {
    String? fallbackRoute,
    Object? result,
  }) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Back',
      onPressed: () =>
          fxSafePop(context, fallbackRoute: fallbackRoute, result: result),
    );
  }

  /// Home shortcut for child routes (goes to dashboard root).
  static Widget homeAction(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: 'Home',
      onPressed: () => context.go('/'),
    );
  }

  /// Standard child AppBar: Back + title + optional Home + [actions].
  static PreferredSizeWidget child({
    required BuildContext context,
    required Widget title,
    String? fallbackRoute,
    List<Widget>? actions,
    Color? backgroundColor,
    bool showHome = true,
  }) {
    final bg = context.fx.surface;
    return AppBar(
      toolbarHeight: AppSpacing.appBarHeight,
      backgroundColor: bg,
      automaticallyImplyLeading: false,
      leading: leadingBack(context, fallbackRoute: fallbackRoute),
      title: title,
      actions: [
        ...?actions,
        if (showHome) homeAction(context),
        const FxAppearanceButton(),
        const SizedBox(width: 8),
      ],
    );
  }
}
