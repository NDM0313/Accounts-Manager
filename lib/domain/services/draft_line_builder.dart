import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';

/// Builds balanced draft lines client-side; posting copies them to journal via RPC.
abstract final class DraftLineBuilder {
  static String? accountIdByCode(List<FxAccount> accounts, String code) {
    for (final a in accounts) {
      if (a.code == code) return a.id;
    }
    return null;
  }

  static String cashCodeForCurrency(List<FxAccount> accounts, String currencyCode) {
    for (final a in accounts) {
      if (a.currencyCode == currencyCode &&
          a.accountType == 'asset' &&
          a.code.startsWith('11') &&
          a.isActive) {
        return a.code;
      }
    }
    return switch (currencyCode) {
      'PKR' => '1110',
      'USD' => '1120',
      'AED' => '1130',
      'CNY' => '1140',
      'SAR' => '1150',
      _ => '1110',
    };
  }

  static List<FxTransactionLineInput> build({
    required FxTransactionType type,
    required List<FxAccount> accounts,
    required String currencyCode,
    required double foreignAmount,
    required double rateUsed,
    required double baseAmountPkr,
    String? fromAccountCode,
    String? toAccountCode,
    String? expenseAccountCode,
    String? settlementAccountCode,
    String? toCurrencyCode,
    double? toForeignAmount,
    double? toRateUsed,
    double? revaluationDeltaPkr,
    bool onCredit = false,
  }) {
    switch (type) {
      case FxTransactionType.currencyBuy:
        return _currencyBuy(
          accounts,
          currencyCode,
          foreignAmount,
          rateUsed,
          baseAmountPkr,
          creditAccountCode: onCredit ? (settlementAccountCode ?? '2100') : null,
        );
      case FxTransactionType.currencySell:
        return _currencySell(
          accounts,
          currencyCode,
          foreignAmount,
          rateUsed,
          baseAmountPkr,
          debitAccountCode: onCredit ? (settlementAccountCode ?? '1190') : null,
        );
      case FxTransactionType.accountTransfer:
        return _transfer(accounts, fromAccountCode!, toAccountCode!, currencyCode, baseAmountPkr);
      case FxTransactionType.expense:
        return _expense(accounts, expenseAccountCode!, fromAccountCode ?? '1110', currencyCode, baseAmountPkr);
      case FxTransactionType.openingBalance:
        return _openingBalance(
          accounts,
          fromAccountCode ?? cashCodeForCurrency(accounts, currencyCode),
          currencyCode,
          foreignAmount,
          baseAmountPkr,
        );
      case FxTransactionType.crossCurrency:
        return _crossCurrency(
          accounts,
          currencyCode,
          foreignAmount,
          rateUsed,
          toCurrencyCode!,
          toForeignAmount!,
          toRateUsed!,
        );
      case FxTransactionType.settlementSend:
        return _settlementSend(
          accounts,
          settlementAccountCode ?? '2100',
          fromAccountCode ?? cashCodeForCurrency(accounts, currencyCode),
          currencyCode,
          baseAmountPkr,
        );
      case FxTransactionType.settlementReceive:
        return _settlementReceive(
          accounts,
          settlementAccountCode ?? '1180',
          fromAccountCode ?? cashCodeForCurrency(accounts, currencyCode),
          currencyCode,
          baseAmountPkr,
        );
      case FxTransactionType.dailyClosingAdjustment:
        return _closingAdjustment(
          accounts,
          fromAccountCode ?? cashCodeForCurrency(accounts, currencyCode),
          currencyCode,
          baseAmountPkr,
        );
      case FxTransactionType.revaluation:
        return _revaluation(
          accounts,
          fromAccountCode ?? cashCodeForCurrency(accounts, currencyCode),
          currencyCode,
          revaluationDeltaPkr ?? baseAmountPkr,
        );
      case FxTransactionType.manualJournal:
        throw UnsupportedError('Manual journal uses fx_post_manual_journal RPC');
    }
  }

  static List<FxTransactionLineInput> _currencyBuy(
    List<FxAccount> accounts,
    String currencyCode,
    double foreignAmount,
    double rateUsed,
    double baseAmountPkr, {
    String? creditAccountCode,
  }) {
    final foreignCash = accountIdByCode(accounts, cashCodeForCurrency(accounts, currencyCode))!;
    final creditCode = creditAccountCode ?? '1110';
    final creditAccount = accountIdByCode(accounts, creditCode)!;
    final creditCurrency = creditCode == '1110' ? 'PKR' : 'PKR';
    return [
      FxTransactionLineInput(
        lineNo: 1,
        accountId: foreignCash,
        currencyCode: currencyCode,
        foreignAmount: foreignAmount,
        rateUsed: rateUsed,
        debitPkr: baseAmountPkr,
        creditPkr: 0,
        memo: creditAccountCode != null ? 'Buy $currencyCode (credit)' : 'Buy $currencyCode',
      ),
      FxTransactionLineInput(
        lineNo: 2,
        accountId: creditAccount,
        currencyCode: creditCurrency,
        foreignAmount: baseAmountPkr,
        rateUsed: 1,
        debitPkr: 0,
        creditPkr: baseAmountPkr,
        memo: creditAccountCode != null ? 'Buy $currencyCode (credit)' : 'Buy $currencyCode',
      ),
    ];
  }

