import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class RemittanceReportsScreen extends ConsumerWidget {
  const RemittanceReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(remittancesListProvider);
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(title: const Text('Remittance Reports'), backgroundColor: context.fx.background),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          final open = items.where((r) => r.status.isOpen).length;
          final completed = items.where((r) => r.status == FxRemittanceStatus.completed).length;
          final totalRecv = items.fold<double>(0, (s, r) => s + r.receiveAmount);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stat(context, 'Open orders', '$open'),
                _stat(context, 'Completed', '$completed'),
                _stat(context, 'Total receive volume', fmt.format(totalRecv)),
                const SizedBox(height: 16),
                Text(
                  'Detailed remittance reporting will expand after migration is applied.',
                  style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context)),
          Text(value, style: AppTypography.headlineSm(context.fx.onSurface, context: context)),
        ],
      ),
    );
  }
}
