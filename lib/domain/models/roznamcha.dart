class RoznamchaLine {
  const RoznamchaLine({
    required this.entryDate,
    required this.entryTime,
    required this.entryNo,
    this.transactionId,
    required this.transactionType,
    required this.accountCode,
    required this.accountName,
    this.partyId,
    this.partyName,
    this.description,
    required this.moneyInPkr,
    required this.moneyOutPkr,
    required this.currencyCode,
    required this.foreignAmount,
    required this.attachmentCount,
    this.runningBalancePkr = 0,
  });

  final DateTime entryDate;
  final DateTime entryTime;
  final String entryNo;
  final String? transactionId;
  final String transactionType;
  final String accountCode;
  final String accountName;
  final String? partyId;
  final String? partyName;
  final String? description;
  final double moneyInPkr;
  final double moneyOutPkr;
  final String currencyCode;
  final double foreignAmount;
  final int attachmentCount;
  final double runningBalancePkr;

  bool get isInternalTransfer =>
      transactionType == 'account_transfer' ||
      transactionType.toLowerCase().contains('transfer');

  factory RoznamchaLine.fromJson(Map<String, dynamic> json) {
    return RoznamchaLine(
      entryDate: DateTime.parse(json['entry_date'] as String),
      entryTime: DateTime.parse(
        (json['entry_time'] ?? json['entry_date']).toString(),
      ),
      entryNo: json['entry_no'] as String? ?? '',
      transactionId: json['transaction_id'] as String?,
      transactionType: json['transaction_type'] as String? ?? 'journal',
      accountCode: json['account_code'] as String,
      accountName: json['account_name'] as String,
      partyId: json['party_id'] as String?,
      partyName: json['party_name'] as String?,
      description: json['description'] as String?,
      moneyInPkr: (json['money_in_pkr'] as num?)?.toDouble() ?? 0,
      moneyOutPkr: (json['money_out_pkr'] as num?)?.toDouble() ?? 0,
      currencyCode: json['currency_code'] as String? ?? 'PKR',
      foreignAmount: (json['foreign_amount'] as num?)?.toDouble() ?? 0,
      attachmentCount: (json['attachment_count'] as num?)?.toInt() ?? 0,
    );
  }

  RoznamchaLine copyWithRunning(double balance) => RoznamchaLine(
        entryDate: entryDate,
        entryTime: entryTime,
        entryNo: entryNo,
        transactionId: transactionId,
        transactionType: transactionType,
        accountCode: accountCode,
        accountName: accountName,
        partyId: partyId,
        partyName: partyName,
        description: description,
        moneyInPkr: moneyInPkr,
        moneyOutPkr: moneyOutPkr,
        currencyCode: currencyCode,
        foreignAmount: foreignAmount,
        attachmentCount: attachmentCount,
        runningBalancePkr: balance,
      );
}

class RoznamchaOpening {
  const RoznamchaOpening({
    required this.accountCode,
    required this.accountName,
    required this.openingPkr,
  });

  final String accountCode;
  final String accountName;
  final double openingPkr;

  factory RoznamchaOpening.fromJson(Map<String, dynamic> json) {
    return RoznamchaOpening(
      accountCode: json['account_code'] as String,
      accountName: json['account_name'] as String,
      openingPkr: (json['opening_pkr'] as num?)?.toDouble() ?? 0,
    );
  }
}

class RoznamchaView {
  const RoznamchaView({
    required this.from,
    required this.to,
    required this.openings,
    required this.lines,
    required this.totalIn,
    required this.totalOut,
    required this.closing,
    required this.externalIn,
    required this.externalOut,
  });

  final DateTime from;
  final DateTime to;
  final List<RoznamchaOpening> openings;
  final List<RoznamchaLine> lines;
  final double totalIn;
  final double totalOut;
  final double closing;
  final double externalIn;
  final double externalOut;

  double get openingTotal =>
      openings.fold<double>(0, (s, o) => s + o.openingPkr);
}

/// Builds chronological running balances and consolidated external totals.
abstract final class RoznamchaBuilder {
  static RoznamchaView build({
    required DateTime from,
    required DateTime to,
    required List<RoznamchaOpening> openings,
    required List<RoznamchaLine> rawLines,
  }) {
    final openingByAccount = {
      for (final o in openings) o.accountCode: o.openingPkr,
    };
    final runningByAccount = Map<String, double>.from(openingByAccount);
    final sorted = [...rawLines]
      ..sort((a, b) {
        final d = a.entryDate.compareTo(b.entryDate);
        if (d != 0) return d;
        final t = a.entryTime.compareTo(b.entryTime);
        if (t != 0) return t;
        return a.entryNo.compareTo(b.entryNo);
      });

    var totalIn = 0.0;
    var totalOut = 0.0;
    var externalIn = 0.0;
    var externalOut = 0.0;
    final lines = <RoznamchaLine>[];

    for (final line in sorted) {
      totalIn += line.moneyInPkr;
      totalOut += line.moneyOutPkr;
      if (!line.isInternalTransfer) {
        externalIn += line.moneyInPkr;
        externalOut += line.moneyOutPkr;
      }
      final prev = runningByAccount[line.accountCode] ?? 0;
      final next = prev + line.moneyInPkr - line.moneyOutPkr;
      runningByAccount[line.accountCode] = next;
      lines.add(line.copyWithRunning(next));
    }

    final closing = runningByAccount.values.fold<double>(0, (s, v) => s + v);

    return RoznamchaView(
      from: from,
      to: to,
      openings: openings,
      lines: lines,
      totalIn: totalIn,
      totalOut: totalOut,
      closing: closing,
      externalIn: externalIn,
      externalOut: externalOut,
    );
  }
}