  static List<FxTransactionLineInput> _currencySell(
    List<FxAccount> accounts,
    String currencyCode,
    double foreignAmount,
    double rateUsed,
    double baseAmountPkr, {
    String? debitAccountCode,
  }) {
    final foreignCash = accountIdByCode(accounts, cashCodeForCurrency(accounts, currencyCode))!;
    final debitCode = debitAccountCode ?? '1110';
    final debitAccount = accountIdByCode(accounts, debitCode)!;
    return [
      FxTransactionLineInput(
        lineNo: 1,
        accountId: debitAccount,
        currencyCode: 'PKR',
        foreignAmount: baseAmountPkr,
        rateUsed: 1,
        debitPkr: baseAmountPkr,
        creditPkr: 0,
        memo: debitAccountCode != null ? 'Sell $currencyCode (credit)' : 'Sell $currencyCode',
      ),
      FxTransactionLineInput(
        lineNo: 2,
        accountId: foreignCash,
        currencyCode: currencyCode,
        foreignAmount: foreignAmount,
        rateUsed: rateUsed,
        debitPkr: 0,
        creditPkr: baseAmountPkr,
        memo: debitAccountCode != null ? 'Sell $currencyCode (credit)' : 'Sell $currencyCode',
      ),
    ];
  }

  static List<FxTransactionLineInput> _transfer(
    List<FxAccount> accounts,
    String fromCode,
    String toCode,
    String currencyCode,
    double amount,
  ) {
    return [
      FxTransactionLineInput(
        lineNo: 1,
        accountId: accountIdByCode(accounts, toCode)!,
        currencyCode: currencyCode,
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: amount,
        creditPkr: 0,
      ),
      FxTransactionLineInput(
        lineNo: 2,
        accountId: accountIdByCode(accounts, fromCode)!,
        currencyCode: currencyCode,
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: 0,
        creditPkr: amount,
      ),
    ];
  }

  static List<FxTransactionLineInput> _expense(
    List<FxAccount> accounts,
    String expenseCode,
    String cashCode,
    String currencyCode,
    double amount,
  ) {
    return [
      FxTransactionLineInput(
        lineNo: 1,
        accountId: accountIdByCode(accounts, expenseCode)!,
        currencyCode: currencyCode,
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: amount,
        creditPkr: 0,
      ),
      FxTransactionLineInput(
        lineNo: 2,
        accountId: accountIdByCode(accounts, cashCode)!,
        currencyCode: currencyCode,
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: 0,
        creditPkr: amount,
      ),
    ];
  }

  static List<FxTransactionLineInput> _openingBalance(
    List<FxAccount> accounts,
    String cashCode,
    String currencyCode,
    double foreignAmount,
    double baseAmountPkr,
  ) {
    final equity = accountIdByCode(accounts, '3100')!;
    final cash = accountIdByCode(accounts, cashCode)!;
    return [
      FxTransactionLineInput(
        lineNo: 1,
        accountId: cash,
        currencyCode: currencyCode,
        foreignAmount: foreignAmount,
        rateUsed: baseAmountPkr / (foreignAmount == 0 ? 1 : foreignAmount),
        debitPkr: baseAmountPkr,
        creditPkr: 0,
        memo: 'Opening balance',
      ),
      FxTransactionLineInput(
        lineNo: 2,
        accountId: equity,
        currencyCode: 'PKR',
        foreignAmount: baseAmountPkr,
        rateUsed: 1,
        debitPkr: 0,
        creditPkr: baseAmountPkr,
        memo: 'Opening balance',
      ),
    ];
  }

  static List<FxTransactionLineInput> _crossCurrency(
    List<FxAccount> accounts,
    String fromCurrency,
    double fromAmount,
    double fromRate,
    String toCurrency,
    double toAmount,
    double toRate,
  ) {
    final baseOut = fromAmount * fromRate;
    final baseIn = toAmount * toRate;
    final spread = baseIn - baseOut;
    final fromCash = accountIdByCode(accounts, cashCodeForCurrency(accounts, fromCurrency))!;
    final toCash = accountIdByCode(accounts, cashCodeForCurrency(accounts, toCurrency))!;

    final lines = <FxTransactionLineInput>[
      FxTransactionLineInput(
        lineNo: 1,
        accountId: toCash,
        currencyCode: toCurrency,
        foreignAmount: toAmount,
        rateUsed: toRate,
        debitPkr: baseIn,
        creditPkr: 0,
        memo: 'Cross $fromCurrency → $toCurrency',
      ),
      FxTransactionLineInput(
        lineNo: 2,
        accountId: fromCash,
        currencyCode: fromCurrency,
        foreignAmount: fromAmount,
        rateUsed: fromRate,
        debitPkr: 0,
        creditPkr: baseOut,
        memo: 'Cross $fromCurrency → $toCurrency',
      ),
    ];

    if (spread.abs() > 0.001) {
      final spreadAccount = spread > 0 ? '4100' : '5700';
      final spreadId = accountIdByCode(accounts, spreadAccount)!;
      if (spread > 0) {
        lines.add(
          FxTransactionLineInput(
            lineNo: 3,
            accountId: spreadId,
            currencyCode: 'PKR',
            foreignAmount: spread.abs(),
            rateUsed: 1,
            debitPkr: 0,
            creditPkr: spread.abs(),
            memo: 'Cross-currency spread',
          ),
        );
      } else {
        lines.add(
          FxTransactionLineInput(
            lineNo: 3,
            accountId: spreadId,
            currencyCode: 'PKR',
            foreignAmount: spread.abs(),
            rateUsed: 1,
            debitPkr: spread.abs(),
            creditPkr: 0,
            memo: 'Cross-currency spread',
          ),
        );
      }
    }

    return lines;
  }

