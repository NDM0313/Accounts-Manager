import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/data/supabase/supabase_client.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown when auth succeeded but [fx_users_profiles] is missing.
/// Admin must run server-side bootstrap — Flutter never bypasses RLS.
class ProfileNotConfiguredScreen extends ConsumerWidget {
  const ProfileNotConfiguredScreen({super.key});

  static const _bootstrapDocPath = 'doc/admin_bootstrap.md';
  static const _sqlScriptPath = 'supabase/scripts/bootstrap_first_admin.sql';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = supabase.auth.currentUser?.id;
    final userEmail = ref
        .watch(authSessionProvider)
        .maybeWhen(data: (s) => s.session?.user.email, orElse: () => null);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Admin Setup'),
        backgroundColor: context.fx.background,
        actions: [
          IconButton(
            tooltip: 'Retry profile check',
            onPressed: () => ref.invalidate(currentProfileProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Icon(
              Icons.admin_panel_settings_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Profile not configured',
            style: AppTypography.headlineLg(
              context.fx.onSurface,
              context: context,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Signed in successfully, but no FX Ledger profile is linked. '
            'An admin must map your account in Supabase Dashboard — the app cannot do this (RLS).',
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ),
            textAlign: TextAlign.center,
          ),
          if (userEmail != null) ...[
            const SizedBox(height: 8),
            Text(
              userEmail,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 24),
          if (userId != null) _UserIdCard(userId: userId),
          const SizedBox(height: 16),
          _SetupStep(
            number: 1,
            title: 'Find your User ID',
            body:
                'Copy the UUID above, or open Supabase → Authentication → Users.',
          ),
          _SetupStep(
            number: 2,
            title: 'Run bootstrap SQL',
            body:
                'Open SQL Editor on project ygidlcqhupmxvsdjmvnf. '
                'Run $_sqlScriptPath (replace YOUR_AUTH_USER_UUID_HERE).',
          ),
          _SetupStep(
            number: 3,
            title: 'Assign FXDEV / MAIN + admin role',
            body:
                'The script links you to company FXDEV, branch MAIN, and the admin role. '
                'See $_bootstrapDocPath for manual Table Editor steps.',
          ),
          _SetupStep(
            number: 4,
            title: 'Return to app',
            body:
                'Tap refresh (top right) or sign out and sign in. Dashboard should open with COA and currencies.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Safety', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    '• Flutter uses publishable key only — no service_role\n'
                    '• Do not use supabase.dincouture.pk or old ERP VPS\n'
                    '• Posting/transactions remain disabled until Phase 3',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => ref.read(authControllerProvider).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _UserIdCard extends StatelessWidget {
  const _UserIdCard({required this.userId});

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
            'YOUR USER ID (auth.users.id)',
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('User ID copied')));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy User ID'),
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text('$number', style: theme.textTheme.labelSmall),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
