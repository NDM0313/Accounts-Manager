import 'dart:typed_data';

import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/core/utils/report_export.dart';
import 'package:accounts_manager/core/widgets/demo_workspace_banner.dart';
import 'package:accounts_manager/domain/models/roznamcha.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

String _csvCell(String? value) {
  if (value == null || value.isEmpty) return '';
  final v = value;
  if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

String _formatTypeLabel(RoznamchaLine line) {
  if (line.isInternalTransfer) {
    return '${line.transactionType} (Internal transfer)';
  }
  return line.transactionType;
}

String formatRoznamchaCsv(
  RoznamchaView view, {
  String? companyName,
  String? branchName,
  String? accountScopeLabel,
}) {
  final buf = StringBuffer();
  if (companyName != null && companyName.isNotEmpty) {
    buf.writeln('# Company: ${_csvCell(companyName)}');
  }
  if (branchName != null && branchName.isNotEmpty) {
    buf.writeln('# Branch: ${_csvCell(branchName)}');
  }
  final from = view.from.toIso8601String().split('T').first;
  final to = view.to.toIso8601String().split('T').first;
  buf.writeln('# Period: $from to $to');
  if (accountScopeLabel != null && accountScopeLabel.isNotEmpty) {
    buf.writeln('# Account scope: ${_csvCell(accountScopeLabel)}');
  }
  buf.writeln(
    '# Summary (PKR): Opening=${view.openingTotal}; '
    'Money in=${view.totalIn}; Money out=${view.totalOut}; '
    'Closing=${view.closing}; External in=${view.externalIn}; '
    'External out=${view.externalOut}',
  );
  buf.writeln(
    '# Note: Internal transfers excluded from External in/out totals.',
  );
  buf.writeln(
    'Date,Time,Ref,Account Code,Account Name,Party,Type,Description,'
    'Currency,Money In PKR,Money Out PKR,Balance After PKR,Attachments',
  );
  final timeFmt = DateFormat('HH:mm');
  for (final line in view.lines) {
    buf.writeln(
      [
        line.entryDate.toIso8601String().split('T').first,
        timeFmt.format(line.entryTime.toLocal()),
        _csvCell(line.entryNo),
        _csvCell(line.accountCode),
        _csvCell(line.accountName),
        _csvCell(line.partyName),
        _csvCell(_formatTypeLabel(line)),
        _csvCell(line.description),
        _csvCell(line.currencyCode),
        line.moneyInPkr.toString(),
        line.moneyOutPkr.toString(),
        line.runningBalancePkr.toString(),
        line.attachmentCount.toString(),
      ].join(','),
    );
  }
  return buf.toString();
}

String formatRoznamchaText(
  RoznamchaView view, {
  String? companyName,
  String? branchName,
  String? accountScopeLabel,
}) {
  final df = DateFormat('dd MMM yyyy');
  final fmt = NumberFormat('#,##0.00');
  final buf = StringBuffer('Roznamcha — Cash & Bank Book\n');
  if (companyName != null && companyName.isNotEmpty) {
    buf.writeln('Company: $companyName');
  }
  if (branchName != null && branchName.isNotEmpty) {
    buf.writeln('Branch: $branchName');
  }
  buf.writeln('Period: ${df.format(view.from)} – ${df.format(view.to)}');
  if (accountScopeLabel != null && accountScopeLabel.isNotEmpty) {
    buf.writeln('Account scope: $accountScopeLabel');
  }
  buf.writeln('Currency basis: PKR (ledger amounts)');
  buf.writeln('');
  buf.writeln('Summary');
  buf.writeln('Opening: ${fmt.format(view.openingTotal)}');
  buf.writeln('Money in: ${fmt.format(view.totalIn)}');
  buf.writeln('Money out: ${fmt.format(view.totalOut)}');
  buf.writeln('Closing: ${fmt.format(view.closing)}');
  buf.writeln('External in: ${fmt.format(view.externalIn)}');
  buf.writeln('External out: ${fmt.format(view.externalOut)}');
  buf.writeln(
    'Note: Internal transfers are excluded from External in/out totals.',
  );
  buf.writeln('');
  if (view.lines.isEmpty) {
    buf.writeln('No cash/bank movements in this period.');
  } else {
    buf.writeln('Entries: ${view.lines.length}');
  }
  return buf.toString();
}

Map<String, List<RoznamchaLine>> _linesByCurrency(RoznamchaView view) {
  final map = <String, List<RoznamchaLine>>{};
  for (final line in view.lines) {
    map.putIfAbsent(line.currencyCode, () => []).add(line);
  }
  final keys = map.keys.toList()..sort();
  return {for (final k in keys) k: map[k]!};
}

List<_RoznamchaPdfSection> _pdfSectionsForView(RoznamchaView view) {
  final currencies = _linesByCurrency(view);
  if (currencies.isEmpty) return const [];

  return currencies.entries.map((entry) {
    var inSum = 0.0;
    var outSum = 0.0;
    for (final l in entry.value) {
      inSum += l.moneyInPkr;
      outSum += l.moneyOutPkr;
    }
    return _RoznamchaPdfSection(
      currencyCode: entry.key,
      lines: entry.value,
      moneyInSubtotal: inSum,
      moneyOutSubtotal: outSum,
    );
  }).toList();
}

Future<Uint8List> buildRoznamchaPdf({
  required RoznamchaView view,
  String? companyName,
  String? branchName,
  String? accountScopeLabel,
  bool isDemo = false,
}) {
  return _buildRoznamchaMultiPagePdf(
    view: view,
    companyName: companyName,
    branchName: branchName,
    accountScopeLabel: accountScopeLabel,
    isDemo: isDemo,
    sections: _pdfSectionsForView(view),
  );
}

class _RoznamchaPdfSection {
  const _RoznamchaPdfSection({
    required this.currencyCode,
    required this.lines,
    required this.moneyInSubtotal,
    required this.moneyOutSubtotal,
  });

  final String currencyCode;
  final List<RoznamchaLine> lines;
  final double moneyInSubtotal;
  final double moneyOutSubtotal;
}

String _pdfSubtitle(RoznamchaView view, String? accountScopeLabel) {
  final df = DateFormat('dd MMM yyyy');
  final period = '${df.format(view.from)} – ${df.format(view.to)}';
  final scope = accountScopeLabel ?? 'All cash/bank accounts';
  return '$period · $scope · Amounts in PKR';
}

List<List<String>> _pdfRowsForLines(List<RoznamchaLine> lines) {
  final fmt = NumberFormat('#,##0.00');
  final df = DateFormat('dd MMM yyyy');
  final tf = DateFormat('HH:mm');
  return lines
      .map(
        (line) => [
          '${df.format(line.entryDate)} ${tf.format(line.entryTime.toLocal())}',
          line.entryNo,
          '${line.accountCode} · ${line.accountName}',
          line.partyName ?? '—',
          _formatTypeLabel(line),
          line.description ?? '',
          line.moneyInPkr > 0 ? fmt.format(line.moneyInPkr) : '—',
          line.moneyOutPkr > 0 ? fmt.format(line.moneyOutPkr) : '—',
          fmt.format(line.runningBalancePkr),
          line.attachmentCount > 0 ? '${line.attachmentCount}' : '—',
        ],
      )
      .toList();
}

Future<Uint8List> _buildRoznamchaMultiPagePdf({
  required RoznamchaView view,
  String? companyName,
  String? branchName,
  String? accountScopeLabel,
  required bool isDemo,
  required List<_RoznamchaPdfSection> sections,
}) async {
  final doc = pw.Document();
  final generated = DateFormat('d MMM yyyy HH:mm').format(DateTime.now());
  final orgLine = [?companyName, ?branchName].join(' · ');
  final fmt = NumberFormat('#,##0.00');

  pw.Widget summaryBlock() => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary (PKR — all scoped accounts)',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              pw.Text(
                'Opening: ${fmt.format(view.openingTotal)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Money in: ${fmt.format(view.totalIn)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Money out: ${fmt.format(view.totalOut)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Closing: ${fmt.format(view.closing)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'External in: ${fmt.format(view.externalIn)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'External out: ${fmt.format(view.externalOut)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Internal transfers are excluded from External in/out totals.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 8),
        ],
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (isDemo)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(6),
              color: PdfColors.orange800,
              child: pw.Text(
                'DEMO — SAMPLE DATA, NOT REAL ACCOUNTS',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          if (isDemo) pw.SizedBox(height: 6),
          pw.Text(
            'FX Cash Ledger',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          if (orgLine.isNotEmpty)
            pw.Text(orgLine, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            'Roznamcha',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            _pdfSubtitle(view, accountScopeLabel),
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Generated: $generated',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          summaryBlock(),
          pw.Divider(),
        ],
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              isDemo
                  ? 'DEMO — SAMPLE DATA, NOT REAL ACCOUNTS'
                  : 'Roznamcha — internal cash & bank book.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
      build: (context) {
        if (sections.isEmpty) {
          return [
            pw.Text(
              'No cash/bank movements in this period.',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ];
        }
        final widgets = <pw.Widget>[];
        for (var i = 0; i < sections.length; i++) {
          final section = sections[i];
          if (i > 0) {
            widgets.add(pw.SizedBox(height: 12));
          }
          if (sections.length > 1) {
            widgets.add(
              pw.Text(
                'Account currency: ${section.currencyCode}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));
          }
          widgets.add(
            pw.TableHelper.fromTextArray(
              headers: const [
                'Date/Time',
                'Ref',
                'Account',
                'Party',
                'Type',
                'Description',
                'Money In',
                'Money Out',
                'Balance After',
                'Attachments',
              ],
              data: _pdfRowsForLines(section.lines),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 7,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          );
          if (sections.length > 1) {
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(
              pw.Text(
                'Subtotal (${section.currencyCode} account lines, PKR amounts): '
                'Money in ${fmt.format(section.moneyInSubtotal)} · '
                'Money out ${fmt.format(section.moneyOutSubtotal)}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          }
        }
        return widgets;
      },
    ),
  );

  return Uint8List.fromList(await doc.save());
}

Future<void> exportRoznamchaReport(
  BuildContext context, {
  required RoznamchaView view,
  String? companyName,
  String? branchName,
  String? accountScopeLabel,
  bool isDemo = false,
}) async {
  if (view.lines.isEmpty && view.openingTotal == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No Roznamcha data to export.')),
    );
    return;
  }

  final fmt = NumberFormat('#,##0.00');
  final fromLabel = view.from.toIso8601String().split('T').first;
  final toLabel = view.to.toIso8601String().split('T').first;

  final csv = withDemoExportBanner(
    formatRoznamchaCsv(
      view,
      companyName: companyName,
      branchName: branchName,
      accountScopeLabel: accountScopeLabel,
    ),
    isDemo: isDemo,
  );
  final text = formatRoznamchaText(
    view,
    companyName: companyName,
    branchName: branchName,
    accountScopeLabel: accountScopeLabel,
  );
  final pdf = await buildRoznamchaPdf(
    view: view,
    companyName: companyName,
    branchName: branchName,
    accountScopeLabel: accountScopeLabel,
    isDemo: isDemo,
  );

  if (!context.mounted) return;

  await showFxExportSheet(
    context,
    document: FxExportDocument(
      title: 'Roznamcha $fromLabel → $toLabel',
      textBody: isDemo ? '${DemoWorkspaceBanner.label}\n\n$text' : text,
      csvBody: csv,
      pdfBytes: pdf,
      subject: 'Roznamcha $fromLabel to $toLabel',
      companyName: companyName,
      branchName: branchName,
    ),
    summaryLines: [
      ('Opening', fmt.format(view.openingTotal)),
      ('Money in', fmt.format(view.totalIn)),
      ('Money out', fmt.format(view.totalOut)),
      ('Closing', fmt.format(view.closing)),
      ('External in', fmt.format(view.externalIn)),
      ('External out', fmt.format(view.externalOut)),
    ],
  );
}
