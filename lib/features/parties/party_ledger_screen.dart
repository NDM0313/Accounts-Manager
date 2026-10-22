import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_statement_bottom_bar.dart';
import 'package:accounts_manager/core/widgets/system/system.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/parties/party_statement_export_sheet.dart';
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
      appBar: FxPageHeader.appBar(
        context: context,
        fallbackRoute: isCustomer ? '/parties' : '/parties/agents',
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Export statement',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => _exportStatement(context, ref),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(partyStatementProvider(partyId));
              ref.invalidate(partyDealOpenItemsProvider(partyId));
            },
          ),
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
              onExportPdf: () => _exportStatement(context, ref),
            )
          : null,
      body: partyAsync.when(
        loading: () => const FxLoadingState(),
        error: (e, _) => FxErrorState(message: 'Error: $e'),
        data: (party) {
          if (party == null) {
            return const FxEmptyState(message: 'Party not found.');
          }
          if (party.partyType == FxPartyType.customer) {
            return CustomerLedgerStitchView(
              partyId: partyId,
              party: party,
              statementAsync: statementAsync,
              fmt: fmt,
              onExport: () => _exportStatement(context, ref),
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

  Future<void> _exportStatement(BuildContext context, WidgetRef ref) async {
    final view = ref
        .read(partyStatementProvider(partyId))
        .whenOrNull(data: (v) => v);
    if (view == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No statement data to share.')),
      );
      return;
    }
    await showPartyStatementExportSheet(context, view: view);
  }
}
