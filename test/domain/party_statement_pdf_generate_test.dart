import 'dart:io';

import 'package:accounts_manager/core/export/party_statement_pdf.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:accounts_manager/domain/services/party_statement_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate Sara simple+detailed PDFs for visual review', () async {
    const sara = FxParty(
      id: 'sara',
      companyId: 'demo',
      partyType: FxPartyType.customer,
      code: 'DEMO_CLI_SARA',
      name: 'DEMO Client Sara',
      isActive: true,
      phoneDisplay: '+92 300 0000000',
      email: 'sara.demo@example.com',
    );

    FxTransactionLine ar(String id, double d, double c) => FxTransactionLine(
      id: id,
      lineNo: 1,
      accountId: 'ar',
      accountCode: '1190',
      currencyCode: 'PKR',
      foreignAmount: d > 0 ? d : c,
      rateUsed: 1,
      debitPkr: d,
      creditPkr: c,
    );

    final view = PartyStatementBuilder.build(
      party: sara,
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 22),
      openingBalancePkr: 0,
      isInternalView: false,
      company: const PartyStatementCompanyMeta(
        companyName: 'FX DEMO — SAMPLE DATA',
        branchName: 'Demo Branch',
        isDemo: true,
      ),
      attachmentCountsByTx: const {'t3': 2},
      transactions: [
        FxTransaction(
          id: 't1',
          transactionType: FxTransactionType.settlementReceive,
          status: 'posted',
          transactionNo: '20261021-00008',
          transactionDate: DateTime(2026, 10, 21),
          currencyCode: 'PKR',
          totalForeignAmount: 77000,
          rateUsed: 1,
          totalBaseAmountPkr: 77000,
          description: 'DEMO_SEED_V1',
          lines: [ar('l1', 0, 77000)],
        ),
        FxTransaction(
          id: 't2',
          transactionType: FxTransactionType.currencySell,
          status: 'posted',
          transactionNo: '20261021-00009',
          transactionDate: DateTime(2026, 10, 21),
          currencyCode: 'AED',
          totalForeignAmount: 1000,
          rateUsed: 77,
          totalBaseAmountPkr: 77000,
          description: 'DEMO_SEED_V1 full',
          lines: [ar('l2', 77000, 0)],
        ),
        FxTransaction(
          id: 't3',
          transactionType: FxTransactionType.currencySell,
          status: 'posted',
          transactionNo: '20261022-00003',
          transactionDate: DateTime(2026, 10, 22),
          currencyCode: 'CNY',
          totalForeignAmount: 15000,
          rateUsed: 43,
          totalBaseAmountPkr: 645000,
          description: 'testt',
          dealNo: 'DL-20261021-0007',
          lines: [ar('l3', 645000, 0)],
        ),
      ],
    );

    final outDir = Directory('tmp/statement_pdf_samples');
    await outDir.create(recursive: true);

    for (final format in PartyStatementFormat.values) {
      final bytes = await buildPartyStatementPdf(
        view: view,
        format: format,
        audience: PartyStatementAudience.external,
      );
      expect(bytes.length, greaterThan(1000));
      final file = File('${outDir.path}/sara_${format.name}_external.pdf');
      await file.writeAsBytes(bytes);
      // Embedded TTF may not leave plain ASCII of body text in the stream.
      expect(bytes[0], 0x25); // %PDF
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x44);
      expect(bytes[3], 0x46);
    }
  });
}
