import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/services/deal_workflow_guide.dart';

class DealNarrativeSection {
  const DealNarrativeSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

class DealWorkflowHelp {
  const DealWorkflowHelp({
    required this.statusMeaning,
    required this.whatToDoNext,
    required this.afterNextAction,
    required this.statementsAffected,
  });

  final String statusMeaning;
  final String whatToDoNext;
  final String afterNextAction;
  final List<String> statementsAffected;
}

abstract final class DealWorkflowNarrative {
  static List<DealNarrativeSection> buildSummary({
    required FxDeal deal,
    required List<FxDealLeg> legs,
  }) {
    final view = DealWorkflowGuide.build(deal: deal, legs: legs);
    final sections = <DealNarrativeSection>[];

    sections.add(
      DealNarrativeSection(
        title: 'Customer order',
        lines: [
          'Customer ${deal.customerName ?? '—'} wants ${deal.sellAmount} ${deal.sellCurrencyCode}.',
          'Customer payable PKR ${deal.customerPayablePkr.toStringAsFixed(0)}.',
          'Customer paid PKR ${deal.customerPaidPkr.toStringAsFixed(0)}.',
          'Receivable PKR ${deal.customerReceivablePkr.toStringAsFixed(0)}.',
        ],
      ),
    );

    final sourcing = _find(legs, FxDealLegType.sourcingRequirement);
    if (sourcing != null ||
        deal.status == FxDealStatus.sourcingRequired ||
        deal.status == FxDealStatus.sourcingInProgress) {
      sections.add(
        DealNarrativeSection(
          title: 'Sourcing required',
          lines: [
            'We need to arrange ${deal.sellAmount} ${deal.sellCurrencyCode}.',
            'Current status: ${deal.status.label}.',
            if (sourcing != null)
              'Sourcing leg: ${sourcing.receiveAmount} ${sourcing.receiveCurrency ?? deal.sellCurrencyCode} (${sourcing.status.label}).',
          ],
        ),
      );
    }

    final agentSrc = _find(legs, FxDealLegType.agentSource);
    if (agentSrc != null) {
      final lines = <String>[
        'Agent ${agentSrc.counterpartyName ?? '—'} will provide currency.',
        if (agentSrc.receiveAmount > 0)
          'Receive ${agentSrc.receiveAmount} ${agentSrc.receiveCurrency ?? deal.sellCurrencyCode}.',
        if (agentSrc.payAmount > 0)
          'Pay ${agentSrc.payAmount} ${agentSrc.payCurrency ?? 'PKR'}.',
        'Leg status: ${agentSrc.status.label}.',
      ];
      sections.add(DealNarrativeSection(title: 'Agent source', lines: lines));
    }

    final agentPay = _find(legs, FxDealLegType.agentPayment);
    if (agentPay != null) {
      sections.add(
        DealNarrativeSection(
          title: 'Agent payment',
          lines: [
            'Payment to agent ${agentPay.counterpartyName ?? '—'}: ${agentPay.status.label}.',
            if (agentPay.payAmount > 0)
              'Amount: ${agentPay.payAmount} ${agentPay.payCurrency ?? 'PKR'}.',
          ],
        ),
      );
    }

    sections.add(
      DealNarrativeSection(
        title: 'Next action',
        lines: [view.nextActionTitle, _afterActionHint(view.nextActionTitle)],
      ),
    );

    return sections;
  }

  static DealWorkflowHelp buildHelp({
    required FxDeal deal,
    required List<FxDealLeg> legs,
  }) {
    final view = DealWorkflowGuide.build(deal: deal, legs: legs);
    return DealWorkflowHelp(
      statusMeaning: _statusMeaning(deal.status),
      whatToDoNext: view.nextActionTitle,
      afterNextAction: _afterActionHint(view.nextActionTitle),
      statementsAffected: _statementsAffected(deal, legs, view.nextActionTitle),
    );
  }

  static FxDealLeg? _find(List<FxDealLeg> legs, FxDealLegType type) {
    try {
      return legs.lastWhere((l) => l.legType == type);
    } catch (_) {
      return null;
    }
  }

