import 'package:accounts_manager/data/repositories/opening_balance_repository.dart';
import 'package:accounts_manager/domain/models/fx_opening_balance_batch.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final openingBalanceRepositoryProvider = Provider((ref) => OpeningBalanceRepository());

final openingBalanceStatusProvider = FutureProvider<FxOpeningBalanceView>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null) {
    return const FxOpeningBalanceView(status: FxOpeningBalanceStatus.missing);
  }
  return ref.read(openingBalanceRepositoryProvider).getStatus(profile.branchId);
});

final openingBalanceNeedsSetupProvider = Provider<bool>((ref) {
  final async = ref.watch(openingBalanceStatusProvider);
  return async.maybeWhen(
    data: (v) => v.status == FxOpeningBalanceStatus.missing,
    orElse: () => false,
  );
});

final openingBalancePostedProvider = Provider<bool>((ref) {
  final async = ref.watch(openingBalanceStatusProvider);
  return async.maybeWhen(
    data: (v) => v.status == FxOpeningBalanceStatus.posted,
    orElse: () => false,
  );
});
