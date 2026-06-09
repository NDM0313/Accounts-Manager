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
    subtitle: 'Read-only COA from fx_accounts',
    icon: Icons.account_tree_outlined,
    route: '/accounts',
  ),
  GeneralHubEntry(
    title: 'Parties',
    subtitle: 'Customers, agents, settlements',
    icon: Icons.people_outline,
    route: '/parties',
  ),
  GeneralHubEntry(
    title: 'Agent Ledger',
    subtitle: 'Settlement agents',
    icon: Icons.support_agent_outlined,
    route: '/parties/agents',
  ),
  GeneralHubEntry(
    title: 'Manual Journal',
    subtitle: 'Post balanced journal entry',
    icon: Icons.edit_note_outlined,
    route: '/journal/new',
  ),
  GeneralHubEntry(
    title: 'Currency Rates',
    subtitle: 'Manage buy/sell rates',
    icon: Icons.currency_exchange,
    route: '/rates',
  ),
  GeneralHubEntry(
    title: 'Reports',
    subtitle: 'Trial balance, P&L, and more',
    icon: Icons.assessment_outlined,
    route: '/reports',
  ),
];
