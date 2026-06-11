import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/report_export.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChartOfAccountsScreen extends ConsumerWidget {
  const ChartOfAccountsScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final accounts = await ref.read(accountsProvider.future);
      if (!context.mounted) return;
      if (accounts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No accounts to export.')),
        );
        return;
      }
      await shareReportCsv(csv: formatCoaCsv(accounts), subject: 'FX Ledger Chart of Accounts');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return FxPageScaffold(
      fallbackRoute: '/accounts-hub',
      title: const Text('Chart of Accounts'),
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share),
          tooltip: 'Export CSV',
          onPressed: () => _export(context, ref),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Chart of Accounts', style: AppTypography.headlineLg(Theme.of(context).colorScheme.onSurface, context: context)),
          const SizedBox(height: 8),
          Text(
            'Read-only COA from fx_accounts.',
            style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context),
          ),
          const SizedBox(height: 16),
          accountsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const FxObsidianReportPanel(
              child: Text('Unable to load accounts. Profile and RLS permissions required.'),
            ),
            data: (accounts) {
              if (accounts.isEmpty) {
                return const FxObsidianReportPanel(child: Text('No accounts visible for your profile.'));
              }
              return Container(
                decoration: BoxDecoration(
                  color: context.fx.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(color: context.fx.outlineVariant),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: accounts.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: context.fx.outlineVariant),
                  itemBuilder: (context, index) {
                    final a = accounts[index];
                    return ListTile(
                      title: Text('${a.code} · ${a.name}', style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurface, context: context)),
                      subtitle: Text(a.accountType, style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                      trailing: a.isActive ? null : Text('Inactive', style: AppTypography.labelCaps(context.fx.onSurfaceVariant, context: context)),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
