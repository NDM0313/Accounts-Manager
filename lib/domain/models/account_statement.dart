import 'package:accounts_manager/data/repositories/report_repository.dart';

class AccountStatementLine {
  const AccountStatementLine({
    required this.entryDate,
    required this.entryNo,
    required this.description,
    required this.debitPkr,
    required this.creditPkr,
    required this.currencyCode,
    required this.foreignAmount,
    required this.runningBalancePkr,
  });

  final DateTime entryDate;
  final String entryNo;
  final String? description;
  final double debitPkr;
  final double creditPkr;
  final String currencyCode;
  final double foreignAmount;
  final double runningBalancePkr;
}

class AccountStatementView {
  const AccountStatementView({
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.from,
    required this.to,
    required this.openingBalancePkr,
    required this.closingBalancePkr,
    required this.lines,
  });

  final String accountCode;
  final String accountName;
  final String accountType;
  final DateTime from;
  final DateTime to;
  final double openingBalancePkr;
  final double closingBalancePkr;
  final List<AccountStatementLine> lines;

  static bool isDebitNormal(String accountType) {
    final t = accountType.toLowerCase();
    return t == 'asset' || t == 'expense';
  }

  /// Builds statement lines with running balance from GL rows and opening balance.
  static AccountStatementView build({
    required String accountCode,
    required String accountName,
    required String accountType,
    required DateTime from,
    required DateTime to,
    required double openingBalancePkr,
    required List<GeneralLedgerRow> ledgerRows,
  }) {
    final debitNormal = isDebitNormal(accountType);
    var balance = openingBalancePkr;
    final lines = <AccountStatementLine>[];

    for (final row in ledgerRows) {
      balance += debitNormal
          ? row.debitPkr - row.creditPkr
          : row.creditPkr - row.debitPkr;
      lines.add(
        AccountStatementLine(
          entryDate: row.entryDate,
          entryNo: row.entryNo,
          description: row.description,
          debitPkr: row.debitPkr,
          creditPkr: row.creditPkr,
          currencyCode: row.currencyCode,
          foreignAmount: row.foreignAmount,
          runningBalancePkr: balance,
        ),
      );
    }

    return AccountStatementView(
      accountCode: accountCode,
      accountName: accountName,
      accountType: accountType,
      from: from,
      to: to,
      openingBalancePkr: openingBalancePkr,
      closingBalancePkr: lines.isEmpty
          ? openingBalancePkr
          : lines.last.runningBalancePkr,
      lines: lines,
    );
  }
}
