import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// MTCN header with copy + status pill.
class FxStitchRemittanceMtcnHeader extends StatelessWidget {
  const FxStitchRemittanceMtcnHeader({
    super.key,
    required this.trackingId,
    required this.statusLabel,
    this.showReadyPill = false,
  });

  final String trackingId;
  final String statusLabel;
  final bool showReadyPill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRACKING NUMBER (MTCN)',
                  style: AppTypography.labelCaps(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        trackingId,
                        style: AppTypography.headlineLg(
                          context.fx.primary,
                          context: context,
                        ).copyWith(letterSpacing: 2, fontSize: 24),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.content_copy, size: 18, color: context.fx.secondary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: trackingId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('MTCN copied')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showReadyPill)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.fx.tertiaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: context.fx.tertiaryContainer.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: context.fx.tertiaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: AppTypography.dataMd(
                      context.fx.tertiaryContainer,
                      context: context,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Remittance payout bento layout per global_remittance_payout mock.
class FxStitchRemittancePayoutLayout extends StatelessWidget {
  const FxStitchRemittancePayoutLayout({
    super.key,
    required this.remittance,
    required this.fmt,
    this.onSharePickup,
    this.actionSection,
    this.timelineSection,
  });

  final FxRemittance remittance;
  final NumberFormat fmt;
  final VoidCallback? onSharePickup;
  final Widget? actionSection;
  final Widget? timelineSection;

  @override
  Widget build(BuildContext context) {
    final r = remittance;
    final rateLabel =
        '1 ${r.receiveCurrency} = ${r.exchangeRate.toStringAsFixed(2)} ${r.payoutCurrency}';

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxStitchCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: context.fx.surfaceContainer,
                    child: Icon(Icons.currency_exchange, color: context.fx.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Transfer Summary',
                    style: AppTypography.headlineSm(
                      context.fx.primary,
                      context: context,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'LIVE EXCHANGE RATE',
                        style: AppTypography.labelCaps(
                          context.fx.onSurfaceVariant,
                          context: context,
                        ).copyWith(fontSize: 9),
                      ),
                      Text(
                        rateLabel,
                        style: AppTypography.dataMd(
                          context.fx.secondary,
                          context: context,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: context.fx.outlineVariant),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _AmountBox(
                      label: 'Sender Pays (${r.receiveCurrency})',
                      amount: fmt.format(r.receiveAmount),
                      currency: r.receiveCurrency,
                      subtitle: r.commissionAmount > 0
                          ? '+ ${fmt.format(r.commissionAmount)} fee'
                          : null,
                      muted: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AmountBox(
                      label: 'Recipient Receives (${r.payoutCurrency})',
                      amount: fmt.format(r.payoutAmount),
                      currency: r.payoutCurrency,
                      subtitle: 'Guaranteed Payout',
                      highlighted: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _IdentityCard(
                title: 'Recipient Details',
                icon: Icons.person,
                rows: [
                  ('Full Name', r.receiverName),
                  if (r.receiverPhone != null)
                    ('Phone Number', r.receiverPhone!),
                  if (r.receiverCity != null)
                    ('City', '${r.receiverCity}${r.receiverCountry != null ? ', ${r.receiverCountry}' : ''}'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _IdentityCard(
                title: 'Sender Details',
                icon: Icons.outbound,
                rows: [
                  ('Sent By', r.senderName ?? '—'),
                  ('Payment Method', r.payoutMethod ?? 'Cash / Transfer'),
                  if (r.branchName != null) ('Branch', r.branchName!),
                ],
              ),
            ),
          ],
        ),
        if (actionSection != null) ...[
          const SizedBox(height: 16),
          actionSection!,
        ],
        if (timelineSection != null) ...[
          const SizedBox(height: 16),
          timelineSection!,
        ],
      ],
    );

    final pickupColumn = _PickupColumn(
      agentName: r.payoutAgentName ?? 'Payout Agent',
      branchName: r.branchName ?? 'Branch pickup',
      onSharePickup: onSharePickup,
      payoutCode: r.payoutCode,
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: leftColumn),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: pickupColumn),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            leftColumn,
            const SizedBox(height: 16),
            pickupColumn,
          ],
        );
      },
    );
  }
}

