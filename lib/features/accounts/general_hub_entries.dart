import 'package:flutter/material.dart';

class GeneralHubEntry {
  const GeneralHubEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
}

const generalHubEntries = [
  GeneralHubEntry(
    title: 'Chart of Accounts',
    subtitle: 'Account structure & management',
    icon: Icons.account_tree_outlined,
    route: '/accounts',
  ),
  GeneralHubEntry(
    title: 'Account Ledger (GL)',
    subtitle: 'Movements for a selected account',
    icon: Icons.menu_book_outlined,
    route: '/reports/general-ledger',
  ),
  GeneralHubEntry(
    title: 'Party Directory',
    subtitle: 'Customers, agents, suppliers + balances',
    icon: Icons.people_outline,
    route: '/parties',
  ),
  GeneralHubEntry(
    title: 'Roznamcha',
    subtitle: 'Daily cash & bank book',
    icon: Icons.menu_book,
    route: '/reports/roznamcha',
  ),
  GeneralHubEntry(
    title: 'Expenses',
    subtitle: 'Draft → post → reverse expenses',
    icon: Icons.receipt_long_outlined,
    route: '/expenses',
  ),
  GeneralHubEntry(
    title: 'Add Cash / Bank',
    subtitle: 'Create with optional opening',
    icon: Icons.account_balance,
    route: '/accounts/new-cash',
  ),
  GeneralHubEntry(
    title: 'New Party',
    subtitle: 'Profile + optional opening',
    icon: Icons.person_add_outlined,
    route: '/parties/new',
  ),
  GeneralHubEntry(
    title: 'Opening Balances',
    subtitle: 'Starting balances setup',
    icon: Icons.account_balance_wallet_outlined,
    route: '/opening-balances',
  ),
  GeneralHubEntry(
    title: 'Import Payment Slip',
    subtitle: 'OCR review → confirm post',
    icon: Icons.document_scanner_outlined,
    route: '/slips/import',
  ),
  GeneralHubEntry(
    title: 'Trial Balance',
    subtitle: 'Balances as of date',
    icon: Icons.balance_outlined,
    route: '/reports/trial-balance',
  ),
  GeneralHubEntry(
    title: 'Profit & Loss',
    subtitle: 'Income & expenses',
    icon: Icons.trending_up_outlined,
    route: '/reports/profit-loss',
  ),
  GeneralHubEntry(
    title: 'Balance Sheet',
    subtitle: 'Assets & liabilities',
    icon: Icons.account_balance_outlined,
    route: '/reports/balance-sheet',
  ),
  GeneralHubEntry(
    title: 'Currency Position',
    subtitle: 'FX exposure',
    icon: Icons.public_outlined,
    route: '/reports/currency-position',
  ),
  GeneralHubEntry(
    title: 'Audit Log',
    subtitle: 'Change history',
    icon: Icons.history_outlined,
    route: '/audit',
  ),
  GeneralHubEntry(
    title: 'Team Messages',
    subtitle: 'Internal staff chat',
    icon: Icons.chat_bubble_outline,
    route: '/messages',
  ),
  GeneralHubEntry(
    title: 'Rate Board',
    subtitle: 'Reference FX rates',
    icon: Icons.currency_exchange_outlined,
    route: '/rates',
  ),
  GeneralHubEntry(
    title: 'FX Deals',
    subtitle: 'Order first, source later',
    icon: Icons.handshake_outlined,
    route: '/deals',
  ),
  GeneralHubEntry(
    title: 'Remittance',
    subtitle: 'Hawala / payout tracking',
    icon: Icons.send_outlined,
    route: '/remittance',
  ),
  GeneralHubEntry(
    title: 'Currencies',
    subtitle: 'Add & manage FX',
    icon: Icons.currency_exchange,
    route: '/settings/currencies',
  ),
];