  static String _statusMeaning(FxDealStatus status) => switch (status) {
    FxDealStatus.booked =>
      'Customer order is booked. Payment and sourcing may still be open.',
    FxDealStatus.customerPartiallyPaid =>
      'Customer has paid part of the PKR receivable.',
    FxDealStatus.customerPaid => 'Customer has fully paid in PKR.',
    FxDealStatus.sourcingRequired =>
      'Foreign currency must be sourced before delivery.',
    FxDealStatus.sourcingInProgress =>
      'Agent sourcing is underway; currency not yet confirmed in hand.',
    FxDealStatus.agentPartiallyPaid =>
      'Agent has been partially paid for sourced currency.',
    FxDealStatus.agentPaid =>
      'Agent has been paid; confirm receipt of foreign currency.',
    FxDealStatus.currencyReceived =>
      'Foreign currency is in hand; proceed to customer delivery.',
    FxDealStatus.delivered =>
      'Currency delivered to customer; finalize profit/loss.',
    FxDealStatus.completed => 'Deal is complete; profit/loss is recorded.',
    _ => status.label,
  };

  static String _afterActionHint(String nextAction) {
    final lower = nextAction.toLowerCase();
    if (lower.contains('customer payment')) {
      return 'Customer receivable on the party statement will decrease.';
    }
    if (lower.contains('source currency') || lower.contains('agent source')) {
      return 'Deal moves to sourcing in progress; agent payable may be created.';
    }
    if (lower.contains('pay agent')) {
      return 'Agent payable is settled; attach payment proof if required.';
    }
    if (lower.contains('confirm currency received')) {
      return 'Foreign cash position increases; deal status moves toward currency received.';
    }
    if (lower.contains('delivery') || lower.contains('tt')) {
      return 'Customer receives currency; cost basis and deal profit can be finalized.';
    }
    if (lower.contains('profit')) {
      return 'Review actual profit/loss on this deal.';
    }
    return 'Deal status and related statements will update after this step.';
  }

  static List<String> _statementsAffected(
    FxDeal deal,
    List<FxDealLeg> legs,
    String nextAction,
  ) {
    final items = <String>[
      'Customer statement (${deal.customerName ?? 'customer'})',
    ];
    final agent =
        _find(legs, FxDealLegType.agentSource) ??
        _find(legs, FxDealLegType.agentPayment);
    if (agent?.counterpartyName != null) {
      items.add('Agent statement (${agent!.counterpartyName})');
    }
    items.add('${deal.sellCurrencyCode} currency position');
    items.add('Deal profit/loss');
    if (nextAction.toLowerCase().contains('journal') == false) {
      items.add('General ledger (when legs post transactions)');
    }
    return items;
  }
}

/// Per-leg timeline action label and optional route.
class DealLegTimelineAction {
  const DealLegTimelineAction({
    required this.label,
    this.route,
    this.onTapKind,
  });

  final String label;
  final String? route;
  final DealLegActionKind? onTapKind;
}

enum DealLegActionKind { viewCustomerStatement, viewProof }

abstract final class DealLegTimelineActions {
  static DealLegTimelineAction? forLeg({
    required FxDealLeg leg,
    required FxDeal deal,
    String? customerPartyId,
  }) {
    if (leg.status == FxDealLegStatus.completed) {
      return switch (leg.legType) {
        FxDealLegType.customerOrder when customerPartyId != null =>
          DealLegTimelineAction(
            label: 'View customer statement',
            onTapKind: DealLegActionKind.viewCustomerStatement,
          ),
        _ when leg.attachmentCount > 0 => DealLegTimelineAction(
          label: 'View proof',
          onTapKind: DealLegActionKind.viewProof,
        ),
        _ => null,
      };
    }

    return switch (leg.legType) {
      FxDealLegType.sourcingRequirement => DealLegTimelineAction(
        label: 'Source currency',
        route: '/deals/${deal.id}/legs/agent-source',
      ),
      FxDealLegType.agentSource => DealLegTimelineAction(
        label: 'Confirm received',
        route: '/deals/${deal.id}/legs/currency-receipt',
      ),
      FxDealLegType.agentPayment => DealLegTimelineAction(
        label: 'Pay agent',
        route: '/deals/${deal.id}/legs/agent-payment',
      ),
      FxDealLegType.currencyReceipt => DealLegTimelineAction(
        label: 'Confirm received',
        route: '/deals/${deal.id}/legs/currency-receipt',
      ),
      FxDealLegType.delivery => DealLegTimelineAction(
        label: 'Confirm delivery',
        route: '/deals/${deal.id}/delivery',
      ),
      _ => null,
    };
  }
}
