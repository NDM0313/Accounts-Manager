import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/core/export/report_pdf_builder.dart';
import 'package:accounts_manager/core/utils/report_export.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_converted_amount.dart';
import 'package:accounts_manager/data/repositories/report_repository.dart';
import 'package:accounts_manager/domain/models/account_statement.dart';
import 'package:accounts_manager/domain/services/reporting_currency_converter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> exportTrialBalanceReport(
  BuildContext context, {
  required List<TrialBalanceRow> rows,
  required String dateLabel,
  ReportingCurrencyConverter? converter,
  ReportCurrencyView view = ReportCurrencyView.base,
}) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No trial balance data to export.')),
    );
    return;
  }
  final fmt = NumberFormat('#,##0.00');
  final csv = formatTrialBalanceCsv(rows, converter: converter, view: view);
  final text = _textFromCsv(csv, title: 'Trial Balance as of $dateLabel');
  final pdfRows = rows
      .map(
        (r) => [
          r.accountCode,
          r.accountName,
          fmt.format(r.debitPkr),
          fmt.format(r.creditPkr),
          converter != null
              ? formatReportAmount(
                  pkrAmount: r.netPkr,
                  converter: converter,
                  view: view,
                  fmt: fmt,
                )
              : fmt.format(r.netPkr),
        ],
      )
      .toList();
  final pdf = await buildSimpleReportPdf(
    title: 'Trial Balance',
    subtitle: 'As of $dateLabel',
    headers: const ['Code', 'Account', 'Debit PKR', 'Credit PKR', 'Net'],
    rows: pdfRows,
  );
  if (!context.mounted) return;
  await showFxExportSheet(
    context,
    document: FxExportDocument(
      title: 'Trial Balance $dateLabel',
      textBody: text,
      csvBody: csv,
      pdfBytes: pdf,
      subject: 'FX Ledger Trial Balance $dateLabel',
    ),
  );
}

Future<void> exportBalanceSheetReport(
  BuildContext context, {
  required List<BalanceSheetRow> rows,
  required String dateLabel,
  ReportingCurrencyConverter? converter,
  ReportCurrencyView view = ReportCurrencyView.base,
}) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No balance sheet data to export.')),
    );
    return;
  }
  final fmt = NumberFormat('#,##0.00');
  final csv = formatBalanceSheetCsv(rows, converter: converter, view: view);
  final text = _textFromCsv(csv, title: 'Balance Sheet as of $dateLabel');
  final pdfRows = rows
      .map(
        (r) => [
          r.accountCode,
          r.accountName,
          r.accountType,
          converter != null
              ? formatReportAmount(
                  pkrAmount: r.balancePkr,
                  converter: converter,
                  view: view,
                  fmt: fmt,
                )
              : fmt.format(r.balancePkr),
        ],
      )
      .toList();
  final pdf = await buildSimpleReportPdf(
    title: 'Balance Sheet',
    subtitle: 'As of $dateLabel',
    headers: const ['Code', 'Account', 'Type', 'Balance'],
    rows: pdfRows,
  );
  if (!context.mounted) return;
  await showFxExportSheet(
    context,
    document: FxExportDocument(
      title: 'Balance Sheet $dateLabel',
      textBody: text,
      csvBody: csv,
      pdfBytes: pdf,
      subject: 'FX Ledger Balance Sheet $dateLabel',
    ),
  );
}

Future<void> exportProfitLossReport(
  BuildContext context, {
  required List<ProfitLossRow> rows,
  required String fromLabel,
  required String toLabel,
  ReportingCurrencyConverter? converter,
  ReportCurrencyView view = ReportCurrencyView.base,
}) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No P&L data to export.')));
    return;
  }
  final fmt = NumberFormat('#,##0.00');
  final csv = formatProfitLossCsv(rows, converter: converter, view: view);
  final text = _textFromCsv(csv, title: 'Profit & Loss $fromLabel → $toLabel');
  final pdfRows = rows
      .map(
        (r) => [
          r.accountCode,
          r.accountName,
          r.accountType,
          converter != null
              ? formatReportAmount(
                  pkrAmount: r.amountPkr,
                  converter: converter,
                  view: view,
                  fmt: fmt,
                )
              : fmt.format(r.amountPkr),
        ],
      )
      .toList();
  final pdf = await buildSimpleReportPdf(
    title: 'Profit & Loss',
    subtitle: '$fromLabel → $toLabel',
    headers: const ['Code', 'Account', 'Type', 'Amount'],
    rows: pdfRows,
  );
  if (!context.mounted) return;
  await showFxExportSheet(
    context,
    document: FxExportDocument(
      title: 'P&L $fromLabel to $toLabel',
      textBody: text,
      csvBody: csv,
      pdfBytes: pdf,
      subject: 'FX Ledger P&L $fromLabel to $toLabel',
    ),
  );
}

