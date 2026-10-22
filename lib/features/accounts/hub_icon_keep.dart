import 'package:flutter/material.dart';

/// Explicit Icon() references so Flutter web `--tree-shake-icons` keeps glyphs
/// used via variable IconData on the Accounts Hub tiles.
void keepAccountsHubIcons() {
  // ignore: unused_local_variable
  final keep = <Widget>[
    const Icon(Icons.account_balance_wallet_outlined),
    const Icon(Icons.currency_exchange_outlined),
    const Icon(Icons.handshake_outlined),
    const Icon(Icons.public_outlined),
    const Icon(Icons.chat_bubble_outline),
    const Icon(Icons.account_tree_outlined),
    const Icon(Icons.add_card_outlined),
    const Icon(Icons.credit_card),
    const Icon(Icons.add_box_outlined),
    const Icon(Icons.document_scanner_outlined),
    const Icon(Icons.photo_camera_outlined),
    const Icon(Icons.people_outline),
    const Icon(Icons.person_add_outlined),
    const Icon(Icons.receipt_long_outlined),
    const Icon(Icons.menu_book_outlined),
    const Icon(Icons.balance_outlined),
    const Icon(Icons.trending_up_outlined),
    const Icon(Icons.account_balance_outlined),
    const Icon(Icons.history_outlined),
    const Icon(Icons.currency_exchange),
    const Icon(Icons.home_outlined),
    const Icon(Icons.settings_outlined),
  ];
  assert(keep.isNotEmpty);
}