  static List<FxTransactionLineInput> _settlementSend(
    List<FxAccount> accounts,
    String payableCode,
    String cashCode,
    String currencyCode,
    double amount,
  ) {
    return [
      FxTransactionLineInput(
        lineNo: 1,
        accountId: accountIdByCode(accounts, payableCode)!,
        currencyCode: currencyCode,
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: amount,
        creditPkr: 0,
        memo: 'Settlement send',
      ),
      FxTransactionLineInput(
        lineNo: 2,
        accountId: accountIdByCode(accounts, cashCode)!,
        currencyCode: currencyCode,
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: 0,
        creditPkr: amount,
        memo: 'Settlement send',
      ),
    ];
  }

  static List<FxTransactionLineInput> _settlementReceive(
    List<FxAccount> accounts,
    String receivableCode,
    String cashCode,
    String currencyCode,
    double amount,
  ) {
    return [
      FxTransactionLineInput(
        lineNo: 1,
        accountId: accountIdByCode(accounts, cashCode)!,
        currencyCode: currencyCode,
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: amount,
        creditPkr: 0,
        memo: 'Settlement receive',
      ),
      FxTransactionLineInput(
        lineNo: 2,
        accountId: accountIdByCode(accounts, receivableCode)!,
        currencyCode: currencyCode,
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: 0,
        creditPkr: amount,
        memo: 'Settlement receive',
      ),
    ];
  }

  static List<FxTransactionLineInput> _closingAdjustment(
    List<FxAccount> accounts,
    String cashCode,
    String currencyCode,
    double signedAmountPkr,
  ) {
    final cash = accountIdByCode(accounts, cashCode)!;
    final overShort = accountIdByCode(accounts, '6300')!;
    final amount = signedAmountPkr.abs();
    if (signedAmountPkr >= 0) {
      return [
        FxTransactionLineInput(
          lineNo: 1,
          accountId: cash,
          currencyCode: currencyCode,
          foreignAmount: amount,
          rateUsed: 1,
          debitPkr: amount,
          creditPkr: 0,
          memo: 'Closing adjustment',
        ),
        FxTransactionLineInput(
          lineNo: 2,
          accountId: overShort,
          currencyCode: 'PKR',
          foreignAmount: amount,
          rateUsed: 1,
          debitPkr: 0,
          creditPkr: amount,
          memo: 'Closing adjustment',
        ),
      ];
    }
    return [
      FxTransactionLineInput(
        lineNo: 1,
        accountId: overShort,
        currencyCode: 'PKR',
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: amount,
        creditPkr: 0,
        memo: 'Closing adjustment',
      ),
      FxTransactionLineInput(
        lineNo: 2,
        accountId: cash,
        currencyCode: currencyCode,
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: 0,
        creditPkr: amount,
        memo: 'Closing adjustment',
      ),
    ];
  }

  static List<FxTransactionLineInput> _revaluation(
    List<FxAccount> accounts,
    String cashCode,
    String currencyCode,
    double deltaPkr,
  ) {
    final cash = accountIdByCode(accounts, cashCode)!;
    final amount = deltaPkr.abs();
    if (deltaPkr >= 0) {
      final gain = accountIdByCode(accounts, '4400')!;
      return [
        FxTransactionLineInput(
          lineNo: 1,
          accountId: cash,
          currencyCode: currencyCode,
          foreignAmount: amount,
          rateUsed: 1,
          debitPkr: amount,
          creditPkr: 0,
          memo: 'Revaluation gain',
        ),
        FxTransactionLineInput(
          lineNo: 2,
          accountId: gain,
          currencyCode: 'PKR',
          foreignAmount: amount,
          rateUsed: 1,
          debitPkr: 0,
          creditPkr: amount,
          memo: 'Revaluation gain',
        ),
      ];
    }
    final loss = accountIdByCode(accounts, '5700')!;
    return [
      FxTransactionLineInput(
        lineNo: 1,
        accountId: loss,
        currencyCode: 'PKR',
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: amount,
        creditPkr: 0,
        memo: 'Revaluation loss',
      ),
      FxTransactionLineInput(
        lineNo: 2,
        accountId: cash,
        currencyCode: currencyCode,
        foreignAmount: amount,
        rateUsed: 1,
        debitPkr: 0,
        creditPkr: amount,
        memo: 'Revaluation loss',
      ),
    ];
  }
}
