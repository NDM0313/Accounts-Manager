import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Prominent amount entry with a readable currency chip (not a fake dropdown).
class FxAmountEntry extends StatelessWidget {
  const FxAmountEntry({
    super.key,
    required this.controller,
    required this.currencyCode,
    this.enabled = true,
    this.onChanged,
    this.helperText,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String currencyCode;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? helperText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            narrow ? 12 : 16,
            12,
            narrow ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: fx.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: fx.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  autofocus: autofocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: AppTypography.currencyDisplay(
                    color: fx.onSurface,
                    mobile: narrow,
                    context: context,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0.00',
                    hintStyle: AppTypography.currencyDisplay(
                      color: fx.onSurfaceVariant.withValues(alpha: 0.45),
                      mobile: narrow,
                      context: context,
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: 'Currency $currencyCode',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: fx.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: fx.outlineVariant),
                  ),
                  child: Text(
                    currencyCode,
                    style: AppTypography.bodyMd(
                      fx.onSurface,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: AppTypography.bodySm(fx.onSurfaceVariant, context: context),
          ),
        ],
      ],
    );
  }
}
