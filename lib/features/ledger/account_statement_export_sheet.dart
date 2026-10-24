import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/export/account_statement_pdf.dart';
import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/domain/models/account_statement.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

/// Simple/Detailed + External/Internal, then preview / share for account statements.
Future<void> showAccountStatementExportSheet(
  BuildContext context, {
  required AccountStatementView view,
}) async {
  var format = AccountStatementFormat.simple;
  var audience = AccountStatementAudience.internal;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final fx = ctx.fx;
          final bottom = MediaQuery.paddingOf(ctx).bottom;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Export account statement',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${view.accountCode} · ${view.accountName}\n'
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
                    SegmentedButton<AccountStatementFormat>(
                      segments: const [
                        ButtonSegment(
                          value: AccountStatementFormat.simple,
                          label: Text('Simple'),
                          icon: Icon(Icons.view_agenda_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: AccountStatementFormat.detailed,
                          label: Text('Detailed'),
                          icon: Icon(Icons.notes_outlined, size: 16),
                        ),
                      ],
                      selected: {format},
                      onSelectionChanged: (s) =>
                          setLocal(() => format = s.first),
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
                    SegmentedButton<AccountStatementAudience>(
                      segments: const [
                        ButtonSegment(
                          value: AccountStatementAudience.external,
                          label: Text('External'),
                          icon: Icon(Icons.public_outlined, size: 16),
                        ),
                        ButtonSegment(
                          value: AccountStatementAudience.internal,
                          label: Text('Internal'),
                          icon: Icon(Icons.lock_outline, size: 16),
                        ),
                      ],
                      selected: {audience},
                      onSelectionChanged: (s) =>
                          setLocal(() => audience = s.first),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      audience == AccountStatementAudience.external
                          ? 'External copy is suitable to share outside the team.'
                          : 'Internal copy for accounting use.',
                      style: TextStyle(fontSize: 11, color: fx.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () async {
                        final pdf = await buildAccountStatementPdf(
                          view: view,
                          format: format,
                          audience: audience,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await Printing.layoutPdf(
                          onLayout: (_) async => pdf,
                          name:
                              'Account statement — ${view.accountCode} ${view.accountName}',
                        );
                      },
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Preview / Print statement'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final pdf = await buildAccountStatementPdf(
                          view: view,
                          format: format,
                          audience: audience,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await showFxExportSheet(
                          ctx,
                          document: FxExportDocument(
                            title:
                                'Account statement — ${view.accountCode} · ${view.accountName}',
                            textBody:
                                '${view.accountCode} · ${view.accountName}\n'
                                'Opening ${view.openingBalancePkr.toStringAsFixed(2)} · '
                                'Closing ${view.closingBalancePkr.toStringAsFixed(2)}',
                            pdfBytes: pdf,
                            subject:
                                'Account statement — ${view.accountCode}',
                          ),
                          refLabel:
                              'Account statement — ${view.accountCode} · ${view.accountName}',
                          printActionLabel: 'Print statement',
                          printActionSubtitle: 'System print dialog / PDF preview',
                          omitImageShare: true,
                          omitEmailShare: false,
                          omitCopyLink: true,
                        );
                      },
                      icon: const Icon(Icons.ios_share_outlined),
                      label: const Text('Download / Share PDF'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
