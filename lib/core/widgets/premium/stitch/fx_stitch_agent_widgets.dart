import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Agent statement institution header block.
class FxStitchAgentInstitutionHeader extends StatelessWidget {
  const FxStitchAgentInstitutionHeader({
    super.key,
    required this.party,
  });

  final FxParty party;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INSTITUTION',
          style: AppTypography.labelCaps(
            context.fx.secondary,
            context: context,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          party.name,
          style: AppTypography.headlineMd(
            context.fx.primary,
            context: context,
          ).copyWith(letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.verified_user, size: 16, color: context.fx.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Global Sourcing Desk • Agent ID: ${party.code}',
                style: AppTypography.bodySm(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Agent statement 4-card KPI bento.
class FxStitchAgentKpiBento extends StatelessWidget {
  const FxStitchAgentKpiBento({
    super.key,
    required this.summary,
    required this.fmt,
  });

  final PartyStatementSummary summary;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final paid = summary.totalDebitPkr - summary.netBalancePkr;
    final remaining = summary.netBalancePkr.abs();
    final payable = summary.totalDebitPkr.abs();
    final paidPct = payable > 0 ? (paid.abs() / payable).clamp(0.0, 1.0) : 0.0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _KpiCard(
          label: 'CURRENCY RCVD',
          value: fmt.format(summary.totalCreditPkr),
          icon: Icons.payments_outlined,
          iconColor: context.fx.secondary,
        ),
        _KpiCard(
          label: 'AMOUNT PAYABLE',
          value: 'PKR ${fmt.format(payable)}',
          icon: Icons.account_balance_wallet_outlined,
          iconColor: context.fx.error,
        ),
        _KpiCard(
          label: 'AMOUNT PAID',
          value: 'PKR ${fmt.format(paid.abs())}',
          icon: Icons.check_circle_outline,
          iconColor: context.fx.onSecondaryContainer,
          backgroundColor: context.fx.primary,
          valueColor: context.fx.onSecondaryContainer,
          labelColor: context.fx.onSecondaryContainer,
          subtitle: '${(paidPct * 100).round()}% Settled',
        ),
        _KpiCard(
          label: 'REMAINING',
          value: 'PKR ${fmt.format(remaining)}',
          icon: Icons.pending_actions_outlined,
          iconColor: Colors.white70,
          backgroundColor: context.fx.secondaryContainer,
          valueColor: Colors.white,
          labelColor: Colors.white,
          progress: 1 - paidPct,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.backgroundColor,
    this.valueColor,
    this.labelColor,
    this.subtitle,
    this.progress,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? backgroundColor;
  final Color? valueColor;
  final Color? labelColor;
  final String? subtitle;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor ?? context.fx.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: backgroundColor == null
            ? Border.all(color: context.fx.outlineVariant)
            : null,
        boxShadow: backgroundColor == context.fx.primary
            ? [
                BoxShadow(
                  color: context.fx.primary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTypography.labelCaps(
                  labelColor ?? context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 9),
              ),
              Icon(icon, size: 20, color: iconColor.withValues(alpha: 0.6)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.headlineSm(
                  valueColor ?? context.fx.primary,
                  context: context,
                ).copyWith(fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTypography.bodySm(
                    context.fx.tertiaryContainer,
                    context: context,
                  ).copyWith(fontSize: 11),
                ),
              if (progress != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Agent deal ledger row per Stitch mock.
class FxStitchAgentDealRow extends StatelessWidget {
  const FxStitchAgentDealRow({
    super.key,
    required this.item,
    required this.fmt,
    required this.onTap,
    this.highlighted = false,
  });

  final PartyDealOpenItem item;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final status = item.dealStatus;
    final (statusLabel, statusColor) = _statusStyle(context, status);
    final rate = item.sellAmount > 0
        ? (item.payablePkr / item.sellAmount)
        : 0.0;

    return Material(
      color: context.fx.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border(
              left: BorderSide(
                color: highlighted
                    ? context.fx.secondary
                    : context.fx.outlineVariant,
                width: highlighted ? 4 : 1,
              ),
              top: BorderSide(color: context.fx.outlineVariant),
              right: BorderSide(color: context.fx.outlineVariant),
              bottom: BorderSide(color: context.fx.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: highlighted
                          ? context.fx.secondaryContainer
                          : context.fx.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      highlighted
                          ? Icons.receipt_long_outlined
                          : Icons.currency_exchange,
                      size: 18,
                      color: highlighted
                          ? context.fx.secondary
                          : context.fx.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deal #${item.dealNo ?? item.dealId.substring(0, 8)}',
                          style: AppTypography.bodyMd(
                            context.fx.primary,
                            context: context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${item.sellCurrency ?? ''} ${fmt.format(item.sellAmount)}',
                          style: AppTypography.bodySm(
                            context.fx.onSurfaceVariant,
                            context: context,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel.toUpperCase(),
                      style: AppTypography.labelCaps(
                        statusColor,
                        context: context,
                      ).copyWith(fontSize: 9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _miniCell(
                      context,
                      'RATE',
                      rate > 0 ? fmt.format(rate) : '—',
                    ),
                  ),
                  Expanded(
                    child: _miniCell(
                      context,
                      'PKR EQ.',
                      fmt.format(item.payablePkr),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniCell(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelCaps(
            context.fx.onSurfaceVariant,
            context: context,
          ).copyWith(fontSize: 8),
        ),
        Text(
          value,
          style: AppTypography.bodyMd(context.fx.primary, context: context),
        ),
      ],
    );
  }

  (String, Color) _statusStyle(BuildContext context, FxDealStatus status) {
    if (status.isOpen) return ('Pending', context.fx.secondary);
    if (status == FxDealStatus.completed) return ('Paid', context.fx.tertiaryFixedDim);
    return (status.label, context.fx.onSurfaceVariant);
  }
}

/// Transfer lifecycle compact timeline for agent statement.
class FxStitchAgentTransferTimeline extends StatelessWidget {
  const FxStitchAgentTransferTimeline({super.key, required this.lines});

  final List<PartyStatementLine> lines;

  @override
  Widget build(BuildContext context) {
    final recent = lines.take(3).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transfer Lifecycle (Recent)',
          style: AppTypography.headlineSm(
            context.fx.primary,
            context: context,
          ),
        ),
        const SizedBox(height: 12),
        FxStitchCard(
          color: context.fx.surfaceContainer,
          child: Column(
            children: [
              for (var i = 0; i < recent.length; i++)
                _TimelineNode(
                  title: recent[i].transactionType.label,
                  subtitle:
                      '${recent[i].currencyCode} ${NumberFormat('#,##0.00').format(recent[i].foreignAmount)}',
                  time: DateFormat('HH:mm').format(recent[i].transactionDate),
                  isLast: i == recent.length - 1,
                  active: i == recent.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isLast,
    this.active = false,
  });

  final String title;
  final String subtitle;
  final String time;
  final bool isLast;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? context.fx.secondaryContainer
                      : context.fx.tertiaryFixedDim,
                  border: active
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: Icon(
                  active ? Icons.sync : Icons.check,
                  size: 14,
                  color: active ? Colors.white : context.fx.tertiary,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    color: context.fx.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMd(
                      context.fx.onSurface,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ),
                  ),
                  Text(
                    time,
                    style: AppTypography.labelCaps(
                      active ? context.fx.secondary : context.fx.onSurfaceVariant,
                      context: context,
                    ).copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
