import 'dart:typed_data';

import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Professional A4 party statement PDF (Simple / Detailed).
Future<Uint8List> buildPartyStatementPdf({
  required PartyStatementView view,
  required PartyStatementFormat format,
  required PartyStatementAudience audience,
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
  final external = audience == PartyStatementAudience.external;
  final generated = view.generatedAt ?? DateTime.now();

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
                    'Statement of Account',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      color: teal,
                    ),
                  ),
                  pw.Text(
                    external ? 'External party copy' : 'Internal copy',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    format == PartyStatementFormat.detailed
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
                  view.party.name,
                  style: pw.TextStyle(font: fontBold, fontSize: 11, color: navy),
                ),
                pw.Text(
                  'Code ${view.party.code} · ${view.party.partyType.label}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                if ((view.party.phoneDisplay ?? view.party.phone)?.isNotEmpty ==
                    true)
                  pw.Text(
                    'Phone: ${view.party.phoneDisplay ?? view.party.phone}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                if (view.party.email != null && view.party.email!.isNotEmpty)
                  pw.Text(
                    'Email: ${view.party.email}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Period: ${df.format(view.from)} – ${df.format(view.to)}'
                  ' · Statement currency: ${view.statementCurrency}'
                  ' · Generated: ${dtf.format(generated)} ${view.timezoneLabel}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _kpi('Opening', mf.format(view.openingBalancePkr), navy, fontBold),
              _kpi('Debits', mf.format(view.summary.totalDebitPkr), navy, fontBold),
              _kpi(
                'Credits',
                mf.format(view.summary.totalCreditPkr),
                navy,
                fontBold,
              ),
              _kpi(
                'Closing',
                mf.format(view.closingBalancePkr),
                teal,
                fontBold,
              ),
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
      final descChildren = <pw.Widget>[
        pw.Text(line.narrative, style: const pw.TextStyle(fontSize: 8)),
      ];
      if (line.attachmentCount > 0) {
        descChildren.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Attachments: ${line.attachmentCount}',
              style: pw.TextStyle(
                fontSize: 7,
                color: teal,
                font: fontMedium,
              ),
            ),
          ),
        );
      }
      if (format == PartyStatementFormat.detailed) {
        for (final d in line.detailBlocks) {
          descChildren.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1),
              child: pw.Text(
                '· $d',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              ),
            ),
          );
        }
      }

      rows.add(
        pw.TableRow(
          decoration: bg == null ? null : pw.BoxDecoration(color: bg),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: pw.Text(
                df.format(line.transactionDate),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: pw.Text(
                line.transactionNo ?? line.transactionId.substring(0, 8),
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: descChildren,
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: amountCell(
                line.debitPkr == 0 ? '—' : mf.format(line.debitPkr),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(4, 5, 4, 5),
              child: amountCell(
                line.creditPkr == 0 ? '—' : mf.format(line.creditPkr),
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
      margin: const pw.EdgeInsets.fromLTRB(42, 36, 42, 42), // ~12–15mm
      header: (context) => headerBlock(),
      footer: (context) => pw.Column(
        children: [
          pw.Divider(color: rule, thickness: 0.6),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  '$company'
                  '${external ? ' · Statement for party records' : ' · Internal accounting use'}',
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ],
      ),
      build: (context) => [
        pw.Table(
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(color: rule, width: 0.4),
            top: pw.BorderSide(color: rule),
            bottom: pw.BorderSide(color: rule),
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(1.6),
            2: const pw.FlexColumnWidth(3.6),
            3: const pw.FlexColumnWidth(1.2),
            4: const pw.FlexColumnWidth(1.2),
            5: const pw.FlexColumnWidth(1.2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: navy),
              children: [
                for (final h in [
                  'Date',
                  'Reference',
                  'Description',
                  'Debit',
                  'Credit',
                  'Balance',
                ])
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 8,
                        color: PdfColors.white,
                      ),
                      textAlign: (h == 'Debit' || h == 'Credit' || h == 'Balance')
                          ? pw.TextAlign.right
                          : pw.TextAlign.left,
                    ),
                  ),
              ],
            ),
            ...dataRows(),
          ],
        ),
        pw.SizedBox(height: 12),
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
                'Period totals',
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: navy),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Opening ${mf.format(view.openingBalancePkr)} + '
                'Debits ${mf.format(view.summary.totalDebitPkr)} − '
                'Credits ${mf.format(view.summary.totalCreditPkr)} = '
                'Closing ${mf.format(view.closingBalancePkr)} ${view.statementCurrency}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                view.balanceExplanation,
                style: pw.TextStyle(fontSize: 8, font: fontMedium, color: teal),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

pw.Widget _kpi(String label, String value, PdfColor color, pw.Font bold) {
  return pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 4),
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD6DEE6)),
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
            style: pw.TextStyle(font: bold, fontSize: 9, color: color),
          ),
        ],
      ),
    ),
  );
}

/// Backward-compatible wrapper used by older call sites.
Future<Uint8List> buildStatementPdf({
  required String title,
  required String partyName,
  required String periodLabel,
  required String displayCurrency,
  required List<List<String>> lineRows,
  required String totalDebit,
  required String totalCredit,
  required String closingBalance,
  bool internal = true,
}) async {
  // Legacy path retained for non-party callers; prefer [buildPartyStatementPdf].
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Text('$partyName · $periodLabel · $displayCurrency'),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const [
            'Date',
            'Ref',
            'Type',
            'Currency',
            'Debit',
            'Credit',
            'Balance',
          ],
          data: lineRows,
        ),
        pw.SizedBox(height: 8),
        pw.Text('Debit $totalDebit · Credit $totalCredit · Closing $closingBalance'),
        pw.Text(internal ? 'Internal copy' : 'External copy'),
      ],
    ),
  );
  return Uint8List.fromList(await doc.save());
}
