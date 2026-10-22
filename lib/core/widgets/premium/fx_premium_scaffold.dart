import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/premium/fx_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pops the route stack when possible; otherwise navigates to [fallbackRoute].
///
/// Prefer this for Cancel/Back on flat (non-shell) routes opened via hash deep
/// links — bare [GoRouter.pop] is a no-op when `canPop` is false.
void fxSafePop(
  BuildContext context, {
  String? fallbackRoute,
  Object? result,
}) {
  final router = GoRouter.maybeOf(context);
  final canPop = router != null
      ? context.canPop()
      : Navigator.of(context).canPop();
  if (canPop) {
    if (router != null) {
      context.pop(result);
    } else {
      Navigator.of(context).pop(result);
    }
    return;
  }
  if (fallbackRoute != null && router != null) {
    context.go(fallbackRoute);
  }
}

/// Premium detail/form page — 64px app bar, always-visible back + Home.
class FxPremiumScaffold extends StatelessWidget {
  const FxPremiumScaffold({
    super.key,
    required this.title,
    required this.body,
    this.fallbackRoute,
    this.actions,
    this.backgroundColor,
    this.floatingActionButton,
    this.bottomBar,
    this.showHome = true,
  });

  final Widget title;
  final Widget body;
  final String? fallbackRoute;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final bool showHome;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.fx.background;
    return Scaffold(
      backgroundColor: bg,
      appBar: FxAppBar.child(
        context: context,
        title: title,
        fallbackRoute: fallbackRoute,
        backgroundColor: bg,
        showHome: showHome,
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
    );
  }
}
