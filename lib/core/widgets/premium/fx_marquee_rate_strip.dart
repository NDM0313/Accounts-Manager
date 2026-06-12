import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/fx_rate.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Stitch home_dashboard scrolling rate ticker.
class FxMarqueeRateStrip extends StatefulWidget {
  const FxMarqueeRateStrip({super.key, required this.rates});

  final List<FxRate> rates;

  @override
  State<FxMarqueeRateStrip> createState() => _FxMarqueeRateStripState();
}

class _FxMarqueeRateStripState extends State<FxMarqueeRateStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rates.isEmpty) return const SizedBox.shrink();
    final fmt = NumberFormat('#,##0.00');
    final items = widget.rates
        .map(
          (r) => _RateChip(
            pair: '${r.currencyCode}/PKR',
            rate: fmt.format(r.referenceRate),
          ),
        )
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: context.fx.surfaceContainer,
        border: Border(bottom: BorderSide(color: context.fx.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(-_controller.value * 600, 0),
              child: child,
            );
          },
          child: Row(
            children: [
              ...items,
              ...items,
            ],
          ),
        ),
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  const _RateChip({required this.pair, required this.rate});

  final String pair;
  final String rate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.stackLg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            pair,
            style: AppTypography.labelCaps(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            rate,
            style: AppTypography.dataMd(context.fx.primary, context: context),
          ),
        ],
      ),
    );
  }
}
