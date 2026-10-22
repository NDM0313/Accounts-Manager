import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/utils/client_operation_id.dart';
import 'package:accounts_manager/core/utils/contact_import.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/data/repositories/party_bank_repository.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PartyFormScreen extends ConsumerStatefulWidget {
  const PartyFormScreen({super.key, this.partyId});

  final String? partyId;

  @override
  ConsumerState<PartyFormScreen> createState() => _PartyFormScreenState();
}

class _PartyFormScreenState extends ConsumerState<PartyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addr1Ctrl = TextEditingController();
  final _addr2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: '');
  final _websiteCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _openingAmountCtrl = TextEditingController();
  final _openingRateCtrl = TextEditingController();
  final _openingMemoCtrl = TextEditingController();

  FxPartyType _type = FxPartyType.customer;
  bool _busy = false;
  bool _loaded = false;
  bool _detailsOpen = false;
  bool _openingOpen = false;
  bool _addOpening = false;
  String _openingCcy = 'PKR';
  String _openingDirection = 'party_owes_us';
  DateTime _openingDate = DateTime.now();
  String? _assignedCode;
  String? _inlineError;
  List<FxParty> _phoneDupes = const [];

  bool get _isEdit => widget.partyId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final party = await ref.read(partyDetailProvider(widget.partyId!).future);
    if (party == null || !mounted) return;
    setState(() {
      _codeCtrl.text = party.code;
      _nameCtrl.text = party.name;
      _contactCtrl.text = party.contactPerson ?? '';
      _businessCtrl.text = party.businessName ?? '';
      _phoneCtrl.text = party.phoneDisplay ?? party.phone ?? '';
      _phone2Ctrl.text = party.phone2Display ?? '';
      _whatsappCtrl.text = party.whatsappDisplay ?? '';
      _emailCtrl.text = party.email ?? '';
      _addr1Ctrl.text = party.addressLine1 ?? '';
      _addr2Ctrl.text = party.addressLine2 ?? '';
      _cityCtrl.text = party.city ?? '';
      _provinceCtrl.text = party.province ?? '';
      _postalCtrl.text = party.postalCode ?? '';
      _countryCtrl.text = party.countryCode ?? '';
      _websiteCtrl.text = party.website ?? '';
      _notesCtrl.text = party.notes ?? '';
      _type = party.partyType;
      _assignedCode = party.code;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _codeCtrl,
      _nameCtrl,
      _contactCtrl,
      _businessCtrl,
      _phoneCtrl,
      _phone2Ctrl,
      _whatsappCtrl,
      _emailCtrl,
      _addr1Ctrl,
      _addr2Ctrl,
      _cityCtrl,
      _provinceCtrl,
      _postalCtrl,
      _countryCtrl,
      _websiteCtrl,
      _notesCtrl,
      _openingAmountCtrl,
      _openingRateCtrl,
      _openingMemoCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _importContact() async {
    ImportedContact? picked;
    if (ContactImport.isContactPickerSupported) {
      picked = await ContactImport.pickFromBrowser();
      if (picked == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Contact picker cancelled or denied. You can import a .vcf or type manually.',
            ),
          ),
        );
      }
    } else {
      final list = await ContactImport.pickFromVcf();
      if (!mounted) return;
      if (list.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ContactImport.isContactPickerSupported
                  ? 'No contact selected'
                  : 'Browser contact access is not available here (common on iPhone Safari). Import a .vcf or enter manually.',
            ),
          ),
        );
        return;
      }
      if (list.length == 1) {
        picked = list.first;
      } else {
        picked = await showDialog<ImportedContact>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Choose contact from file'),
            children: list
                .map(
                  (c) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, c),
                    child: Text(
                      '${c.name ?? 'Unnamed'}'
                      '${c.phones.isEmpty ? '' : ' · ${c.phones.first}'}',
                    ),
                  ),
                )
                .toList(),
          ),
        );
      }
    }
    if (picked == null || !mounted) return;
    setState(() {
      if ((picked!.name ?? '').trim().isNotEmpty) {
        _nameCtrl.text = picked.name!.trim();
      }
      if (picked.phones.isNotEmpty) _phoneCtrl.text = picked.phones.first;
      if (picked.phones.length > 1) _phone2Ctrl.text = picked.phones[1];
      if (picked.emails.isNotEmpty) _emailCtrl.text = picked.emails.first;
      _detailsOpen = true;
    });
  }

  Future<void> _checkPhoneDupes() async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;
    final e164 = normalizePhoneE164ish(_phoneCtrl.text);
    if (e164.isEmpty) {
      setState(() => _phoneDupes = const []);
      return;
    }
    final dupes = await ref.read(partyRepositoryProvider).findPossiblePhoneDuplicates(
          companyId: profile.companyId,
          phoneE164: e164,
          excludePartyId: widget.partyId,
        );
    if (mounted) setState(() => _phoneDupes = dupes);
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    if (_isEdit && !_loaded) {
      return Scaffold(
        backgroundColor: fx.background,
        appBar: AppBar(
          title: const Text('Edit party'),
          backgroundColor: fx.background,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy) return;
        final leave = await _confirmDiscard();
        if (leave && mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: fx.background,
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit party' : 'New party'),
          backgroundColor: fx.background,
          actions: [
            TextButton.icon(
              onPressed: _busy ? null : _importContact,
              icon: const Icon(Icons.contact_page_outlined),
              label: Text(
                ContactImport.isContactPickerSupported
                    ? 'Import contact'
                    : 'Import .vcf',
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<FxPartyType>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'Role / type',
                      ),
                      items: FxPartyType.values
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label),
                            ),
                          )
                          .toList(),
                      onChanged: _busy || _isEdit
                          ? null
                          : (v) => setState(() => _type = v ?? _type),
                    ),
                    const SizedBox(height: 12),
                    FxObsidianFormField(
                      label: 'Name',
                      controller: _nameCtrl,
                      enabled: !_busy,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    FxObsidianFormField(
                      label: 'Code (optional — auto if blank)',
                      controller: _codeCtrl,
                      enabled: !_busy && !_isEdit,
                      hintText: 'Leave blank to auto-generate',
                    ),
                    if (_assignedCode != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Assigned: $_assignedCode'),
                      ),
                    const SizedBox(height: 12),
                    FxObsidianFormField(
                      label: 'Primary phone (include country code)',
                      controller: _phoneCtrl,
                      enabled: !_busy,
                      onChanged: (_) => _checkPhoneDupes(),
                    ),
                    if (_phoneDupes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Possible duplicate phone: ${_phoneDupes.map((p) => '${p.name} (${p.code})').join(', ')}. '
                        'Not merged automatically — review before saving.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ExpansionTile(
                      initiallyExpanded: _detailsOpen,
                      onExpansionChanged: (v) =>
                          setState(() => _detailsOpen = v),
                      title: const Text('Additional details (optional)'),
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      children: [
                        FxObsidianFormField(
                          label: 'Contact person',
                          controller: _contactCtrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'Business name',
                          controller: _businessCtrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'Additional phone',
                          controller: _phone2Ctrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'WhatsApp',
                          controller: _whatsappCtrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'Email',
                          controller: _emailCtrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'Address line 1',
                          controller: _addr1Ctrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'Address line 2',
                          controller: _addr2Ctrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'City',
                          controller: _cityCtrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'Province / state',
                          controller: _provinceCtrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'Postal code',
                          controller: _postalCtrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'Country code (e.g. PK, AE, CN)',
                          controller: _countryCtrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'Website',
                          controller: _websiteCtrl,
                          enabled: !_busy,
                        ),
                        FxObsidianFormField(
                          label: 'Notes',
                          controller: _notesCtrl,
                          maxLines: 3,
                          enabled: !_busy,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Photo/logo: upload from party statement/attachments after save '
                          '(private company storage).',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (!_isEdit) ...[
                      const SizedBox(height: 8),
                      ExpansionTile(
                        initiallyExpanded: _openingOpen,
                        onExpansionChanged: (v) =>
                            setState(() => _openingOpen = v),
                        title: const Text(
                          'Add opening balance / Purana balance (optional)',
                        ),
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Post an opening with this party'),
                            subtitle: const Text(
                              'Date = opening at START of selected day (PKT). '
                              'Not income or a new sale. Agent-held inventory/custody '
                              'is NOT posted here (would double-count) — use Opening Balances '
                              'currency position / agent custody tools.',
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
                                'As-of / opening date: ${DateFormat.yMMMd().format(_openingDate)}',
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
                                  if (d != null) {
                                    setState(() => _openingDate = d);
                                  }
                                },
                                child: const Text('Change'),
                              ),
                            ),
                            DropdownButtonFormField<String>(
                              initialValue: _openingDirection,
                              decoration: const InputDecoration(
                                labelText: 'Balance direction',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'party_owes_us',
                                  child: Text(
                                    'Party owes us / Humein lena hai (Receivable / Debit)',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'we_owe_party',
                                  child: Text(
                                    'We owe party / Humein dena hai (Payable / Credit)',
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(
                                () => _openingDirection = v ?? _openingDirection,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _openingCcy,
                                    decoration: const InputDecoration(
                                      labelText: 'Currency',
                                    ),
                                    items: const [
                                      'PKR',
                                      'USD',
                                      'AED',
                                      'CNY',
                                    ]
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setState(
                                      () => _openingCcy = v ?? _openingCcy,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FxObsidianFormField(
                                    label: 'Amount ($_openingCcy)',
                                    controller: _openingAmountCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_openingCcy != 'PKR') ...[
                              FxObsidianFormField(
                                label: 'Historical rate (PKR per 1 $_openingCcy)',
                                controller: _openingRateCtrl,
                                hintText: 'Required — not live rate',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                              ),
                            ],
                            FxObsidianFormField(
                              label: 'Opening reference / notes',
                              controller: _openingMemoCtrl,
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (_isEdit) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Bank details',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _PartyBankSection(partyId: widget.partyId!),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => context.push(
                                  '/parties/${widget.partyId}/ledger',
                                ),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Open statement / balances'),
                      ),
                    ],
                    if (_inlineError != null) ...[
                      const SizedBox(height: 12),
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
                saveLabel: _isEdit ? 'Save changes' : 'Create party',
                onCancel: () async {
                  if (await _confirmDiscard() && mounted) context.pop();
                },
                onSave: _busy ? null : _save,
                busy: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (_nameCtrl.text.trim().isEmpty &&
        _phoneCtrl.text.trim().isEmpty &&
        !_addOpening) {
      return true;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Unsaved party details will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _save() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;

    Map<String, dynamic>? opening;
    if (!_isEdit && _addOpening) {
      final amt = double.tryParse(
        _openingAmountCtrl.text.replaceAll(',', ''),
      );
      if (amt == null || amt <= 0) {
        setState(
          () => _inlineError = 'Opening amount must be greater than zero.',
        );
        return;
      }
      double? rate;
      if (_openingCcy != 'PKR') {
        rate = double.tryParse(_openingRateCtrl.text.replaceAll(',', ''));
        if (rate == null || rate <= 0) {
          setState(
            () => _inlineError =
                'Enter the historical PKR rate for $_openingCcy opening.',
          );
          return;
        }
      }
      opening = {
        'amount': amt,
        'currency_code': _openingCcy,
        'direction': _openingDirection,
        'as_of_date': DateFormat('yyyy-MM-dd').format(_openingDate),
        if (rate != null) 'rate_used': rate,
        'memo': _openingMemoCtrl.text.trim().isEmpty
            ? null
            : _openingMemoCtrl.text.trim(),
      };
    }

    setState(() => _busy = true);
    try {
      final phoneDisplay = _phoneCtrl.text.trim();
      final payload = <String, dynamic>{
        if (_isEdit) 'id': widget.partyId,
        if (!_isEdit) 'company_id': profile.companyId,
        if (!_isEdit) 'branch_id': profile.branchId,
        'party_type': _type.dbValue,
        'name': _nameCtrl.text.trim(),
        if (_codeCtrl.text.trim().isNotEmpty) 'code': _codeCtrl.text.trim(),
        'contact_person': _contactCtrl.text.trim(),
        'business_name': _businessCtrl.text.trim(),
        'phone_display': phoneDisplay,
        'phone_e164': normalizePhoneE164ish(phoneDisplay),
        'phone2_display': _phone2Ctrl.text.trim(),
        'phone2_e164': normalizePhoneE164ish(_phone2Ctrl.text),
        'whatsapp_display': _whatsappCtrl.text.trim(),
        'whatsapp_e164': normalizePhoneE164ish(_whatsappCtrl.text),
        'email': _emailCtrl.text.trim(),
        'address_line1': _addr1Ctrl.text.trim(),
        'address_line2': _addr2Ctrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'province': _provinceCtrl.text.trim(),
        'postal_code': _postalCtrl.text.trim(),
        'country_code': _countryCtrl.text.trim().toUpperCase(),
        'website': _websiteCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        if (opening != null) 'opening': opening,
      };

      if (!_isEdit) {
        final op = await ClientOperationId.begin(
          'party_create',
          '${profile.companyId}:${_nameCtrl.text.trim()}',
        );
        payload['client_operation_id'] = op;
      }

      final result =
          await ref.read(partyRepositoryProvider).upsertPartyProfile(payload);
      final code = result['code'] as String?;
      final id = result['party_id'] as String;
      if (!_isEdit) {
        await ClientOperationId.complete(
          'party_create',
          '${profile.companyId}:${_nameCtrl.text.trim()}',
        );
      }
      ref.invalidate(partiesProvider);
      if (_isEdit) ref.invalidate(partyDetailProvider(widget.partyId!));
      if (!mounted) return;
      setState(() => _assignedCode = code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'Party updated.'
                : 'Party saved as $code'
                    '${result['opening_tx_id'] != null ? ' with opening posted.' : '.'}',
          ),
        ),
      );
      context.pop(id);
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        setState(() {
          if (msg.contains('DUPLICATE_CODE')) {
            _inlineError =
                'That custom code is already used. Choose another or leave blank.';
          } else if (msg.contains('PARTY_CREATED_OPENING_PENDING')) {
            _inlineError =
                'Party was saved, but you cannot post openings. Ask a poster to add the opening.';
          } else if (msg.contains('OPENING_DATE_CLOSED')) {
            _inlineError = 'Opening date is on a closed day — pick another date.';
          } else if (msg.contains('RATE_REQUIRED')) {
            _inlineError = 'Foreign openings need an explicit historical rate.';
          } else {
            _inlineError = 'Save failed: $e';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _PartyBankSection extends ConsumerStatefulWidget {
  const _PartyBankSection({required this.partyId});
  final String partyId;

  @override
  ConsumerState<_PartyBankSection> createState() => _PartyBankSectionState();
}

class _PartyBankSectionState extends ConsumerState<_PartyBankSection> {
  final _repo = PartyBankRepository();
  List<FxPartyBankAccount> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _rows = await _repo.fetchForParty(widget.partyId);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;
    final bank = TextEditingController();
    final title = TextEditingController();
    final number = TextEditingController();
    final iban = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add bank account'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bank,
                decoration: const InputDecoration(labelText: 'Bank name'),
              ),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Account title'),
              ),
              TextField(
                controller: number,
                decoration: const InputDecoration(labelText: 'Account number'),
              ),
              TextField(
                controller: iban,
                decoration: const InputDecoration(
                  labelText: 'IBAN (optional)',
                ),
              ),
            ],
          ),
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
    if (ok != true) return;
    await _repo.upsert(
      companyId: profile.companyId,
      partyId: widget.partyId,
      bankName: bank.text.trim().isEmpty ? null : bank.text.trim(),
      accountTitle: title.text.trim().isEmpty ? null : title.text.trim(),
      accountNumber: number.text.trim().isEmpty ? null : number.text.trim(),
      iban: iban.text.trim().isEmpty ? null : iban.text.trim(),
      isPrimary: _rows.isEmpty,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LinearProgressIndicator();
    return Column(
      children: [
        ..._rows.map(
          (b) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(b.bankName ?? 'Bank'),
            subtitle: Text(
              '${b.accountTitle ?? ''} · ${b.maskedIdentifier}'
              '${b.isPrimary ? ' · default' : ''}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: 'Deactivate',
              onPressed: () async {
                await _repo.deactivate(b.id);
                await _load();
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add bank details'),
          ),
        ),
      ],
    );
  }
}
