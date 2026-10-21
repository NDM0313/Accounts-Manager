import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/data/repositories/party_bank_repository.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  FxPartyType _type = FxPartyType.customer;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.partyId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    final party = await ref.read(partyDetailProvider(widget.partyId!).future);
    if (party == null || !mounted) return;
    setState(() {
      _codeCtrl.text = party.code;
      _nameCtrl.text = party.name;
      _phoneCtrl.text = party.phone ?? '';
      _notesCtrl.text = party.notes ?? '';
      _type = party.partyType;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final isEdit = widget.partyId != null;

    if (isEdit && !_loaded) {
      return Scaffold(
        backgroundColor: fx.background,
        appBar: AppBar(
          title: const Text('Edit party'),
          backgroundColor: fx.background,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: fx.background,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit party' : 'New party'),
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
                  DropdownButtonFormField<FxPartyType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Party type'),
                    items: FxPartyType.values
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.label)),
                        )
                        .toList(),
                    onChanged: _busy || isEdit
                        ? null
                        : (v) => setState(() => _type = v ?? _type),
                  ),
                  const SizedBox(height: 12),
                  FxObsidianFormField(
                    label: 'Code',
                    controller: _codeCtrl,
                    enabled: !_busy && !isEdit,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Code required'
                        : null,
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
                    label: 'Phone',
                    controller: _phoneCtrl,
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 12),
                  FxObsidianFormField(
                    label: 'Notes',
                    controller: _notesCtrl,
                    maxLines: 3,
                    enabled: !_busy,
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Bank details (optional, multiple allowed — identifiers masked)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _PartyBankSection(partyId: widget.partyId!),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Deactivate party?'),
                                  content: const Text(
                                    'Soft-deactivate only. History stays; no hard delete.',
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
                              if (ok != true) return;
                              setState(() => _busy = true);
                              try {
                                await ref
                                    .read(partyRepositoryProvider)
                                    .deactivateParty(widget.partyId!);
                                ref.invalidate(partiesProvider);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Party deactivated'),
                                    ),
                                  );
                                  context.pop();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Deactivate party'),
                    ),
                  ],
                ],
              ),
            ),
            FxObsidianActionBar(
              busy: _busy,
              saveLabel: isEdit ? 'Save changes' : 'Create party',
              onCancel: () => context.pop(),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = await ref.read(currentProfileProvider.future);
    if (profile == null) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(partyRepositoryProvider);
      if (widget.partyId != null) {
        await repo.updateParty(
          widget.partyId!,
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
      } else {
        final created = await repo.createParty(
          FxParty(
            id: '',
            companyId: profile.companyId,
            branchId: profile.branchId,
            partyType: _type,
            code: _codeCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim().isEmpty
                ? null
                : _phoneCtrl.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
            isActive: true,
          ),
        );
        ref.invalidate(partiesProvider);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Party saved.')));
          context.pop(created.id);
        }
        return;
      }
      ref.invalidate(partiesProvider);
      if (widget.partyId != null) {
        ref.invalidate(partyDetailProvider(widget.partyId!));
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Party saved.')));
        context.pop();
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add bank account'),
        content: Column(
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
              decoration: const InputDecoration(
                labelText: 'Account / IBAN',
                helperText: 'Stored structured — not used for silent OCR match',
              ),
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
    if (ok != true) return;
    await _repo.upsert(
      companyId: profile.companyId,
      partyId: widget.partyId,
      bankName: bank.text.trim().isEmpty ? null : bank.text.trim(),
      accountTitle: title.text.trim().isEmpty ? null : title.text.trim(),
      accountNumber: number.text.trim().isEmpty ? null : number.text.trim(),
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
