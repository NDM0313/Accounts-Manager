import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_audit_timeline.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key, this.inShell = false});

  final bool inShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(auditLogsProvider);

    final content = logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (logs) {
        if (logs.isEmpty) {
          return Center(
            child: Text(
              'No audit entries yet.',
              style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context),
            ),
          );
        }
        return SingleChildScrollView(
          child: FxAuditTimeline(items: logs),
        );
      },
    );

    if (inShell) {
      return FxObsidianPage(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
          16,
          MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
          88,
        ),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Audit Log'),
        backgroundColor: context.fx.background,
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
          16,
          MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
          16,
        ),
        child: content,
      ),
    );
  }
}
