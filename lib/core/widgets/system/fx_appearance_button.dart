import 'package:accounts_manager/app/theme/fx_design_tokens.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FxAppearanceButton extends ConsumerWidget {
  const FxAppearanceButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton.filledTonal(
    tooltip: context.fxDark ? 'Switch to light mode' : 'Switch to dark mode',
    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    style: IconButton.styleFrom(
      backgroundColor: context.fxAccentSurface(FxAccent.brand),
      foregroundColor: context.fxAccent(FxAccent.brand),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    icon: Icon(
      context.fxDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      size: 20,
    ),
    onPressed: () => ref
        .read(themeModeProvider.notifier)
        .set(context.fxDark ? ThemeMode.light : ThemeMode.dark),
  );
}
