import 'package:intl/intl.dart';

/// User-facing copy for agent custody and party FX control lines (no posting logic).
abstract final class AgentCustodyLabels {
  static const emptyCustodyInventory =
      'No custody inventory rows — Unavailable from agent balance book';

  static const pkrLedgerVsCustodyNote =
      'PKR ledger balance and FX custody are separate books — do not double-count.';

  static const custodyNotPhysicalCash =
      'Custody amounts are book inventory, not physical cash on hand.';

  static String custodySectionTitle() => 'FX held with agent';

  static String custodyMetricLabel(String metric) => metric;

  static String payablePkrCreditLabel() => 'PKR payable credit (custody book)';

  static String partyForeignNetLabel({
    required String currencyCode,
    required double foreignNet,
    NumberFormat? formatter,
  }) {
    final fmt = formatter ?? NumberFormat('#,##0.00');
    return '$currencyCode control net ${fmt.format(foreignNet)}';
  }
}
