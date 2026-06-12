import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FxWorkflowGuideScreen extends StatelessWidget {
  const FxWorkflowGuideScreen({super.key});

  static const steps = [
    _GuideStep(
      n: 1,
      title: 'Opening balance',
      body:
          'Enter starting cash, FX positions, and party balances once via Opening Balance wizard.',
      route: '/opening-balances',
      routeLabel: 'Open Opening Balances',
    ),
    _GuideStep(
      n: 2,
      title: 'Customer order',
      body:
          'Book a customer FX deal — customer wants currency before you have stock.',
      route: '/deals/new',
      routeLabel: 'New Customer FX Order',
    ),
    _GuideStep(
      n: 3,
      title: 'Sourcing requirement',
      body:
          'System flags sourcing when sell currency is not available. Add sourcing leg on deal detail.',
      route: '/deals',
      routeLabel: 'View Deals',
    ),
    _GuideStep(
      n: 4,
      title: 'Agent source',
      body:
          'Link an agent who can provide the currency. May involve cross-currency (e.g. pay AED for RMB).',
      route: '/deals',
      routeLabel: 'Deal detail → Agent source',
    ),
    _GuideStep(
      n: 5,
      title: 'Agent payment',
      body:
          'Pay agent partially or fully via settlement send. Agent payable shows on agent statement.',
      route: '/parties',
      routeLabel: 'Agent statement',
    ),
    _GuideStep(
      n: 6,
      title: 'Currency receipt',
      body:
          'Confirm currency received from agent — updates cash position and deal leg.',
      route: '/deals',
      routeLabel: 'Deal detail → Confirm receipt',
    ),
    _GuideStep(
      n: 7,
      title: 'Delivery / TT',
      body: 'Confirm delivery or TT to customer when order is fulfilled.',
      route: '/deals',
      routeLabel: 'Deal detail → Delivery',
    ),
    _GuideStep(
      n: 8,
      title: 'Customer payment',
      body:
          'Record customer PKR payments. Partial payments leave receivable on customer statement.',
      route: '/parties',
      routeLabel: 'Customer statement',
    ),
    _GuideStep(
      n: 9,
      title: 'Statements',
      body:
          'Review party/agent statements with running balance. Share customer or internal copy.',
      route: '/parties',
      routeLabel: 'Party statements',
    ),
    _GuideStep(
      n: 10,
      title: 'Profit / loss',
      body:
          'P&L and spread income reflect completed deals. Trial balance must stay balanced.',
      route: '/reports/profit-loss',
      routeLabel: 'Profit & Loss',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FxPageScaffold(
      fallbackRoute: '/',
      title: const Text('How FX Deal Works'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'End-to-end workflow for FX Cash Ledger. Use demo data (after seed) to walk through each step.',
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          const SizedBox(height: 16),
          for (final step in steps) ...[
            _StepCard(step: step),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep({
    required this.n,
    required this.title,
    required this.body,
    required this.route,
    required this.routeLabel,
  });

  final int n;
  final String title;
  final String body;
  final String route;
  final String routeLabel;
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final _GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fx.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: context.fx.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${step.n}',
            style: AppTypography.labelCaps(
              context.fx.primary,
              context: context,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.title,
            style: AppTypography.headlineMd(
              context.fx.onSurface,
              context: context,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.body,
            style: AppTypography.bodyMd(
              context.fx.onSurfaceVariant,
              context: context,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.push(step.route),
            child: Text(step.routeLabel),
          ),
        ],
      ),
    );
  }
}
