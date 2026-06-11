import 'package:flutter/material.dart';
import 'package:accounts_manager/core/widgets/premium/fx_transaction_menu_sheet.dart';

/// @deprecated Use [FxTransactionMenuSheet.show].
abstract final class FxObsidianBottomSheet {
  static void showTransactionTypes(BuildContext context) {
    FxTransactionMenuSheet.show(context);
  }
}
