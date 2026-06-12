import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_shell.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_currency.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final allCurrenciesProvider = FutureProvider<List<FxCurrency>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) return [];
  return ref.read(currencyRepositoryProvider).fetchAllCurrencies();
});

class CurrencyManagementScreen extends ConsumerStatefulWidget {
  const CurrencyManagementScreen({super.key});

  @override
  ConsumerState<CurrencyManagementScreen> createState() =>
      _CurrencyManagementScreenState();
}

class _CurrencyManagementScreenState
    extends ConsumerState<CurrencyManagementScreen> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _symbolCtrl = TextEditingController();
  final _decimalsCtrl = TextEditingController(text: '2');
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _symbolCtrl.dispose();
    _decimalsCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCurrency() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    final decimals = int.tryParse(_decimalsCtrl.text.trim()) ?? 2;
    if (code.length < 2 || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter currency code (2+) and name.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(currencyRepositoryProvider)
          .createCurrency(
            code: code,
            name: name,
            symbol: _symbolCtrl.text.trim(),
            decimalPlaces: decimals,
          );
      ref.invalidate(currenciesProvider);
      ref.invalidate(allCurrenciesProvider);
      ref.invalidate(accountsProvider);
      _codeCtrl.clear();
      _nameCtrl.clear();
      _symbolCtrl.clear();
      _decimalsCtrl.text = '2';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Currency $code added with cash account.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deactivate(FxCurrency c) async {
    if (c.isBase) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate ${c.code}?'),
        content: const Text(
          'Currency will be hidden from new transactions. Cannot deactivate if used on posted records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(currencyRepositoryProvider).deactivateCurrency(c.code);
      ref.invalidate(currenciesProvider);
      ref.invalidate(allCurrenciesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${c.code} deactivated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currenciesAsync = ref.watch(allCurrenciesProvider);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Currencies'),
        backgroundColor: context.fx.background,
      ),
      body: FxObsidianPage(
        child: ListView(
          children: [
            Text(
              'Manage currencies. PKR is the base currency. Each new currency gets a cash account in the chart of accounts.',
              style: AppTypography.bodyMd(
                context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 12),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.fx.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: context.fx.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FxSectionLabel(label: 'Add currency'),
                  const SizedBox(height: 12),
                  FxObsidianFormField(
                    label: 'Code (e.g. GBP)',
                    controller: _codeCtrl,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 12),
                  FxObsidianFormField(
                    label: 'Name',
                    controller: _nameCtrl,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 12),
                  FxObsidianFormField(
                    label: 'Symbol (optional)',
                    controller: _symbolCtrl,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 12),
                  FxObsidianFormField(
                    label: 'Decimal places',
                    controller: _decimalsCtrl,
                    keyboardType: TextInputType.number,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _addCurrency,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add currency'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const FxSectionLabel(label: 'All currencies'),
            const SizedBox(height: 8),
            currenciesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (currencies) => Container(
                decoration: BoxDecoration(
                  color: context.fx.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(color: context.fx.outlineVariant),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < currencies.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: context.fx.outlineVariant),
                      ListTile(
                        title: Text(
                          '${currencies[i].code} — ${currencies[i].name}',
                          style: AppTypography.bodyMd(
                            context.fx.onSurface,
                            context: context,
                          ),
                        ),
                        subtitle: Text(
                          currencies[i].isBase
                              ? 'Base currency · ${currencies[i].decimalPlaces} decimals'
                              : '${currencies[i].isActive ? 'Active' : 'Inactive'} · ${currencies[i].decimalPlaces} decimals · sym ${currencies[i].symbol.isEmpty ? '—' : currencies[i].symbol}',
                          style: AppTypography.bodyMd(
                            context.fx.onSurfaceVariant,
                            context: context,
                          ).copyWith(fontSize: 12),
                        ),
                        trailing: currencies[i].isBase
                            ? null
                            : currencies[i].isActive
                            ? IconButton(
                                icon: Icon(
                                  Icons.toggle_on,
                                  color: context.fx.tertiary,
                                ),
                                tooltip: 'Deactivate',
                                onPressed: () => _deactivate(currencies[i]),
                              )
                            : Icon(
                                Icons.toggle_off,
                                color: context.fx.onSurfaceVariant,
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
