import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ProfileAccessIssueKind {
  missingMembership,
  backendError,
  sessionExpired,
  permissionDenied,
}

/// Shown when auth succeeded but profile/workspace access is unavailable.
/// Never instructs end users to bootstrap against legacy Cloud / FXDEV.
class ProfileAccessIssueScreen extends ConsumerWidget {
  const ProfileAccessIssueScreen({
    super.key,
    required this.kind,
    this.detail,
    this.onRetry,
  });

  final ProfileAccessIssueKind kind;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = supabase.auth.currentUser?.id;
    final userEmail = ref
        .watch(authSessionProvider)
        .maybeWhen(data: (s) => s.session?.user.email, orElse: () => null);

    final title = switch (kind) {
      ProfileAccessIssueKind.missingMembership => 'Workspace access needed',
      ProfileAccessIssueKind.backendError => 'Could not load profile',
      ProfileAccessIssueKind.sessionExpired => 'Session expired',
      ProfileAccessIssueKind.permissionDenied => 'Permission denied',
    };

    final body = switch (kind) {
      ProfileAccessIssueKind.missingMembership =>
        'You are signed in, but no active FX Ledger workspace membership was found '
            'for this account. Ask an admin to restore your company access — '
            'do not run bootstrap scripts from the app.',
      ProfileAccessIssueKind.backendError =>
        'A temporary error prevented loading your profile. Your account was not deleted. '
            'Check your connection and retry. If this continues, contact support.',
      ProfileAccessIssueKind.sessionExpired =>
        'Your session expired. Sign in again to continue.',
      ProfileAccessIssueKind.permissionDenied =>
        'You do not have permission to open this workspace. Switch company or ask an admin.',
    };

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Account access'),
        backgroundColor: context.fx.background,
        actions: [
          if (onRetry != null)
            IconButton(
              tooltip: 'Retry',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Icon(
              kind == ProfileAccessIssueKind.backendError
                  ? Icons.cloud_off_outlined
                  : Icons.lock_person_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTypography.headlineLg(
              context.fx.onSurface,
              context: context,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ),
            textAlign: TextAlign.center,
          ),
          if (detail != null && detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.fx.onSurfaceVariant,
              ),
            ),
          ],
          if (userEmail != null) ...[
            const SizedBox(height: 8),
            Text(
              userEmail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (userId != null) ...[
            const SizedBox(height: 16),
            _SupportIdCard(userId: userId),
          ],
          const SizedBox(height: 24),
          if (onRetry != null)
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => ref.read(authControllerProvider).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

/// Backward-compatible alias for older imports/routes.
class ProfileNotConfiguredScreen extends ProfileAccessIssueScreen {
  const ProfileNotConfiguredScreen({super.key})
      : super(kind: ProfileAccessIssueKind.missingMembership);
}

class _SupportIdCard extends StatelessWidget {
  const _SupportIdCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Support reference (auth user id)',
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            userId,
            style: AppTypography.labelMono(
              context.fx.onSurface,
              context: context,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: userId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User ID copied')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy for support'),
          ),
        ],
      ),
    );
  }
}
