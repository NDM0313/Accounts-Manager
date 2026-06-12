class FxJournalLine {
  const FxJournalLine({
    required this.id,
    required this.lineNo,
    required this.accountId,
    this.accountCode,
    this.accountName,
    required this.currencyCode,
    required this.foreignAmount,
    required this.rateUsed,
    required this.debitPkr,
    required this.creditPkr,
    this.memo,
  });

  final String id;
  final int lineNo;
  final String accountId;
  final String? accountCode;
  final String? accountName;
  final String currencyCode;
  final double foreignAmount;
  final double rateUsed;
  final double debitPkr;
  final double creditPkr;
  final String? memo;

  factory FxJournalLine.fromJson(Map<String, dynamic> json) {
    final account = json['fx_accounts'] as Map<String, dynamic>?;
    return FxJournalLine(
      id: json['id'] as String,
      lineNo: json['line_no'] as int,
      accountId: json['account_id'] as String,
      accountCode: account?['code'] as String?,
      accountName: account?['name'] as String?,
      currencyCode: json['currency_code'] as String,
      foreignAmount: (json['foreign_amount'] as num).toDouble(),
      rateUsed: (json['rate_used'] as num).toDouble(),
      debitPkr: (json['debit_pkr'] as num).toDouble(),
      creditPkr: (json['credit_pkr'] as num).toDouble(),
      memo: json['memo'] as String?,
    );
  }
}

class FxJournalEntry {
  const FxJournalEntry({
    required this.id,
    required this.entryNo,
    required this.entryDate,
    this.description,
    required this.transactionId,
    required this.lines,
    this.isVoid = false,
  });

  final String id;
  final String entryNo;
  final DateTime entryDate;
  final String? description;
  final String? transactionId;
  final List<FxJournalLine> lines;
  final bool isVoid;

  double get totalDebit => lines.fold(0, (s, l) => s + l.debitPkr);
  double get totalCredit => lines.fold(0, (s, l) => s + l.creditPkr);
  bool get isBalanced => totalDebit == totalCredit && totalDebit > 0;

  factory FxJournalEntry.fromJson(Map<String, dynamic> json) {
    final rawLines = json['fx_journal_lines'] as List? ?? [];
    final lines =
        rawLines
            .cast<Map<String, dynamic>>()
            .map(FxJournalLine.fromJson)
            .toList()
          ..sort((a, b) => a.lineNo.compareTo(b.lineNo));

    return FxJournalEntry(
      id: json['id'] as String,
      entryNo: json['entry_no'] as String,
      entryDate: DateTime.parse(json['entry_date'] as String),
      description: json['description'] as String?,
      transactionId: json['transaction_id'] as String?,
      isVoid: json['is_void'] as bool? ?? false,
      lines: lines,
    );
  }
}