Future<void> exportCurrencyPositionReport(
  BuildContext context, {
  required List<CurrencyPositionRow> rows,
  required String dateLabel,
  ReportingCurrencyConverter? converter,
  ReportCurrencyView view = ReportCurrencyView.base,
}) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No currency position data to export.')),
    );
    return;
  }
  final fmt = NumberFormat('#,##0.00');
  final csv = formatCurrencyPositionCsv(rows, converter: converter, view: view);
  final text = _textFromCsv(csv, title: 'Currency Position as of $dateLabel');
  final pdfRows = rows
      .map(
        (r) => [
          r.currencyCode,
          fmt.format(r.foreignBalance),
          converter != null
              ? formatReportAmount(
                  pkrAmount: r.baseEquivalentPkr,
                  converter: converter,
                  view: view,
                  fmt: fmt,
                )
              : fmt.format(r.baseEquivalentPkr),
        ],
      )
      .toList();
  final pdf = await buildSimpleReportPdf(
    title: 'Currency Position',
    subtitle: 'As of $dateLabel',
    headers: const ['Currency', 'Foreign', 'PKR Equivalent'],
    rows: pdfRows,
  );
  if (!context.mounted) return;
  await showFxExportSheet(
    context,
    document: FxExportDocument(
      title: 'Currency Position $dateLabel',
      textBody: text,
      csvBody: csv,
      pdfBytes: pdf,
      subject: 'FX Ledger Currency Position $dateLabel',
    ),
  );
}

Future<void> exportAccountStatementReport(
  BuildContext context, {
  required AccountStatementView view,
  ReportingCurrencyConverter? converter,
  ReportCurrencyView currencyView = ReportCurrencyView.base,
}) async {
  if (view.lines.isEmpty && view.openingBalancePkr == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No statement data to export.')),
    );
    return;
  }
  final fmt = NumberFormat('#,##0.00');
  final fromLabel = view.from.toIso8601String().split('T').first;
  final toLabel = view.to.toIso8601String().split('T').first;
  final csv = formatAccountStatementCsv(
    view,
    converter: converter,
    viewMode: currencyView,
  );
  final text = _textFromCsv(
    csv,
    title: '${view.accountCode} · ${view.accountName} ($fromLabel → $toLabel)',
  );
  final pdfRows = view.lines
      .map(
        (l) => [
          l.entryDate.toIso8601String().split('T').first,
          l.entryNo,
          l.description ?? '',
          fmt.format(l.debitPkr),
          fmt.format(l.creditPkr),
          fmt.format(l.runningBalancePkr),
        ],
      )
      .toList();
  final pdf = await buildStatementPdf(
    title: 'Account Statement',
    partyName: '${view.accountCode} · ${view.accountName}',
    periodLabel: '$fromLabel → $toLabel',
    displayCurrency: converter?.displayCurrencyCode ?? 'PKR',
    lineRows: pdfRows,
    totalDebit: view.lines
        .fold<double>(0, (s, l) => s + l.debitPkr)
        .toStringAsFixed(2),
    totalCredit: view.lines
        .fold<double>(0, (s, l) => s + l.creditPkr)
        .toStringAsFixed(2),
    closingBalance: view.closingBalancePkr.toStringAsFixed(2),
  );
  if (!context.mounted) return;
  await showFxExportSheet(
    context,
    document: FxExportDocument(
      title: 'Account Statement — ${view.accountCode}',
      textBody: text,
      csvBody: csv,
      pdfBytes: pdf,
      subject: 'Account Statement ${view.accountCode}',
    ),
  );
}

Future<void> exportDailyClosingReport(
  BuildContext context, {
  required List<ClosingPreviewRow> rows,
  required String dateLabel,
}) async {
  if (rows.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No closing data to export.')));
    return;
  }
  final fmt = NumberFormat('#,##0.00');
  final csv = formatDailyClosingCsv(rows);
  final buf = StringBuffer('Daily Closing Report — $dateLabel\n\n');
  for (final r in rows) {
    buf.writeln(
      '${r.accountCode} · ${r.accountName} (${r.currencyCode}): ${fmt.format(r.systemBalance)}',
    );
  }
  final pdfRows = rows
      .map(
        (r) => [
          r.accountCode,
          r.accountName,
          r.currencyCode,
          fmt.format(r.systemBalance),
        ],
      )
      .toList();
  final pdf = await buildSimpleReportPdf(
    title: 'Daily Closing',
    subtitle: dateLabel,
    headers: const ['Code', 'Account', 'Currency', 'Closing Balance'],
    rows: pdfRows,
  );
  if (!context.mounted) return;
  await showFxExportSheet(
    context,
    document: FxExportDocument(
      title: 'Daily Closing $dateLabel',
      textBody: buf.toString(),
      csvBody: csv,
      pdfBytes: pdf,
      subject: 'Daily Closing $dateLabel',
    ),
  );
}

String _textFromCsv(String csv, {required String title}) {
  return '$title\n\n$csv';
}
