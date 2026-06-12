import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// v1: read-only branch/company context after login (single-branch seed).
class BranchSelectScreen extends ConsumerWidget {
  const BranchSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchContextProvider);

    return Scaffold(
      backgroundColor: context.fx.background,
      body: FxObsidianPage(
        child: branchAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (ctx) {
            if (ctx == null) {
              return const Center(
                child: Text('No branch assigned to your profile.'),
              );
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your workspace',
                  style: AppTypography.headlineLg(
                    context.fx.onSurface,
                    context: context,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.fx.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(color: context.fx.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ctx.companyName,
                        style: AppTypography.headlineMd(
                          context.fx.onSurface,
                          context: context,
                        ),
                      ),
                      Text(
                        'Code: ${ctx.companyCode}',
                        style: AppTypography.bodyMd(
                          context.fx.onSurfaceVariant,
                          context: context,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        ctx.branchName,
                        style: AppTypography.bodyMd(
                          context.fx.onSurface,
                          context: context,
                        ),
                      ),
                      Text(
                        'Branch: ${ctx.branchCode}',
                        style: AppTypography.bodyMd(
                          context.fx.onSurfaceVariant,
                          context: context,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Continue to dashboard'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
