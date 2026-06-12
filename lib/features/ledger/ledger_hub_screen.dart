import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_segmented_tabs.dart';
import 'package:accounts_manager/core/widgets/premium/fx_transaction_menu_sheet.dart';
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

  @override
  Widget build(BuildContext context) {
    final horizontal = MediaQuery.sizeOf(context).width >= 900
        ? AppSpacing.marginDesktop
        : AppSpacing.marginMobile;

    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.containerMax,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FxPremiumSegmentedTabs(
                    tabs: const ['Transactions', 'Account statement'],
                    selectedIndex: _tab.index,
                    onChanged: (i) =>
                        setState(() => _tab = LedgerHubTab.values[i]),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _tab == LedgerHubTab.transactions
                        ? const TransactionListScreen(
                            inShell: true,
                            embeddedInHub: true,
                          )
                        : const AccountStatementScreen(),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_tab == LedgerHubTab.transactions)
          Positioned(
            right: horizontal,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () => FxTransactionMenuSheet.show(context),
              backgroundColor: context.fx.primary,
              foregroundColor: context.fx.onPrimary,
              elevation: 2,
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }
}
