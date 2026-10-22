import 'package:accounts_manager/domain/models/cash_bank_account.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/transaction_draft_mode.dart';
import 'package:intl/intl.dart';

/// Builds posting descriptions from confirmed structured values only.
abstract final class MoneyMovementDescription {
  static final _amt = NumberFormat('#,##0.##');

  static String accountPhrase(FxAccount? account) {
    if (account == null) return 'selected account';
    final mask = CashBankAccountRules.maskIdentifier(
      account.accountNumber ?? account.iban,
    );
    if (mask.isEmpty) return account.name;
    return '${account.name} $mask';
  }

  static String build({
    required TransactionDraftMode mode,
    required String currencyCode,
    required double amount,
    required String partyName,
    required FxAccount? vaultAccount,
    String? reference,
    String? dealLabel,
    String? extraNotes,
  }) {
    final amt = '${currencyCode.toUpperCase()} ${_amt.format(amount)}';
    final vault = accountPhrase(vaultAccount);
    final core = switch (mode) {
      TransactionDraftMode.customerReceipt ||
      TransactionDraftMode.agentReturn =>
        'Received $amt from $partyName into $vault.',
      TransactionDraftMode.agentPayment ||
      TransactionDraftMode.customerRefund =>
        'Paid $amt to $partyName from $vault.',
      TransactionDraftMode.standard =>
        'Settlement $amt with $partyName via $vault.',
    };
    final bits = <String>[core];
    if (dealLabel != null && dealLabel.trim().isNotEmpty) {
      bits.add('Deal: ${dealLabel.trim()}.');
    }
    if (reference != null && reference.trim().isNotEmpty) {
      bits.add('Ref: ${reference.trim()}.');
    }
    if (extraNotes != null && extraNotes.trim().isNotEmpty) {
      bits.add(extraNotes.trim());
    }
    return bits.join(' ');
  }

  static String reviewSentence({
    required bool isReceive,
    required String currencyCode,
    required double amount,
    required String partyName,
    required FxAccount? vaultAccount,
  }) {
    final amt = '${currencyCode.toUpperCase()} ${_amt.format(amount)}';
    final vault = accountPhrase(vaultAccount);
    if (isReceive) {
      return 'Receive $amt from $partyName into $vault.';
    }
    return 'Pay $amt from $vault to $partyName.';
  }
}
