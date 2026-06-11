import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/data/repositories/journal_repository.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_user_profile.dart';
import 'package:accounts_manager/features/journal/manual_journal_validation.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ManualJournalScreen extends ConsumerStatefulWidget {
  const ManualJournalScreen({super.key});

  @override
  ConsumerState<ManualJournalScreen> createState() => _ManualJournalScreenState();
}

class _ManualJournalLine {
  _ManualJournalLine({required this.accountCode});

  String accountCode;
  final debitCtrl = TextEditingController();
  final creditCtrl = TextEditingController();
  String currencyCode = 'PKR';

  void dispose() {
    debitCtrl.dispose();
    creditCtrl.dispose();
  }
}

class _ManualJournalScreenState extends ConsumerState<ManualJournalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  final _lines = [_ManualJournalLine(accountCode: '1110'), _ManualJournalLine(accountCode: '5800')];
  DateTime _entryDate = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  bool _lineHasBothSides(_ManualJournalLine l) => manualJournalLineHasBothSides(
        ManualJournalLineAmounts(debitText: l.debitCtrl.text, creditText: l.creditCtrl.text),
      );

  Iterable<ManualJournalLineAmounts> get _lineAmounts => _lines.map(
        (l) => ManualJournalLineAmounts(debitText: l.debitCtrl.text, creditText: l.creditCtrl.text),
      );

  double get _totalDebit => manualJournalTotalDebit(_lineAmounts);

  double get _totalCredit => manualJournalTotalCredit(_lineAmounts);

  bool get _hasInvalidLines => manualJournalHasInvalidLines(_lineAmounts);

  bool get _isBalanced => manualJournalIsBalanced(_lineAmounts);

  bool get _canPost => _isBalanced && !_busy;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return FxPageScaffold(
      fallbackRoute: '/reports',
      title: const Text('Manual Journal'),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Profile error: $e')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Profile not configured.'));
          return accountsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Accounts error: $e')),
            data: (accounts) => _buildForm(context, profile, accounts),
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, FxUserProfile profile, List<FxAccount> accounts) {
    final dateLabel = DateFormat('d MMM yyyy').format(_entryDate);

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                InkWell(
                  onTap: _busy
                      ? null
                      : () async {
                          final picked = await FxObsidianPickers.showDate(context, initialDate: _entryDate);
                          if (picked != null) setState(() => _entryDate = picked);
                        },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FxSectionLabel(label: 'Entry date'),
                            Text(dateLabel, style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
                          ],
                        ),
                      ),
                      Icon(Icons.calendar_today_outlined, color: context.fx.onSurfaceVariant),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FxObsidianFormField(
                  label: 'Description',
                  controller: _descriptionCtrl,
                  maxLines: 2,
                  enabled: !_busy,
                ),
                const SizedBox(height: 16),
                FxSectionLabel(label: 'Journal lines'),
                const SizedBox(height: 4),
                Text(
                  'Enter amount in Debit or Credit per line, not both.',
                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _lines.length; i++) ...[
                  _lineRow(i, accounts),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => setState(() => _lines.add(_ManualJournalLine(accountCode: '1110'))),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add line'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hasInvalidLines
                        ? context.fx.errorContainer.withValues(alpha: 0.3)
                        : _isBalanced
                            ? context.fx.tertiaryContainer
                            : context.fx.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: _hasInvalidLines ? context.fx.error : context.fx.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Debit: ${_totalDebit.toStringAsFixed(2)}', style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
                      Text('Credit: ${_totalCredit.toStringAsFixed(2)}', style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
                      Text(
                        _hasInvalidLines
                            ? 'Invalid line'
                            : _isBalanced
                                ? 'Balanced'
                                : 'Out of balance',
                        style: AppTypography.labelCaps(
                          _hasInvalidLines || !_isBalanced ? context.fx.error : context.fx.tertiary,
                          context: context,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FxObsidianActionBar(
            busy: _busy,
            saveLabel: 'Post journal',
            onCancel: () => fxSafePop(context, fallbackRoute: '/reports'),
            onSave: _canPost ? () => _post(profile, accounts) : null,
          ),
        ],
      ),
    );
  }

  Widget _lineRow(int index, List<FxAccount> accounts) {
    final line = _lines[index];
    final invalid = _lineHasBothSides(line);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: invalid ? context.fx.error : context.fx.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: line.accountCode,
                  decoration: const InputDecoration(labelText: 'Account', isDense: true),
                  items: accounts
                      .map((a) => DropdownMenuItem(value: a.code, child: Text('${a.code} · ${a.name}')))
                      .toList(),
                  onChanged: _busy ? null : (v) => setState(() => line.accountCode = v ?? line.accountCode),
                ),
              ),
              if (_lines.length > 2)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: context.fx.error),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _lines[index].dispose();
                            _lines.removeAt(index);
                          }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FxObsidianFormField(
                  label: 'Debit PKR',
                  controller: line.debitCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  enabled: !_busy,
                  onChanged: (v) {
                    if ((double.tryParse(v) ?? 0) > 0 && line.creditCtrl.text.isNotEmpty) {
                      line.creditCtrl.clear();
                    }
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FxObsidianFormField(
                  label: 'Credit PKR',
                  controller: line.creditCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  enabled: !_busy,
                  onChanged: (v) {
                    if ((double.tryParse(v) ?? 0) > 0 && line.debitCtrl.text.isNotEmpty) {
                      line.debitCtrl.clear();
                    }
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _post(FxUserProfile profile, List<FxAccount> accounts) async {
    if (_hasInvalidLines) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Each line must be debit OR credit, not both.')),
      );
      return;
    }
    if (!_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Journal must balance.')));
      return;
    }

    setState(() => _busy = true);
    try {
      String? accountIdFor(String code) {
        for (final a in accounts) {
          if (a.code == code) return a.id;
        }
        return null;
      }

      final inputs = <ManualJournalLineInput>[];
      for (final line in _lines) {
        final d = double.tryParse(line.debitCtrl.text) ?? 0;
        final c = double.tryParse(line.creditCtrl.text) ?? 0;
        final debit = d > 0 && c == 0 ? d : 0.0;
        final credit = c > 0 && d == 0 ? c : 0.0;
        if (debit == 0 && credit == 0) continue;
        final accountId = accountIdFor(line.accountCode);
        if (accountId == null) throw StateError('Unknown account ${line.accountCode}');
        inputs.add(
          ManualJournalLineInput(
            accountId: accountId,
            currencyCode: line.currencyCode,
            foreignAmount: debit > 0 ? debit : credit,
            rateUsed: 1,
            debitPkr: debit,
            creditPkr: credit,
          ),
        );
      }

      final entryId = await ref.read(journalRepositoryProvider).postManualJournal(
            companyId: profile.companyId,
            branchId: profile.branchId,
            entryDate: _entryDate,
            lines: inputs,
            description: _descriptionCtrl.text.isEmpty ? null : _descriptionCtrl.text,
          );

      ref.invalidate(trialBalanceProvider);
      ref.invalidate(trialBalanceTotalsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Journal posted.')));
        context.pushReplacement('/journal/$entryId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
