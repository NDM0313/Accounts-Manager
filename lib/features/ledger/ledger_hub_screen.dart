import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_bottom_sheet.dart';
import 'package:accounts_manager/features/ledger/account_statement_screen.dart';
import 'package:accounts_manager/features/transactions/transaction_list_screen.dart';
import 'package:flutter/material.dart';

enum LedgerHubTab { transactions, accountStatement }

class LedgerHubScreen extends StatefulWidget {
  const LedgerHubScreen({super.key});

  @override
  State<LedgerHubScreen> createState() => _LedgerHubScreenState();
}

class _LedgerHubScreenState extends State<LedgerHubScreen> {
  LedgerHubTab _tab = LedgerHubTab.transactions;
  bool _fxHelpExpanded = false;

  @override
  Widget build(BuildContext context) {
    final horizontal = MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile;

    final fab = _tab == LedgerHubTab.transactions
        ? FloatingActionButton(
            onPressed: () => FxObsidianBottomSheet.showTransactionTypes(context),
            backgroundColor: context.fx.tertiary,
            foregroundColor: context.fx.onTertiary,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
            child: const Icon(Icons.add, size: 28),
          )
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSpacing.containerMax),
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _segmentedControl(),
                  if (_tab == LedgerHubTab.transactions) ...[
                    const SizedBox(height: 12),
                    _fxHelpPanel(),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: _tab == LedgerHubTab.transactions
                        ? const TransactionListScreen(inShell: true, embeddedInHub: true)
                        : const AccountStatementScreen(),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (fab != null) Positioned(right: 16, bottom: 88, child: fab),
      ],
    );
  }

  Widget _fxHelpPanel() {
    return Material(
      color: context.fx.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _fxHelpExpanded = !_fxHelpExpanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline, size: 18, color: context.fx.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'How FX works',
                      style: AppTypography.bodyMd(context.fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(_fxHelpExpanded ? Icons.expand_less : Icons.expand_more, color: context.fx.onSurfaceVariant),
                ],
              ),
              if (_fxHelpExpanded) ...[
                const SizedBox(height: 8),
                Text(
                  '• Buy = foreign cash in; PKR or payable out (agent purchase on credit).\n'
                  '• Sell = foreign cash out; PKR or receivable in (customer sale on credit).\n'
                  '• Customer FX Deal = order first, source from agents later (+ menu or Accounts → FX Deals).\n'
                  '• PKR → USD → AED: use Chained Exchange (+ menu).\n'
                  '• Add currencies in Settings → Currencies.',
                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12, height: 1.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _segmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(child: _segment('TRANSACTIONS', LedgerHubTab.transactions)),
          Expanded(child: _segment('ACCOUNT STATEMENT', LedgerHubTab.accountStatement)),
        ],
      ),
    );
  }

  Widget _segment(String label, LedgerHubTab tab) {
    final selected = _tab == tab;
    return Material(
      color: selected ? context.fx.tertiary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: () => setState(() => _tab = tab),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelCaps(selected ? context.fx.onTertiary : context.fx.onSurfaceVariant, context: context)
                .copyWith(fontSize: 10),
          ),
        ),
      ),
    );
  }
}
