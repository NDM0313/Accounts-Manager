import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_settings_row.dart';
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
            FxSectionLabel(label: 'General'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: context.fx.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: context.fx.outlineVariant),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < generalHubEntries.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: context.fx.outlineVariant),
                    FxSettingsRow(
                      icon: generalHubEntries[i].icon,
                      title: generalHubEntries[i].title,
                      subtitle: generalHubEntries[i].subtitle,
                      onTap: () => context.push(generalHubEntries[i].route),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
