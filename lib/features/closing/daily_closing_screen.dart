import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_closing_report_view.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_dialog.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_pickers.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class DailyClosingScreen extends ConsumerStatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  ConsumerState<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends ConsumerState<DailyClosingScreen> {
  final _notesCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final closingDate = ref.watch(closingDateProvider);
    final previewAsync = ref.watch(closingPreviewProvider);
    final closedAsync = ref.watch(closingDayClosedProvider);
    final fmt = NumberFormat('#,##0.00');
    final dateLabel = closingDate.toIso8601String().split('T').first;
    final horizontal = MediaQuery.sizeOf(context).width >= 900 ? AppSpacing.marginDesktop : AppSpacing.marginMobile;

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Daily Closing'),
        backgroundColor: context.fx.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () => _pickDate(context, ref, closingDate),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.fx.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(color: context.fx.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FxSectionLabel(label: 'Closing date'),
                      Text(dateLabel, style: AppTypography.headlineMd(Theme.of(context).colorScheme.onSurface, context: context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          closedAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (closed) {
              if (!closed) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.fx.tertiaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: context.fx.tertiary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.tertiary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This day is already closed. Posting and edits are blocked.',
                        style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurface, context: context),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          FxSectionLabel(label: 'System cash counts'),
          const SizedBox(height: 12),
          previewAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => Text('Unable to load preview: $e'),
            data: (rows) {
              if (rows.isEmpty) {
                return Text(
                  'No cash accounts to close. Post transactions first.',
                  style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context),
                );
              }
              return Column(
                children: rows.map((r) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: context.fx.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: context.fx.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r.accountCode} · ${r.accountName}', style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurface, context: context).copyWith(fontWeight: FontWeight.w600)),
                              Text(r.currencyCode, style: AppTypography.bodyMd(Theme.of(context).colorScheme.onSurfaceVariant, context: context).copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(fmt.format(r.systemBalance), style: AppTypography.headlineMd(Theme.of(context).colorScheme.onSurface, context: context).copyWith(fontSize: 16)),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          FxSectionLabel(label: 'Closing notes'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              hintText: 'Optional notes for this closing…',
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            enabled: !_busy,
          ),
          const SizedBox(height: 24),
          closedAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (closed) {
              if (!closed) {
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _closeDay,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      foregroundColor: context.fx.background,
                    ),
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Close Daily Ledger', style: AppTypography.labelCaps(context.fx.background, context: context).copyWith(fontSize: 12)),
                  ),
                );
              }
              return previewAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (rows) => FxClosingReportView(rows: rows, dateLabel: dateLabel),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, DateTime current) async {
    final picked = await FxObsidianPickers.showDate(
      context,
      initialDate: current,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(closingDateProvider.notifier).setDate(picked);
    }
  }

  Future<void> _closeDay() async {
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null) return;

    final ok = await showFxObsidianConfirmDialog(
      context: context,
      title: 'Close day?',
      message: 'This locks the selected date for posting and transaction edits. Continue?',
      confirmLabel: 'Close day',
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final date = ref.read(closingDateProvider);
      await ref.read(reportRepositoryProvider).closeDay(
            profile.branchId,
            closingDate: date,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      ref.invalidate(closingPreviewProvider);
      ref.invalidate(closingDayClosedProvider);
      ref.invalidate(dayClosedProvider);
      ref.invalidate(auditLogsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Day closed successfully.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Close failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
