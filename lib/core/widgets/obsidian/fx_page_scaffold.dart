import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pops the route stack when possible; otherwise navigates to [fallbackRoute].
void fxSafePop(BuildContext context, {String? fallbackRoute}) {
  if (Navigator.of(context).canPop()) {
    if (GoRouter.maybeOf(context) != null) {
      context.pop();
    } else {
      Navigator.of(context).pop();
    }
    return;
  }
  if (fallbackRoute != null && GoRouter.maybeOf(context) != null) {
    context.go(fallbackRoute);
  }
}

/// Detail/form page with a always-visible back arrow and safe fallback navigation.
class FxPageScaffold extends StatelessWidget {
  const FxPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.fallbackRoute,
    this.actions,
    this.backgroundColor,
    this.floatingActionButton,
  });

  final Widget title;
  final Widget body;
  final String? fallbackRoute;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.fx.background;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => fxSafePop(context, fallbackRoute: fallbackRoute),
        ),
        title: title,
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
