enum FxOpeningBalanceStatus {
  missing('missing'),
  draft('draft'),
  posted('posted'),
  voided('voided');

  const FxOpeningBalanceStatus(this.dbValue);
  final String dbValue;

  static FxOpeningBalanceStatus fromDb(String? value) {
    if (value == null) return missing;
    return FxOpeningBalanceStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => missing,
    );
  }
}

enum FxOpeningBalanceLineKind {
  cashBank('cash_bank'),
  currencyPosition('currency_position'),
  partyReceivable('party_receivable'),
  partyPayable('party_payable');

  const FxOpeningBalanceLineKind(this.dbValue);
  final String dbValue;

  static FxOpeningBalanceLineKind fromDb(String value) {
    return FxOpeningBalanceLineKind.values.firstWhere(
      (k) => k.dbValue == value,
      orElse: () => cashBank,
    );
  }

  String get label => switch (this) {
        cashBank => 'Cash / Bank',
        currencyPosition => 'Currency Position',
        partyReceivable => 'Receivable',
        partyPayable => 'Payable',
      };
}

class FxOpeningBalanceBatch {
  const FxOpeningBalanceBatch({
    required this.id,
    required this.batchNo,
    required this.companyId,
    required this.branchId,
    required this.openingDate,
    required this.baseCurrencyCode,
    required this.totalDebitPkr,
    required this.totalCreditPkr,
    this.description,
    this.notes,
    this.equityAccountId,
    this.postedAt,
    this.createdAt,
  });

  final String id;
  final String? batchNo;
  final String companyId;
  final String branchId;
  final DateTime openingDate;
  final String baseCurrencyCode;
  final double totalDebitPkr;
  final double totalCreditPkr;
  final String? description;
  final String? notes;
  final String? equityAccountId;
  final DateTime? postedAt;
  final DateTime? createdAt;

  double get differencePkr => (totalDebitPkr - totalCreditPkr).abs();
  bool get isBalanced => differencePkr < 0.01 && totalDebitPkr > 0;

  factory FxOpeningBalanceBatch.fromJson(Map<String, dynamic> json) {
    return FxOpeningBalanceBatch(
      id: json['id'] as String,
      batchNo: json['batch_no'] as String?,
      companyId: json['company_id'] as String,
      branchId: json['branch_id'] as String,
      openingDate: DateTime.parse(json['opening_date'] as String),
      baseCurrencyCode: json['base_currency_code'] as String? ?? 'PKR',
      totalDebitPkr: _num(json['total_debit_pkr']),
      totalCreditPkr: _num(json['total_credit_pkr']),
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      equityAccountId: json['equity_account_id'] as String?,
      postedAt: json['posted_at'] != null ? DateTime.parse(json['posted_at'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  static double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class FxOpeningBalanceLine {
  const FxOpeningBalanceLine({
    this.id,
    required this.lineNo,
    required this.lineKind,
    this.accountId,
    this.partyId,
    required this.currencyCode,
    required this.foreignAmount,
    required this.rateUsed,
    required this.pkrAmount,
    this.locationLabel,
    this.memo,
  });

  final String? id;
  final int lineNo;
  final FxOpeningBalanceLineKind lineKind;
  final String? accountId;
  final String? partyId;
  final String currencyCode;
  final double foreignAmount;
  final double rateUsed;
  final double pkrAmount;
  final String? locationLabel;
  final String? memo;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'line_no': lineNo,
        'line_kind': lineKind.dbValue,
        if (accountId != null) 'account_id': accountId,
        if (partyId != null) 'party_id': partyId,
        'currency_code': currencyCode,
        'foreign_amount': foreignAmount,
        'rate_used': rateUsed,
        'pkr_amount': pkrAmount,
        if (locationLabel != null && locationLabel!.isNotEmpty) 'location_label': locationLabel,
        if (memo != null && memo!.isNotEmpty) 'memo': memo,
      };

  factory FxOpeningBalanceLine.fromJson(Map<String, dynamic> json) {
    return FxOpeningBalanceLine(
      id: json['id'] as String?,
      lineNo: json['line_no'] as int,
      lineKind: FxOpeningBalanceLineKind.fromDb(json['line_kind'] as String),
      accountId: json['account_id'] as String?,
      partyId: json['party_id'] as String?,
      currencyCode: json['currency_code'] as String? ?? 'PKR',
      foreignAmount: FxOpeningBalanceBatch._num(json['foreign_amount']),
      rateUsed: FxOpeningBalanceBatch._num(json['rate_used']),
      pkrAmount: FxOpeningBalanceBatch._num(json['pkr_amount']),
      locationLabel: json['location_label'] as String?,
      memo: json['memo'] as String?,
    );
  }

  FxOpeningBalanceLine copyWith({
    int? lineNo,
    FxOpeningBalanceLineKind? lineKind,
    String? accountId,
    String? partyId,
    String? currencyCode,
    double? foreignAmount,
    double? rateUsed,
    double? pkrAmount,
    String? locationLabel,
    String? memo,
  }) {
    return FxOpeningBalanceLine(
      id: id,
      lineNo: lineNo ?? this.lineNo,
      lineKind: lineKind ?? this.lineKind,
      accountId: accountId ?? this.accountId,
      partyId: partyId ?? this.partyId,
      currencyCode: currencyCode ?? this.currencyCode,
      foreignAmount: foreignAmount ?? this.foreignAmount,
      rateUsed: rateUsed ?? this.rateUsed,
      pkrAmount: pkrAmount ?? this.pkrAmount,
      locationLabel: locationLabel ?? this.locationLabel,
      memo: memo ?? this.memo,
    );
  }
}

class FxOpeningBalanceView {
  const FxOpeningBalanceView({
    required this.status,
    this.batch,
    this.lines = const [],
  });

  final FxOpeningBalanceStatus status;
  final FxOpeningBalanceBatch? batch;
  final List<FxOpeningBalanceLine> lines;

  factory FxOpeningBalanceView.fromRpc(Map<String, dynamic> json) {
    final batchJson = json['batch'];
    final linesJson = json['lines'];
    return FxOpeningBalanceView(
      status: FxOpeningBalanceStatus.fromDb(json['status'] as String?),
      batch: batchJson is Map<String, dynamic> ? FxOpeningBalanceBatch.fromJson(batchJson) : null,
      lines: linesJson is List
          ? linesJson
              .cast<Map<String, dynamic>>()
              .map(FxOpeningBalanceLine.fromJson)
              .toList()
          : const [],
    );
  }
}
