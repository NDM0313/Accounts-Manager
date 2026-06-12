import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Stitch customer/agent statement activity row.
class FxStitchStatementRow extends StatelessWidget {
  const FxStitchStatementRow({
    super.key,
    required this.line,
    required this.onTap,
    this.embedded = false,
  });

  final PartyStatementLine line;
  final VoidCallback onTap;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final date = DateFormat('MMM d, yyyy').format(line.transactionDate);
    final ref = line.transactionNo ?? line.transactionId.substring(0, 8);
    final badge = _badgeLabel(line);
    final amount = fmt.format(line.pkrEquivalent.abs());
    final debit = line.debitPkr > 0 ? fmt.format(line.debitPkr) : null;
    final credit = line.creditPkr > 0 ? fmt.format(line.creditPkr) : null;

    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                date,
                style: AppTypography.bodySm(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
              const Spacer(),
              Text(
                '#$ref',
                style: AppTypography.labelCaps(
                  context.fx.outline,
                  context: context,
                ).copyWith(fontSize: 9),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.fx.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: AppTypography.labelCaps(
                      context.fx.onPrimary,
                      context: context,
                    ).copyWith(fontSize: 8),
                  ),
                ),
              ],
            ],
          ),
          if (line.description != null && line.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              line.description!,
              style: AppTypography.bodySm(
                context.fx.onSurfaceVariant,
                context: context,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'PKR $amount',
            textAlign: TextAlign.center,
            style: AppTypography.headlineSm(
              context.fx.onSurface,
              context: context,
            ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: context.fx.outlineVariant,
                  style: BorderStyle.solid,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  debit != null ? 'Debit: $debit' : 'No Debit',
                  style: AppTypography.bodySm(
                    debit != null ? context.fx.error : context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                const Spacer(),
                Text(
                  credit != null ? 'Credit: $credit' : 'No Credit',
                  style: AppTypography.bodySm(
                    credit != null
                        ? context.fx.tertiaryContainer
                        : context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              ],
            ),
          ),
        ],
    );

    if (embedded) {
      return InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(14), child: content),
      );
    }
    return FxStitchCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: content,
    );
  }

  String? _badgeLabel(PartyStatementLine line) {
    final d = line.description?.toUpperCase() ?? '';
    if (d.contains('SOLD')) return 'SOLD ${line.currencyCode}'.trim();
    if (d.contains('PAYMENT') || line.creditPkr > 0) return 'PAYMENT';
    if (d.contains('BUY')) return 'BUY ${line.currencyCode}'.trim();
    return null;
  }
}
