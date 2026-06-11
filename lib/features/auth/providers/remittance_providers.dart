import 'package:accounts_manager/data/repositories/remittance_repository.dart';
import 'package:accounts_manager/domain/models/fx_remittance.dart';
import 'package:accounts_manager/domain/models/fx_remittance_event.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final remittanceRepositoryProvider = Provider((ref) => RemittanceRepository());

final remittancesRefreshProvider = NotifierProvider<RemittancesRefreshNotifier, int>(RemittancesRefreshNotifier.new);

class RemittancesRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final remittancesListProvider = FutureProvider<List<FxRemittance>>((ref) async {
  ref.watch(remittancesRefreshProvider);
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return [];
  return ref.read(remittanceRepositoryProvider).fetchList(profile.branchId);
});

final remittanceDetailProvider = FutureProvider.family<FxRemittance?, String>((ref, id) async {
  ref.watch(remittancesRefreshProvider);
  return ref.read(remittanceRepositoryProvider).fetchOne(id);
});

final remittanceTimelineProvider = FutureProvider.family<List<FxRemittanceEvent>, String>((ref, id) async {
  ref.watch(remittancesRefreshProvider);
  return ref.read(remittanceRepositoryProvider).fetchTimeline(id);
});
