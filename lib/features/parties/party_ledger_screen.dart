import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/core/export/report_pdf_builder.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_statement_bottom_bar.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/domain/services/party_statement_builder.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/parties/widgets/agent_ledger_stitch_view.dart';
import 'package:accounts_manager/features/parties/widgets/customer_ledger_stitch_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class PartyLedgerScreen extends ConsumerWidget {
  const PartyLedgerScreen({super.key, required this.partyId});

  final String partyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partyAsync = ref.watch(partyDetailProvider(partyId));
    final statementAsync = ref.watch(partyStatementProvider(partyId));
    final fmt = NumberFormat('#,##0.00');
    final isCustomer = partyAsync.value?.partyType == FxPartyType.customer;
    final title = isCustomer ? 'Customer Ledger' : 'Agent Ledger';

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.background,
        title: Text(title),
        actions: [
          if (isCustomer)
            IconButton(
              icon: const Icon(Icons.ios_share_outlined),
              onPressed: () => _exportStatement(
                context,
                ref,
                customerCopy: false,
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(partyStatementProvider(partyId));
                ref.invalidate(partyDealOpenItemsProvider(partyId));
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: context.fx.primaryContainer,
                child: Text(
                  partyAsync.value?.name.isNotEmpty == true
                      ? partyAsync.value!.name[0].toUpperCase()
                      : 'A',
                  style: TextStyle(
                    color: context.fx.onPrimaryContainer,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: isCustomer
          ? FxStitchStatementBottomBar(
              onReceivePayment: () => context.push(
                '/transactions/receive-payment?partyId=$partyId',
              ),
              onSendRefund: () => context.push(
                '/transactions/new?type=${FxTransactionType.settlementSend.dbValue}&partyId=$partyId',
              ),
              onExportPdf: () => _exportStatement(
                context,
                ref,
                customerCopy: true,
              ),
            )
          : null,
      body: partyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (party) {
          if (party == null) {
            return const Center(child: Text('Party not found.'));
          }
          if (party.partyType == FxPartyType.customer) {
            return CustomerLedgerStitchView(
              partyId: partyId,
              party: party,
              statementAsync: statementAsync,
              fmt: fmt,
              onExport: () => _exportStatement(
                context,
                ref,
                customerCopy: false,
              ),
            );
          }
          return AgentLedgerStitchView(
            partyId: partyId,
            party: party,
            statementAsync: statementAsync,
            fmt: fmt,
          );
        },
      ),
    );
  }

  Future<void> _exportStatement(
    BuildContext context,
    WidgetRef ref, {
    required bool customerCopy,
  }) async {
    final view = ref
        .read(partyStatementProvider(partyId))
        .whenOrNull(data: (v) => v);
    if (view == null || view.lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No statement data to share.')),
      );
      return;
    }
    final internal = !customerCopy;
    final text = PartyStatementBuilder.formatShareText(
      view,
      internal: internal,
    );
    final csv = PartyStatementBuilder.formatShareCsv(view);
    final pdfRows = view.lines
        .map(
          (l) => [
            l.transactionDate.toIso8601String().split('T').first,
            l.transactionNo ?? l.transactionId.substring(0, 8),
            l.transactionType.label,
            l.currencyCode,
            l.debitPkr.toStringAsFixed(2),
            l.creditPkr.toStringAsFixed(2),
            l.runningBalancePkr.toStringAsFixed(2),
          ],
        )
        .toList();
    final pdf = await buildStatementPdf(
      title: 'Party Statement',
      partyName: view.party.name,
      periodLabel:
          '${view.from.toIso8601String().split('T').first} → ${view.to.toIso8601String().split('T').first}',
      displayCurrency: 'PKR',
      lineRows: pdfRows,
      totalDebit: view.summary.totalDebitPkr.toStringAsFixed(2),
      totalCredit: view.summary.totalCreditPkr.toStringAsFixed(2),
      closingBalance: view.summary.netBalancePkr.toStringAsFixed(2),
      internal: internal,
    );
    if (!context.mounted) return;
    await showFxExportSheet(
      context,
      mode: internal ? FxExportMode.internal : FxExportMode.customerFacing,
      document: FxExportDocument(
        title: 'Party Statement — ${view.party.name}',
        textBody: text,
        csvBody: csv,
        pdfBytes: pdf,
        subject: 'Party Statement — ${view.party.name}',
      ),
    );
  }
}
