import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';

/// Builds party statement lines with debit/credit and running balance from transactions.
abstract final class PartyStatementBuilder {
  static const _partyAccountCodes = {'1180', '1190', '2100', '2200', '2300'};

  static PartyStatementView build({
    required FxParty party,
    required DateTime from,
    required DateTime to,
    required List<FxTransaction> transactions,
    Set<String> transactionIdsWithAttachments = const {},
    bool isInternalView = true,
    double openingBalancePkr = 0,
  }) {
    final sorted = [...transactions]
      ..sort((a, b) {
        final d = a.transactionDate.compareTo(b.transactionDate);
        if (d != 0) return d;
        return (a.transactionNo ?? a.id).compareTo(b.transactionNo ?? b.id);
      });

    final debitNormal = _isDebitNormal(party.partyType);
    var running = openingBalancePkr;
    var totalDebit = 0.0;
    var totalCredit = 0.0;
    final balancesByCurrency = <String, double>{};
    var pendingDrafts = 0;
    DateTime? lastDate;

    final lines = <PartyStatementLine>[];

    for (final tx in sorted) {
      if (tx.isDraft) pendingDrafts++;
      if (tx.transactionDate.isAfter(lastDate ?? DateTime(1970))) {
        lastDate = tx.transactionDate;
      }

      final (debit, credit) = _debitCreditForTransaction(party, tx);
      totalDebit += debit;
      totalCredit += credit;

      if (debitNormal) {
        running += debit - credit;
      } else {
        running += credit - debit;
      }

      final pkrEq = tx.totalBaseAmountPkr;
      balancesByCurrency[tx.currencyCode] =
          (balancesByCurrency[tx.currencyCode] ?? 0) + tx.totalForeignAmount;

      lines.add(
        PartyStatementLine(
          transactionDate: tx.transactionDate,
          transactionNo: tx.transactionNo,
          transactionType: tx.transactionType,
          status: tx.status,
          currencyCode: tx.currencyCode,
          foreignAmount: tx.totalForeignAmount,
          rateUsed: tx.rateUsed,
          debitPkr: debit,
          creditPkr: credit,
          runningBalancePkr: running,
          pkrEquivalent: pkrEq,
          transactionId: tx.id,
          description: tx.description,
          hasAttachment: transactionIdsWithAttachments.contains(tx.id),
        ),
      );
    }

    final netBalance = lines.isEmpty
        ? openingBalancePkr
        : lines.last.runningBalancePkr;

    return PartyStatementView(
      party: party,
      from: from,
      to: to,
      isInternalView: isInternalView,
      openingBalancePkr: openingBalancePkr,
      summary: PartyStatementSummary(
        totalDebitPkr: totalDebit,
        totalCreditPkr: totalCredit,
        netBalancePkr: netBalance,
        pendingDraftCount: pendingDrafts,
        lastTransactionDate: lastDate,
        balancesByCurrency: balancesByCurrency,
      ),
      lines: lines,
    );
  }

  static bool _isDebitNormal(FxPartyType type) => switch (type) {
    FxPartyType.customer => true,
    FxPartyType.agent => false,
    FxPartyType.settlement => false,
  };

  static (double debit, double credit) _debitCreditForTransaction(
    FxParty party,
    FxTransaction tx,
  ) {
    for (final line in tx.lines) {
      final code = line.accountCode;
      if (code != null && _partyAccountCodes.contains(code)) {
        return (line.debitPkr, line.creditPkr);
      }
    }
    return _fallbackDebitCredit(party, tx);
  }

  static (double debit, double credit) _fallbackDebitCredit(
    FxParty party,
    FxTransaction tx,
  ) {
    final pkr = tx.totalBaseAmountPkr;
    return switch (tx.transactionType) {
      FxTransactionType.currencyBuy when party.partyType == FxPartyType.agent =>
        (0.0, pkr),
      FxTransactionType.currencySell
          when party.partyType == FxPartyType.customer =>
        (pkr, 0.0),
      FxTransactionType.settlementSend => (pkr, 0.0),
      FxTransactionType.settlementReceive => (0.0, pkr),
      _ => (0.0, 0.0),
    };
  }

  static double computeOpeningBalance({
    required FxParty party,
    required List<FxTransaction> priorTransactions,
  }) {
    if (priorTransactions.isEmpty) return 0;
    final view = build(
      party: party,
      from: DateTime(1970),
      to: DateTime(2100),
      transactions: priorTransactions,
    );
    return view.summary.netBalancePkr;
  }

  static String formatShareText(
    PartyStatementView view, {
    required bool internal,
  }) {
    final buf = StringBuffer();
    buf.writeln('FX Cash Ledger — Party Statement');
    buf.writeln('${view.party.name} (${view.party.partyType.label})');
    buf.writeln(
      'Period: ${view.from.toIso8601String().split('T').first} → ${view.to.toIso8601String().split('T').first}',
    );
    buf.writeln(
      'Closing balance (PKR): ${view.summary.netBalancePkr.toStringAsFixed(2)}',
    );
    buf.writeln('');
    buf.writeln(
      'Date       Ref          Type              Dr PKR    Cr PKR    Balance',
    );
    for (final line in view.lines) {
      buf.write('${line.transactionDate.toIso8601String().split('T').first} ');
      buf.write(
        '${(line.transactionNo ?? line.transactionId.substring(0, 8)).padRight(12)} ',
      );
      buf.write('${line.transactionType.label.padRight(18)} ');
      buf.write('${line.debitPkr.toStringAsFixed(0).padLeft(8)} ');
      buf.write('${line.creditPkr.toStringAsFixed(0).padLeft(8)} ');
      buf.writeln(line.runningBalancePkr.toStringAsFixed(0).padLeft(10));
      if (internal) {
        buf.writeln(
          '  ${line.foreignAmount.toStringAsFixed(2)} ${line.currencyCode} @ ${line.rateUsed}',
        );
      }
    }
    buf.writeln('');
    buf.writeln(
      'Total debit PKR: ${view.summary.totalDebitPkr.toStringAsFixed(2)}',
    );
    buf.writeln(
      'Total credit PKR: ${view.summary.totalCreditPkr.toStringAsFixed(2)}',
    );
    if (!internal) {
      buf.writeln('\n— Customer copy: internal rates and notes omitted —');
    } else {
      buf.writeln('\nInternal ledger statement');
    }
    return buf.toString();
  }

  static String formatShareCsv(PartyStatementView view) {
    final buf = StringBuffer();
    buf.writeln(
      'Date,TxnNo,Type,Status,Currency,ForeignAmount,Rate,DebitPKR,CreditPKR,RunningBalancePKR,PKREquivalent',
    );
    for (final line in view.lines) {
      buf.writeln(
        '${line.transactionDate.toIso8601String().split('T').first},'
        '${line.transactionNo ?? ''},'
        '${line.transactionType.dbValue},'
        '${line.status},'
        '${line.currencyCode},'
        '${line.foreignAmount},'
        '${line.rateUsed},'
        '${line.debitPkr},'
        '${line.creditPkr},'
        '${line.runningBalancePkr},'
        '${line.pkrEquivalent}',
      );
    }
    return buf.toString();
  }
}
