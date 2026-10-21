import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/demo_workspace_banner.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DemoWalkthroughScreen extends ConsumerWidget {
  const DemoWalkthroughScreen({super.key});

  static const _steps = <_DemoStep>[
    _DemoStep(
      title: 'Opening balance',
      body: 'PKR 2,000,000 cash vs opening equity. Illustrative only.',
      route: '/reports/trial-balance',
    ),
    _DemoStep(
      title: 'Agent purchases',
      body:
          'CNY 10,000 @ 40, AED 5,000 @ 75, USD 2,000 @ 280 — held by demo agents. Remaining PKR cash 665,000.',
      route: '/parties',
    ),
    _DemoStep(
      title: 'Ali — CNY partial delivery',
      body:
          'Paid 164,000 PKR for 4,000 CNY. Paid out 1,500 CNY (cost 60,000, spread 1,500). 2,500 CNY still reserved.',
      route: '/remittance',
    ),
    _DemoStep(
      title: 'Sara — AED completed',
      body: '1,000 AED @ 77 fully paid and paid out from Dubai agent stock. Spread 2,000 PKR.',
      route: '/remittance',
    ),
    _DemoStep(
      title: 'Bilal — pending receipt',
      body: '500 USD order; only 50,000 PKR received. No reservation/payout yet.',
      route: '/remittance',
    ),
    _DemoStep(
      title: 'Hina — agent-funded payout',
      body:
          'Agent paid from own funds; payable 38,000 PKR; settled 20,000; remaining 18,000. Owned AED stock untouched.',
      route: '/remittance',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(branchContextProvider).value;
    final isDemo = branch?.companyCode == 'AM_DEMO';

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        title: const Text('Demo walkthrough'),
        backgroundColor: context.fx.surface,
      ),
      body: Column(
        children: [
          if (isDemo) const DemoWorkspaceBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Rates are fixed illustrative samples (not market quotes). '
                  'Realized spread is posted; pending margin is not.',
                  style: AppTypography.bodyMd(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Expected controls: PKR cash 974,000 · CNY 8,500 (2,500 reserved) · '
                  'AED 4,000 · USD 2,000 · advances 152,500 · agent payable 18,000 · '
                  'realized spread 3,500.',
                  style: AppTypography.bodySm(
                    context.fx.onSurfaceVariant,
                    context: context,
                  ),
                ),
                const SizedBox(height: 16),
                ..._steps.map(
                  (s) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(s.title),
                      subtitle: Text(s.body),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(s.route),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.summarize_outlined),
                  title: const Text('Trial balance / profit'),
                  onTap: () => context.push('/reports/trial-balance'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoStep {
  const _DemoStep({
    required this.title,
    required this.body,
    required this.route,
  });
  final String title;
  final String body;
  final String route;
}
