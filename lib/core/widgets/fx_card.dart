import 'package:flutter/material.dart';

class FxCard extends StatelessWidget {
  const FxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}

class FxSectionHeader extends StatelessWidget {
  const FxSectionHeader({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class FxBalanceCard extends StatelessWidget {
  const FxBalanceCard({
    super.key,
    required this.label,
    required this.amount,
    this.subtitle,
    this.accent,
  });

  final String label;
  final String amount;
  final String? subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(
            amount,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: accent ?? theme.colorScheme.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class FxComingSoonChip extends StatelessWidget {
  const FxComingSoonChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: const Text('Coming soon'),
      visualDensity: VisualDensity.compact,
      labelStyle: Theme.of(context).textTheme.labelSmall,
    );
  }
}

class FxStatusChip extends StatelessWidget {
  const FxStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      'posted' => ('Posted', theme.colorScheme.tertiary),
      'draft' => ('Draft', theme.colorScheme.onSurfaceVariant),
      'voided' => ('Voided', theme.colorScheme.error),
      _ => (status, theme.colorScheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          letterSpacing: 0.04,
        ),
      ),
    );
  }
}
