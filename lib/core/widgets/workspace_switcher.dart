import 'package:accounts_manager/app/theme/fx_design_tokens.dart';
import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/fx_workspace.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Compact company/workspace picker for app bar and settings.
class WorkspaceSwitcherButton extends ConsumerWidget {
  const WorkspaceSwitcherButton({
    super.key,
    this.compact = true,
    this.iconOnly = false,
  });

  final bool compact;
  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspacesAsync = ref.watch(myWorkspacesProvider);
    return workspacesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (workspaces) {
        if (workspaces.length < 2) {
          final only = workspaces.isEmpty ? null : workspaces.first;
          if (only == null || !compact) return const SizedBox.shrink();
          return _chip(context, only.companyCode, only.isDemo);
        }
        final active = workspaces.firstWhere(
          (w) => w.isActiveWorkspace,
          orElse: () => workspaces.first,
        );
        return PopupMenuButton<FxWorkspace>(
          tooltip: 'Switch workspace',
          onSelected: (ws) => _switchTo(context, ref, ws),
          itemBuilder: (context) => [
            for (final ws in workspaces)
              PopupMenuItem(
                value: ws,
                child: Row(
                  children: [
                    Icon(
                      ws.isActiveWorkspace
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: ws.isDemo
                          ? context.fxAccent(FxAccent.pending)
                          : context.fx.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ws.companyName,
                            style: AppTypography.bodyMd(
                              context.fx.onSurface,
                              context: context,
                            ),
                          ),
                          Text(
                            '${ws.companyCode} · ${ws.branchCode}'
                            '${ws.isDemo ? ' · DEMO' : ''}',
                            style: AppTypography.bodySm(
                              context.fx.onSurfaceVariant,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: _chip(context, active.companyCode, active.isDemo),
        );
      },
    );
  }

  Widget _chip(BuildContext context, String code, bool isDemo) {
    if (iconOnly) {
      return Tooltip(
        message: 'Workspace: $code',
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            isDemo ? Icons.science_outlined : Icons.business_outlined,
            color: isDemo
                ? context.fxAccent(FxAccent.pending)
                : context.fx.primary,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDemo
            ? context.fxAccent(FxAccent.pending).withValues(alpha: 0.12)
            : context.fx.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDemo
              ? context.fxAccent(FxAccent.pending)
              : context.fx.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDemo ? Icons.science_outlined : Icons.business_outlined,
            size: 14,
            color: isDemo
                ? context.fxAccent(FxAccent.pending)
                : context.fx.primary,
          ),
          const SizedBox(width: 6),
          Text(
            code,
            style: AppTypography.labelCaps(
              isDemo ? context.fxAccent(FxAccent.pending) : context.fx.primary,
              context: context,
            ).copyWith(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.expand_more,
            size: 16,
            color: isDemo
                ? context.fxAccent(FxAccent.pending)
                : context.fx.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Future<void> _switchTo(
    BuildContext context,
    WidgetRef ref,
    FxWorkspace ws,
  ) async {
    if (ws.isActiveWorkspace) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .switchWorkspace(companyId: ws.companyId, branchId: ws.branchId);
      invalidateWorkspaceScopedProviders(ref);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ws.isDemo
                ? 'Switched to DEMO sample workspace'
                : 'Switched to ${ws.companyCode}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Workspace switch failed: $e')));
    }
  }
}