class _AmountBox extends StatelessWidget {
  const _AmountBox({
    required this.label,
    required this.amount,
    required this.currency,
    this.subtitle,
    this.muted = false,
    this.highlighted = false,
  });

  final String label;
  final String amount;
  final String currency;
  final String? subtitle;
  final bool muted;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted
            ? context.fx.surfaceContainerHighest
            : context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: highlighted
              ? context.fx.secondary.withValues(alpha: 0.3)
              : context.fx.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 9),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  amount,
                  style: AppTypography.headlineLg(
                    highlighted ? context.fx.secondary : context.fx.primary,
                    context: context,
                  ).copyWith(fontSize: 22),
                ),
              ),
              Text(
                currency,
                style: AppTypography.dataMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppTypography.bodySm(
                highlighted ? context.fx.secondary : context.fx.onSurfaceVariant,
                context: context,
              ).copyWith(fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.fx.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.dataLg(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.$1.toUpperCase(),
                    style: AppTypography.labelCaps(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ).copyWith(fontSize: 9),
                  ),
                  Text(
                    r.$2,
                    style: AppTypography.bodyMd(
                      context.fx.onSurface,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.w600),
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

class _PickupColumn extends StatelessWidget {
  const _PickupColumn({
    required this.agentName,
    required this.branchName,
    this.onSharePickup,
    this.payoutCode,
  });

  final String agentName;
  final String branchName;
  final VoidCallback? onSharePickup;
  final String? payoutCode;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.location_on, color: context.fx.primary),
                const SizedBox(width: 8),
                Text(
                  'Pickup Location',
                  style: AppTypography.dataLg(
                    context.fx.onSurface,
                    context: context,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Change',
                    style: AppTypography.dataMd(
                      context.fx.secondary,
                      context: context,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.fx.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: context.fx.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.fx.secondary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'NEAREST',
                        style: AppTypography.labelCaps(
                          Colors.white,
                          context: context,
                        ).copyWith(fontSize: 8),
                      ),
                    ),
                  ),
                  Text(
                    agentName,
                    style: AppTypography.bodyMd(
                      context.fx.onSurface,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    branchName,
                    style: AppTypography.bodySm(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: context.fx.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border.all(color: context.fx.outlineVariant),
              ),
              child: Center(
                child: Icon(
                  Icons.map_outlined,
                  size: 48,
                  color: context.fx.outlineVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSharePickup,
                style: FilledButton.styleFrom(
                  backgroundColor: context.fx.primary,
                ),
                icon: const Icon(Icons.share),
                label: const Text('Share Pickup Info with Recipient'),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.fx.surfaceContainerLowest,
              border: Border(top: BorderSide(color: context.fx.outlineVariant)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.fx.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.qr_code_2,
                    color: context.fx.onSecondaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fast Track Pickup',
                        style: AppTypography.bodySm(
                          context.fx.onSurface,
                          context: context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        payoutCode != null
                            ? 'Code: $payoutCode'
                            : 'Recipient can scan at the counter.',
                        style: AppTypography.bodySm(
                          context.fx.onSurfaceVariant,
                          context: context,
                        ).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AML compliance footer.
class FxStitchRemittanceComplianceFooter extends StatelessWidget {
  const FxStitchRemittanceComplianceFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_user, size: 18, color: context.fx.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'SECURE BANK-GRADE ENCRYPTION',
                style: AppTypography.labelCaps(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This transaction is subject to verification. FX Cash Ledger complies with all AML and KYC regulations.',
            style: AppTypography.bodySm(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
