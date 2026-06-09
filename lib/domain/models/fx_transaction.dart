import 'package:accounts_manager/domain/models/fx_transaction_line.dart';

export 'fx_transaction_line.dart';

enum FxTransactionType {
  openingBalance('opening_balance'),
  accountTransfer('account_transfer'),
  expense('expense'),
  currencyBuy('currency_buy'),
  currencySell('currency_sell'),
  crossCurrency('cross_currency'),
  settlementSend('settlement_send'),
  settlementReceive('settlement_receive'),
  revaluation('revaluation'),
  manualJournal('manual_journal'),
  dailyClosingAdjustment('daily_closing_adjustment');

  const FxTransactionType(this.dbValue);
  final String dbValue;

  static FxTransactionType? fromDb(String value) {
    for (final t in values) {
      if (t.dbValue == value) return t;
    }
    return null;
  }

  String get label => switch (this) {
        openingBalance => 'Opening Balance',
        accountTransfer => 'Account Transfer',
        expense => 'Expense',
        currencyBuy => 'Currency Buy',
        currencySell => 'Currency Sell',
        crossCurrency => 'Cross Currency',
        settlementSend => 'Settlement Send',
        settlementReceive => 'Settlement Receive',
        revaluation => 'Revaluation',
        manualJournal => 'Manual Journal',
        dailyClosingAdjustment => 'Closing Adjustment',
      };

  bool get isSettlement => this == settlementSend || this == settlementReceive;
}

class FxTransaction {
  const FxTransaction({
    required this.id,
    required this.transactionType,
    required this.status,
    this.transactionNo,
    required this.transactionDate,
    required this.currencyCode,
    required this.totalForeignAmount,
    required this.rateUsed,
    required this.totalBaseAmountPkr,
    this.description,
    this.partyId,
    this.createdAt,
    this.postedAt,
    this.lines = const [],
  });

  final String id;
  final FxTransactionType transactionType;
  final String status;
  final String? transactionNo;
  final DateTime transactionDate;
  final String currencyCode;
  final double totalForeignAmount;
  final double rateUsed;
  final double totalBaseAmountPkr;
  final String? description;
  final String? partyId;
  final DateTime? createdAt;
  final DateTime? postedAt;
  final List<FxTransactionLine> lines;

  bool get isDraft => status == 'draft';
  bool get isPosted => status == 'posted';
  bool get isVoided => status == 'voided';

  factory FxTransaction.fromJson(Map<String, dynamic> json, {List<FxTransactionLine>? lines}) {
    final rawLines = json['fx_transaction_lines'] as List?;
    final parsedLines = lines ??
        (rawLines == null
            ? <FxTransactionLine>[]
            : rawLines.cast<Map<String, dynamic>>().map(FxTransactionLine.fromJson).toList()
              ..sort((a, b) => a.lineNo.compareTo(b.lineNo)));

    return FxTransaction(
      id: json['id'] as String,
      transactionType: FxTransactionType.fromDb(json['transaction_type'] as String)!,
      status: json['status'] as String,
      transactionNo: json['transaction_no'] as String?,
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      currencyCode: json['currency_code'] as String,
      totalForeignAmount: (json['total_foreign_amount'] as num).toDouble(),
      rateUsed: (json['rate_used'] as num).toDouble(),
      totalBaseAmountPkr: (json['total_base_amount_pkr'] as num).toDouble(),
      description: json['description'] as String?,
      partyId: json['party_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      postedAt: json['posted_at'] != null ? DateTime.parse(json['posted_at'] as String) : null,
      lines: parsedLines,
    );
  }
}
