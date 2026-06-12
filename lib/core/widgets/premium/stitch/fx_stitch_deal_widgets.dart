import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/domain/services/deal_workflow_guide.dart';
import 'package:flutter/material.dart';

/// Deal detail 2x2 summary card.
class FxStitchDealSummaryCard extends StatelessWidget {
  const FxStitchDealSummaryCard({
    super.key,
    required this.customer,
    required this.amount,
    required this.rate,
    required this.pkrTotal,
  });

  final String customer;
  final String amount;
  final String rate;
  final String pkrTotal;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _cell(context, 'CUSTOMER', customer, context.fx.onSurface)),
              Expanded(child: _cell(context, 'TOTAL AMOUNT', amount, context.fx.onSurface)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _cell(context, 'EXCHANGE RATE', rate, context.fx.onSurface)),
              Expanded(child: _cell(context, 'TOTAL PKR', pkrTotal, context.fx.secondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext c, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelCaps(
            c.fx.onSurfaceVariant,
            context: c,
          ).copyWith(fontSize: 9),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.headlineSm(color, context: c).copyWith(fontSize: 15),
        ),
      ],
    );
  }
}

/// Vertical deal lifecycle timeline per Stitch mock.
enum FxStitchProofAction { viewProof, addProof, locked }

class FxStitchWorkflowTimeline extends StatelessWidget {
  const FxStitchWorkflowTimeline({
    super.key,
    required this.steps,
    this.onStepTap,
    this.onProofTap,
    this.proofActionFor,
  });

  final List<DealWorkflowStep> steps;
  final void Function(DealWorkflowStep step)? onStepTap;
  final void Function(DealWorkflowStep step)? onProofTap;
  final FxStitchProofAction Function(DealWorkflowStep step)? proofActionFor;

  @override
  Widget build(BuildContext context) {
    final visible = steps
        .where((s) => s.status != DealWorkflowStepStatus.skipped)
        .toList();
    return FxStitchCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deal Lifecycle',
            style: AppTypography.headlineSm(
              context.fx.primary,
              context: context,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < visible.length; i++)
            _StepRow(
              step: visible[i],
              isLast: i == visible.length - 1,
              proofAction: proofActionFor?.call(visible[i]) ??
                  _defaultProofAction(visible[i]),
              onProofTap: onProofTap != null
                  ? () => onProofTap!(visible[i])
                  : null,
            ),
        ],
      ),
    );
  }

  static FxStitchProofAction _defaultProofAction(DealWorkflowStep step) {
    if (step.status == DealWorkflowStepStatus.completed) {
      return step.attachmentCount > 0
          ? FxStitchProofAction.viewProof
          : FxStitchProofAction.locked;
    }
    if (step.status == DealWorkflowStepStatus.pending ||
        step.status == DealWorkflowStepStatus.partial) {
      return FxStitchProofAction.addProof;
    }
    return FxStitchProofAction.locked;
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isLast,
    this.proofAction,
    this.onProofTap,
  });

  final DealWorkflowStep step;
  final bool isLast;
  final FxStitchProofAction? proofAction;
  final VoidCallback? onProofTap;

  @override
  Widget build(BuildContext context) {
    final completed = step.status == DealWorkflowStepStatus.completed;
    final pending = step.status == DealWorkflowStepStatus.pending;
    final partial = step.status == DealWorkflowStepStatus.partial;
    final active = pending || partial;
    final nodeColor = completed
        ? context.fx.tertiaryContainer
        : active
        ? context.fx.secondary
        : context.fx.outlineVariant;

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
                  color: completed
                      ? context.fx.tertiaryContainer
                      : active
                      ? context.fx.surfaceContainerHigh
                      : context.fx.surfaceContainerLow,
                  border: Border.all(
                    color: active ? context.fx.secondary : nodeColor,
                    width: active ? 2 : 1,
                  ),
                ),
                child: completed
                    ? Icon(Icons.check_circle, size: 16, color: context.fx.onTertiary)
                    : active
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.fx.secondary,
                          ),
                        ),
                      )
                    : Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.fx.outlineVariant,
                          ),
                        ),
                      ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: completed
                        ? context.fx.secondary.withValues(alpha: 0.4)
                        : context.fx.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.label,
                          style: AppTypography.bodyMd(
                            active
                                ? context.fx.secondary
                                : completed
                                ? context.fx.onSurface
                                : context.fx.onSurfaceVariant,
                            context: context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (step.amountLabel != null)
                          Text(
                            step.amountLabel!,
                            style: AppTypography.bodySm(
                              context.fx.onSurfaceVariant,
                              context: context,
                            ),
                          ),
                        if (step.partyName != null)
                          Text(
                            step.partyName!,
                            style: AppTypography.bodySm(
                              context.fx.onSurfaceVariant,
                              context: context,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (proofAction != null)
                    _ProofButton(
                      action: proofAction!,
                      onTap: onProofTap,
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

class _ProofButton extends StatelessWidget {
  const _ProofButton({required this.action, this.onTap});

  final FxStitchProofAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = action == FxStitchProofAction.locked;
    final label = switch (action) {
      FxStitchProofAction.viewProof => 'VIEW PROOF',
      FxStitchProofAction.addProof => 'ADD PROOF',
      FxStitchProofAction.locked => 'LOCKED',
    };
    final icon = switch (action) {
      FxStitchProofAction.viewProof => Icons.attachment,
      FxStitchProofAction.addProof => Icons.attach_file,
      FxStitchProofAction.locked => Icons.lock_outline,
    };
    final color = locked
        ? context.fx.outlineVariant
        : action == FxStitchProofAction.addProof
        ? context.fx.secondary
        : context.fx.onSurfaceVariant;

    return TextButton.icon(
      onPressed: locked ? null : onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: AppTypography.labelCaps(color, context: context).copyWith(
          fontSize: 9,
        ),
      ),
    );
  }
}

/// Navy "Next Action Required" card.
class FxStitchDealNextActionCard extends StatelessWidget {
  const FxStitchDealNextActionCard({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.fx.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: context.fx.onPrimaryContainer, size: 18),
              const SizedBox(width: 8),
              Text(
                'NEXT ACTION REQUIRED',
                style: AppTypography.labelCaps(
                  context.fx.onPrimaryContainer,
                  context: context,
                ).copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTypography.headlineSm(
              Colors.white,
              context: context,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: context.fx.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.arrow_forward),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Deal health insight card with progress bar.
class FxStitchDealHealthCard extends StatelessWidget {
  const FxStitchDealHealthCard({
    super.key,
    this.leadTimeLabel = '1.4h',
    this.progress = 0.85,
    this.caption = 'Processing faster than 85% of similar deals.',
  });

  final String leadTimeLabel;
  final double progress;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      color: context.fx.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEAL HEALTH',
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ).copyWith(fontSize: 9),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Lead Time',
                style: AppTypography.bodyMd(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
              const Spacer(),
              Text(
                leadTimeLabel,
                style: AppTypography.headlineSm(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: context.fx.outlineVariant.withValues(alpha: 0.4),
              color: context.fx.tertiaryFixedDim,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
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
