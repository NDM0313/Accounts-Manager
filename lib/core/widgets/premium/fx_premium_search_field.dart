import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxPremiumSearchField extends StatelessWidget {
  const FxPremiumSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Search party or reference…',
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTypography.bodyMd(context.fx.onSurface, context: context),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTypography.bodyMd(
            context.fx.onSurfaceVariant,
            context: context,
          ).copyWith(fontSize: 13),
          prefixIcon: Icon(
            Icons.search,
            size: 20,
            color: context.fx.onSurfaceVariant,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: context.fx.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide(color: context.fx.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide(color: context.fx.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: BorderSide(color: context.fx.secondary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
