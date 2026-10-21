import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final _bankCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  String _kind = 'cash';
  String _currency = 'PKR';
  bool _busy = false;

  static const _currencies = ['PKR', 'USD', 'AED', 'CNY'];

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind == 'bank' ? 'bank' : 'cash';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bankCtrl.dispose();
    _titleCtrl.dispose();
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(accountRepositoryProvider).createCashBankAccount(
            name: _nameCtrl.text.trim(),
            currencyCode: _currency,
            kind: _kind,
            bankName: _bankCtrl.text.trim().isEmpty ? null : _bankCtrl.text.trim(),
            accountTitle:
                _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
            accountIdentifier:
                _idCtrl.text.trim().isEmpty ? null : _idCtrl.text.trim(),
            branchId: profile.branchId,
          );
      ref.invalidate(accountsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${result['code']} — ${result['name']} '
            '(${result['currency_code']}). Opening balance is 0. '
            'Use Opening Balances for funded starts.',
          ),
        ),
      );
      context.pop(result['account_id'] as String?);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create account: $e')),
        );
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
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      hintText: 'e.g. Meezan PKR Main / Till Cash',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                      labelText: 'Currency',
                      helperText: _currency == 'CNY'
                          ? 'Shown as RMB in some places; stored as CNY'
                          : 'Balance is tracked in this currency only',
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
                    TextFormField(
                      controller: _bankCtrl,
                      decoration: const InputDecoration(labelText: 'Bank name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Account title'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _idCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Account / IBAN (optional)',
                        helperText: 'Stored with the account metadata notes',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'New accounts start at zero. Opening balances use the '
                    'separate Opening Balances workflow (permission-controlled).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
