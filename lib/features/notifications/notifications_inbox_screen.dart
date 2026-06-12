import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
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

    return FxPageScaffold(
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
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              return ListTile(
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.isUnread
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  '${n.body}\n${_dtFmt.format(n.createdAt.toLocal())}',
                ),
                isThreeLine: true,
                onTap: () async {
                  await ref.read(notificationRepositoryProvider).markRead(n.id);
                  ref.read(remittancesRefreshProvider.notifier).refresh();
                  if (n.remittanceId != null && context.mounted) {
                    context.push('/remittance/${n.remittanceId}');
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
