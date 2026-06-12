import 'package:accounts_manager/core/widgets/premium/fx_confirm_transaction_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FxPostConfirmationData {
  const FxPostConfirmationData({
    required this.title,
    this.partyLabel,
    this.dealNo,
    this.accountLabel,
    required this.currencyCode,
    required this.amount,
    this.rate,
    this.pkrEquivalent,
    this.notes,
  });

  final String title;
  final String? partyLabel;
  final String? dealNo;
  final String? accountLabel;
  final String currencyCode;
  final double amount;
  final double? rate;
  final double? pkrEquivalent;
  final String? notes;
}

Future<bool> showFxPostConfirmationDialog(
  BuildContext context,
  FxPostConfirmationData data,
) async {
  final fmt = NumberFormat('#,##0.00');
  final lines = <(String, String)>[
  if (data.partyLabel != null) ('Party', data.partyLabel!),
  if (data.dealNo != null) ('Deal', data.dealNo!),
  if (data.accountLabel != null) ('Account', data.accountLabel!),
  ('Base Amount', '${fmt.format(data.amount)} ${data.currencyCode}'),
  if (data.notes != null && data.notes!.trim().isNotEmpty)
    ('Notes', data.notes!),
  ];
  final total = data.pkrEquivalent != null
      ? 'PKR ${fmt.format(data.pkrEquivalent!)}'
      : '${fmt.format(data.amount)} ${data.currencyCode}';
  final result = await FxConfirmTransactionDialog.show(
    context,
    title: data.title,
    subtitle: 'Review details before final ledger posting.',
    operationLabel: 'Operation',
    operationValue: data.title,
    rateLabel: 'Rate',
    rateValue: data.rate != null && data.rate! > 0
        ? data.rate!.toStringAsFixed(4)
        : '—',
    lines: lines,
    totalLabel: 'Total Amount',
    totalValue: total,
    disclaimer:
        'Funds will be locked immediately upon confirmation. This action cannot be undone once posted to the ledger.',
  );
  return result ?? false;
}
