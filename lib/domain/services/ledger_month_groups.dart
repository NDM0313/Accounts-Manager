import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:intl/intl.dart';

/// Calendar month bucket for party ledger presentation.
class LedgerMonthGroup {
  const LedgerMonthGroup({
    required this.yearMonth,
    required this.label,
    required this.lines,
    required this.totalDebit,
    required this.totalCredit,
    required this.monthNet,
    required this.closingBalanceAfterLastLine,
    required this.isPartialMonth,
    this.closingAsOfDate,
  });

  /// Stable key `yyyy-MM` from transaction calendar month.
  final String yearMonth;

  /// Human-readable month title (e.g. "June 2026").
  final String label;

  /// Statement lines in this month, chronological (oldest first).
  final List<PartyStatementLine> lines;

  final double totalDebit;
  final double totalCredit;

  /// Net movement in the month (debit minus credit) from [lines] only.
  final double monthNet;

  /// Running balance after the chronologically last line in this month.
  final double closingBalanceAfterLastLine;

  /// True when [rangeTo] ends before the last calendar day of this month.
  final bool isPartialMonth;

  /// When [isPartialMonth], the statement range end date; otherwise null.
  final DateTime? closingAsOfDate;

  /// Groups [chronologicalLines] (oldest first) by calendar month of
  /// [PartyStatementLine.transactionDate].
  ///
  /// Month boundaries use the [DateTime] **local** date parts (`year`, `month`,
  /// `day`) on each line. Party statements are interpreted in Pakistan
  /// (Asia/Karachi); callers should supply transaction dates already aligned to
  /// that zone's calendar day (same convention as [PartyStatementBuilder]).
  static List<LedgerMonthGroup> groupChronological(
    List<PartyStatementLine> chronologicalLines, {
    required DateTime rangeTo,
  }) {
    if (chronologicalLines.isEmpty) return const [];

    final rangeDay = DateTime(rangeTo.year, rangeTo.month, rangeTo.day);
    final monthFormat = DateFormat('MMMM yyyy');
    final buckets = <String, List<PartyStatementLine>>{};
    final order = <String>[];

    for (final line in chronologicalLines) {
      final key = _yearMonthKey(line.transactionDate);
      if (!buckets.containsKey(key)) {
        buckets[key] = [];
        order.add(key);
      }
      buckets[key]!.add(line);
    }

    return order.map((key) {
      final monthLines = buckets[key]!;
      final sample = monthLines.first.transactionDate;
      final year = sample.year;
      final month = sample.month;
      final totalDebit = monthLines.fold<double>(0, (s, l) => s + l.debitPkr);
      final totalCredit =
          monthLines.fold<double>(0, (s, l) => s + l.creditPkr);
      final monthNet = totalDebit - totalCredit;
      final closing = monthLines.last.runningBalancePkr;
      final monthEnd = DateTime(year, month + 1, 0);
      final isPartial = rangeDay.year == year &&
          rangeDay.month == month &&
          rangeDay.isBefore(monthEnd);

      return LedgerMonthGroup(
        yearMonth: key,
        label: monthFormat.format(DateTime(year, month)),
        lines: monthLines,
        totalDebit: totalDebit,
        totalCredit: totalCredit,
        monthNet: monthNet,
        closingBalanceAfterLastLine: closing,
        isPartialMonth: isPartial,
        closingAsOfDate: isPartial ? rangeDay : null,
      );
    }).toList();
  }

  static String _yearMonthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';
}
