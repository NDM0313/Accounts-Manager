import 'package:accounts_manager/core/widgets/premium/fx_transaction_actions_sheet.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

FxTransaction _tx({
  required String status,
  FxTransactionType type = FxTransactionType.settlementReceive,
}) {
  return FxTransaction(
    id: '00000000-0000-0000-0000-000000000001',
    transactionType: type,
    status: status,
    transactionDate: DateTime(2026, 6, 1),
    currencyCode: 'PKR',
    totalForeignAmount: 1000,
    rateUsed: 1,
    totalBaseAmountPkr: 1000,
  );
}

void main() {
  test('draft exposes edit/delete draft only', () {
    final actions = fxTransactionActionsFor(
      tx: _tx(status: 'draft'),
      dayClosed: false,
    );
    expect(
      actions.map((a) => a.action),
      containsAll([
        FxTransactionUiAction.editDraft,
        FxTransactionUiAction.deleteDraft,
        FxTransactionUiAction.viewAudit,
      ]),
    );
    expect(
      actions.any((a) => a.action == FxTransactionUiAction.voidReverse),
      isFalse,
    );
  });

  test('posted exposes correct + void; day closed disables them', () {
    final open = fxTransactionActionsFor(
      tx: _tx(status: 'posted'),
      dayClosed: false,
    );
    final closed = fxTransactionActionsFor(
      tx: _tx(status: 'posted'),
      dayClosed: true,
    );
    final correct = open.firstWhere(
      (a) => a.action == FxTransactionUiAction.correctEntry,
    );
    final voidAction = open.firstWhere(
      (a) => a.action == FxTransactionUiAction.voidReverse,
    );
    expect(correct.enabled, isTrue);
    expect(voidAction.enabled, isTrue);
    expect(
      closed
          .firstWhere((a) => a.action == FxTransactionUiAction.correctEntry)
          .enabled,
      isFalse,
    );
    expect(
      closed
          .firstWhere((a) => a.action == FxTransactionUiAction.voidReverse)
          .blockedReason,
      contains('closed'),
    );
  });

  test('opening balance blocks ordinary correct/metadata', () {
    final actions = fxTransactionActionsFor(
      tx: _tx(
        status: 'posted',
        type: FxTransactionType.openingBalance,
      ),
      dayClosed: false,
    );
    expect(
      actions
          .firstWhere((a) => a.action == FxTransactionUiAction.correctEntry)
          .enabled,
      isFalse,
    );
  });
}
