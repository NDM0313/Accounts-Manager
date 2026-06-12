import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_status_badge.dart';
import 'package:flutter/material.dart';

enum PartyHeroMode { customer, agent }

/// Stitch customer/agent statement hero header.
class FxPartyHeroCard extends StatelessWidget {
  const FxPartyHeroCard({
    super.key,
    required this.name,
    required this.balanceLabel,
    required this.balanceValue,
    required this.balanceSuffix,
    this.mode = PartyHeroMode.customer,
    this.badgeLabel,
    this.statusLabel = 'Active',
    this.subtitle,
  });

  final String name;
  final String balanceLabel;
  final String balanceValue;
  final String balanceSuffix;
  final PartyHeroMode mode;
  final String? badgeLabel;
  final String statusLabel;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackLg),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -16,
            right: -16,
            child: Icon(
              mode == PartyHeroMode.agent
                  ? Icons.handshake_outlined
                  : Icons.account_balance_outlined,
              size: 96,
              color: context.fx.primary.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTypography.headlineMd(
                  context.fx.primary,
                  context: context,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (badgeLabel != null)
                    FxStatusBadge(
                      label: badgeLabel!,
                      tone: FxStatusTone.completed,
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: context.fx.tertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: AppTypography.bodySm(
                          context.fx.onSurfaceVariant,
                          context: context,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      balanceLabel.toUpperCase(),
                      style: AppTypography.labelCaps(
                        context.fx.onSurfaceVariant,
                        context: context,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: balanceValue,
                            style: AppTypography.currencyDisplay(
                              color: context.fx.secondary,
                              context: context,
                            ),
                          ),
                          TextSpan(
                            text: ' $balanceSuffix',
                            style: AppTypography.bodyLg(
                              context.fx.onSurfaceVariant,
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
