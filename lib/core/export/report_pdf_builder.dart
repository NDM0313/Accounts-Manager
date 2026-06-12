import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:typed_data';

Future<Uint8List> buildSimpleReportPdf({
  required String title,
  required String subtitle,
  required List<List<String>> rows,
  required List<String> headers,
  String? footer,
  String? companyName,
  String? branchName,
}) async {
  final doc = pw.Document();
  final generated = DateFormat('d MMM yyyy HH:mm').format(DateTime.now());
  final orgLine = [?companyName, ?branchName].join(' · ');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'FX Cash Ledger',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          if (orgLine.isNotEmpty)
            pw.Text(orgLine, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            'Generated: $generated',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
        ],
      ),
      footer: (context) => pw.Text(
        footer ?? 'Internal ledger statement — for accounting use.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

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
  return buildSimpleReportPdf(
    title: title,
    subtitle:
        '$partyName · $periodLabel · Display: $displayCurrency${internal ? '' : ' (customer copy)'}',
    headers: const [
      'Date',
      'Ref',
      'Type',
      'Currency',
      'Debit',
      'Credit',
      'Balance',
    ],
    rows: lineRows,
    footer: internal
        ? 'Internal ledger statement'
        : 'Customer statement — internal cost and profit omitted',
  );
}

Future<Uint8List> buildReceiptPdf({
  required String receiptText,
  required String title,
}) async {
  final lines = receiptText.split('\n').map((l) => [l]).toList();
  return buildSimpleReportPdf(
    title: title,
    subtitle: 'Transaction receipt',
    headers: const ['Detail'],
    rows: lines,
    footer: 'FX Cash Ledger — retain for your records',
  );
}

Future<Uint8List> buildDealStatementPdf({
  required String dealNo,
  required String customerName,
  required String status,
  required List<String> bodyLines,
  bool internal = true,
}) async {
  final rows = bodyLines.map((l) => [l]).toList();
  return buildSimpleReportPdf(
    title: 'Deal Statement — $dealNo',
    subtitle: '$customerName · $status${internal ? '' : ' · Customer copy'}',
    headers: const ['Detail'],
    rows: rows,
    footer: internal ? 'Internal deal summary' : 'Customer deal summary',
  );
}
