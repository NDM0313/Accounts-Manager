import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_app_bar.dart';
import 'package:flutter/material.dart';

/// Standard child-route header: Back + title + optional Home + actions.
class FxPageHeader {
  FxPageHeader._();

  static PreferredSizeWidget appBar({
    required BuildContext context,
    required Widget title,
    String? fallbackRoute,
    List<Widget>? actions,
    bool showHome = true,
    Color? backgroundColor,
  }) {
    return FxAppBar.child(
      context: context,
      title: title,
      fallbackRoute: fallbackRoute,
      actions: actions,
      showHome: showHome,
      backgroundColor: backgroundColor,
    );
  }
}

/// In-body title block for compact headers under the app bar.
class FxPageTitleBlock extends StatelessWidget {
  const FxPageTitleBlock({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.headlineSm(
                  context.fx.onSurface,
                  context: context,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
