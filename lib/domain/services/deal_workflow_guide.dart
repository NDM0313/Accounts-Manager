import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';

enum DealWorkflowStepStatus { pending, partial, completed, skipped }

class DealWorkflowStep {
  const DealWorkflowStep({
    required this.key,
    required this.label,
    required this.status,
    this.amountLabel,
    this.partyName,
    this.attachmentCount = 0,
    this.route,
  });

  final String key;
  final String label;
  final DealWorkflowStepStatus status;
  final String? amountLabel;
  final String? partyName;
  final int attachmentCount;
  final String? route;
}

class DealWorkflowView {
  const DealWorkflowView({
    required this.statusLabel,
    required this.nextActionTitle,
    this.nextActionRoute,
    this.warningText,
    required this.steps,
    required this.isCompleted,
  });

  final String statusLabel;
  final String nextActionTitle;
  final String? nextActionRoute;
  final String? warningText;
  final List<DealWorkflowStep> steps;
  final bool isCompleted;
}

abstract final class DealWorkflowGuide {
  static DealWorkflowView build({
    required FxDeal deal,
    required List<FxDealLeg> legs,
  }) {
    final steps = <DealWorkflowStep>[];
    FxDealLeg? find(FxDealLegType t) {
      try {
        return legs.lastWhere((l) => l.legType == t);
      } catch (_) {
        return null;
      }
    }

    bool has(FxDealLegType t) => legs.any((l) => l.legType == t);
    bool pending(FxDealLegType t) =>
        legs.any((l) => l.legType == t && l.status == FxDealLegStatus.pending);

    final order = find(FxDealLegType.customerOrder);
    steps.add(DealWorkflowStep(
      key: 'order',
      label: 'Customer Order',
      status: order != null ? DealWorkflowStepStatus.completed : DealWorkflowStepStatus.pending,
      amountLabel: order != null ? '${deal.sellAmount} ${deal.sellCurrencyCode}' : null,
    ));

    final payStatus = deal.customerReceivablePkr <= 0
        ? DealWorkflowStepStatus.completed
        : deal.customerPaidPkr > 0
            ? DealWorkflowStepStatus.partial
            : DealWorkflowStepStatus.pending;
    steps.add(DealWorkflowStep(
      key: 'customer_payment',
      label: 'Customer Payment',
      status: payStatus,
      amountLabel: 'Receivable PKR ${deal.customerReceivablePkr.toStringAsFixed(0)}',
    ));

    final sourcing = find(FxDealLegType.sourcingRequirement);
    if (sourcing != null || deal.status == FxDealStatus.sourcingRequired) {
      steps.add(DealWorkflowStep(
        key: 'sourcing',
        label: 'Sourcing Requirement',
        status: sourcing?.status == FxDealLegStatus.completed
            ? DealWorkflowStepStatus.completed
            : DealWorkflowStepStatus.pending,
        amountLabel: sourcing != null ? '${sourcing.receiveAmount} ${sourcing.receiveCurrency ?? deal.sellCurrencyCode}' : null,
        route: '/deals/${deal.id}/sourcing',
      ));
    }

    final agentSrc = find(FxDealLegType.agentSource);
    steps.add(DealWorkflowStep(
      key: 'agent_source',
      label: 'Agent Source',
      status: agentSrc == null
          ? DealWorkflowStepStatus.skipped
          : agentSrc.status == FxDealLegStatus.completed
              ? DealWorkflowStepStatus.completed
              : DealWorkflowStepStatus.partial,
      amountLabel: agentSrc != null
          ? 'Recv ${agentSrc.receiveAmount} ${agentSrc.receiveCurrency ?? ''}'
          : null,
      partyName: agentSrc?.counterpartyName,
      attachmentCount: agentSrc?.attachmentCount ?? 0,
      route: '/deals/${deal.id}/legs/agent-source',
    ));

    final cross = find(FxDealLegType.crossCurrencySource);
    steps.add(DealWorkflowStep(
      key: 'cross_source',
      label: 'Cross-Currency Source',
      status: cross == null ? DealWorkflowStepStatus.skipped : DealWorkflowStepStatus.completed,
      partyName: cross?.counterpartyName,
      attachmentCount: cross?.attachmentCount ?? 0,
      route: '/deals/${deal.id}/legs/cross-source',
    ));

    final agentPay = find(FxDealLegType.agentPayment);
    steps.add(DealWorkflowStep(
      key: 'agent_payment',
      label: 'Agent Payment',
      status: agentPay == null
          ? DealWorkflowStepStatus.skipped
          : agentPay.status == FxDealLegStatus.completed
              ? DealWorkflowStepStatus.completed
              : DealWorkflowStepStatus.pending,
      attachmentCount: agentPay?.attachmentCount ?? 0,
      route: '/deals/${deal.id}/legs/agent-payment',
    ));

    final receipt = find(FxDealLegType.currencyReceipt);
    steps.add(DealWorkflowStep(
      key: 'currency_receipt',
      label: 'Currency Receipt',
      status: receipt == null ? DealWorkflowStepStatus.skipped : DealWorkflowStepStatus.completed,
      attachmentCount: receipt?.attachmentCount ?? 0,
      route: '/deals/${deal.id}/legs/currency-receipt',
    ));

    final delivery = find(FxDealLegType.delivery);
    steps.add(DealWorkflowStep(
      key: 'delivery',
      label: 'Delivery / TT Confirmation',
      status: delivery != null ? DealWorkflowStepStatus.completed : DealWorkflowStepStatus.pending,
      attachmentCount: delivery?.attachmentCount ?? 0,
      route: '/deals/${deal.id}/delivery',
    ));

    steps.add(DealWorkflowStep(
      key: 'pl',
      label: 'Profit/Loss Finalization',
      status: deal.actualProfitPkr != null
          ? DealWorkflowStepStatus.completed
          : deal.status == FxDealStatus.completed
              ? DealWorkflowStepStatus.partial
              : DealWorkflowStepStatus.pending,
    ));

    steps.add(DealWorkflowStep(
      key: 'done',
      label: 'Completed',
      status: deal.status == FxDealStatus.completed
          ? DealWorkflowStepStatus.completed
          : DealWorkflowStepStatus.pending,
    ));

    String nextTitle;
    String? nextRoute;
    String? warning;

    if (deal.status == FxDealStatus.completed) {
      nextTitle = 'Review profit/loss';
      nextRoute = null;
    } else if (deal.customerReceivablePkr > 0 &&
        (deal.status == FxDealStatus.booked ||
            deal.status == FxDealStatus.customerPartiallyPaid)) {
      nextTitle = 'Receive customer payment';
      nextRoute = null;
    } else if (deal.status == FxDealStatus.sourcingRequired ||
        (pending(FxDealLegType.sourcingRequirement) && !has(FxDealLegType.agentSource))) {
      nextTitle = 'Source currency from agent';
      nextRoute = '/deals/${deal.id}/legs/agent-source';
      warning = '${deal.sellCurrencyCode} may not be available in own balance — add agent source leg.';
    } else if (has(FxDealLegType.agentSource) &&
        !has(FxDealLegType.agentPayment) &&
        deal.status != FxDealStatus.completed) {
      nextTitle = 'Pay agent / attach payment proof';
      nextRoute = '/deals/${deal.id}/legs/agent-payment';
    } else if (has(FxDealLegType.agentPayment) && !has(FxDealLegType.currencyReceipt)) {
      nextTitle = 'Confirm currency received';
      nextRoute = '/deals/${deal.id}/legs/currency-receipt';
    } else if (!has(FxDealLegType.delivery) && deal.status != FxDealStatus.completed) {
      nextTitle = 'Confirm delivery / TT';
      nextRoute = '/deals/${deal.id}/delivery';
    } else if (deal.customerReceivablePkr > 0) {
      nextTitle = 'Receive customer payment';
      nextRoute = null;
    } else {
      nextTitle = 'Continue deal workflow';
      nextRoute = '/deals/${deal.id}/sourcing';
    }

    return DealWorkflowView(
      statusLabel: deal.status.label,
      nextActionTitle: nextTitle,
      nextActionRoute: nextRoute,
      warningText: warning,
      steps: steps,
      isCompleted: deal.status == FxDealStatus.completed,
    );
  }
}
