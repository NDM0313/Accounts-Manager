import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Grouped form fields with a calm section title.
class FxFormSection extends StatelessWidget {
  const FxFormSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.optional = false,
  });

  final String title;
  final String? subtitle;
  final bool optional;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.headlineSm(
                  fx.onSurface,
                  context: context,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (optional)
              Text(
                'Optional',
                style: AppTypography.bodySm(
                  fx.onSurfaceVariant,
                  context: context,
                ),
              ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: AppTypography.bodySm(
              fx.onSurfaceVariant,
              context: context,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.stackSm),
        ..._spaced(children),
      ],
    );
  }

  List<Widget> _spaced(List<Widget> items) {
    if (items.isEmpty) return const [];
    final out = <Widget>[items.first];
    for (var i = 1; i < items.length; i++) {
      out.add(const SizedBox(height: AppSpacing.stackSm));
      out.add(items[i]);
    }
    return out;
  }
}

/// Sticky Save / Cancel action row for forms.
class FxFormActionBar extends StatelessWidget {
  const FxFormActionBar({
    super.key,
    required this.onSave,
    this.onCancel,
    this.saveLabel = 'Save',
    this.cancelLabel = 'Cancel',
    this.saving = false,
    this.saveEnabled = true,
  });

  final VoidCallback? onSave;
  final VoidCallback? onCancel;
  final String saveLabel;
  final String cancelLabel;
  final bool saving;
  final bool saveEnabled;

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return Material(
      color: fx.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: fx.outlineVariant)),
          color: fx.surface,
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.stackMd,
          AppSpacing.stackSm,
          AppSpacing.stackMd,
          AppSpacing.stackSm + MediaQuery.paddingOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              if (onCancel != null)
                TextButton(
                  onPressed: saving ? null : onCancel,
                  child: Text(cancelLabel),
                ),
              const Spacer(),
              FilledButton(
                onPressed: (!saveEnabled || saving) ? null : onSave,
                child: saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fx.onPrimary,
                        ),
                      )
                    : Text(saveLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
