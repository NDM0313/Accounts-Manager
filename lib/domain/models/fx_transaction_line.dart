class FxTransactionLineInput {
  const FxTransactionLineInput({
    required this.lineNo,
    required this.accountId,
    required this.currencyCode,
    required this.foreignAmount,
    required this.rateUsed,
    required this.debitPkr,
    required this.creditPkr,
    this.memo,
  });

  final int lineNo;
  final String accountId;
  final String currencyCode;
  final double foreignAmount;
  final double rateUsed;
  final double debitPkr;
  final double creditPkr;
  final String? memo;

  Map<String, dynamic> toJson(String transactionId) => {
    'transaction_id': transactionId,
    'line_no': lineNo,
    'account_id': accountId,
    'currency_code': currencyCode,
    'foreign_amount': foreignAmount,
    'rate_used': rateUsed,
    'base_amount_pkr': debitPkr > 0 ? debitPkr : creditPkr,
    'debit_pkr': debitPkr,
    'credit_pkr': creditPkr,
    if (memo != null) 'memo': memo,
  };
}

class FxTransactionLine {
  const FxTransactionLine({
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

  factory FxTransactionLine.fromJson(Map<String, dynamic> json) {
    final account = json['fx_accounts'] as Map<String, dynamic>?;
    return FxTransactionLine(
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
