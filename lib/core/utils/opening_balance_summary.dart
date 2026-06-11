import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:accounts_manager/domain/models/fx_opening_balance_batch.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

String formatOpeningBalanceSummary({
  required FxOpeningBalanceBatch batch,
  required List<FxOpeningBalanceLine> lines,
  List<FxAccount> accounts = const [],
  List<FxParty> parties = const [],
}) {
  final fmt = NumberFormat('#,##0.00');
  final dateFmt = DateFormat('d MMM yyyy');
  String accountName(String? id) {
    if (id == null) return '—';
    return accounts.where((a) => a.id == id).map((a) => '${a.code} ${a.name}').firstOrNull ?? id;
  }
  String partyName(String? id) {
    if (id == null) return '—';
    return parties.where((p) => p.id == id).map((p) => p.name).firstOrNull ?? id;
  }

  final buf = StringBuffer()
    ..writeln('FX Cash Ledger — Opening Balance Summary')
    ..writeln('─────────────────────────────────────────')
    ..writeln('Batch: ${batch.batchNo ?? batch.id.substring(0, 8).toUpperCase()}')
    ..writeln('Opening date: ${dateFmt.format(batch.openingDate)}')
    ..writeln('Base currency: ${batch.baseCurrencyCode}');
  if (batch.description != null && batch.description!.isNotEmpty) {
    buf.writeln('Description: ${batch.description}');
  }
  buf
    ..writeln()
    ..writeln('Lines:')
    ..writeln('─────────────────────────────────────────');

  for (final line in lines) {
    buf.writeln('${line.lineNo}. ${line.lineKind.label}');
    if (line.accountId != null) buf.writeln('   Account: ${accountName(line.accountId)}');
    if (line.partyId != null) buf.writeln('   Party: ${partyName(line.partyId)}');
    buf.writeln('   ${line.currencyCode} ${fmt.format(line.foreignAmount)} @ ${fmt.format(line.rateUsed)}');
    buf.writeln('   PKR equivalent: ${fmt.format(line.pkrAmount)}');
    if (line.locationLabel != null && line.locationLabel!.isNotEmpty) {
      buf.writeln('   Location: ${line.locationLabel}');
    }
    buf.writeln();
  }

  buf
    ..writeln('─────────────────────────────────────────')
    ..writeln('Total debits (PKR):  ${fmt.format(batch.totalDebitPkr)}')
    ..writeln('Total credits (PKR): ${fmt.format(batch.totalCreditPkr)}')
    ..writeln('Balancing: Owner Capital / Opening Balance Equity')
    ..writeln('─────────────────────────────────────────');

  return buf.toString();
}

Future<void> shareOpeningBalanceSummary({
  required FxOpeningBalanceBatch batch,
  required List<FxOpeningBalanceLine> lines,
  List<FxAccount> accounts = const [],
  List<FxParty> parties = const [],
}) {
  return SharePlus.instance.share(ShareParams(
    text: formatOpeningBalanceSummary(
      batch: batch,
      lines: lines,
      accounts: accounts,
      parties: parties,
    ),
    subject: 'Opening Balance ${batch.batchNo ?? batch.id.substring(0, 8)}',
  ));
}
