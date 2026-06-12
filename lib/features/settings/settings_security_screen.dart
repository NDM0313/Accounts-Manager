import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/security/app_lock_service.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/fx_settings_section.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_settings_row.dart';
import 'package:accounts_manager/core/utils/report_export.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

final appLockServiceProvider = Provider<AppLockService>(
  (ref) => AppLockService(),
);

class SettingsSecurityScreen extends ConsumerStatefulWidget {
  const SettingsSecurityScreen({super.key});

  @override
  ConsumerState<SettingsSecurityScreen> createState() =>
      _SettingsSecurityScreenState();
}

class _SettingsSecurityScreenState extends ConsumerState<SettingsSecurityScreen> {
  bool _biometric = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ref.read(appLockServiceProvider).isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometric = enabled;
        _loading = false;
      });
    }
  }

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

  Future<void> _changePin() async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New PIN'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm PIN'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true && pinCtrl.text == confirmCtrl.text && pinCtrl.text.length >= 4) {
      await ref.read(appLockServiceProvider).setPin(pinCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN updated')),
        );
      }
    }
    pinCtrl.dispose();
    confirmCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).value;

    return FxPremiumScaffold(
      title: Text(
        'Settings',
        style: AppTypography.headlineSm(context.fx.primary, context: context),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              children: [
                FxPremiumCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: context.fx.surfaceContainerHigh,
                        child: Text(
                          (profile?.fullName ?? 'U')
                              .split(' ')
                              .map((p) => p.isNotEmpty ? p[0] : '')
                              .take(2)
                              .join()
                              .toUpperCase(),
                          style: AppTypography.headlineSm(
                            context.fx.onPrimary,
                            context: context,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.fullName ?? 'User',
                              style: AppTypography.headlineSm(
                                context.fx.primary,
                                context: context,
                              ),
                            ),
                            Text(
                              profile?.email ?? '',
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
                ),
                const SizedBox(height: 24),
                FxSettingsSection(
                  title: 'Security',
                  children: [
                    if (!kIsWeb)
                      SwitchListTile(
                        secondary: Icon(
                          Icons.face,
                          color: context.fx.secondary,
                        ),
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
                    ListTile(
                      leading: Icon(
                        Icons.lock_reset,
                        color: context.fx.secondary,
                      ),
                      title: const Text('Change Pin'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _changePin,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FxSettingsSection(
                  title: 'Preferences',
                  children: [
                    SwitchListTile(
                      secondary: Icon(
                        Icons.dark_mode_outlined,
                        color: context.fx.secondary,
                      ),
                      title: const Text('Dark theme'),
                      subtitle: const Text('Executive FX dark mode'),
                      value: ref.watch(themeModeProvider) == ThemeMode.dark,
                      onChanged: (_) =>
                          ref.read(themeModeProvider.notifier).toggle(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FxSettingsSection(
                  title: 'Data Management',
                  children: [
                    FxSettingsRow(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Backup to Cloud',
                      subtitle: 'Managed via Supabase storage',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Backup sync uses branch storage bucket'),
                          ),
                        );
                      },
                    ),
                    FxSettingsRow(
                      icon: Icons.sim_card_download_outlined,
                      title: 'Export All Data (JSON/CSV)',
                      onTap: () => _exportTrialBalance(context, ref),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
