import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/env.dart';
import 'package:accounts_manager/core/utils/report_export.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_settings_section.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/settings/settings_security_screen.dart'
    show appLockServiceProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometric = false;

  @override
  void initState() {
    super.initState();
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final enabled = await ref.read(appLockServiceProvider).isBiometricEnabled();
    if (mounted) setState(() => _biometric = enabled);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final branchAsync = ref.watch(branchContextProvider);
    final horizontal = MediaQuery.sizeOf(context).width >= 900
        ? AppSpacing.marginDesktop
        : AppSpacing.marginMobile;

    return FxStitchScaffold(
      padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 88),
      scrollable: false,
      child: ListView(
        children: [
          profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const SizedBox.shrink(),
            data: (profile) {
              final name = profile?.fullName ?? 'User';
              final role = branchAsync.whenOrNull(
                    data: (ctx) => ctx != null
                        ? '${ctx.companyName} · ${ctx.branchName}'
                        : null,
                  ) ??
                  profile?.email ??
                  '';
              final initials = name.isNotEmpty
                  ? name
                      .split(' ')
                      .map((p) => p.isNotEmpty ? p[0] : '')
                      .take(2)
                      .join()
                      .toUpperCase()
                  : '?';
              return FxStitchCard(
                color: context.fx.surfaceContainer,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.fx.secondary,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: context.fx.secondaryContainer,
                        child: Text(
                          initials,
                          style: AppTypography.headlineSm(
                            context.fx.onSecondaryContainer,
                            context: context,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTypography.headlineSm(
                              context.fx.primary,
                              context: context,
                            ),
                          ),
                          Text(
                            role,
                            style: AppTypography.bodySm(
                              context.fx.onSurfaceVariant,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          FxStitchSettingsSection(
            title: 'Security',
            children: [
              if (!kIsWeb)
                SwitchListTile(
                  secondary: Icon(Icons.face, color: context.fx.secondary),
                  title: const Text('Face ID / Pin Unlock'),
                  value: _biometric,
                  onChanged: (v) async {
                    if (v) {
                      final ok = await ref
                          .read(appLockServiceProvider)
                          .authenticateWithBiometric();
                      if (!ok && mounted) return;
                    }
                    await ref
                        .read(appLockServiceProvider)
                        .setBiometricEnabled(v);
                    setState(() => _biometric = v);
                  },
                ),
              FxStitchSettingsTile(
                icon: Icons.lock_reset,
                title: 'Change Pin',
                onTap: () => context.push('/settings/security'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FxStitchSettingsSection(
            title: 'Data Management',
            children: [
              FxStitchSettingsTile(
                icon: Icons.cloud_upload_outlined,
                title: 'Backup to Cloud',
                subtitle: 'Managed via Supabase storage',
                trailing: Icon(Icons.sync, color: context.fx.outline, size: 20),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backup sync uses branch storage bucket'),
                    ),
                  );
                },
              ),
              FxStitchSettingsTile(
                icon: Icons.sim_card_download_outlined,
                title: 'Export All Data (JSON/CSV)',
                onTap: () => _exportTrialBalance(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FxStitchSettingsSection(
            title: 'Preferences',
            children: [
              FxStitchSettingsTile(
                icon: Icons.language,
                title: 'Language',
                trailing: Text(
                  'English (US)',
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                onTap: () {},
              ),
              FxStitchSettingsTile(
                icon: Icons.light_mode_outlined,
                title: 'Theme',
                trailing: Text(
                  _themeLabel(themeMode),
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                onTap: () => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FxStitchSettingsSection(
            title: 'About',
            children: [
              FxStitchSettingsTile(
                icon: Icons.info_outline,
                title: 'Version',
                trailing: Text(
                  '2.4.0',
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                onTap: () {},
              ),
              FxStitchSettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          FxStitchSettingsSection(
            title: 'Workspace',
            children: [
              FxStitchSettingsTile(
                icon: Icons.currency_exchange,
                title: 'Currencies',
                subtitle: 'Add PKR, USD, AED, GBP…',
                onTap: () => context.push('/settings/currencies'),
              ),
              FxStitchSettingsTile(
                icon: Icons.tune_outlined,
                title: 'Currency Settings',
                subtitle: 'Base & display currency',
                onTap: () => context.push('/settings/currency-settings'),
              ),
              FxStitchSettingsTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Opening Balances',
                subtitle: 'Starting cash, FX & party balances',
                onTap: () => context.push('/opening-balances'),
              ),
              FxStitchSettingsTile(
                icon: Icons.business_outlined,
                title: 'Workspace',
                subtitle: 'Company and branch',
                onTap: () => context.push('/branch'),
              ),
              FxStitchSettingsTile(
                icon: Icons.lock_clock_outlined,
                title: 'Daily Closing',
                subtitle: 'Close today\'s ledger session',
                onTap: () => context.push('/closing'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FxStitchSettingsSection(
            title: 'System',
            children: [
              FxStitchSettingsTile(
                icon: Icons.cloud_outlined,
                title: 'Supabase project',
                subtitle: Env.supabaseProjectRef,
                trailing: const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(authControllerProvider).signOut(),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.fx.error,
              side: BorderSide(color: context.fx.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'Dark Mode',
        ThemeMode.light => 'Light Mode',
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
      await SharePlus.instance.share(
        ShareParams(
          text: formatTrialBalanceCsv(rows),
          subject: 'FX Ledger Trial Balance',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}
