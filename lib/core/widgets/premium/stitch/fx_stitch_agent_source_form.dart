import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:flutter/material.dart';

/// Stitch agent_source_leg bento form layout.
class FxStitchAgentSourceForm extends StatelessWidget {
  const FxStitchAgentSourceForm({
    super.key,
    required this.agents,
    required this.agentId,
    required this.onAgentChanged,
    required this.receiveAmountCtrl,
    required this.payAmountCtrl,
    required this.receiveCurrency,
    required this.payCurrency,
    required this.onReceiveCurrencyChanged,
    required this.onPayCurrencyChanged,
    required this.dealRateLabel,
    required this.referenceRateLabel,
    required this.spreadLabel,
    required this.pkrEquivalentLabel,
    required this.pkrCaption,
    required this.deliveryTarget,
    required this.onDeliveryChanged,
    required this.notesCtrl,
    this.warningText,
    this.rateField,
    this.proofSection,
    this.onSwap,
  });

  final List<FxParty> agents;
  final String? agentId;
  final ValueChanged<String?> onAgentChanged;
  final TextEditingController receiveAmountCtrl;
  final TextEditingController payAmountCtrl;
  final String? receiveCurrency;
  final String payCurrency;
  final ValueChanged<String?> onReceiveCurrencyChanged;
  final ValueChanged<String?> onPayCurrencyChanged;
  final String dealRateLabel;
  final String referenceRateLabel;
  final String? spreadLabel;
  final String pkrEquivalentLabel;
  final String pkrCaption;
  final FxDeliveryTarget deliveryTarget;
  final ValueChanged<FxDeliveryTarget> onDeliveryChanged;
  final TextEditingController notesCtrl;
  final String? warningText;
  final Widget? rateField;
  final Widget? proofSection;
  final VoidCallback? onSwap;

  static const _currencies = ['CNY', 'USD', 'AED', 'SAR', 'PKR', 'EUR'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WorkflowDots(),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 700;
            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FxStitchCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT AGENT',
                        style: AppTypography.labelCaps(
                          context.fx.onSurfaceVariant,
                          context: context,
                        ).copyWith(fontSize: 9),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: agentId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: context.fx.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                          ),
                        ),
                        items: agents
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                            )
                            .toList(),
                        onChanged: onAgentChanged,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FxStitchCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AmountRow(
                        label: 'RECEIVE FROM AGENT',
                        controller: receiveAmountCtrl,
                        currency: receiveCurrency ?? 'USD',
                        currencies: _currencies,
                        onCurrencyChanged: onReceiveCurrencyChanged,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: IconButton.filled(
                          onPressed: onSwap,
                          style: IconButton.styleFrom(
                            backgroundColor: context.fx.primary,
                            foregroundColor: context.fx.onPrimary,
                          ),
                          icon: const Icon(Icons.sync_alt, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _AmountRow(
                        label: 'PAY TO AGENT',
                        controller: payAmountCtrl,
                        currency: payCurrency,
                        currencies: _currencies,
                        onCurrencyChanged: onPayCurrencyChanged,
                      ),
                      if (rateField != null) ...[
                        const SizedBox(height: 12),
                        rateField!,
                      ],
                    ],
                  ),
                ),
              ],
            );

            final right = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.fx.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(
                      color: context.fx.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rate Comparison',
                                  style: AppTypography.headlineSm(
                                    Colors.white,
                                    context: context,
                                  ),
                                ),
                                Text(
                                  'Deal vs Ref Market',
                                  style: AppTypography.bodySm(
                                    context.fx.onPrimaryContainer,
                                    context: context,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.trending_up,
                            color: context.fx.tertiaryFixedDim,
                            size: 32,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _RateBox(
                              label: 'DEAL RATE',
                              value: dealRateLabel,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _RateBox(
                              label: 'REF RATE',
                              value: referenceRateLabel,
                            ),
                          ),
                        ],
                      ),
                      if (spreadLabel != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.fx.tertiary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                spreadLabel!,
                                style: AppTypography.labelCaps(
                                  context.fx.onTertiary,
                                  context: context,
                                ).copyWith(fontSize: 9),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Within tolerance',
                              style: AppTypography.bodySm(
                                context.fx.onPrimaryContainer,
                                context: context,
                              ).copyWith(fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FxStitchCard(
                  color: context.fx.surfaceContainerHigh,
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: context.fx.surfaceContainerLowest,
                        child: Icon(Icons.calculate, color: context.fx.secondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PKR EQUIVALENT',
                              style: AppTypography.labelCaps(
                                context.fx.onSurfaceVariant,
                                context: context,
                              ).copyWith(fontSize: 9),
                            ),
                            Text(
                              pkrEquivalentLabel,
                              style: AppTypography.headlineMd(
                                context.fx.primary,
                                context: context,
                              ).copyWith(fontSize: 24),
                            ),
                            Text(
                              pkrCaption,
                              style: AppTypography.bodySm(
                                context.fx.onSurfaceVariant,
                                context: context,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (warningText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.fx.errorContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      border: Border.all(
                        color: context.fx.error.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning, color: context.fx.error),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Low Balance Alert',
                                style: AppTypography.bodyMd(
                                  context.fx.error,
                                  context: context,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                warningText!,
                                style: AppTypography.bodySm(
                                  context.fx.error,
                                  context: context,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );

            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 16),
                  Expanded(child: right),
                ],
              );
            }
            return Column(
              children: [left, const SizedBox(height: 16), right],
            );
          },
        ),
        const SizedBox(height: 16),
        FxStitchCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DELIVERY TARGET SELECTION',
                style: AppTypography.labelCaps(
                  context.fx.onSurfaceVariant,
                  context: context,
                ).copyWith(fontSize: 9),
              ),
              const SizedBox(height: 12),
              ...FxDeliveryTarget.values.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DeliveryCard(
                    target: t,
                    selected: deliveryTarget == t,
                    onTap: () => onDeliveryChanged(t),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Notes / reference no.',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        if (proofSection != null) ...[
          const SizedBox(height: 12),
          proofSection!,
        ],
      ],
    );
  }
}

