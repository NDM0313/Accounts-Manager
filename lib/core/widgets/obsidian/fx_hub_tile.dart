import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxHubTile extends StatelessWidget {
  const FxHubTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.compact = true,
    this.iconSize = 36,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final padding = compact ? 12.0 : 20.0;
    final effectiveIconSize = compact ? 36.0 : iconSize;

    return Material(
      color: context.fx.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        side: BorderSide(color: context.fx.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: context.fx.surfaceContainer,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: compact ? _compactLayout(context, effectiveIconSize) : _expandedLayout(context, effectiveIconSize),
        ),
      ),
    );
  }

  Widget _compactLayout(BuildContext context, double size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _iconBox(context, size),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headlineMd(context.fx.onSurface, context: context).copyWith(fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 11, height: 1.2),
        ),
      ],
    );
  }

  Widget _expandedLayout(BuildContext context, double size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iconBox(context, size),
        const Spacer(),
        Text(
          title,
          style: AppTypography.headlineMd(context.fx.onSurface, context: context).copyWith(fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12),
        ),
      ],
    );
  }

  Widget _iconBox(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Icon(icon, size: size * 0.5, color: Theme.of(context).colorScheme.primary),
    );
  }
}
