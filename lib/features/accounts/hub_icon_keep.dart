import 'package:flutter/material.dart';

/// Explicit Icon() references so Flutter web `--tree-shake-icons` keeps glyphs
/// used via variable IconData on the Accounts Hub tiles.
///
/// Must not rely on `assert` — asserts are stripped in release, which lets DCE
/// drop this list and shake the glyphs out of MaterialIcons-Regular.otf.
List<Widget> keepAccountsHubIcons() {
  return const <Widget>[
    Icon(Icons.account_balance_wallet_outlined),
    Icon(Icons.currency_exchange_outlined),
    Icon(Icons.handshake_outlined),
    Icon(Icons.public_outlined),
    Icon(Icons.chat_bubble_outline),
    Icon(Icons.account_tree_outlined),
    Icon(Icons.add_card_outlined),
    Icon(Icons.credit_card),
    Icon(Icons.add_box_outlined),
    Icon(Icons.document_scanner_outlined),
    Icon(Icons.photo_camera_outlined),
    Icon(Icons.people_outline),
    Icon(Icons.person_add_outlined),
    Icon(Icons.receipt_long_outlined),
    Icon(Icons.menu_book_outlined),
    Icon(Icons.balance_outlined),
    Icon(Icons.trending_up_outlined),
    Icon(Icons.account_balance_outlined),
    Icon(Icons.history_outlined),
    Icon(Icons.currency_exchange),
    Icon(Icons.home_outlined),
    Icon(Icons.settings_outlined),
  ];
}
