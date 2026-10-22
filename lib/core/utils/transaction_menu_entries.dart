import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/transaction_draft_mode.dart';
import 'package:flutter/material.dart';

class TransactionMenuGroup {
  const TransactionMenuGroup({required this.title, required this.entries});

  final String title;
  final List<TransactionMenuEntry> entries;
}

class TransactionMenuEntry {
  const TransactionMenuEntry({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

/// Compact primary actions + More — no duplicate receive/pay forms.
List<TransactionMenuGroup> buildTransactionMenuGroups() {
  return [
    TransactionMenuGroup(
      title: 'Primary',
      entries: [
        const TransactionMenuEntry(
          label: 'Scan Slip',
          icon: Icons.document_scanner_outlined,
          route: '/slips/import',
        ),
        const TransactionMenuEntry(
          label: 'Receive Money',
          icon: Icons.call_received_outlined,
          route: '/transactions/money?direction=receive&mode=customer_receipt',
        ),
        const TransactionMenuEntry(
          label: 'Pay Money',
          icon: Icons.send_outlined,
          route: '/transactions/money?direction=pay&mode=agent_payment',
        ),
        const TransactionMenuEntry(
          label: 'Buy Currency',
          icon: Icons.add_shopping_cart_outlined,
          route: '/transactions/new?type=currency_buy',
        ),
        const TransactionMenuEntry(
          label: 'Sell Currency',
          icon: Icons.payments_outlined,
          route: '/transactions/new?type=currency_sell',
        ),
        if (FeatureFlags.dealsWorkflowEnabled)
          const TransactionMenuEntry(
            label: 'New Deal',
            icon: Icons.handshake_outlined,
            route: '/deals/new',
          ),
        const TransactionMenuEntry(
          label: 'Transfer Between Accounts',
          icon: Icons.swap_horiz,
          route: '/transactions/new?type=account_transfer',
        ),
        const TransactionMenuEntry(
          label: 'Expense',
          icon: Icons.receipt_long_outlined,
          route: '/transactions/new?type=expense',
        ),
      ],
    ),
    TransactionMenuGroup(
      title: 'More',
      entries: [
        if (FeatureFlags.remittanceWorkflowEnabled)
          const TransactionMenuEntry(
            label: 'New Remittance Order',
            icon: Icons.public_outlined,
            route: '/remittance/new',
          ),
        if (FeatureFlags.remittanceWorkflowEnabled)
          const TransactionMenuEntry(
            label: 'Remittance List',
            icon: Icons.list_alt_outlined,
            route: '/remittance',
          ),
        const TransactionMenuEntry(
          label: 'Cross Currency',
          icon: Icons.currency_exchange,
          route: '/transactions/new?type=cross_currency',
        ),
        const TransactionMenuEntry(
          label: 'Chained Exchange',
          icon: Icons.link,
          route: '/transactions/chained-exchange',
        ),
        TransactionMenuEntry(
          label: TransactionDraftMode.agentReturn.menuLabel,
          icon: Icons.reply_outlined,
          route: '/transactions/money?direction=receive&mode=agent_return',
        ),
        TransactionMenuEntry(
          label: TransactionDraftMode.customerRefund.menuLabel,
          icon: Icons.undo_outlined,
          route: '/transactions/money?direction=pay&mode=customer_refund',
        ),
        TransactionMenuEntry(
          label: FxTransactionType.revaluation.label,
          icon: Icons.trending_up,
          route: '/transactions/new?type=revaluation',
        ),
        const TransactionMenuEntry(
          label: 'Opening Balances',
          icon: Icons.account_balance_wallet_outlined,
          route: '/opening-balances/wizard',
        ),
      ],
    ),
  ];
}

/// Flat labels for tests.
List<String> transactionMenuLabels() {
  return buildTransactionMenuGroups()
      .expand((g) => g.entries.map((e) => e.label))
      .toList();
}
