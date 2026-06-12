import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_action_bar.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
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
        await repo.createParty(
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
