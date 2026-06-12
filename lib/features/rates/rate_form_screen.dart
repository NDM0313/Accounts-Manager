import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/core/utils/rate_source_labels.dart';
import 'package:accounts_manager/data/repositories/rate_repository.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum RateFormMode { create, editVersion, duplicate }

/// Prefilled forms (edit/duplicate) default effective time to now, not the source row.
bool rateFormUsesNowForEffectiveAt(RateFormMode mode) =>
    mode == RateFormMode.editVersion || mode == RateFormMode.duplicate;

/// User-facing message when effective_at collides with an existing row.
const rateFormEffectiveAtConflictMessage =
    'A rate already exists for this currency at that date/time. Pick a different effective time.';

/// Unified rate form: new, edit (new version), duplicate.
class RateFormScreen extends ConsumerStatefulWidget {
  const RateFormScreen({super.key, this.rateId, this.duplicateFromId});

  final String? rateId;
  final String? duplicateFromId;

  RateFormMode get mode {
    if (rateId != null) return RateFormMode.editVersion;
    if (duplicateFromId != null) return RateFormMode.duplicate;
    return RateFormMode.create;
  }

  @override
  ConsumerState<RateFormScreen> createState() => _RateFormScreenState();
}

class _RateFormScreenState extends ConsumerState<RateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _midCtrl = TextEditingController();
  final _buyCtrl = TextEditingController();
  final _sellCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _currencyId;
  String? _source;
  DateTime? _effectiveAt;
  DateTime? _previousEffectiveAt;
  bool _busy = false;
  bool _loaded = false;
  double _halfSpread = 0.5;

  static const _sources = ['manual', 'import', 'market', 'api'];

  @override
  void dispose() {
    _midCtrl.dispose();
    _buyCtrl.dispose();
    _sellCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFromId(String id) async {
    if (_loaded) return;
    final rate = await ref.read(rateRepositoryProvider).fetchRateById(id);
    if (rate == null || !mounted) return;
    setState(() {
      _currencyId = rate.currencyId;
      _midCtrl.text = rate.referenceRate.toStringAsFixed(4);
      _buyCtrl.text = rate.buyRate.toString();
      _sellCtrl.text = rate.sellRate.toString();
      _halfSpread = (rate.sellRate - rate.buyRate) / 2;
      _source = rate.source;
      _notesCtrl.text = rate.notes ?? '';
      if (widget.mode == RateFormMode.editVersion) {
        _previousEffectiveAt = rate.effectiveAt.toLocal();
      }
      _effectiveAt = rateFormUsesNowForEffectiveAt(widget.mode)
          ? DateTime.now()
          : rate.effectiveAt.toLocal();
      _loaded = true;
    });
  }

  void _applyMidToBuySell() {
    final mid = double.tryParse(_midCtrl.text);
    if (mid == null || mid <= 0) return;
    _buyCtrl.text = (mid - _halfSpread).toStringAsFixed(4);
    _sellCtrl.text = (mid + _halfSpread).toStringAsFixed(4);
    setState(() {});
  }

  void _syncMidFromBuySell() {
    final buy = double.tryParse(_buyCtrl.text);
    final sell = double.tryParse(_sellCtrl.text);
    if (buy != null && sell != null) {
      _halfSpread = (sell - buy) / 2;
      _midCtrl.text = ((buy + sell) / 2).toStringAsFixed(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final currenciesAsync = ref.watch(currenciesProvider);
    final loadId = widget.rateId ?? widget.duplicateFromId;

    if (loadId != null && !_loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromId(loadId));
    }

    final title = switch (widget.mode) {
      RateFormMode.create => 'New rate',
      RateFormMode.editVersion => 'Edit rate (new version)',
      RateFormMode.duplicate => 'Duplicate rate',
    };

    return FxPageScaffold(
      fallbackRoute: '/rates',
      title: Text(
        title,
        style: AppTypography.headlineMd(context.fx.onSurface, context: context),
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
            error: (e, _) =>
                Center(child: Text('Unable to load currencies: $e')),
            data: (currencies) {
              final fxCurrencies = currencies.where((c) => !c.isBase).toList();
              _currencyId ??= fxCurrencies.firstOrNull?.id;
              _source ??= 'manual';
              _effectiveAt ??= DateTime.now();

              return Column(
                children: [
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (widget.mode == RateFormMode.editVersion)
                            FxObsidianReportPanel(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: context.fx.tertiary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Old transactions will keep their locked rates. This new rate applies to future transactions only.',
                                      style: AppTypography.bodyMd(
                                        context.fx.onSurfaceVariant,
                                        context: context,
                                      ).copyWith(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (widget.mode == RateFormMode.editVersion)
                            const SizedBox(height: 12),
                          Text(
                            'Currency pair',
                            style: AppTypography.labelCaps(
                              context.fx.outline,
                              context: context,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            key: ValueKey(_currencyId),
                            initialValue: _currencyId,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: context.fx.surfaceContainerLow,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusLg,
                                ),
                              ),
                            ),
                            items: fxCurrencies
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text('${c.code}/PKR · ${c.name}'),
                                  ),
                                )
                                .toList(),
                            onChanged:
                                widget.mode == RateFormMode.editVersion || _busy
                                ? null
                                : (v) => setState(() => _currencyId = v),
                            validator: (v) =>
                                v == null ? 'Select currency' : null,
                          ),
                          const SizedBox(height: 16),
                          FxObsidianFormField(
                            label: 'Reference / mid rate (PKR)',
                            controller: _midCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            enabled: !_busy,
                            accentTertiary: true,
                            onChanged: (_) => _applyMidToBuySell(),
                            validator: _positiveRate,
                          ),
                          const SizedBox(height: 12),
                          FxObsidianFormField(
                            label: 'Buy rate (PKR)',
                            controller: _buyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            enabled: !_busy,
                            onChanged: (_) {
                              _syncMidFromBuySell();
                              setState(() {});
                            },
                            validator: _positiveRate,
                          ),
                          const SizedBox(height: 12),
                          FxObsidianFormField(
                            label: 'Sell rate (PKR)',
                            controller: _sellCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            enabled: !_busy,
                            onChanged: (_) {
                              _syncMidFromBuySell();
                              setState(() {});
                            },
                            validator: _positiveRate,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Source',
                            style: AppTypography.labelCaps(
                              context.fx.outline,
                              context: context,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _source,
                            items: _sources
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    enabled: RateSourceLabels.isSelectable(s),
                                    child: Text(RateSourceLabels.label(s)),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _source = v),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: _busy
                                ? null
                                : () async {
                                    final initial =
                                        _effectiveAt ?? DateTime.now();
                                    final date =
                                        await FxObsidianPickers.showDate(
                                          context,
                                          initialDate: initial,
                                          lastDate: DateTime.now().add(
                                            const Duration(days: 365),
                                          ),
                                        );
                                    if (date == null || !context.mounted) {
                                      return;
                                    }
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                        initial,
                                      ),
                                    );
                                    if (time == null) return;
                                    setState(() {
                                      _effectiveAt = DateTime(
                                        date.year,
                                        date.month,
                                        date.day,
                                        time.hour,
                                        time.minute,
                                      );
                                    });
                                  },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Effective date/time',
                                        style: AppTypography.labelCaps(
                                          context.fx.outline,
                                          context: context,
                                        ),
                                      ),
                                      Text(
                                        _effectiveAt != null
                                            ? DateFormat.yMMMd()
                                                  .add_jm()
                                                  .format(
                                                    _effectiveAt!.toLocal(),
                                                  )
                                            : 'Required',
                                        style: AppTypography.bodyMd(
                                          context.fx.onSurface,
                                          context: context,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  color: context.fx.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                          if (widget.mode == RateFormMode.editVersion &&
                              _previousEffectiveAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Previous version effective from: ${DateFormat.yMMMd().add_jm().format(_previousEffectiveAt!.toLocal())}',
                              style: AppTypography.bodyMd(
                                context.fx.onSurfaceVariant,
                                context: context,
                              ).copyWith(fontSize: 11),
                            ),
                            Text(
                              'New version must use a different date/time.',
                              style: AppTypography.bodyMd(
                                context.fx.onSurfaceVariant,
                                context: context,
                              ).copyWith(fontSize: 11),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FxObsidianFormField(
                            label: 'Notes',
                            controller: _notesCtrl,
                            maxLines: 2,
                            enabled: !_busy,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This rate will apply from the selected date/time. Old transactions remain unchanged.',
                            style: AppTypography.bodyMd(
                              context.fx.onSurfaceVariant,
                              context: context,
                            ).copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  FxObsidianActionBar(
                    busy: _busy,
                    saveLabel: widget.mode == RateFormMode.editVersion
                        ? 'Save new version'
                        : 'Save rate',
                    onCancel: _busy
                        ? () {}
                        : () => fxSafePop(context, fallbackRoute: '/rates'),
                    onSave: _busy ? () {} : () => _save(profile.branchId),
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

  Future<void> _save(String branchId) async {
    if (!_formKey.currentState!.validate()) return;
    if (_effectiveAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select effective date/time')),
      );
      return;
    }
    final buy = double.parse(_buyCtrl.text);
    final sell = double.parse(_sellCtrl.text);
    if (buy > sell) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buy rate should not exceed sell rate')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(rateRepositoryProvider);
      final taken = await repo.effectiveAtExists(
        currencyId: _currencyId!,
        effectiveAt: _effectiveAt!,
      );
      if (taken) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(rateFormEffectiveAtConflictMessage)),
          );
        }
        return;
      }
      await repo.createRateVersion(
        branchId: branchId,
        currencyId: _currencyId!,
        buyRate: buy,
        sellRate: sell,
        midRate: double.tryParse(_midCtrl.text),
        effectiveAt: _effectiveAt!,
        source: _source ?? 'manual',
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      ref.invalidate(ratesProvider);
      ref.invalidate(rateBoardPairsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rate saved.')));
        context.pop();
      }
    } on RateEffectiveAtConflictException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(rateFormEffectiveAtConflictMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
