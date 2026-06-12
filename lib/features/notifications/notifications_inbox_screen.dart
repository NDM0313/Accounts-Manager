import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_card.dart';
import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';
import 'package:accounts_manager/features/auth/providers/remittance_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class NotificationsInboxScreen extends ConsumerWidget {
  const NotificationsInboxScreen({super.key});

  static final _dtFmt = DateFormat('dd MMM HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(notificationsProvider);

    return FxPremiumScaffold(
      title: const Text('Notifications'),
      fallbackRoute: '/remittance',
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No notifications',
                style: AppTypography.bodyMd(
                  context.fx.onSurfaceVariant,
                  context: context,
                ),
              ),
            );
          }
          final unread = items.where((n) => n.isUnread).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (unread > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '$unread unread',
                    style: AppTypography.bodyMd(
                      context.fx.secondary,
                      context: context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ...items.map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FxPremiumCard(
                    padding: const EdgeInsets.all(12),
                    child: InkWell(
                      onTap: () async {
                        await ref
                            .read(notificationRepositoryProvider)
                            .markRead(n.id);
                        ref.read(remittancesRefreshProvider.notifier).refresh();
                        if (n.remittanceId != null && context.mounted) {
                          context.push('/remittance/${n.remittanceId}');
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (n.isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: context.fx.secondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  n.title,
                                  style:
                                      AppTypography.headlineSm(
                                        context.fx.onSurface,
                                        context: context,
                                      ).copyWith(
                                        fontSize: 14,
                                        fontWeight: n.isUnread
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            n.body,
                            style: AppTypography.bodyMd(
                              context.fx.onSurfaceVariant,
                              context: context,
                            ).copyWith(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _dtFmt.format(n.createdAt.toLocal()),
                            style: AppTypography.bodyMd(
                              context.fx.outline,
                              context: context,
                            ).copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
