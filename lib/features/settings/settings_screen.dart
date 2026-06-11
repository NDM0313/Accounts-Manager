import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/env.dart';
import 'package:accounts_manager/core/utils/report_export.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_settings_row.dart';
import 'package:accounts_manager/features/accounts/general_hub_entries.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final branchAsync = ref.watch(branchContextProvider);

    return FxObsidianPage(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
        16,
        MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile,
        88,
      ),
      child: ListView(
        children: [
          profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
            data: (profile) {
              final name = profile?.fullName ?? 'User';
              final email = profile?.email ?? '';
              final branchLabel = branchAsync.whenOrNull(
                data: (ctx) => ctx != null ? '${ctx.companyName} · ${ctx.branchName}' : null,
              );
              final initials = name.isNotEmpty
                  ? name.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase()
                  : '?';
              return Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: context.fx.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(color: context.fx.outlineVariant),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: context.fx.primary,
                      child: Text(
                        initials,
                        style: AppTypography.headlineMd(context.fx.onPrimary, context: context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: AppTypography.headlineMd(Theme.of(context).colorScheme.onSurface, context: context)),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context),
                            ),
                          if (branchLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              branchLabel,
                              style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          FxSectionLabel(label: 'General'),
          const SizedBox(height: 8),
          _SettingsGroup(
            children: [
              for (var i = 0; i < generalHubEntries.length; i++)
                FxSettingsRow(
                  icon: generalHubEntries[i].icon,
                  title: generalHubEntries[i].title,
                  subtitle: generalHubEntries[i].subtitle,
                  onTap: () => context.push(generalHubEntries[i].route),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FxSectionLabel(label: 'Configuration'),
          const SizedBox(height: 8),
          _SettingsGroup(
            children: [
              FxSettingsRow(
                icon: Icons.currency_exchange,
                title: 'Currencies',
                subtitle: 'Add PKR, USD, AED, GBP…',
                onTap: () => context.push('/settings/currencies'),
              ),
              FxSettingsRow(
                icon: Icons.tune_outlined,
                title: 'Currency Settings',
                subtitle: 'Base currency & display/reporting currency',
                onTap: () => context.push('/settings/currency-settings'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FxSectionLabel(label: 'Operations'),
          const SizedBox(height: 8),
          _SettingsGroup(
            children: [
              FxSettingsRow(
                icon: Icons.lock_clock_outlined,
                title: 'Daily Closing',
                subtitle: 'Close today\'s ledger session',
                onTap: () => context.push('/closing'),
              ),
              FxSettingsRow(
                icon: Icons.business_outlined,
                title: 'Workspace',
                subtitle: 'Company and branch',
                onTap: () => context.push('/branch'),
              ),
              FxSettingsRow(
                icon: Icons.dark_mode_outlined,
                title: 'Appearance',
                subtitle: _themeLabel(themeMode),
                trailing: Switch(
                  value: themeMode == ThemeMode.dark,
                  onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                ),
                onTap: () => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FxSectionLabel(label: 'Ledger setup'),
          const SizedBox(height: 8),
          _SettingsGroup(
            children: [
              FxSettingsRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Opening Balances',
                subtitle: 'Enter starting cash, FX & party balances',
                onTap: () => context.push('/opening-balances'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FxSectionLabel(label: 'System'),
          const SizedBox(height: 8),
          _SettingsGroup(
            children: [
              FxSettingsRow(
                icon: Icons.cloud_outlined,
                title: 'Supabase project',
                subtitle: Env.supabaseProjectRef,
                trailing: const SizedBox.shrink(),
              ),
              FxSettingsRow(
                icon: Icons.backup_outlined,
                title: 'Backup & restore',
                subtitle: 'Export trial balance CSV',
                onTap: () => _exportTrialBalance(context, ref),
              ),
              FxSettingsRow(
                icon: Icons.security_outlined,
                title: 'Security',
                subtitle: 'Session & permissions info',
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Security settings managed via Supabase auth and RLS.')),
                ),
              ),
              FxSettingsRow(
                icon: Icons.logout,
                title: 'Sign out',
                subtitle: 'End session',
                onTap: () => ref.read(authControllerProvider).signOut(),
                trailing: const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'Dark (Obsidian)',
        ThemeMode.light => 'Light (Precision Ledger)',
        ThemeMode.system => 'System',
      };

  Future<void> _exportTrialBalance(BuildContext context, WidgetRef ref) async {
    try {
      final rows = await ref.read(trialBalanceProvider.future);
      if (!context.mounted) return;
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No trial balance data to export.')),
        );
        return;
      }
      await SharePlus.instance.share(ShareParams(
        text: formatTrialBalanceCsv(rows),
        subject: 'FX Ledger Trial Balance',
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.fx.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}
