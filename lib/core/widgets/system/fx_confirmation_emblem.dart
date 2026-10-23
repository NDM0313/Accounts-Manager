import 'package:accounts_manager/app/theme/fx_design_tokens.dart';
import 'package:flutter/material.dart';

/// Figma Success pulse (6:486): fade 0–320ms, scale .7→1.08→1
/// at 0/380/600ms, then hold to the end of the 2s timeline.
class FxConfirmationEmblem extends StatefulWidget {
  const FxConfirmationEmblem({super.key});

  @override
  State<FxConfirmationEmblem> createState() => _FxConfirmationEmblemState();
}

class _FxConfirmationEmblemState extends State<FxConfirmationEmblem>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
      controller.value = 1;
    } else if (!controller.isAnimating) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: context.fxAccentSurface(FxAccent.receive),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.check,
        size: 44,
        color: context.fxAccent(FxAccent.receive),
      ),
    ),
    builder: (context, child) {
      final t = controller.value;
      final opacity = const Cubic(
        0,
        0,
        .58,
        1,
      ).transform((t / .16).clamp(0, 1));
      final scale = t < .19
          ? .7 + .38 * const Cubic(0, 0, .58, 1).transform(t / .19)
          : t < .30
          ? 1.08 - .08 * const Cubic(.42, 0, .58, 1).transform((t - .19) / .11)
          : 1.0;
      return Opacity(
        opacity: opacity,
        child: Transform.scale(scale: scale, child: child),
      );
    },
  );
}
