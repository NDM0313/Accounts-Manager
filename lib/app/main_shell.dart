import 'package:accounts_manager/core/widgets/premium/fx_premium_shell.dart';
import 'package:accounts_manager/features/auth/profile_not_configured_screen.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => ProfileNotConfiguredScreen(),
      data: (profile) {
        if (profile == null) return const ProfileNotConfiguredScreen();
        return child;
      },
    );
  }
}

typedef MainShell = FxPremiumShell;
