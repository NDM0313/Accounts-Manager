import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/core/export/party_statement_pdf.dart';
import 'package:accounts_manager/domain/models/party_statement.dart';
import 'package:accounts_manager/domain/services/party_statement_builder.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

/// Choose Simple/Detailed + External/Internal, then preview / PDF / print.
Future<void> showPartyStatementExportSheet(
  BuildContext context, {
  required PartyStatementView view,
}) async {
  var format = PartyStatementFormat.simple;
  var audience = view.isInternalView
      ? PartyStatementAudience.internal
      : PartyStatementAudience.external;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final fx = ctx.fx;
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.paddingOf(ctx).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Export statement',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${view.party.name} · '
                  '${DateFormat('dd MMM yyyy').format(view.from)} – '
                  '${DateFormat('dd MMM yyyy').format(view.to)}',
                  style: TextStyle(color: fx.onSurfaceVariant, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(
                  'Format',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: fx.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<PartyStatementFormat>(
                  segments: const [
                    ButtonSegment(
                      value: PartyStatementFormat.simple,
                      label: Text('Simple'),
                      icon: Icon(Icons.view_agenda_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: PartyStatementFormat.detailed,
                      label: Text('Detailed'),
                      icon: Icon(Icons.notes_outlined, size: 16),
                    ),
                  ],
                  selected: {format},
                  onSelectionChanged: (s) => setLocal(() => format = s.first),
                ),
                const SizedBox(height: 16),
                Text(
                  'Audience',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: fx.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<PartyStatementAudience>(
                  segments: const [
                    ButtonSegment(
                      value: PartyStatementAudience.external,
                      label: Text('External'),
                      icon: Icon(Icons.public_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: PartyStatementAudience.internal,
                      label: Text('Internal'),
                      icon: Icon(Icons.lock_outline, size: 16),
                    ),
                  ],
                  selected: {audience},
                  onSelectionChanged: (s) => setLocal(() => audience = s.first),
                ),
                const SizedBox(height: 8),
                Text(
                  audience == PartyStatementAudience.external
                      ? 'External copy hides internal seed notes and cost markup.'
                      : 'Internal copy may include extra operational detail.',
                  style: TextStyle(fontSize: 11, color: fx.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () async {
                    final pdf = await buildPartyStatementPdf(
                      view: view,
                      format: format,
                      audience: audience,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await Printing.layoutPdf(
                      onLayout: (_) async => pdf,
                      name:
                          'Statement_${view.party.code}_${format.name}_${audience.name}.pdf',
                    );
                  },
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Preview / Print'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final external =
                        audience == PartyStatementAudience.external;
                    final rebuilt = PartyStatementView(
                      party: view.party,
                      from: view.from,
                      to: view.to,
                      summary: view.summary,
                      lines: view.lines,
                      isInternalView: !external,
                      openingBalancePkr: view.openingBalancePkr,
                      statementCurrency: view.statementCurrency,
                      company: view.company,
                      generatedAt: view.generatedAt,
                      balanceExplanation: view.balanceExplanation,
                      timezoneLabel: view.timezoneLabel,
                    );
                    final pdf = await buildPartyStatementPdf(
                      view: rebuilt,
                      format: format,
                      audience: audience,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    await showFxExportSheet(
                      context,
                      mode: external
                          ? FxExportMode.customerFacing
                          : FxExportMode.internal,
                      document: FxExportDocument(
                        title: 'Statement — ${view.party.name}',
                        textBody: PartyStatementBuilder.formatShareText(
                          rebuilt,
                          internal: !external,
                        ),
                        csvBody: PartyStatementBuilder.formatShareCsv(rebuilt),
                        pdfBytes: pdf,
                        subject: 'Statement of Account — ${view.party.name}',
                        companyName: view.company?.companyName,
                        branchName: view.company?.branchName,
                      ),
                    );
                  },
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('Download / Share'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
