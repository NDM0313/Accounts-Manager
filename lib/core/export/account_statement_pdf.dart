import 'dart:typed_data';

import 'package:accounts_manager/domain/models/account_statement.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Professional A4 account / ledger statement PDF.
///
/// Shares visual language with [buildPartyStatementPdf]: company identity,
/// DEMO banner, KPI strip, Date|Ref|Description|Debit|Credit|Balance table,
/// repeated headers and page numbers.
///
/// Balance convention matches [AccountStatementView.build]:
/// - Debit-normal (asset/expense): closing = opening + debits − credits
/// - Credit-normal (liability/equity/income): closing = opening + credits − debits
Future<Uint8List> buildAccountStatementPdf({
  required AccountStatementView view,
  required AccountStatementFormat format,
  required AccountStatementAudience audience,
}) async {
  final fontRegular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Geist-Regular.ttf'),
  );
  final fontMedium = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Geist-Medium.ttf'),
  );
  final fontBold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Geist-Bold.ttf'),
  );

  final theme = pw.ThemeData.withFont(
    base: fontRegular,
    bold: fontBold,
    italic: fontRegular,
    boldItalic: fontBold,
  );

  final navy = PdfColor.fromInt(0xFF0B1F33);
  final teal = PdfColor.fromInt(0xFF0F766E);
  final rule = PdfColor.fromInt(0xFFD6DEE6);
  final zebra = PdfColor.fromInt(0xFFF5F8FA);

  final df = DateFormat('dd MMM yyyy');
  final dtf = DateFormat('dd MMM yyyy HH:mm');
  final mf = NumberFormat('#,##0.00');

  final company = view.company?.companyName ?? 'FX Cash Ledger';
  final branch = view.company?.branchName;
  final isDemo = view.company?.isDemo ?? false;
  final external = audience == AccountStatementAudience.external;
  final generated = view.generatedAt ?? DateTime.now();
  final typeLabel = view.accountType.isEmpty
      ? 'Account'
      : '${view.accountType[0].toUpperCase()}${view.accountType.substring(1)}';

  final doc = pw.Document(theme: theme);

  pw.Widget amountCell(String text, {bool bold = false}) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: bold ? fontBold : fontRegular,
            fontSize: 8,
            fontFallback: [fontRegular],
          ),
        ),
      );

  pw.Widget kpi(String label, String value, PdfColor color) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 4),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: rule),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label.toUpperCase(),
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                value,
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: color),
              ),
            ],
          ),
        ),
      );

  pw.Widget headerBlock() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (isDemo)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              color: PdfColors.orange800,
              child: pw.Text(
                'DEMO — SAMPLE DATA, NOT REAL ACCOUNTS',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  font: fontBold,
                ),
              ),
            ),
          if (isDemo) pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      company,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 14,
                        color: navy,
                      ),
                    ),
                    if (branch != null && branch.isNotEmpty)
                      pw.Text(
                        branch,
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                          font: fontMedium,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Account statement',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      color: teal,
                    ),
                  ),
                  pw.Text(
                    external ? 'External copy' : 'Internal copy',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    format == AccountStatementFormat.detailed
                        ? 'Detailed format'
                        : 'Simple format',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: rule),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  view.accountName,
                  style: pw.TextStyle(font: fontBold, fontSize: 11, color: navy),
                ),
                pw.Text(
                  'Code ${view.accountCode} · $typeLabel'
                  '${view.isDebitNormalAccount ? ' · debit-normal' : ' · credit-normal'}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Period: ${df.format(view.from)} – ${df.format(view.to)}'
                  ' · Currency: ${view.statementCurrency}'
                  ' · Generated: ${dtf.format(generated)}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              kpi('Opening', mf.format(view.openingBalancePkr), navy),
              kpi('Debits', mf.format(view.periodDebitPkr), navy),
              kpi('Credits', mf.format(view.periodCreditPkr), navy),
              kpi('Closing', mf.format(view.closingBalancePkr), teal),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Amounts in ${view.statementCurrency}',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
                font: fontMedium,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
        ],
      );

  pw.TableRow tableHeader() => pw.TableRow(
        decoration: pw.BoxDecoration(color: navy),
        children: [
          for (final h in ['Date', 'Reference', 'Description', 'Debit', 'Credit', 'Balance'])
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                h,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 7.5,
                  color: PdfColors.white,
                ),
              ),
            ),
        ],
      );

  pw.TableRow openingRow() => pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(df.format(view.from), style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text('—', style: const pw.TextStyle(fontSize: 8)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(
              'Opening balance',
              style: pw.TextStyle(fontSize: 8, font: fontBold),
            ),
          ),
          amountCell('—'),
          amountCell('—'),
          amountCell(mf.format(view.openingBalancePkr), bold: true),
        ],
      );

  List<pw.TableRow> dataRows() {
    final rows = <pw.TableRow>[openingRow()];
    for (var i = 0; i < view.lines.length; i++) {
      final line = view.lines[i];
      final bg = i.isOdd ? zebra : null;
      final desc = <pw.Widget>[
        pw.Text(
          line.description?.trim().isNotEmpty == true
              ? line.description!.trim()
              : line.entryNo,
          style: const pw.TextStyle(fontSize: 8),
        ),
      ];
      if (format == AccountStatementFormat.detailed &&
          line.currencyCode != 'PKR' &&
          line.foreignAmount.abs() > 0.0005) {
        desc.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1),
            child: pw.Text(
              '· ${mf.format(line.foreignAmount.abs())} ${line.currencyCode}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ),
        );
      }
      if (external &&
          (line.description?.toUpperCase().contains('COST') == true ||
              line.description?.toUpperCase().contains('MARGIN') == true)) {
        // Keep recorded narrative; do not invent rates. External still shows
        // posted amounts — internal margin labels stay as-is from source memo.
      }

      rows.add(
        pw.TableRow(
          decoration: bg == null ? null : pw.BoxDecoration(color: bg),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: pw.Text(
                df.format(line.entryDate),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: pw.Text(
                line.entryNo,
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: desc,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: amountCell(
                line.debitPkr.abs() < 0.005 ? '—' : mf.format(line.debitPkr),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: amountCell(
                line.creditPkr.abs() < 0.005 ? '—' : mf.format(line.creditPkr),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: amountCell(mf.format(line.runningBalancePkr), bold: true),
            ),
          ],
        ),
      );
    }
    return rows;
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
      header: (context) {
        if (context.pageNumber == 1) return pw.SizedBox();
        return pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$company · ${view.accountCode}',
                  style: pw.TextStyle(fontSize: 8, font: fontMedium, color: navy),
                ),
                pw.Text(
                  'Account statement (continued)',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: rule, thickness: 0.5),
            pw.SizedBox(height: 6),
          ],
        );
      },
      footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                isDemo ? 'DEMO sample — not for settlement' : 'Confidential',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          ),
      build: (context) => [
            headerBlock(),
            pw.Table(
              border: pw.TableBorder.all(color: rule, width: 0.4),
              columnWidths: {
                0: const pw.FixedColumnWidth(58),
                1: const pw.FixedColumnWidth(62),
                2: const pw.FlexColumnWidth(3.2),
                3: const pw.FixedColumnWidth(58),
                4: const pw.FixedColumnWidth(58),
                5: const pw.FixedColumnWidth(62),
              },
              children: [tableHeader(), ...dataRows()],
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              view.isDebitNormalAccount
                  ? 'Convention: debit-normal — closing ≈ opening + period debits − period credits.'
                  : 'Convention: credit-normal — closing ≈ opening + period credits − period debits.',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}
