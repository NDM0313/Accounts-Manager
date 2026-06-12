import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Daily closing report cards grouped by currency (Stitch daily_closing_report mock).
class FxClosingReportView extends StatelessWidget {
  const FxClosingReportView({
    super.key,
    required this.rows,
    required this.dateLabel,
  });

  final List<ClosingPreviewRow> rows;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final fmt = NumberFormat('#,##0.00');

    final byCurrency = <String, List<ClosingPreviewRow>>{};
    for (final r in rows) {
      byCurrency.putIfAbsent(r.currencyCode, () => []).add(r);
    }

    final currencies = byCurrency.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxSectionLabel(label: 'Closing report · $dateLabel'),
        const SizedBox(height: 12),
        for (final currency in currencies) ...[
          _CurrencyCard(
            currencyCode: currency,
            accounts: byCurrency[currency]!,
            fmt: fmt,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  const _CurrencyCard({
    required this.currencyCode,
    required this.accounts,
    required this.fmt,
  });

  final String currencyCode;
  final List<ClosingPreviewRow> accounts;
  final NumberFormat fmt;

  double get _totalClosing =>
      accounts.fold<double>(0, (s, r) => s + r.systemBalance);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                currencyCode,
                style: AppTypography.headlineMd(
                  context.fx.onSurface,
                  context: context,
                ).copyWith(fontSize: 18),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Closing balance',
                    style: AppTypography.labelCaps(
                      context.fx.outline,
                      context: context,
                    ).copyWith(fontSize: 10),
                  ),
                  Text(
                    fmt.format(_totalClosing),
                    style: AppTypography.labelMono(
                      context.fx.tertiary,
                      context: context,
                    ).copyWith(fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          if (accounts.length > 1) ...[
            const SizedBox(height: 16),
            Text(
              'By account',
              style: AppTypography.labelCaps(
                context.fx.outline,
                context: context,
              ),
            ),
            const SizedBox(height: 8),
            for (final r in accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${r.accountCode} · ${r.accountName}',
                      style: AppTypography.bodyMd(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ).copyWith(fontSize: 12),
                    ),
                    Text(
                      fmt.format(r.systemBalance),
                      style: AppTypography.labelMono(
                        context.fx.onSurface,
                        context: context,
                      ).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
