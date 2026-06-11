import 'package:accounts_manager/core/widgets/premium/fx_transaction_card.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

export 'package:accounts_manager/core/widgets/premium/fx_transaction_card.dart' show FxTransactionCard;

enum FxLedgerSortOrder { newest, oldest }

enum FxLedgerFilter { active, draft, voided, all }

/// @deprecated Use [FxTransactionCard].
class FxLedgerCard extends StatelessWidget {
  const FxLedgerCard({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  final FxTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FxTransactionCard(transaction: transaction, onTap: onTap);
  }
}

String formatLedgerDateHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  if (d == today) return 'Today';
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('d MMM yyyy').format(date);
}

Map<String, List<FxTransaction>> groupTransactionsByDate(
  List<FxTransaction> items, {
  FxLedgerSortOrder sort = FxLedgerSortOrder.newest,
}) {
  final sorted = [...items]
    ..sort((a, b) {
      final da = a.postedAt ?? a.createdAt ?? a.transactionDate;
      final db = b.postedAt ?? b.createdAt ?? b.transactionDate;
      return sort == FxLedgerSortOrder.newest ? db.compareTo(da) : da.compareTo(db);
    });

  final map = <String, List<FxTransaction>>{};
  for (final tx in sorted) {
    final dt = tx.postedAt ?? tx.createdAt ?? tx.transactionDate;
    final key = DateTime(dt.year, dt.month, dt.day).toIso8601String();
    map.putIfAbsent(key, () => []).add(tx);
  }
  return map;
}
