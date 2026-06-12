import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_section_label.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_card.dart';
import 'package:flutter/material.dart';

/// Bordered premium container for report rows and summary cards.
class FxObsidianReportPanel extends StatelessWidget {
  const FxObsidianReportPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.sectionLabel,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? sectionLabel;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FxPremiumCard(
      padding: padding,
      onTap: onTap,
      color: color,
      child: child,
    );
  }
}

/// Uppercase column headers for tabular report layouts.
class FxObsidianReportTableHeader extends StatelessWidget {
  const FxObsidianReportTableHeader({super.key, required this.columns});

  final List<Widget> columns;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(flex: i == 0 ? 3 : 2, child: columns[i]),
          ],
        ],
      ),
    );
  }

  static Widget columnLabel(
    BuildContext context,
    String text, {
    TextAlign align = TextAlign.start,
  }) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
      style: AppTypography.labelCaps(
        context.fx.outline,
        context: context,
      ).copyWith(fontSize: 10, letterSpacing: 1.2),
    );
  }
}

/// Section with optional label and list of report panels.
class FxObsidianReportSection extends StatelessWidget {
  const FxObsidianReportSection({
    super.key,
    required this.label,
    required this.children,
  });

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FxSectionLabel(label: label),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}
