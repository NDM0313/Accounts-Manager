import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/opening_balance_summary.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_form_field.dart';
import 'package:accounts_manager/data/repositories/profile_repository.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_opening_balance_batch.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_user_profile.dart';
import 'package:accounts_manager/domain/services/opening_balance_line_mapper.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/opening_balance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class OpeningBalanceWizardScreen extends ConsumerStatefulWidget {
  const OpeningBalanceWizardScreen({super.key});

  @override
  ConsumerState<OpeningBalanceWizardScreen> createState() => _OpeningBalanceWizardScreenState();
}

class _OpeningBalanceWizardScreenState extends ConsumerState<OpeningBalanceWizardScreen> {
  static const _stepTitles = [
    'Opening Setup',
    'Cash & Bank',
    'Currency Positions',
    'Party / Agent',
    'Review',
    'Post',
  ];

  int _step = 0;
  bool _busy = false;
  String? _batchId;
  DateTime _openingDate = DateTime.now();
  final _descriptionCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _equityAccountId;

  final _cashLines = <FxOpeningBalanceLine>[];
  final _positionLines = <FxOpeningBalanceLine>[];
  final _partyLines = <FxOpeningBalanceLine>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingDraft());
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingDraft() async {
    final view = await ref.read(openingBalanceStatusProvider.future);
    if (!mounted || view.status != FxOpeningBalanceStatus.draft) return;
    setState(() {
      _batchId = view.batch?.id;
      if (view.batch != null) {
        _openingDate = view.batch!.openingDate;
        _descriptionCtrl.text = view.batch!.description ?? '';
        _notesCtrl.text = view.batch!.notes ?? '';
        _equityAccountId = view.batch!.equityAccountId;
      }
      _cashLines.clear();
      _positionLines.clear();
      _partyLines.clear();
      for (final line in view.lines) {
        switch (line.lineKind) {
          case FxOpeningBalanceLineKind.cashBank:
            _cashLines.add(line);
          case FxOpeningBalanceLineKind.currencyPosition:
            _positionLines.add(line);
          case FxOpeningBalanceLineKind.partyReceivable:
          case FxOpeningBalanceLineKind.partyPayable:
            _partyLines.add(line);
        }
      }
    });
  }

  List<FxOpeningBalanceLine> get _allLines {
    final lines = [..._cashLines, ..._positionLines, ..._partyLines];
    var n = 1;
    return [for (final l in lines) l.copyWith(lineNo: n++)];
  }

  bool get _isBalanced => OpeningBalanceLineMapper.isBalanced(_allLines);

  Future<void> _saveDraft(FxUserProfile profile) async {
    setState(() => _busy = true);
    try {
      final view = await ref.read(openingBalanceRepositoryProvider).saveDraft(
            companyId: profile.companyId,
            branchId: profile.branchId,
            openingDate: _openingDate,
            batchId: _batchId,
            description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            equityAccountId: _equityAccountId,
            lines: _allLines,
          );
      ref.invalidate(openingBalanceStatusProvider);
      if (!mounted) return;
      setState(() {
        _batchId = view.batch?.id;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  Future<void> _post(FxUserProfile profile) async {
    if (_batchId == null) await _saveDraft(profile);
    if (_batchId == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post opening balance?'),
        content: const Text(
          'This will create posted opening balance journals and lock the batch. '
          'Ensure all amounts are correct before continuing.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(openingBalanceRepositoryProvider).postBatch(_batchId!);
      ref.invalidate(openingBalanceStatusProvider);
      ref.invalidate(trialBalanceProvider);
      ref.invalidate(trialBalanceTotalsProvider);
      ref.invalidate(cashBalancesProvider);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = 5;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening balance posted successfully')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post failed: $e')));
      }
    }
  }

  void _nextStep(FxUserProfile profile) {
    if (_step == 4 && !_isBalanced) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Batch must be balanced before posting')),
      );
      return;
    }
    if (_step < 4) {
      _saveDraft(profile);
      setState(() => _step++);
    } else if (_step == 4) {
      _post(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final branchAsync = ref.watch(branchContextProvider);

    return FxPageScaffold(
      fallbackRoute: '/opening-balances',
      title: Text('Opening Balance — ${_stepTitles[_step]}'),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Profile error: $e')),
        data: (profile) {
          if (profile == null) return const Center(child: Text('Sign in required'));
          return accountsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Accounts error: $e')),
            data: (accounts) {
              _equityAccountId ??= OpeningBalanceLineMapper.equityCode.let(
                (c) => accounts.where((a) => a.code == c).map((a) => a.id).firstOrNull,
              );

              return Column(
                children: [
                  _StepIndicator(current: _step, total: _stepTitles.length),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: switch (_step) {
                        0 => _buildSetupStep(context, branchAsync, accounts),
                        1 => _buildCashBankStep(context, accounts),
                        2 => _buildPositionStep(context, accounts),
                        3 => _buildPartyStep(context, accounts),
                        4 => _buildReviewStep(context, accounts),
                        _ => _buildPostStep(context, ref),
                      },
                    ),
                  ),
                  _WizardActionBar(
                    busy: _busy,
                    primaryLabel: _step == 4 ? 'Post Opening Balance' : _step == 5 ? 'Done' : 'Next',
                    onPrimary: () {
                      if (_step == 5) {
                        context.go('/opening-balances');
                      } else {
                        _nextStep(profile);
                      }
                    },
                    showBack: _step > 0 && _step < 5,
                    onBack: () => setState(() => _step--),
                    showSaveDraft: _step < 4,
                    onSaveDraft: () => _saveDraft(profile),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSetupStep(BuildContext context, AsyncValue<BranchContext?> branchAsync, List<FxAccount> accounts) {
    final branchLabel = branchAsync.whenOrNull(data: (c) => c != null ? '${c.companyName} · ${c.branchName}' : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WarningBanner(
          text: 'Opening balances should be entered once before real transactions.',
        ),
        const SizedBox(height: 16),
        if (branchLabel != null) ListTile(title: const Text('Company / Branch'), subtitle: Text(branchLabel)),
        ListTile(
          title: const Text('Opening date'),
          subtitle: Text(DateFormat.yMMMd().format(_openingDate)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: () async {
            final picked = await FxObsidianPickers.showDate(context, initialDate: _openingDate);
            if (picked != null) setState(() => _openingDate = picked);
          },
        ),
        const ListTile(title: Text('Base currency'), subtitle: Text('PKR')),
        const SizedBox(height: 8),
        FxObsidianFormField(controller: _descriptionCtrl, label: 'Description (optional)'),
        const SizedBox(height: 12),
        FxObsidianFormField(controller: _notesCtrl, label: 'Notes (optional)', maxLines: 2),
        const SizedBox(height: 16),
        Text(
          'Balancing account: Owner Capital (${OpeningBalanceLineMapper.equityCode})',
          style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
        ),
      ],
    );
  }

  Widget _buildCashBankStep(BuildContext context, List<FxAccount> accounts) {
    final cashAccounts = OpeningBalanceLineMapper.cashAndBankAccounts(accounts);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FxSectionLabel(label: 'Cash & bank balances'),
        const SizedBox(height: 8),
        ..._cashLines.asMap().entries.map((e) => _LineCard(
              line: e.value,
              accounts: accounts,
              onDelete: () => setState(() => _cashLines.removeAt(e.key)),
            )),
        OutlinedButton.icon(
          onPressed: () => _showAddLineSheet(
            context: context,
            accounts: accounts,
            cashAccounts: cashAccounts,
            kind: FxOpeningBalanceLineKind.cashBank,
            onAdd: (line) => setState(() => _cashLines.add(line)),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add cash / bank row'),
        ),
      ],
    );
  }

  Widget _buildPositionStep(BuildContext context, List<FxAccount> accounts) {
    final cashAccounts = OpeningBalanceLineMapper.cashAndBankAccounts(accounts);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FxSectionLabel(label: 'Currency positions'),
        Text(
          'Foreign currency held with average cost and location.',
          style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
        ),
        const SizedBox(height: 8),
        ..._positionLines.asMap().entries.map((e) => _LineCard(
              line: e.value,
              accounts: accounts,
              onDelete: () => setState(() => _positionLines.removeAt(e.key)),
            )),
        OutlinedButton.icon(
          onPressed: () => _showAddLineSheet(
            context: context,
            accounts: accounts,
            cashAccounts: cashAccounts,
            kind: FxOpeningBalanceLineKind.currencyPosition,
            onAdd: (line) => setState(() => _positionLines.add(line)),
            showLocation: true,
          ),
          icon: const Icon(Icons.add),
          label: const Text('Add currency position'),
        ),
      ],
    );
  }

  Widget _buildPartyStep(BuildContext context, List<FxAccount> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FxSectionLabel(label: 'Party & agent balances'),
        const SizedBox(height: 8),
        ..._partyLines.asMap().entries.map((e) => _LineCard(
              line: e.value,
              accounts: accounts,
              onDelete: () => setState(() => _partyLines.removeAt(e.key)),
            )),
        OutlinedButton.icon(
          onPressed: () => _showAddPartySheet(context: context, onAdd: (line) => setState(() => _partyLines.add(line))),
          icon: const Icon(Icons.add),
          label: const Text('Add party / agent balance'),
        ),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context, List<FxAccount> accounts) {
    final fmt = NumberFormat('#,##0.00');
    final totals = OpeningBalanceLineMapper.batchTotals(_allLines);
    final diff = (totals.totalDebit - totals.totalCredit).abs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isBalanced && _allLines.isNotEmpty)
          _WarningBanner(text: 'Batch is unbalanced by PKR ${fmt.format(diff)}'),
        if (_allLines.isEmpty) _WarningBanner(text: 'Add at least one line before posting'),
        const SizedBox(height: 16),
        _SummaryRow(label: 'Total debits (PKR)', value: fmt.format(totals.totalDebit)),
        _SummaryRow(label: 'Total credits (PKR)', value: fmt.format(totals.totalCredit)),
        _SummaryRow(label: 'Difference', value: fmt.format(diff)),
        const SizedBox(height: 16),
        const FxSectionLabel(label: 'Balancing account'),
        Text(
          'Owner Capital (${OpeningBalanceLineMapper.equityCode}) — Opening Balance Equity',
          style: AppTypography.bodyMd(context.fx.onSurface, context: context),
        ),
        const SizedBox(height: 16),
        const FxSectionLabel(label: 'All lines'),
        ..._allLines.map((l) => _LineCard(line: l, accounts: accounts, onDelete: null)),
      ],
    );
  }

  Widget _buildPostStep(BuildContext context, WidgetRef ref) {
    final viewAsync = ref.watch(openingBalanceStatusProvider);
    return viewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
      data: (view) {
        if (view.batch == null) {
          return const Text('Posted batch details unavailable.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: context.fx.tertiary),
            const SizedBox(height: 12),
            Text(
              'Opening balance posted',
              style: AppTypography.headlineMd(context.fx.onSurface, context: context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                final accounts = await ref.read(accountsProvider.future);
                final parties = await ref.read(partiesProvider(null).future);
                if (!context.mounted) return;
                await shareOpeningBalanceSummary(
                  batch: view.batch!,
                  lines: view.lines,
                  accounts: accounts,
                  parties: parties,
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share opening balance summary'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddLineSheet({
    required BuildContext context,
    required List<FxAccount> accounts,
    required List<FxAccount> cashAccounts,
    required FxOpeningBalanceLineKind kind,
    required void Function(FxOpeningBalanceLine line) onAdd,
    bool showLocation = false,
  }) async {
    String? accountId = cashAccounts.isNotEmpty ? cashAccounts.first.id : null;
    var currency = 'PKR';
    final amountCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '1');
    final locationCtrl = TextEditingController();
    final memoCtrl = TextEditingController();

    final rates = await ref.read(ratesProvider.future);
    void syncRateFromCurrency() {
      if (currency == 'PKR') {
        rateCtrl.text = '1';
      } else {
        final r = rates.where((x) => x.currencyCode == currency).map((x) => x.buyRate).firstOrNull;
        if (r != null) rateCtrl.text = r.toString();
      }
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(ctx).bottom + 16),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              final foreign = double.tryParse(amountCtrl.text) ?? 0;
              final rate = double.tryParse(rateCtrl.text) ?? 1;
              final pkr = OpeningBalanceLineMapper.computePkrAmount(
                currencyCode: currency,
                foreignAmount: foreign,
                rateUsed: rate,
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(kind.label, style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: accountId,
                    decoration: const InputDecoration(labelText: 'Account'),
                    items: cashAccounts
                        .map((a) => DropdownMenuItem(value: a.id, child: Text('${a.code} ${a.name}')))
                        .toList(),
                    onChanged: (v) => setLocal(() => accountId = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: ['PKR', 'USD', 'AED', 'CNY', 'SAR', 'AFN']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      setLocal(() {
                        currency = v ?? 'PKR';
                        syncRateFromCurrency();
                      });
                    },
                  ),
                  TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setLocal(() {})),
                  if (currency != 'PKR')
                    TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'Rate to PKR'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setLocal(() {})),
                  Text('PKR equivalent: ${NumberFormat('#,##0.00').format(pkr)}'),
                  if (showLocation) TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location / counter')),
                  TextField(controller: memoCtrl, decoration: const InputDecoration(labelText: 'Notes')),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: accountId == null || pkr <= 0
                        ? null
                        : () {
                            onAdd(FxOpeningBalanceLine(
                              lineNo: 0,
                              lineKind: kind,
                              accountId: accountId,
                              currencyCode: currency,
                              foreignAmount: foreign,
                              rateUsed: currency == 'PKR' ? 1 : rate,
                              pkrAmount: pkr,
                              locationLabel: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                              memo: memoCtrl.text.trim().isEmpty ? null : memoCtrl.text.trim(),
                            ));
                            Navigator.pop(ctx);
                          },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    amountCtrl.dispose();
    rateCtrl.dispose();
    locationCtrl.dispose();
    memoCtrl.dispose();
  }

  Future<void> _showAddPartySheet({
    required BuildContext context,
    required void Function(FxOpeningBalanceLine line) onAdd,
  }) async {
    final parties = await ref.read(partiesProvider(null).future);
    FxParty? party = parties.isNotEmpty ? parties.first : null;
    var kind = FxOpeningBalanceLineKind.partyReceivable;
    var currency = 'PKR';
    final amountCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '1');
    final memoCtrl = TextEditingController();

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(ctx).bottom + 16),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              final foreign = double.tryParse(amountCtrl.text) ?? 0;
              final rate = double.tryParse(rateCtrl.text) ?? 1;
              final pkr = OpeningBalanceLineMapper.computePkrAmount(
                currencyCode: currency,
                foreignAmount: foreign,
                rateUsed: rate,
              );

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Party / agent balance', style: AppTypography.headlineMd(context.fx.onSurface, context: context)),
                  DropdownButtonFormField<FxParty>(
                    initialValue: party,
                    decoration: const InputDecoration(labelText: 'Party'),
                    items: parties.map((p) => DropdownMenuItem(value: p, child: Text('${p.partyType.label}: ${p.name}'))).toList(),
                    onChanged: (v) => setLocal(() => party = v),
                  ),
                  DropdownButtonFormField<FxOpeningBalanceLineKind>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Balance type'),
                    items: const [
                      DropdownMenuItem(value: FxOpeningBalanceLineKind.partyReceivable, child: Text('Receivable (they owe us)')),
                      DropdownMenuItem(value: FxOpeningBalanceLineKind.partyPayable, child: Text('Payable (we owe them)')),
                    ],
                    onChanged: (v) => setLocal(() => kind = v ?? kind),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: ['PKR', 'USD', 'AED', 'CNY']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setLocal(() => currency = v ?? 'PKR'),
                  ),
                  TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setLocal(() {})),
                  if (currency != 'PKR')
                    TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'Rate to PKR'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setLocal(() {})),
                  Text('PKR equivalent: ${NumberFormat('#,##0.00').format(pkr)}'),
                  TextField(controller: memoCtrl, decoration: const InputDecoration(labelText: 'Notes')),
                  FilledButton(
                    onPressed: party == null || pkr <= 0
                        ? null
                        : () {
                            onAdd(FxOpeningBalanceLine(
                              lineNo: 0,
                              lineKind: kind,
                              partyId: party!.id,
                              currencyCode: currency,
                              foreignAmount: foreign,
                              rateUsed: currency == 'PKR' ? 1 : rate,
                              pkrAmount: pkr,
                              memo: memoCtrl.text.trim().isEmpty ? null : memoCtrl.text.trim(),
                            ));
                            Navigator.pop(ctx);
                          },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    amountCtrl.dispose();
    rateCtrl.dispose();
    memoCtrl.dispose();
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) fn) => fn(this);
}

