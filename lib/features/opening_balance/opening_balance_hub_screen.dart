import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/opening_balance_summary.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_opening_balance_batch.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/opening_balance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class OpeningBalanceHubScreen extends ConsumerWidget {
  const OpeningBalanceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(openingBalanceStatusProvider);
    final fmt = NumberFormat('#,##0.00');

    return FxPageScaffold(
      fallbackRoute: '/settings',
      title: const Text('Opening Balances'),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load status: $e')),
        data: (view) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusBanner(status: view.status),
              const SizedBox(height: 24),
              if (view.status == FxOpeningBalanceStatus.missing) ...[
                Text(
                  'Enter starting balances once before real transactions. '
                  'This posts balanced opening journals through the ledger posting engine.',
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/opening-balances/wizard'),
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('Start Opening Balance Wizard'),
                ),
              ],
              if (view.status == FxOpeningBalanceStatus.draft) ...[
                Text(
                  'You have a draft opening balance batch. Continue editing or post when balanced.',
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                const SizedBox(height: 16),
                if (view.batch != null) ...[
                  _SummaryTile(
                    label: 'Opening date',
                    value: DateFormat.yMMMd().format(view.batch!.openingDate),
                  ),
                  _SummaryTile(label: 'Lines', value: '${view.lines.length}'),
                  _SummaryTile(
                    label: 'Total PKR',
                    value: fmt.format(view.batch!.totalDebitPkr),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/opening-balances/wizard'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Continue Draft'),
                ),
              ],
              if (view.status == FxOpeningBalanceStatus.posted &&
                  view.batch != null) ...[
                _SummaryTile(
                  label: 'Batch',
                  value: view.batch!.batchNo ?? view.batch!.id.substring(0, 8),
                ),
                _SummaryTile(
                  label: 'Opening date',
                  value: DateFormat.yMMMd().format(view.batch!.openingDate),
                ),
                _SummaryTile(
                  label: 'Lines posted',
                  value: '${view.lines.length}',
                ),
                _SummaryTile(
                  label: 'Total PKR',
                  value: fmt.format(view.batch!.totalDebitPkr),
                ),
                if (view.batch!.postedAt != null)
                  _SummaryTile(
                    label: 'Posted',
                    value: DateFormat.yMMMd().add_jm().format(
                      view.batch!.postedAt!.toLocal(),
                    ),
                  ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    final accounts = await ref.read(accountsProvider.future);
                    final parties = await ref.read(
                      partiesProvider(null).future,
                    );
                    if (!context.mounted) return;
                    await shareOpeningBalanceSummary(
                      batch: view.batch!,
                      lines: view.lines,
                      accounts: accounts,
                      parties: parties,
                    );
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share Summary'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Opening balance is locked. Contact an admin to void and repost if correction is needed.',
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              const FxSectionLabel(label: 'What gets recorded'),
              const SizedBox(height: 8),
              Text(
                '• Cash & bank balances\n'
                '• Foreign currency positions with rates\n'
                '• Customer & agent receivables / payables\n'
                '• Balanced by Owner Capital (3100)',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final FxOpeningBalanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      FxOpeningBalanceStatus.missing => (
        context.fx.error,
        Icons.warning_amber_outlined,
        'Opening balances not set',
      ),
      FxOpeningBalanceStatus.draft => (
        context.fx.primary,
        Icons.edit_note_outlined,
        'Draft in progress',
      ),
      FxOpeningBalanceStatus.posted => (
        context.fx.tertiary,
        Icons.check_circle_outline,
        'Opening balance posted',
      ),
      FxOpeningBalanceStatus.voided => (
        context.fx.onSurfaceVariant,
        Icons.block_outlined,
        'Opening balance voided',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTypography.headlineMd(color, context: context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMd(context.fx.onSurface, context: context),
          ),
        ],
      ),
    );
  }
}