class _WorkflowDots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _dot(context, 'Deal Setup', active: false, done: true),
        _line(context),
        _dot(context, 'Agent Leg', active: true),
        _line(context),
        _dot(context, 'Review', active: false),
      ],
    );
  }

  Widget _dot(
    BuildContext context,
    String label, {
    bool active = false,
    bool done = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done || active
                ? context.fx.secondary
                : context.fx.outlineVariant,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: context.fx.secondary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: AppTypography.labelCaps(
            active ? context.fx.secondary : context.fx.onSurfaceVariant,
            context: context,
          ).copyWith(fontSize: 9),
        ),
      ],
    );
  }

  Widget _line(BuildContext context) {
    return Container(
      width: 32,
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.fx.outlineVariant,
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.controller,
    required this.currency,
    required this.currencies,
    required this.onCurrencyChanged,
  });

  final String label;
  final TextEditingController controller;
  final String currency;
  final List<String> currencies;
  final ValueChanged<String?> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelCaps(
            context.fx.onSurfaceVariant,
            context: context,
          ).copyWith(fontSize: 9),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTypography.headlineSm(
                  context.fx.onSurface,
                  context: context,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: context.fx.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 72,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.fx.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: context.fx.outlineVariant),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currency,
                  isDense: true,
                  items: currencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: onCurrencyChanged,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RateBox extends StatelessWidget {
  const _RateBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelCaps(
              Colors.white60,
              context: context,
            ).copyWith(fontSize: 9),
          ),
          Text(
            value,
            style: AppTypography.headlineSm(Colors.white, context: context),
          ),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.target,
    required this.selected,
    required this.onTap,
  });

  final FxDeliveryTarget target;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, subtitle) = switch (target) {
      FxDeliveryTarget.ourAccount => (
          Icons.account_balance,
          'Credit Main Treasury',
        ),
      FxDeliveryTarget.directToCustomer => (
          Icons.person,
          'Bypass Internal Pool',
        ),
      FxDeliveryTarget.tt => (Icons.bolt, 'Urgent Settlement'),
    };

    return Material(
      color: selected
          ? context.fx.secondaryContainer.withValues(alpha: 0.1)
          : context.fx.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: selected ? context.fx.secondary : context.fx.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? context.fx.secondary : context.fx.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.label,
                      style: AppTypography.bodyMd(
                        context.fx.onSurface,
                        context: context,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.bodySm(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
