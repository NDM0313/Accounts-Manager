import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:intl/intl.dart';

/// Builds party-facing narrative text from authoritative posted fields only.
/// Never invents rates by dividing amounts.
abstract final class PartyStatementNarrative {
  static final _qty = NumberFormat('#,##0.##');
  static final _money = NumberFormat('#,##0.00');
  static final _rate = NumberFormat('#,##0.####');

  static String simpleLine({
    required FxParty party,
    required FxTransaction tx,
    required bool externalCopy,
  }) {
    final dealSuffix = tx.dealNo != null && tx.dealNo!.isNotEmpty
        ? ' Deal ${tx.dealNo}.'
        : '';
    final note = _publicNote(tx.description, externalCopy);

    switch (tx.transactionType) {
      case FxTransactionType.currencySell:
        return '${_fxSale(tx)}$dealSuffix$note';
      case FxTransactionType.currencyBuy:
        return '${_fxBuy(tx, party)}$dealSuffix$note';
      case FxTransactionType.settlementReceive:
        return 'Payment received'
            '${tx.currencyCode == 'PKR' ? '' : ' (${_qty.format(tx.totalForeignAmount)} ${tx.currencyCode})'}'
            ' ${_money.format(tx.totalBaseAmountPkr)} PKR.$dealSuffix$note';
      case FxTransactionType.settlementSend:
        return 'Payment / settlement sent'
            ' ${_money.format(tx.totalBaseAmountPkr)} PKR.$dealSuffix$note';
      case FxTransactionType.openingBalance:
        return 'Opening balance entry'
            ' ${_money.format(tx.totalBaseAmountPkr)} PKR.$note';
      case FxTransactionType.crossCurrency:
        return 'Cross-currency exchange'
            ' ${_qty.format(tx.totalForeignAmount)} ${tx.currencyCode}'
            '${_rateClause(tx)}'
            ' = ${_money.format(tx.totalBaseAmountPkr)} PKR.$dealSuffix$note';
      default:
        final label = tx.transactionType.label;
        if (tx.currencyCode != 'PKR' && tx.totalForeignAmount != 0) {
          return '$label: ${_qty.format(tx.totalForeignAmount)} ${tx.currencyCode}'
              '${_rateClause(tx)}'
              ' = ${_money.format(tx.totalBaseAmountPkr)} PKR.$dealSuffix$note';
        }
        return '$label ${_money.format(tx.totalBaseAmountPkr)} PKR.$dealSuffix$note';
    }
  }

  static List<String> detailBlocks({
    required FxParty party,
    required FxTransaction tx,
    required bool externalCopy,
    required int attachmentCount,
  }) {
    final blocks = <String>[
      'Type: ${tx.transactionType.label}',
      if (tx.currencyCode != 'PKR' || tx.totalForeignAmount != 0)
        'Source: ${_qty.format(tx.totalForeignAmount)} ${tx.currencyCode}',
      if (_hasUsableRate(tx))
        'Agreed rate: PKR ${_rate.format(tx.rateUsed)} per 1 ${tx.currencyCode}',
      'Statement amount: ${_money.format(tx.totalBaseAmountPkr)} PKR',
      if (tx.dealNo != null && tx.dealNo!.isNotEmpty) 'Deal: ${tx.dealNo}',
      if (tx.transactionNo != null) 'Reference: ${tx.transactionNo}',
      if (attachmentCount > 0) 'Attachments: $attachmentCount',
    ];
    final note = _publicNote(tx.description, externalCopy).trim();
    if (note.isNotEmpty) {
      blocks.add('Note:${note.trim()}');
    }
    if (!externalCopy && tx.exchangeGroupId != null) {
      blocks.add('Exchange group: ${tx.exchangeGroupId}');
    }
    return blocks;
  }

  static String balanceExplanation({
    required FxPartyType partyType,
    required double closingPkr,
  }) {
    final abs = closingPkr.abs();
    final amount = _money.format(abs);
    if (abs < 0.005) {
      return 'Closing balance is settled (0.00 PKR).';
    }
    return switch (partyType) {
      FxPartyType.customer || FxPartyType.supplier => closingPkr > 0
          ? 'Closing: party owes us $amount PKR (receivable).'
          : 'Closing: we owe party $amount PKR (payable).',
      FxPartyType.agent => closingPkr > 0
          ? 'Closing agent balance $amount PKR (credit-normal view).'
          : 'Closing agent balance $amount PKR (we owe / payable side).',
      FxPartyType.settlement =>
        'Closing settlement balance $amount PKR.',
    };
  }

  static String _fxSale(FxTransaction tx) {
    final ccy = tx.currencyCode;
    final label = switch (ccy) {
      'CNY' => 'RMB/CNY sale',
      'AED' => 'AED sale',
      'USD' => 'USD sale',
      _ => '$ccy sale',
    };
    if (_hasUsableRate(tx)) {
      return '$label: ${_qty.format(tx.totalForeignAmount)} $ccy'
          ' × PKR ${_rate.format(tx.rateUsed)}'
          ' = ${_money.format(tx.totalBaseAmountPkr)} PKR.';
    }
    return '$label: ${_qty.format(tx.totalForeignAmount)} $ccy'
        ' = ${_money.format(tx.totalBaseAmountPkr)} PKR'
        ' (booked amount; historical rate not recorded).';
  }

  static String _fxBuy(FxTransaction tx, FxParty party) {
    final ccy = tx.currencyCode;
    final who = party.partyType == FxPartyType.agent ? 'from agent' : 'purchase';
    if (_hasUsableRate(tx)) {
      return 'Currency buy $who: ${_qty.format(tx.totalForeignAmount)} $ccy'
          ' × PKR ${_rate.format(tx.rateUsed)}'
          ' = ${_money.format(tx.totalBaseAmountPkr)} PKR.';
    }
    return 'Currency buy $who: ${_qty.format(tx.totalForeignAmount)} $ccy'
        ' = ${_money.format(tx.totalBaseAmountPkr)} PKR'
        ' (booked amount; historical rate not recorded).';
  }

  static String _rateClause(FxTransaction tx) {
    if (!_hasUsableRate(tx)) return '';
    return ' @ PKR ${_rate.format(tx.rateUsed)}';
  }

  static bool _hasUsableRate(FxTransaction tx) {
    if (tx.currencyCode == 'PKR') return false;
    return tx.rateUsed > 0 && tx.totalForeignAmount != 0;
  }

  static String _publicNote(String? raw, bool externalCopy) {
    if (raw == null) return '';
    final t = raw.trim();
    if (t.isEmpty) return '';
    // Seed / internal markers stay internal-only.
    if (externalCopy) {
      final lower = t.toLowerCase();
      if (lower.startsWith('demo_seed') ||
          lower.contains('internal') ||
          lower == 'testt') {
        return '';
      }
    }
    return ' $t';
  }
}
