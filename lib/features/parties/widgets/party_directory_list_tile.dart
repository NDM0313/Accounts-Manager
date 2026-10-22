import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/agent_custody.dart';
import 'package:accounts_manager/domain/models/fx_party.dart';
import 'package:accounts_manager/domain/services/agent_custody_labels.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PartyDirectoryListTile extends StatefulWidget {
  const PartyDirectoryListTile({
    super.key,
    required this.party,
    required this.pkrBalanceLabel,
    required this.currencyBalances,
    required this.fmt,
    required this.onOpenLedger,
  });

  final FxParty party;
  final String pkrBalanceLabel;
  final List<PartyCurrencyBalance> currencyBalances;
  final NumberFormat fmt;
  final VoidCallback onOpenLedger;

  @override
  State<PartyDirectoryListTile> createState() => _PartyDirectoryListTileState();
}

class _PartyDirectoryListTileState extends State<PartyDirectoryListTile> {
  bool _fxExpanded = false;

  @override
  Widget build(BuildContext context) {
    final hasFx = widget.currencyBalances.isNotEmpty;

    return Material(
      color: context.fx.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            onTap: widget.onOpenLedger,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.party.name,
                          style: AppTypography.bodyMd(
                            context.fx.onSurface,
                            context: context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.party.code} · ${widget.party.partyType.label}'
                          '${widget.party.primaryPhone.isNotEmpty ? ' · ${widget.party.primaryPhone}' : ''}'
                          '${widget.party.isActive ? '' : ' · Inactive'}',
                          style: AppTypography.bodyMd(
                            context.fx.onSurfaceVariant,
                            context: context,
                          ).copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        widget.pkrBalanceLabel,
                        textAlign: TextAlign.end,
                        style: AppTypography.dataMd(
                          context.fx.onSurface,
                          context: context,
                        ).copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                  if (hasFx)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: _fxExpanded ? 'Hide FX balances' : 'Show FX balances',
                      onPressed: () =>
                          setState(() => _fxExpanded = !_fxExpanded),
                      icon: Icon(
                        _fxExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: context.fx.outline,
                      ),
                    )
                  else
                    Icon(Icons.chevron_right, color: context.fx.outline),
                ],
              ),
            ),
          ),
          if (hasFx && _fxExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    'Foreign control (each currency separate — not summed)',
                    style: AppTypography.bodyMd(
                      context.fx.onSurfaceVariant,
                      context: context,
                    ).copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 6),
                  for (final row in widget.currencyBalances)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        AgentCustodyLabels.partyForeignNetLabel(
                          currencyCode: row.currencyCode,
                          foreignNet: row.foreignNet,
                          formatter: widget.fmt,
                        ),
                        style: AppTypography.dataMd(
                          context.fx.onSurface,
                          context: context,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
