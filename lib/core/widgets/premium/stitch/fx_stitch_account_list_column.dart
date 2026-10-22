import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// General ledger left column — accounts list per Stitch mock.
///
/// When [scrollable] is true, the parent must provide bounded height (e.g.
/// wrap this widget in [Expanded]).
class FxStitchAccountListColumn extends StatelessWidget {
  const FxStitchAccountListColumn({
    super.key,
    required this.accounts,
    required this.selectedCode,
    required this.onSelected,
    this.balances,
    this.scrollable = false,
    this.accountCount,
  });

  final List<FxAccount> accounts;
  final String? selectedCode;
  final ValueChanged<String?> onSelected;
  final Map<String, double>? balances;
  final bool scrollable;
  final int? accountCount;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(symbol: 'PKR ', decimalDigits: 0);
    final count = accountCount ?? accounts.length;
    final header = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accounts',
                style: AppTypography.headlineSm(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
              Text(
                '$count accounts',
                style: AppTypography.bodySm(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => context.push('/accounts/new-cash'),
          child: Text(
            '+ Add New',
            style: AppTypography.bodySm(
              context.fx.secondary,
              context: context,
            ),
          ),
        ),
      ],
    );

    final list = scrollable
        ? ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) =>
                _accountTile(context, accounts[index], fmt),
          )
        : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: accounts.length,
            itemBuilder: (context, index) =>
                _accountTile(context, accounts[index], fmt),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 8),
        if (scrollable) Expanded(child: list) else list,
      ],
    );
  }

  Widget _accountTile(BuildContext context, FxAccount a, NumberFormat fmt) {
    final selected = a.code == selectedCode;
    final bal = balances?[a.code];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: selected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                border: Border(
                  left: BorderSide(color: context.fx.secondary, width: 4),
                ),
              )
            : null,
        child: FxStitchCard(
          onTap: () => onSelected(selected ? null : a.code),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.code,
                      style: AppTypography.labelCaps(
                        selected ? context.fx.secondary : context.fx.outline,
                        context: context,
                      ).copyWith(fontSize: 9),
                    ),
                    Text(
                      a.name,
                      style: AppTypography.bodyMd(
                        context.fx.onSurface,
                        context: context,
                      ).copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (bal != null)
                Text(
                  fmt.format(bal),
                  style: AppTypography.dataMd(
                    context.fx.onSurface,
                    context: context,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
