import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Customer search field with icon + chevron.
class FxStitchReceivePaymentCustomerField extends StatelessWidget {
  const FxStitchReceivePaymentCustomerField({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'CUSTOMER',
          style: AppTypography.labelCaps(
            context.fx.onSurfaceVariant,
            context: context,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: context.fx.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: context.fx.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(Icons.search, color: context.fx.onSurfaceVariant, size: 20),
              const SizedBox(width: 8),
              Expanded(child: child),
              Icon(
                Icons.expand_more,
                color: context.fx.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Glass amount card with currency prefix.
class FxStitchReceivePaymentAmountCard extends StatelessWidget {
  const FxStitchReceivePaymentAmountCard({
    super.key,
    required this.currencyCode,
    required this.amountField,
    this.currencyField,
    this.methodField,
  });

  final String currencyCode;
  final Widget amountField;
  final Widget? currencyField;
  final Widget? methodField;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      color: context.fx.surfaceContainerLowest.withValues(alpha: 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'AMOUNT RECEIVED',
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                currencyCode,
                style: AppTypography.currencyDisplay(
                  color: context.fx.primary,
                  mobile: true,
                  context: context,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: amountField),
            ],
          ),
          if (currencyField != null || methodField != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (currencyField != null) Expanded(child: currencyField!),
                if (currencyField != null && methodField != null)
                  const SizedBox(width: 12),
                if (methodField != null) Expanded(child: methodField!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Allocation section with outstanding balance header.
class FxStitchReceivePaymentAllocationCard extends StatelessWidget {
  const FxStitchReceivePaymentAllocationCard({
    super.key,
    required this.outstandingLabel,
    required this.dealField,
    required this.referenceField,
    this.onAttachProof,
  });

  final String outstandingLabel;
  final Widget dealField;
  final Widget referenceField;
  final VoidCallback? onAttachProof;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.link, color: context.fx.secondary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Allocation',
                style: AppTypography.headlineSm(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'OUTSTANDING',
                    style: AppTypography.labelCaps(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ),
                  ),
                  Text(
                    outstandingLabel,
                    style: AppTypography.dataLg(
                      context.fx.error,
                      context: context,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Divider(color: context.fx.outlineVariant, height: 24),
          dealField,
          const SizedBox(height: 12),
          referenceField,
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAttachProof,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: context.fx.outlineVariant,
                width: 2,
                style: BorderStyle.solid,
              ),
              foregroundColor: context.fx.onSurfaceVariant,
            ),
            icon: const Icon(Icons.attach_file),
            label: const Text('Attach Proof of Payment (PDF, JPG)'),
          ),
        ],
      ),
    );
  }
}

/// Navy payment summary sidebar card.
class FxStitchPaymentSummaryCard extends StatelessWidget {
  const FxStitchPaymentSummaryCard({
    super.key,
    required this.originalBalance,
    required this.paymentApplied,
    required this.remainingBalance,
    required this.currencyCode,
    this.isFullSettlement = false,
  });

  final double originalBalance;
  final double paymentApplied;
  final double remainingBalance;
  final String currencyCode;
  final bool isFullSettlement;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final cur = currencyCode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.fx.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: context.fx.primary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -32,
            right: -32,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: context.fx.secondary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'PAYMENT SUMMARY',
                style: AppTypography.labelCaps(
                  context.fx.onPrimaryContainer.withValues(alpha: 0.8),
                  context: context,
                ),
              ),
              const SizedBox(height: 16),
              _SummaryLine(
                label: 'Original Balance',
                value: '$cur ${fmt.format(originalBalance)}',
                muted: true,
              ),
              const SizedBox(height: 8),
              _SummaryLine(
                label: 'Payment Applied',
                value: '- $cur ${fmt.format(paymentApplied)}',
                accent: context.fx.tertiaryFixedDim,
              ),
              Divider(
                color: context.fx.onPrimaryContainer.withValues(alpha: 0.2),
                height: 24,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Remaining Balance',
                    style: AppTypography.bodyMd(
                      context.fx.onPrimaryContainer,
                      context: context,
                    ),
                  ),
                  Text(
                    '$cur ${fmt.format(remainingBalance)}',
                    style: AppTypography.currencyDisplay(
                      color: context.fx.onPrimary,
                      mobile: true,
                      context: context,
                    ).copyWith(fontSize: 28),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFullSettlement
                      ? context.fx.tertiary
                      : context.fx.tertiaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: isFullSettlement
                          ? context.fx.tertiaryFixedDim
                          : context.fx.tertiaryFixedDim,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isFullSettlement ? 'FULL SETTLEMENT' : 'PARTIAL PAYMENT',
                      style: AppTypography.labelCaps(
                        isFullSettlement
                            ? context.fx.onTertiary
                            : context.fx.tertiaryFixedDim,
                        context: context,
                      ).copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.muted = false,
    this.accent,
  });

  final String label;
  final String value;
  final bool muted;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyMd(
            muted
                ? context.fx.onPrimaryContainer
                : (accent ?? context.fx.onPrimaryContainer),
            context: context,
          ),
        ),
        Text(
          value,
          style: AppTypography.dataMd(
            accent ?? context.fx.onPrimary,
            context: context,
          ),
        ),
      ],
    );
  }
}

/// Post to Ledger CTA + footnote.
class FxStitchReceivePaymentActions extends StatelessWidget {
  const FxStitchReceivePaymentActions({
    super.key,
    required this.onPost,
    this.ledgerNote = 'Transaction will be recorded in Ledger',
    this.busy = false,
  });

  final VoidCallback onPost;
  final String ledgerNote;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : onPost,
          style: FilledButton.styleFrom(
            backgroundColor: context.fx.secondary,
            foregroundColor: context.fx.onSecondary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            ),
          ),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_outlined),
          label: const Text('Post to Ledger'),
        ),
        const SizedBox(height: 8),
        Text(
          ledgerNote,
          textAlign: TextAlign.center,
          style: AppTypography.bodySm(
            context.fx.onSurfaceVariant,
            context: context,
          ),
        ),
      ],
    );
  }
}

/// Flow analysis decorative card.
class FxStitchReceivePaymentFlowCard extends StatelessWidget {
  const FxStitchReceivePaymentFlowCard({super.key, this.insight});

  final String? insight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            context.fx.surface,
            context.fx.surfaceContainerHigh.withValues(alpha: 0.3),
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      alignment: Alignment.bottomLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FLOW ANALYSIS',
            style: AppTypography.labelCaps(
              context.fx.primary,
              context: context,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            insight ?? 'Payment contributes to monthly collection target.',
            style: AppTypography.bodySm(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stitch select field wrapper for receive payment forms.
class FxStitchReceivePaymentSelect extends StatelessWidget {
  const FxStitchReceivePaymentSelect({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelCaps(
            context.fx.onSurfaceVariant,
            context: context,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: context.fx.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: context.fx.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: child,
        ),
      ],
    );
  }
}
