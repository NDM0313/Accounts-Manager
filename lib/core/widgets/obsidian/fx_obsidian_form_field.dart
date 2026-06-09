import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxObsidianFormField extends StatelessWidget {
  const FxObsidianFormField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.maxLines = 1,
    this.readOnly = false,
    this.enabled = true,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.suffix,
    this.accentTertiary = false,
    this.textAlign = TextAlign.start,
    this.style,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final int maxLines;
  final bool readOnly;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final bool accentTertiary;
  final TextAlign textAlign;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final accent = accentTertiary ? context.fx.tertiary : context.fx.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.labelCaps(
            accentTertiary ? context.fx.tertiary : context.fx.onSurfaceVariant, context: context),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          enabled: enabled,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          textAlign: textAlign,
          style: style ?? AppTypography.bodyMd(context.fx.onSurface, context: context),
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: context.fx.surfaceContainerLow,
            suffix: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: BorderSide(
                color: accentTertiary
                    ? context.fx.tertiary.withValues(alpha: 0.3)
                    : context.fx.outlineVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: BorderSide(
                color: accentTertiary
                    ? context.fx.tertiary.withValues(alpha: 0.3)
                    : context.fx.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: BorderSide(color: accent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
