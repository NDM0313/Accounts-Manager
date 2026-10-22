import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_hub_tile.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_responsive_hub_grid.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/features/accounts/general_hub_entries.dart';
import 'package:accounts_manager/features/accounts/hub_icon_keep.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GeneralHubScreen extends StatelessWidget {
  const GeneralHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final iconKeep = keepAccountsHubIcons();

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
      body: FxContentContainer(
        child: ListView(
          children: [
            Offstage(child: Row(children: iconKeep)),
            const FxPageTitleBlock(
              title: 'Accounts hub',
              subtitle:
                  'Chart of accounts, parties, journals, and reports.',
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Home'),
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
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
