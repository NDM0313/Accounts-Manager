import 'dart:io';

import 'package:accounts_manager/core/export/account_statement_pdf.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/domain/models/account_statement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate multi-page account statement PDFs for visual review', () async {
    final rows = <GeneralLedgerRow>[
      for (var i = 1; i <= 45; i++)
        GeneralLedgerRow(
          entryDate: DateTime(2026, 10, (i % 28) + 1),
          entryNo: '20261024-JE-${i.toString().padLeft(4, '0')}',
          accountCode: '1110',
          accountName: 'Cash PKR',
          description:
              'AM_DEMO fixture line $i with a longer narrative so description '
              'column wraps across the professional statement layout',
          debitPkr: i.isOdd ? 1250.50 + i : 0,
          creditPkr: i.isEven ? 980.25 + i : 0,
          currencyCode: i % 5 == 0 ? 'USD' : 'PKR',
          foreignAmount: i % 5 == 0 ? 10.0 + i : 0,
        ),
    ];

    final view = AccountStatementView.build(
      accountCode: '1110',
      accountName: 'Cash PKR',
      accountType: 'asset',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
      openingBalancePkr: 100000,
      ledgerRows: rows,
      company: const AccountStatementCompanyMeta(
        companyName: 'FX DEMO — SAMPLE DATA',
        branchName: 'Demo Branch',
        isDemo: true,
      ),
      generatedAt: DateTime(2026, 10, 24, 15),
    );

    expect(view.isDebitNormalAccount, isTrue);
    expect(
      view.closingBalancePkr,
      closeTo(
        view.openingBalancePkr + view.periodDebitPkr - view.periodCreditPkr,
        0.01,
      ),
    );

    final simple = await buildAccountStatementPdf(
      view: view,
      format: AccountStatementFormat.simple,
      audience: AccountStatementAudience.internal,
    );
    final detailed = await buildAccountStatementPdf(
      view: view,
      format: AccountStatementFormat.detailed,
      audience: AccountStatementAudience.external,
    );

    expect(simple.length, greaterThan(2000));
    expect(detailed.length, greaterThan(2000));
    expect(simple[0], 0x25); // %PDF
    expect(simple[1], 0x50);

    final outDir = Directory('tmp/account_statement_pdf_review')
      ..createSync(recursive: true);
    final simplePath = '${outDir.path}/account_1110_simple.pdf';
    final detailedPath = '${outDir.path}/account_1110_detailed.pdf';
    File(simplePath).writeAsBytesSync(simple);
    File(detailedPath).writeAsBytesSync(detailed);

    // Render evidence: files exist and start with PDF magic.
    expect(File(simplePath).existsSync(), isTrue);
    expect(File(detailedPath).existsSync(), isTrue);
    final head = File(simplePath).openSync().readSync(5);
    expect(String.fromCharCodes(head), startsWith('%PDF'));
  });
}
