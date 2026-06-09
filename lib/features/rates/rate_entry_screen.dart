import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/domain/models/fx_currency.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RateEntryScreen extends ConsumerStatefulWidget {
  const RateEntryScreen({super.key});

  @override
  ConsumerState<RateEntryScreen> createState() => _RateEntryScreenState();
}

class _RateEntryScreenState extends ConsumerState<RateEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _buyCtrl = TextEditingController();
  final _sellCtrl = TextEditingController();
  String? _currencyId;
  bool _busy = false;

  @override
  void dispose() {
    _buyCtrl.dispose();
    _sellCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final currenciesAsync = ref.watch(currenciesProvider);

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: Text('New rate', style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Profile error: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not configured.'));
          }
          return currenciesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Unable to load currencies: $e')),
            data: (currencies) {
              final fxCurrencies = currencies.where((c) => !c.isBase).toList();
              _currencyId ??= fxCurrencies.firstOrNull?.id;
              return Column(
                children: [
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            'Set buy and sell rates for a foreign currency.',
                            style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                          ),
                          const SizedBox(height: 24),
                          Text('Currency', style: AppTypography.labelCaps(context.fx.outline, context: context)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey(_currencyId),
                            initialValue: _currencyId,
                            dropdownColor: context.fx.surfaceContainerHigh,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.fx.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                borderSide: BorderSide(color: context.fx.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                                borderSide: BorderSide(color: context.fx.outlineVariant),
                              ),
                            ),
                            items: fxCurrencies
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text('${c.code} · ${c.name}', style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy ? null : (v) => setState(() => _currencyId = v),
                            validator: (v) => v == null ? 'Select currency' : null,
                          ),
                          const SizedBox(height: 20),
                          FxObsidianFormField(
                            label: 'Buy rate (PKR)',
                            controller: _buyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            enabled: !_busy,
                            validator: _positiveRate,
                            accentTertiary: true,
                          ),
                          const SizedBox(height: 16),
                          FxObsidianFormField(
                            label: 'Sell rate (PKR)',
                            controller: _sellCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            enabled: !_busy,
                            validator: _positiveRate,
                            accentTertiary: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  FxObsidianActionBar(
                    busy: _busy,
                    saveLabel: 'Save rate',
                    onCancel: _busy ? () {} : () => context.pop(),
                    onSave: _busy ? () {} : () => _save(profile.branchId, fxCurrencies),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String? _positiveRate(String? v) {
    final n = double.tryParse(v ?? '');
    if (n == null || n <= 0) return 'Enter a positive rate';
    return null;
  }

  String? _validateSpread() {
    final buy = double.tryParse(_buyCtrl.text);
    final sell = double.tryParse(_sellCtrl.text);
    if (buy != null && sell != null && buy > sell) {
      return 'Buy rate should not exceed sell rate';
    }
    return null;
  }

  Future<void> _save(String branchId, List<FxCurrency> currencies) async {
    if (!_formKey.currentState!.validate()) return;
    final spreadError = _validateSpread();
    if (spreadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(spreadError)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(rateRepositoryProvider).createRate(
            branchId: branchId,
            currencyId: _currencyId!,
            buyRate: double.parse(_buyCtrl.text),
            sellRate: double.parse(_sellCtrl.text),
          );
      ref.invalidate(ratesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rate saved.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