class _WizardActionBar extends StatelessWidget {
  const _WizardActionBar({
    required this.busy,
    required this.primaryLabel,
    required this.onPrimary,
    required this.showBack,
    required this.onBack,
    required this.showSaveDraft,
    required this.onSaveDraft,
  });

  final bool busy;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool showBack;
  final VoidCallback onBack;
  final bool showSaveDraft;
  final VoidCallback onSaveDraft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: context.fx.surface,
        border: Border(top: BorderSide(color: context.fx.outlineVariant)),
      ),
      child: Row(
        children: [
          if (showBack)
            OutlinedButton(onPressed: busy ? null : onBack, child: const Text('Back')),
          if (showSaveDraft) ...[
            if (showBack) const SizedBox(width: 8),
            TextButton(onPressed: busy ? null : onSaveDraft, child: const Text('Save draft')),
          ],
          const Spacer(),
          FilledButton(
            onPressed: busy ? null : onPrimary,
            child: busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(primaryLabel),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text('Step ${current + 1} of $total', style: AppTypography.labelCaps(context.fx.onSurfaceVariant, context: context)),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(value: (current + 1) / total),
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.fx.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: context.fx.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: context.fx.error, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTypography.bodyMd(context.fx.onSurface, context: context))),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
          Text(value, style: AppTypography.bodyMd(context.fx.onSurface, context: context)),
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({required this.line, required this.accounts, this.onDelete});

  final FxOpeningBalanceLine line;
  final List<FxAccount> accounts;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final accountLabel = line.accountId != null
        ? accounts.where((a) => a.id == line.accountId).map((a) => '${a.code} ${a.name}').firstOrNull
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${line.lineKind.label} — ${line.currencyCode} ${fmt.format(line.foreignAmount)}'),
        subtitle: Text(
          [
            ?accountLabel,
            if (line.locationLabel != null) 'Location: ${line.locationLabel}',
            'PKR ${fmt.format(line.pkrAmount)} @ ${fmt.format(line.rateUsed)}',
          ].join('\n'),
        ),
        trailing: onDelete != null
            ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete)
            : null,
      ),
    );
  }
}
