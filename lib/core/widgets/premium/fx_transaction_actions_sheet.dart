import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/fx_transaction.dart';
import 'package:flutter/material.dart';

enum FxTransactionUiAction {
  viewDetails,
  editDraft,
  editReferenceNotes,
  correctEntry,
  voidReverse,
  deleteDraft,
  viewAudit,
}

class FxTransactionActionAvailability {
  const FxTransactionActionAvailability({
    required this.action,
    required this.enabled,
    this.blockedReason,
  });

  final FxTransactionUiAction action;
  final bool enabled;
  final String? blockedReason;

  String get label => switch (action) {
        FxTransactionUiAction.viewDetails => 'View details',
        FxTransactionUiAction.editDraft => 'Edit draft',
        FxTransactionUiAction.editReferenceNotes => 'Edit reference/notes',
        FxTransactionUiAction.correctEntry => 'Correct entry',
        FxTransactionUiAction.voidReverse => 'Void/reverse',
        FxTransactionUiAction.deleteDraft => 'Delete draft',
        FxTransactionUiAction.viewAudit => 'View audit history',
      };

  IconData get icon => switch (action) {
        FxTransactionUiAction.viewDetails => Icons.visibility_outlined,
        FxTransactionUiAction.editDraft => Icons.edit_outlined,
        FxTransactionUiAction.editReferenceNotes => Icons.notes_outlined,
        FxTransactionUiAction.correctEntry => Icons.sync_alt,
        FxTransactionUiAction.voidReverse => Icons.undo,
        FxTransactionUiAction.deleteDraft => Icons.delete_outline,
        FxTransactionUiAction.viewAudit => Icons.history,
      };
}

/// Builds the action matrix for a transaction (UI layer; RPC still enforces).
List<FxTransactionActionAvailability> fxTransactionActionsFor({
  required FxTransaction tx,
  required bool dayClosed,
  bool isOpeningBalance = false,
}) {
  if (tx.isVoided) {
    return [
      const FxTransactionActionAvailability(
        action: FxTransactionUiAction.viewDetails,
        enabled: true,
      ),
      const FxTransactionActionAvailability(
        action: FxTransactionUiAction.viewAudit,
        enabled: true,
      ),
    ];
  }

  if (tx.isDraft) {
    return [
      const FxTransactionActionAvailability(
        action: FxTransactionUiAction.viewDetails,
        enabled: true,
      ),
      FxTransactionActionAvailability(
        action: FxTransactionUiAction.editDraft,
        enabled: !dayClosed,
        blockedReason: dayClosed
            ? 'Day is closed. Draft edits require an open period.'
            : null,
      ),
      FxTransactionActionAvailability(
        action: FxTransactionUiAction.deleteDraft,
        enabled: !dayClosed,
        blockedReason: dayClosed
            ? 'Day is closed. Draft delete is blocked.'
            : null,
      ),
      const FxTransactionActionAvailability(
        action: FxTransactionUiAction.viewAudit,
        enabled: true,
      ),
    ];
  }

  // Posted
  final openingBlock = isOpeningBalance ||
      tx.transactionType == FxTransactionType.openingBalance;
  return [
    const FxTransactionActionAvailability(
      action: FxTransactionUiAction.viewDetails,
      enabled: true,
    ),
    FxTransactionActionAvailability(
      action: FxTransactionUiAction.editReferenceNotes,
      enabled: !dayClosed && !openingBlock,
      blockedReason: dayClosed
          ? 'Day is closed. Metadata edits require admin/open period.'
          : openingBlock
              ? 'Opening balances use the opening-batch correction flow, not ordinary edit.'
              : null,
    ),
    FxTransactionActionAvailability(
      action: FxTransactionUiAction.correctEntry,
      enabled: !dayClosed && !openingBlock,
      blockedReason: dayClosed
          ? 'Day is closed. Correction (repost) is blocked.'
          : openingBlock
              ? 'Opening balances cannot use ordinary Correct entry — void the OB batch instead.'
              : null,
    ),
    FxTransactionActionAvailability(
      action: FxTransactionUiAction.voidReverse,
      enabled: !dayClosed,
      blockedReason: dayClosed
          ? 'Day is closed. Void/reverse requires admin approval policy (not bypassed).'
          : null,
    ),
    const FxTransactionActionAvailability(
      action: FxTransactionUiAction.viewAudit,
      enabled: true,
    ),
  ];
}

Future<FxTransactionUiAction?> showFxTransactionActionsSheet(
  BuildContext context, {
  required FxTransaction tx,
  required bool dayClosed,
}) {
  final items = fxTransactionActionsFor(tx: tx, dayClosed: dayClosed);
  return showModalBottomSheet<FxTransactionUiAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Transaction actions',
                style: AppTypography.headlineSm(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
            ),
            for (final item in items)
              ListTile(
                leading: Icon(
                  item.icon,
                  color: item.enabled
                      ? context.fx.primary
                      : context.fx.onSurfaceVariant,
                ),
                title: Text(item.label),
                subtitle: item.blockedReason != null
                    ? Text(item.blockedReason!)
                    : null,
                enabled: item.enabled,
                onTap: item.enabled
                    ? () => Navigator.pop(ctx, item.action)
                    : () {
                        final reason = item.blockedReason;
                        if (reason != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(reason)),
                          );
                        }
                      },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
