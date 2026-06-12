import 'dart:ui';

import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/transaction_menu_entries.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_transaction_menu.dart';
import 'package:flutter/material.dart';

/// Stitch-style grouped new-transaction bottom sheet.
class FxTransactionMenuSheet extends StatelessWidget {
  const FxTransactionMenuSheet({super.key, required this.groups});

  final List<TransactionMenuGroup> groups;

  static Future<void> show(BuildContext context) {
    final groups = buildTransactionMenuGroups();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        final fx = ctx.fx;
        final maxHeight = MediaQuery.sizeOf(ctx).height * 0.88;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: ColoredBox(
                  color: fx.primary.withValues(alpha: 0.4),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: fx.surfaceContainerLowest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border(
                    top: BorderSide(color: fx.outlineVariant),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: fx.primary.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 48,
                        height: 6,
                        decoration: BoxDecoration(
                          color: fx.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Transaction Type',
                              style: AppTypography.headlineMd(
                                fx.primary,
                                context: ctx,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose an action to record in the ledger',
                              style: AppTypography.bodySm(
                                fx.onSurfaceVariant,
                                context: ctx,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: FxStitchTransactionMenuList(groups: groups),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FxStitchTransactionMenuList(groups: groups);
  }
}
