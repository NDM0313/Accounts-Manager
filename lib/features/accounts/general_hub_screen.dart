import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_hub_tile.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_responsive_hub_grid.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/features/accounts/general_hub_entries.dart';
import 'package:accounts_manager/features/accounts/hub_icon_keep.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GeneralHubScreen extends StatelessWidget {
  const GeneralHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Must run in release too — tree-shake-icons only keeps Icon(Icons.x) AST refs.
    keepAccountsHubIcons();

    return FxPremiumScaffold(
      title: const Text('Accounts'),
      fallbackRoute: '/',
      actions: [
        IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go('/'),
        ),
      ],
      bottomBar: NavigationBar(
        selectedIndex: 2,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
            case 1:
              context.go('/deals');
            case 2:
              break; // already on accounts hub
            case 3:
              context.go('/ledger');
            case 4:
              context.go('/settings');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake),
            label: 'Deals',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Ledger',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      body: FxObsidianPage(
        child: ListView(
          children: [
            Text(
              'Chart of accounts, parties, journals, and reports.',
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Home'),
              ),
            ),
            const SizedBox(height: 8),
            const FxSectionLabel(label: 'General'),
            const SizedBox(height: 12),
            FxResponsiveHubGrid(
              itemCount: generalHubEntries.length,
              itemBuilder: (context, i) {
                final entry = generalHubEntries[i];
                return FxHubTile(
                  title: entry.title,
                  subtitle: entry.subtitle,
                  icon: entry.icon,
                  compact: true,
                  onTap: () => context.push(entry.route),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
