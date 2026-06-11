import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/services/deal_workflow_guide.dart';
import 'package:intl/intl.dart';

String buildDealStatementText({
  required FxDeal deal,
  required List<FxDealLeg> legs,
  bool internal = true,
}) {
  final fmt = NumberFormat('#,##0.00');
  final view = DealWorkflowGuide.build(deal: deal, legs: legs);
  final buf = StringBuffer()
    ..writeln('FX Deal Summary')
    ..writeln('Deal: ${deal.dealNo ?? deal.id}')
    ..writeln('Status: ${deal.status.label}')
    ..writeln('Customer: ${deal.customerName ?? '—'}')
    ..writeln('Sale: ${fmt.format(deal.sellAmount)} ${deal.sellCurrencyCode} @ ${fmt.format(deal.saleRatePkr)} PKR')
    ..writeln('Payable: PKR ${fmt.format(deal.customerPayablePkr)}')
    ..writeln('Paid: PKR ${fmt.format(deal.customerPaidPkr)}')
    ..writeln('Receivable: PKR ${fmt.format(deal.customerReceivablePkr)}')
    ..writeln('Next: ${view.nextActionTitle}')
    ..writeln('')
    ..writeln('Timeline:');
  for (final leg in legs) {
    buf.writeln(
      '  ${leg.legNo}. ${leg.legType.label} — ${leg.status.label}'
      '${leg.counterpartyName != null ? ' (${leg.counterpartyName})' : ''}',
    );
  }
  if (internal && deal.actualProfitPkr != null) {
    buf.writeln('');
    buf.writeln('Actual profit: PKR ${fmt.format(deal.actualProfitPkr)}');
  }
  if (!internal) {
    buf.writeln('');
    buf.writeln('— Customer copy: profit and internal costs omitted —');
  }
  return buf.toString();
}
