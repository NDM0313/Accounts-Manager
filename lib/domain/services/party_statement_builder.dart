import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:accounts_manager/domain/services/party_statement_narrative.dart';
import 'package:intl/intl.dart';

/// Builds party statement lines with debit/credit and running balance from transactions.
abstract final class PartyStatementBuilder {
  static const _partyAccountCodes = {'1180', '1190', '2100', '2200', '2300'};

  static PartyStatementView build({
    required FxParty party,
    required DateTime from,
    required DateTime to,
    required List<FxTransaction> transactions,
    Map<String, int> attachmentCountsByTx = const {},
    Set<String> transactionIdsWithAttachments = const {},
    bool isInternalView = true,
    double openingBalancePkr = 0,
    PartyStatementCompanyMeta? company,
    DateTime? generatedAt,
  }) {
    final sorted = [...transactions]
      ..sort((a, b) {
        final d = a.transactionDate.compareTo(b.transactionDate);
        if (d != 0) return d;
        final no = (a.transactionNo ?? a.id).compareTo(b.transactionNo ?? b.id);
        if (no != 0) return no;
        return a.id.compareTo(b.id);
      });

    final debitNormal = _isDebitNormal(party.partyType);
    var running = openingBalancePkr;
    var totalDebit = 0.0;
    var totalCredit = 0.0;
    final balancesByCurrency = <String, double>{};
    var pendingDrafts = 0;
    DateTime? lastDate;
    final external = !isInternalView;

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

      final attCount = attachmentCountsByTx[tx.id] ??
          (transactionIdsWithAttachments.contains(tx.id) ? 1 : 0);

      final narrative = PartyStatementNarrative.simpleLine(
        party: party,
        tx: tx,
        externalCopy: external,
      );
      final details = PartyStatementNarrative.detailBlocks(
        party: party,
        tx: tx,
        externalCopy: external,
        attachmentCount: attCount,
      );

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
          narrative: narrative,
          detailBlocks: details,
          description: tx.description,
          dealNo: tx.dealNo,
          attachmentCount: attCount,
          hasAttachment: attCount > 0,
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
      company: company,
      generatedAt: generatedAt ?? DateTime.now(),
      balanceExplanation: PartyStatementNarrative.balanceExplanation(
        partyType: party.partyType,
        closingPkr: netBalance,
      ),
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
        FxPartyType.supplier => true,
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
      isInternalView: true,
    );
    return view.summary.netBalancePkr;
  }

  static String formatShareText(
    PartyStatementView view, {
    required bool internal,
  }) {
    final df = DateFormat('dd MMM yyyy');
    final mf = NumberFormat('#,##0.00');
    final buf = StringBuffer();
    final company = view.company?.companyName ?? 'FX Cash Ledger';
    buf.writeln('$company — Statement of Account');
    buf.writeln('${view.party.name} (${view.party.code}) · ${view.party.partyType.label}');
    buf.writeln(
      'Period: ${df.format(view.from)} → ${df.format(view.to)} · Statement currency: PKR',
    );
    buf.writeln('Opening: ${mf.format(view.openingBalancePkr)} PKR');
    buf.writeln('');
    for (final line in view.lines) {
      buf.writeln(
        '${df.format(line.transactionDate)}  '
        '${line.transactionNo ?? line.transactionId.substring(0, 8)}',
      );
      buf.writeln('  ${line.narrative}');
      if (line.attachmentCount > 0) {
        buf.writeln('  Attachments: ${line.attachmentCount}');
      }
      buf.writeln(
        '  Dr ${mf.format(line.debitPkr)}  Cr ${mf.format(line.creditPkr)}  '
        'Bal ${mf.format(line.runningBalancePkr)}',
      );
      if (internal) {
        for (final d in line.detailBlocks) {
          buf.writeln('    · $d');
        }
      }
    }
    buf.writeln('');
    buf.writeln('Total debit:  ${mf.format(view.summary.totalDebitPkr)} PKR');
    buf.writeln('Total credit: ${mf.format(view.summary.totalCreditPkr)} PKR');
    buf.writeln('Closing:      ${mf.format(view.closingBalancePkr)} PKR');
    buf.writeln(view.balanceExplanation);
    if (!internal) {
      buf.writeln('\n— External party copy —');
    }
    return buf.toString();
  }

  static String formatShareCsv(PartyStatementView view) {
    final buf = StringBuffer();
    buf.writeln(
      'Date,TxnNo,Narrative,Currency,ForeignAmount,Rate,DebitPKR,CreditPKR,RunningBalancePKR,Attachments,DealNo',
    );
    for (final line in view.lines) {
      final nar = line.narrative.replaceAll('"', '""');
      buf.writeln(
        '${line.transactionDate.toIso8601String().split('T').first},'
        '${line.transactionNo ?? ''},'
        '"$nar",'
        '${line.currencyCode},'
        '${line.foreignAmount},'
        '${line.rateUsed},'
        '${line.debitPkr},'
        '${line.creditPkr},'
        '${line.runningBalancePkr},'
        '${line.attachmentCount},'
        '${line.dealNo ?? ''}',
      );
    }
    return buf.toString();
  }
}
