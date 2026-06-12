import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class FxSectionLabel extends StatelessWidget {
  const FxSectionLabel({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.labelCaps(
              Theme.of(context).colorScheme.onSurfaceVariant,
              context: context,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

String currencyFlagEmoji(String code) => switch (code) {
  'USD' => '🇺🇸',
  'AED' => '🇦🇪',
  'CNY' => '🇨🇳',
  'SAR' => '🇸🇦',
  'PKR' => '🇵🇰',
  _ => '💱',
};

String currencyDisplayName(String code) => switch (code) {
  'USD' => 'US Dollar',
  'AED' => 'UAE Dirham',
  'CNY' => 'Chinese Yuan',
  'SAR' => 'Saudi Riyal',
  'PKR' => 'Pakistani Rupee',
  _ => code,
};

String currencySymbol(String code) => switch (code) {
  'USD' => '\$',
  'EUR' => '€',
  'AED' => 'د.إ',
  'CNY' => '¥',
  'SAR' => '﷼',
  'PKR' => 'PKR ',
  _ => '',
};
