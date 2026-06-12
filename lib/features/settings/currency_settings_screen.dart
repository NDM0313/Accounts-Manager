import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/display_currency_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CurrencySettingsScreen extends ConsumerWidget {
  const CurrencySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountingAsync = ref.watch(companyAccountingContextProvider);
    final displayCode = ref.watch(displayCurrencyCodeProvider);
    final currenciesAsync = ref.watch(currenciesProvider);

    return FxPageScaffold(
      fallbackRoute: '/settings',
      title: const Text('Currency Settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FxSectionLabel(label: 'Accounting base currency'),
          const SizedBox(height: 8),
          accountingAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (ctx) => _InfoCard(
              children: [
                ListTile(
                  title: const Text('Base currency'),
                  subtitle: Text(
                    '${ctx.baseCurrencyCode} — used for journals, trial balance, and posting.',
                    style: AppTypography.bodyMd(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ),
                  ),
                  trailing: Text(
                    ctx.baseCurrencyCode,
                    style: AppTypography.headlineMd(
                      context.fx.primary,
                      context: context,
                    ),
                  ),
                ),
                if (ctx.hasPostedTransactions)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Base currency affects accounting and cannot be changed after postings without migration/revaluation.',
                      style: AppTypography.bodyMd(
                        context.fx.error,
                        context: context,
                      ).copyWith(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const FxSectionLabel(label: 'Default display / reporting currency'),
          const SizedBox(height: 8),
          Text(
            'Dashboard and reports can show converted values. Accounting stays in base currency.',
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          const SizedBox(height: 12),
          currenciesAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (currencies) {
              final active = currencies.where((c) => c.isActive).toList();
              return DropdownButtonFormField<String>(
                initialValue: active.any((c) => c.code == displayCode)
                    ? displayCode
                    : active.firstOrNull?.code,
                decoration: const InputDecoration(
                  labelText: 'Display currency',
                ),
                items: active
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.code,
                        child: Text('${c.code} — ${c.name}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    ref
                        .read(displayCurrencyCodeProvider.notifier)
                        .setCurrency(v);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.push('/settings/currencies'),
            icon: const Icon(Icons.add),
            label: const Text('Manage currencies (add AFN, etc.)'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}
