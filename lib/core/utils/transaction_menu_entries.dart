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

/// Grouped New Transaction menu entries for the ledger bottom sheet.
List<TransactionMenuGroup> buildTransactionMenuGroups() {
  return [
    TransactionMenuGroup(
      title: 'Common',
      entries: [
        TransactionMenuEntry(
          label: TransactionDraftMode.customerReceipt.menuLabel,
          icon: Icons.call_received_outlined,
          route: '/transactions/new?type=settlement_receive&mode=customer_receipt',
        ),
        TransactionMenuEntry(
          label: TransactionDraftMode.agentPayment.menuLabel,
          icon: Icons.send_outlined,
          route: '/transactions/new?type=settlement_send&mode=agent_payment',
        ),
        const TransactionMenuEntry(
          label: 'Expense',
          icon: Icons.receipt_long_outlined,
          route: '/transactions/new?type=expense',
        ),
        const TransactionMenuEntry(
          label: 'Account Transfer',
          icon: Icons.swap_horiz,
          route: '/transactions/new?type=account_transfer',
        ),
      ],
    ),
    TransactionMenuGroup(
      title: 'Remittance',
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
      ],
    ),
    TransactionMenuGroup(
      title: 'FX Deals',
      entries: [
        if (FeatureFlags.dealsWorkflowEnabled)
          const TransactionMenuEntry(
            label: 'Customer FX Deal',
            icon: Icons.handshake_outlined,
            route: '/deals/new',
          ),
        const TransactionMenuEntry(
          label: 'Currency Buy',
          icon: Icons.add_shopping_cart_outlined,
          route: '/transactions/new?type=currency_buy',
        ),
        const TransactionMenuEntry(
          label: 'Currency Sell',
          icon: Icons.payments_outlined,
          route: '/transactions/new?type=currency_sell',
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
      ],
    ),
    TransactionMenuGroup(
      title: 'Advanced',
      entries: [
        const TransactionMenuEntry(
          label: 'Settlement Receive',
          icon: Icons.call_received_outlined,
          route: '/transactions/new?type=settlement_receive',
        ),
        const TransactionMenuEntry(
          label: 'Settlement Send',
          icon: Icons.send_outlined,
          route: '/transactions/new?type=settlement_send',
        ),
        TransactionMenuEntry(
          label: TransactionDraftMode.agentReturn.menuLabel,
          icon: Icons.reply_outlined,
          route: '/transactions/new?type=settlement_receive&mode=agent_return',
        ),
        TransactionMenuEntry(
          label: TransactionDraftMode.customerRefund.menuLabel,
          icon: Icons.undo_outlined,
          route: '/transactions/new?type=settlement_send&mode=customer_refund',
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
