import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_hub_tile.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_responsive_hub_grid.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/features/accounts/general_hub_entries.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GeneralHubScreen extends StatelessWidget {
  const GeneralHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Accounts'),
        backgroundColor: context.fx.background,
      ),
      body: FxObsidianPage(
        child: ListView(
          children: [
            Text(
              'Chart of accounts, parties, journals, and reports.',
              style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
            ),
            const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }
}
