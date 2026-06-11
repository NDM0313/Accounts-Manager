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
    title: 'Opening Balances',
    subtitle: 'Starting balances setup',
    icon: Icons.account_balance_wallet_outlined,
    route: '/opening-balances',
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
    title: 'Chart of Accounts',
    subtitle: 'Read-only COA',
    icon: Icons.account_tree_outlined,
    route: '/accounts',
  ),
  GeneralHubEntry(
    title: 'Parties',
    subtitle: 'Customers & agents',
    icon: Icons.people_outline,
    route: '/parties',
  ),
  GeneralHubEntry(
    title: 'Party Statements',
    subtitle: 'Tap party → ledger',
    icon: Icons.receipt_long_outlined,
    route: '/parties',
  ),
  GeneralHubEntry(
    title: 'Journal Entries',
    subtitle: 'General ledger',
    icon: Icons.menu_book_outlined,
    route: '/reports/general-ledger',
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
    title: 'Audit Logs',
    subtitle: 'Change history',
    icon: Icons.history_outlined,
    route: '/audit',
  ),
  GeneralHubEntry(
    title: 'Currencies',
    subtitle: 'Add & manage FX',
    icon: Icons.currency_exchange,
    route: '/settings/currencies',
  ),
];
