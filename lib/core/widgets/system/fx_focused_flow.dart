import 'package:flutter/material.dart';

/// Marks a focused create/review flow so chrome can hide bottom navigation.
class FxFocusedFlowScope extends InheritedWidget {
  const FxFocusedFlowScope({
    super.key,
    this.hideBottomNav = true,
    required super.child,
  });

  final bool hideBottomNav;

  static FxFocusedFlowScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FxFocusedFlowScope>();
  }

  static bool hidesBottomNav(BuildContext context) {
    return maybeOf(context)?.hideBottomNav ?? false;
  }

  @override
  bool updateShouldNotify(FxFocusedFlowScope oldWidget) =>
      hideBottomNav != oldWidget.hideBottomNav;
}
