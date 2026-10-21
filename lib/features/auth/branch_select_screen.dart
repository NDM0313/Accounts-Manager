import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/demo_workspace_banner.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/domain/models/fx_workspace.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Company / demo workspace selector (server-enforced memberships).
class BranchSelectScreen extends ConsumerWidget {
  const BranchSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(myWorkspacesProvider);
    final isDemo = ref.watch(isDemoWorkspaceProvider);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Workspace'),
        backgroundColor: context.fx.surface,
      ),
      body: Column(
        children: [
          if (isDemo) const DemoWorkspaceBanner(),
          Expanded(
            child: FxObsidianPage(
              child: workspacesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (workspaces) {
                  if (workspaces.isEmpty) {
                    return const Center(
                      child: Text('No company membership assigned.'),
                    );
                  }
                  return ListView(
                    children: [
                      Text(
                        'Choose company',
                        style: AppTypography.headlineLg(
                          context.fx.onSurface,
                          context: context,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Real membership stays intact. DEMO is sample data only.',
                        style: AppTypography.bodyMd(
                          context.fx.onSurfaceVariant,
                          context: context,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...workspaces.map(
                        (ws) => _WorkspaceCard(
                          workspace: ws,
                          onSelect: () => _select(context, ref, ws),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Continue to dashboard'),
                      ),
                      if (isDemo) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => context.push('/demo/walkthrough'),
                          child: const Text('Open demo walkthrough'),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    FxWorkspace ws,
  ) async {
    if (ws.isActiveWorkspace) {
      if (context.mounted) context.go('/');
      return;
    }
    try {
      await ref.read(profileRepositoryProvider).switchWorkspace(
            companyId: ws.companyId,
            branchId: ws.branchId,
          );
      invalidateWorkspaceScopedProviders(ref);
      if (!context.mounted) return;
      context.go(ws.isDemo ? '/demo/walkthrough' : '/');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workspace switch failed: $e')),
      );
    }
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.workspace, required this.onSelect});

  final FxWorkspace workspace;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final ws = workspace;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(
                color: ws.isActiveWorkspace
                    ? context.fx.secondary
                    : context.fx.outlineVariant,
                width: ws.isActiveWorkspace ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ws.companyName,
                        style: AppTypography.headlineMd(
                          context.fx.onSurface,
                          context: context,
                        ),
                      ),
                    ),
                    if (ws.isDemo)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7A4E00),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'DEMO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (ws.isActiveWorkspace)
                      Icon(Icons.check_circle, color: context.fx.secondary),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Code: ${ws.companyCode} · Branch: ${ws.branchCode}',
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                Text(
                  ws.branchName,
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
