import 'package:accounts_manager/app/theme/app_typography.dart';
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
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(data.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data.partyLabel != null) _row('Party', data.partyLabel!),
            if (data.dealNo != null) _row('Deal', data.dealNo!),
            if (data.accountLabel != null) _row('Account', data.accountLabel!),
            _row('Currency', data.currencyCode),
            _row('Amount', fmt.format(data.amount)),
            if (data.rate != null && data.rate! > 0)
              _row('Rate', data.rate!.toStringAsFixed(4)),
            if (data.pkrEquivalent != null)
              _row('PKR equivalent', 'PKR ${fmt.format(data.pkrEquivalent!)}'),
            if (data.notes != null && data.notes!.trim().isNotEmpty)
              _row('Notes', data.notes!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Confirm & Post'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Widget _row(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: AppTypography.bodyMd(Colors.grey)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
