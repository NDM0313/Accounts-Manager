import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/utils/client_operation_id.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CashBankAccountFormScreen extends ConsumerStatefulWidget {
  const CashBankAccountFormScreen({super.key, this.initialKind = 'cash'});

  final String initialKind;

  @override
  ConsumerState<CashBankAccountFormScreen> createState() =>
      _CashBankAccountFormScreenState();
}

class _CashBankAccountFormScreenState
    extends ConsumerState<CashBankAccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _branchNameCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();
  final _swiftCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _openingAmountCtrl = TextEditingController();
  final _openingRateCtrl = TextEditingController();
  final _openingMemoCtrl = TextEditingController();

  String _kind = 'cash';
  String _currency = 'PKR';
  bool _busy = false;
  bool _addOpening = false;
  DateTime _openingDate = DateTime.now();
  String? _inlineError;

  static const _currencies = ['PKR', 'USD', 'AED', 'CNY'];

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind == 'bank' ? 'bank' : 'cash';
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _codeCtrl,
      _bankCtrl,
      _titleCtrl,
      _numberCtrl,
      _ibanCtrl,
      _branchNameCtrl,
      _branchCodeCtrl,
      _swiftCtrl,
      _notesCtrl,
      _openingAmountCtrl,
      _openingRateCtrl,
      _openingMemoCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;

    Map<String, dynamic>? opening;
    if (_addOpening) {
      final amt = double.tryParse(_openingAmountCtrl.text.replaceAll(',', ''));
      if (amt == null || amt <= 0) {
        setState(
          () => _inlineError = 'Opening amount must be greater than zero.',
        );
        return;
      }
      double? rate;
      if (_currency != 'PKR') {
        rate = double.tryParse(_openingRateCtrl.text.replaceAll(',', ''));
        if (rate == null || rate <= 0) {
          setState(
            () => _inlineError =
                'Enter historical PKR rate for $_currency (not live rate).',
          );
          return;
        }
      }
      opening = {
        'amount': amt,
        'currency_code': _currency,
        'as_of_date': DateFormat('yyyy-MM-dd').format(_openingDate),
        if (rate != null) 'rate_used': rate,
        'direction': 'asset',
        'memo': _openingMemoCtrl.text.trim().isEmpty
            ? null
            : _openingMemoCtrl.text.trim(),
      };
    }

    setState(() => _busy = true);
    try {
      final op = await ClientOperationId.begin(
        'cash_bank_create',
        '${profile.companyId}:${_nameCtrl.text.trim()}',
      );
      final result = await ref.read(accountRepositoryProvider).createCashBankAccount(
            name: _nameCtrl.text.trim(),
            currencyCode: _currency,
            kind: _kind,
            bankName: _bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim(),
            accountTitle:
                _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
            accountIdentifier: _numberCtrl.text.trim().isEmpty
                ? null
                : _numberCtrl.text.trim(),
            iban: _ibanCtrl.text.trim().isEmpty ? null : _ibanCtrl.text.trim(),
            branchName: _branchNameCtrl.text.trim().isEmpty
                ? null
                : _branchNameCtrl.text.trim(),
            branchCode: _branchCodeCtrl.text.trim().isEmpty
                ? null
                : _branchCodeCtrl.text.trim(),
            swiftBic:
                _swiftCtrl.text.trim().isEmpty ? null : _swiftCtrl.text.trim(),
            metadataNotes:
                _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            branchId: profile.branchId,
            code: _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
            opening: opening,
            clientOperationId: op,
          );
      await ClientOperationId.complete(
        'cash_bank_create',
        '${profile.companyId}:${_nameCtrl.text.trim()}',
      );
      ref.invalidate(accountsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${result['code']} — ${result['name']} '
            '(${result['currency_code']})'
            '${result['opening_tx_id'] != null ? ' with opening posted.' : ' at zero.'}',
          ),
        ),
      );
      context.pop(result['account_id'] as String?);
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        setState(() {
          if (msg.contains('DUPLICATE_CODE') || msg.contains('RESERVED_CODE')) {
            _inlineError =
                'Account code conflict or reserved. Leave blank to auto-assign.';
          } else if (msg.contains('ACCOUNT_CREATED_OPENING_PENDING')) {
            _inlineError =
                'Account saved, but opening requires posting permission.';
          } else if (msg.contains('OVERDRAFT_UNSUPPORTED')) {
            _inlineError =
                'Negative/overdraft bank openings are not supported here.';
          } else {
            _inlineError = 'Could not create account: $e';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return Scaffold(
      backgroundColor: fx.background,
      appBar: AppBar(
        title: Text(_kind == 'bank' ? 'Add Bank Account' : 'Add Cash Account'),
        backgroundColor: fx.background,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'cash', label: Text('Cash')),
                      ButtonSegment(value: 'bank', label: Text('Bank')),
                    ],
                    selected: {_kind},
                    onSelectionChanged: _busy
                        ? null
                        : (s) => setState(() => _kind = s.first),
                  ),
                  const SizedBox(height: 16),
                  FxObsidianFormField(
                    controller: _nameCtrl,
                    label: 'Display name',
                    hintText: 'e.g. Meezan PKR Main / Till Cash',
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  FxObsidianFormField(
                    controller: _codeCtrl,
                    label: 'GL code (optional — auto if blank)',
                    hintText: 'Avoid reserved codes (1110, 1160, …)',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                      labelText: 'Currency',
                      helperText: _currency == 'CNY'
                          ? 'Shown as RMB in some places; stored as CNY'
                          : 'Balance tracked in this currency only',
                    ),
                    items: _currencies
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c == 'CNY' ? 'CNY (RMB)' : c),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _currency = v ?? _currency),
                  ),
                  if (_kind == 'bank') ...[
                    const SizedBox(height: 12),
                    FxObsidianFormField(
                      controller: _bankCtrl,
                      label: 'Bank name',
                    ),
                    FxObsidianFormField(
                      controller: _titleCtrl,
                      label: 'Account title',
                    ),
                    FxObsidianFormField(
                      controller: _numberCtrl,
                      label: 'Account number',
                    ),
                    FxObsidianFormField(
                      controller: _ibanCtrl,
                      label: 'IBAN (optional)',
                    ),
                    FxObsidianFormField(
                      controller: _branchNameCtrl,
                      label: 'Branch name (optional)',
                    ),
                    FxObsidianFormField(
                      controller: _branchCodeCtrl,
                      label: 'Branch code (optional)',
                    ),
                    FxObsidianFormField(
                      controller: _swiftCtrl,
                      label: 'SWIFT / BIC (optional)',
                    ),
                  ],
                  FxObsidianFormField(
                    controller: _notesCtrl,
                    label: 'Notes (optional)',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    title: const Text('Opening balance (optional)'),
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Post opening with this account'),
                        subtitle: Text(
                          _kind == 'cash'
                              ? 'Cash openings must be non-negative. Date = start of day (PKT).'
                              : 'Bank openings are non-negative here. Overdraft is not supported in this form.',
                        ),
                        value: _addOpening,
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _addOpening = v),
                      ),
                      if (_addOpening) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Opening date: ${DateFormat.yMMMd().format(_openingDate)}',
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _openingDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 1)),
                              );
                              if (d != null) setState(() => _openingDate = d);
                            },
                            child: const Text('Change'),
                          ),
                        ),
                        FxObsidianFormField(
                          controller: _openingAmountCtrl,
                          label: 'Opening amount ($_currency)',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        if (_currency != 'PKR')
                          FxObsidianFormField(
                            controller: _openingRateCtrl,
                            label: 'Historical rate (PKR per 1 $_currency)',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        FxObsidianFormField(
                          controller: _openingMemoCtrl,
                          label: 'Reference / notes',
                        ),
                      ],
                    ],
                  ),
                  if (_inlineError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _inlineError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            FxObsidianActionBar(
              onCancel: () => context.pop(),
              onSave: _busy ? null : _save,
              saveLabel: _busy ? 'Saving…' : 'Create account',
              busy: _busy,
            ),
          ],
        ),
      ),
    );
  }
}
