import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/domain/models/fx_account.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// General ledger left column — accounts list per Stitch mock.
class FxStitchAccountListColumn extends StatelessWidget {
  const FxStitchAccountListColumn({
    super.key,
    required this.accounts,
    required this.selectedCode,
    required this.onSelected,
    this.balances,
  });

  final List<FxAccount> accounts;
  final String? selectedCode;
  final ValueChanged<String?> onSelected;
  final Map<String, double>? balances;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.compactCurrency(symbol: 'PKR ', decimalDigits: 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Accounts',
              style: AppTypography.headlineSm(
                context.fx.onSurface,
                context: context,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: Text(
                '+ Add New',
                style: AppTypography.bodySm(
                  context.fx.secondary,
                  context: context,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...accounts.take(12).map((a) {
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
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
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
        }),
      ],
    );
  }
}
