import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_segmented_tabs.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
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
    final horizontal = context.fxHorizontalInset;
    // Clearance for bottom nav + real FAB — not a full-width empty strip.
    final listBottomPad =
        MediaQuery.paddingOf(context).bottom +
        kBottomNavigationBarHeight +
        (_tab == LedgerHubTab.transactions ? 72 : 16);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _tab == LedgerHubTab.transactions
          ? FloatingActionButton(
              onPressed: () => FxTransactionMenuSheet.show(context),
              backgroundColor: context.fx.primary,
              foregroundColor: context.fx.onPrimary,
              elevation: 3,
              tooltip: 'New transaction',
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: FxContentContainer(
        padding: EdgeInsets.fromLTRB(horizontal, AppSpacing.stackSm, horizontal, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AppBar / shell already identifies the screen — keep tabs compact.
            FxPremiumSegmentedTabs(
              tabs: const ['Transactions', 'Account statement'],
              selectedIndex: _tab.index,
              onChanged: (i) =>
                  setState(() => _tab = LedgerHubTab.values[i]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: listBottomPad),
                child: _tab == LedgerHubTab.transactions
                    ? const TransactionListScreen(
                        inShell: true,
                        embeddedInHub: true,
                      )
                    : const AccountStatementScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
