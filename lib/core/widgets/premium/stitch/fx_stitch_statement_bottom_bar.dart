import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Customer statement bottom bar — vertical icon actions + Export PDF pill.
class FxStitchStatementBottomBar extends StatelessWidget {
  const FxStitchStatementBottomBar({
    super.key,
    required this.onReceivePayment,
    required this.onSendRefund,
    required this.onExportPdf,
  });

  final VoidCallback onReceivePayment;
  final VoidCallback onSendRefund;
  final VoidCallback onExportPdf;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLowest,
        border: Border(top: BorderSide(color: context.fx.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _VerticalAction(
                  icon: Icons.payments_outlined,
                  label: 'Receive Payment',
                  color: context.fx.secondary,
                  onTap: onReceivePayment,
                ),
              ),
              Expanded(
                child: _VerticalAction(
                  icon: Icons.undo,
                  label: 'Send Refund',
                  color: context.fx.onSurfaceVariant,
                  onTap: onSendRefund,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: context.fx.outlineVariant,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              FilledButton.icon(
                onPressed: onExportPdf,
                style: FilledButton.styleFrom(
                  backgroundColor: context.fx.primary,
                  foregroundColor: context.fx.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                label: Text(
                  'Export PDF',
                  style: AppTypography.bodyMd(
                    context.fx.onPrimary,
                    context: context,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerticalAction extends StatelessWidget {
  const _VerticalAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: AppTypography.labelCaps(color, context: context).copyWith(
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
