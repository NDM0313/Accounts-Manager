import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_opening_balance_batch.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/services/draft_line_builder.dart';

/// Maps wizard rows to balanced transaction line pairs and batch totals.
abstract final class OpeningBalanceLineMapper {
  static const equityCode = '3100';

  static String? partyAccountCode(
    FxPartyType partyType,
    FxOpeningBalanceLineKind kind,
  ) {
    return switch (kind) {
      FxOpeningBalanceLineKind.partyReceivable => switch (partyType) {
        FxPartyType.customer => '1190',
        FxPartyType.agent => '1180',
        FxPartyType.settlement => null,
      },
      FxOpeningBalanceLineKind.partyPayable => switch (partyType) {
        FxPartyType.customer => '2200',
        FxPartyType.agent => '2100',
        FxPartyType.settlement => '2300',
      },
      _ => null,
    };
  }

  static double computePkrAmount({
    required String currencyCode,
    required double foreignAmount,
    required double rateUsed,
  }) {
    if (currencyCode == 'PKR') return foreignAmount;
    return foreignAmount * rateUsed;
  }

  static ({double totalDebit, double totalCredit}) batchTotals(
    List<FxOpeningBalanceLine> lines,
  ) {
    var debit = 0.0;
    var credit = 0.0;
    for (final line in lines) {
      debit += line.pkrAmount;
      credit += line.pkrAmount;
    }
    return (totalDebit: debit, totalCredit: credit);
  }

  static bool isBalanced(List<FxOpeningBalanceLine> lines) {
    if (lines.isEmpty) return false;
    final t = batchTotals(lines);
    return (t.totalDebit - t.totalCredit).abs() < 0.01 && t.totalDebit > 0;
  }

  /// Preview balanced transaction lines for one opening balance row (mirrors RPC post logic).
  static List<FxTransactionLineInput> buildTransactionLines({
    required FxOpeningBalanceLineKind kind,
    required List<FxAccount> accounts,
    required String equityAccountId,
    String? primaryAccountId,
    String? partyAccountCodeOverride,
    required String currencyCode,
    required double foreignAmount,
    required double rateUsed,
    required double pkrAmount,
    String memo = 'Opening balance',
  }) {
    final equity = equityAccountId;
    String? primaryId = primaryAccountId;
    if (partyAccountCodeOverride != null) {
      primaryId = DraftLineBuilder.accountIdByCode(
        accounts,
        partyAccountCodeOverride,
      );
    }
    if (primaryId == null) {
      throw StateError('Primary account required for $kind');
    }

    return switch (kind) {
      FxOpeningBalanceLineKind.cashBank ||
      FxOpeningBalanceLineKind.currencyPosition ||
      FxOpeningBalanceLineKind.partyReceivable => [
        FxTransactionLineInput(
          lineNo: 1,
          accountId: primaryId,
          currencyCode: currencyCode,
          foreignAmount: foreignAmount,
          rateUsed: rateUsed,
          debitPkr: pkrAmount,
          creditPkr: 0,
          memo: memo,
        ),
        FxTransactionLineInput(
          lineNo: 2,
          accountId: equity,
          currencyCode: 'PKR',
          foreignAmount: pkrAmount,
          rateUsed: 1,
          debitPkr: 0,
          creditPkr: pkrAmount,
          memo: memo,
        ),
      ],
      FxOpeningBalanceLineKind.partyPayable => [
        FxTransactionLineInput(
          lineNo: 1,
          accountId: equity,
          currencyCode: 'PKR',
          foreignAmount: pkrAmount,
          rateUsed: 1,
          debitPkr: pkrAmount,
          creditPkr: 0,
          memo: memo,
        ),
        FxTransactionLineInput(
          lineNo: 2,
          accountId: primaryId,
          currencyCode: currencyCode,
          foreignAmount: foreignAmount,
          rateUsed: rateUsed,
          debitPkr: 0,
          creditPkr: pkrAmount,
          memo: memo,
        ),
      ],
    };
  }

  static List<FxAccount> cashAndBankAccounts(List<FxAccount> accounts) {
    return accounts
        .where(
          (a) =>
              a.isActive && a.accountType == 'asset' && a.code.startsWith('11'),
        )
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
  }
}
