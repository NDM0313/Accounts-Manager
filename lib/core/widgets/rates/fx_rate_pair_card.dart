import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/utils/rate_source_labels.dart';

import 'package:accounts_manager/app/theme/app_typography.dart';

import 'package:accounts_manager/core/config/feature_flags.dart';

import 'package:accounts_manager/domain/models/rate_pair_quote.dart';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';



/// Compact card for a currency pair on dashboard / rate board.

class FxRatePairCard extends StatelessWidget {

  const FxRatePairCard({

    super.key,

    required this.pair,

    this.onTap,

    this.compact = false,

    this.showActions = false,

  });



  final RateBoardPair pair;

  final VoidCallback? onTap;

  final bool compact;

  final bool showActions;



  @override

  Widget build(BuildContext context) {

    final fmt = NumberFormat('#,##0.####');

    final fx = context.fx;

    final width = compact ? 160.0 : 180.0;



    return Material(

      color: fx.surfaceContainerLow,

      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),

        child: Container(

          width: width,

          padding: const EdgeInsets.all(12),

          decoration: BoxDecoration(

            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),

            border: Border.all(

              color: pair.isStale ? Colors.orange.withValues(alpha: 0.5) : fx.outlineVariant,

            ),

          ),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisSize: MainAxisSize.min,

            children: [

              Row(

                children: [

                  Expanded(

                    child: Text(

                      pair.pairLabel,

                      style: AppTypography.labelCaps(fx.onSurface, context: context),

                      overflow: TextOverflow.ellipsis,

                    ),

                  ),

                  if (showActions) _RateCardMenu(pair: pair),

                  if (pair.isStale)

                    Icon(Icons.schedule, size: 14, color: Colors.orange.shade700),

                  if (pair.isDerived)

                    Padding(

                      padding: const EdgeInsets.only(left: 4),

                      child: Icon(Icons.link, size: 14, color: fx.onSurfaceVariant),

                    ),

                ],

              ),

              const SizedBox(height: 6),

              Text(

                fmt.format(pair.referenceRate),

                style: AppTypography.headlineMd(fx.tertiary, context: context).copyWith(fontSize: compact ? 16 : 18),

              ),

              if (!compact) ...[

                const SizedBox(height: 4),

                if (pair.buyRate != null)

                  Text('Buy ${fmt.format(pair.buyRate!)}', style: AppTypography.bodyMd(fx.onSurfaceVariant, context: context).copyWith(fontSize: 11)),

                if (pair.sellRate != null)

                  Text('Sell ${fmt.format(pair.sellRate!)}', style: AppTypography.bodyMd(fx.onSurfaceVariant, context: context).copyWith(fontSize: 11)),

              ],

              const SizedBox(height: 4),

              Row(

                children: [

                  _SourceBadge(source: pair.source),

                  const Spacer(),

                  if (pair.effectiveAt != null)

                    Text(

                      _timeLabel(pair.effectiveAt!),

                      style: AppTypography.bodyMd(fx.onSurfaceVariant, context: context).copyWith(fontSize: 10),

                    ),

                ],

              ),

            ],

          ),

        ),

      ),

    );

  }



  String _timeLabel(DateTime at) {

    final local = at.toLocal();

    final now = DateTime.now();

    if (now.difference(local).inHours < 24) {

      return DateFormat.jm().format(local);

    }

    return DateFormat.MMMd().format(local);

  }

}



class _RateCardMenu extends StatelessWidget {

  const _RateCardMenu({required this.pair});



  final RateBoardPair pair;



  @override

  Widget build(BuildContext context) {

    return PopupMenuButton<String>(

      icon: Icon(Icons.more_vert, size: 18, color: context.fx.onSurfaceVariant),

      padding: EdgeInsets.zero,

      itemBuilder: (ctx) {

        if (pair.isDerived) {

          return [

            const PopupMenuItem(value: 'edit_sources', child: Text('Edit source PKR rates')),

            PopupMenuItem(value: 'history_usd', child: Text('USD/PKR history')),

            PopupMenuItem(value: 'history_aed', child: Text('AED/PKR history')),

          ];

        }

        return [

          if (pair.rateId != null)

            const PopupMenuItem(value: 'edit', child: Text('Edit rate')),

          PopupMenuItem(value: 'history', child: Text('View history')),

          if (pair.rateId != null)

            const PopupMenuItem(value: 'duplicate', child: Text('Duplicate as new rate')),

          PopupMenuItem(

            enabled: FeatureFlags.rateDeactivateEnabled,

            value: 'deactivate',

            child: Tooltip(

              message: FeatureFlags.rateDeactivateEnabled ? '' : 'Rate deactivate unavailable',

              child: const Text('Deactivate'),

            ),

          ),

        ];

      },

      onSelected: (action) {

        switch (action) {

          case 'edit':

            if (pair.rateId != null) context.push('/rates/edit/${pair.rateId}');

          case 'history':

            context.push('/rates/history/${pair.fromCurrency}');

          case 'duplicate':

            if (pair.rateId != null) context.push('/rates/new?from=${pair.rateId}');

          case 'edit_sources':

            context.push('/rates');

          case 'history_usd':

            context.push('/rates/history/USD');

          case 'history_aed':

            context.push('/rates/history/AED');

          case 'deactivate':

            break;

        }

      },

    );

  }

}



class _SourceBadge extends StatelessWidget {

  const _SourceBadge({required this.source});



  final String source;



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

      decoration: BoxDecoration(

        color: context.fx.surfaceContainerHigh,

        borderRadius: BorderRadius.circular(4),

      ),

      child: Text(

        RateSourceLabels.label(source),

        style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 9),

      ),

    );

  }

}

