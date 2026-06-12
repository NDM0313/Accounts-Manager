import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Document summary card per share_secure_link_configuration mock.
class FxStitchSecureShareSummaryCard extends StatelessWidget {
  const FxStitchSecureShareSummaryCard({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return FxStitchCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.fx.primaryContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Icon(
              Icons.description,
              color: context.fx.onPrimaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.headlineSm(
                    context.fx.primary,
                    context: context,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.bodySm(
                      context.fx.outline,
                      context: context,
                    ).copyWith(
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashed link preview box.
class FxStitchSecureShareLinkPreview extends StatelessWidget {
  const FxStitchSecureShareLinkPreview({
    super.key,
    required this.url,
    this.onCopy,
  });

  final String url;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Generated Link Preview',
          style: AppTypography.headlineSm(
            context.fx.onSurface,
            context: context,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.fx.surfaceContainerLow.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            border: Border.all(
              color: context.fx.outlineVariant,
              width: 2,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm(
                    context.fx.outline,
                    context: context,
                  ).copyWith(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onCopy ??
                    () => Clipboard.setData(ClipboardData(text: url)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.fx.primary,
                  side: BorderSide(color: context.fx.outlineVariant),
                ),
                icon: const Icon(Icons.content_copy, size: 18),
                label: const Text('Copy'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Generate Secure Link CTA with bolt icon.
class FxStitchSecureShareGenerateCta extends StatelessWidget {
  const FxStitchSecureShareGenerateCta({
    super.key,
    required this.onPressed,
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: busy ? null : onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: context.fx.secondary,
              foregroundColor: context.fx.onSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              ),
              elevation: 4,
            ),
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.bolt),
            label: const Text('Generate Secure Link'),
          ),
        ),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(
            text: 'All shared links are logged in the ',
            style: AppTypography.bodySm(
              context.fx.outline,
              context: context,
            ),
            children: [
              TextSpan(
                text: 'Audit Ledger',
                style: AppTypography.bodySm(
                  context.fx.secondary,
                  context: context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
