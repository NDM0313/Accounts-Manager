import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:flutter/material.dart';

/// Financial Intelligence hero + search per `reports_hub/code.html`.
class FxStitchReportsHero extends StatelessWidget {
  const FxStitchReportsHero({
    super.key,
    required this.searchController,
    this.onSearchChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return FxStitchCard(
      color: context.fx.surfaceContainerLow,
      padding: const EdgeInsets.all(20),
      child: isWide
          ? Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Financial Intelligence',
                        style: AppTypography.headlineMd(
                          context.fx.primary,
                          context: context,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time settlement visibility and performance metrics.',
                        style: AppTypography.bodyMd(
                          context.fx.onSurfaceVariant,
                          context: context,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(width: 280, child: _searchField(context)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Financial Intelligence',
                  style: AppTypography.headlineMd(
                    context.fx.primary,
                    context: context,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real-time settlement visibility and performance metrics.',
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                const SizedBox(height: 12),
                _searchField(context),
              ],
            ),
    );
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search reports...',
        hintStyle: AppTypography.bodySm(
          context.fx.onSurfaceVariant,
          context: context,
        ),
        prefixIcon: Icon(Icons.search, color: context.fx.onSurfaceVariant),
        filled: true,
        fillColor: context.fx.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          borderSide: BorderSide(color: context.fx.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          borderSide: BorderSide(color: context.fx.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          borderSide: BorderSide(color: context.fx.secondary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      style: AppTypography.bodySm(context.fx.onSurface, context: context),
    );
  }
}

/// Report hub grid card with icon tile + chevron.
class FxStitchReportHubCard extends StatelessWidget {
  const FxStitchReportHubCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.iconBackground,
    this.iconColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconBackground;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final bg = iconBackground ?? context.fx.surfaceContainerHigh;
    final fg = iconColor ?? context.fx.secondary;

    return Material(
      color: context.fx.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: context.fx.outlineVariant.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: Icon(icon, color: fg, size: 22),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: context.fx.outline,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTypography.dataLg(
                  context.fx.primary,
                  context: context,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.bodySm(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom analytics promo banner from reports hub mock.
class FxStitchReportsCustomAnalyticsBanner extends StatelessWidget {
  const FxStitchReportsCustomAnalyticsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        color: context.fx.primaryContainer,
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Custom Analytics',
            style: AppTypography.headlineMd(
              context.fx.onPrimary,
              context: context,
            ).copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Can't find the report you need? Generate a custom export or request a tailored visualization.",
            style: AppTypography.bodyMd(
              context.fx.onPrimaryContainer,
              context: context,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: context.fx.secondary,
              foregroundColor: context.fx.onSecondary,
              shape: const StadiumBorder(),
            ),
            child: Text(
              'REQUEST CUSTOM REPORT',
              style: AppTypography.labelCaps(
                context.fx.onSecondary,
                context: context,
              ).copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}
