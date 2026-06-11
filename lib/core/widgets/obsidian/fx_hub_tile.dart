import 'package:accounts_manager/core/widgets/premium/fx_action_tile.dart';
import 'package:flutter/material.dart';

class FxHubTile extends StatelessWidget {
  const FxHubTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.compact = true,
    this.iconSize = 36,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return FxActionTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
      compact: compact,
    );
  }
}
