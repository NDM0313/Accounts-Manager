import 'package:accounts_manager/core/widgets/premium/fx_premium_shell.dart';
import 'package:accounts_manager/data/repositories/profile_repository.dart';
import 'package:accounts_manager/features/auth/profile_not_configured_screen.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authSessionProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    // Wait for session stream before treating a null profile as "missing".
    final sessionReady = authAsync.maybeWhen(
      data: (_) => true,
      orElse: () => supabaseHasSessionFallback(ref),
    );
    if (!sessionReady && authAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading profile…'),
            ],
          ),
        ),
      ),
      error: (error, _) => ProfileAccessIssueScreen(
        kind: error is ProfileLookupException
            ? ProfileAccessIssueKind.backendError
            : ProfileAccessIssueKind.backendError,
        detail: error.toString(),
        onRetry: () => ref.invalidate(currentProfileProvider),
      ),
      data: (profile) {
        if (profile == null) {
          return ProfileAccessIssueScreen(
            kind: ProfileAccessIssueKind.missingMembership,
            onRetry: () => ref.invalidate(currentProfileProvider),
          );
        }
        return child;
      },
    );
  }
}

/// True when auth stream is still warming but a session already exists.
bool supabaseHasSessionFallback(WidgetRef ref) {
  return ref.read(isAuthenticatedProvider);
}

typedef MainShell = FxPremiumShell;
