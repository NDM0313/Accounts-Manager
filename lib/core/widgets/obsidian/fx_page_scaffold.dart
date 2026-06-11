import 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart';

export 'package:accounts_manager/core/widgets/premium/fx_premium_scaffold.dart' show fxSafePop;

/// @deprecated Prefer [FxPremiumScaffold]. Kept for backward compatibility.
class FxPageScaffold extends FxPremiumScaffold {
  const FxPageScaffold({
    super.key,
    required super.title,
    required super.body,
    super.fallbackRoute,
    super.actions,
    super.backgroundColor,
    super.floatingActionButton,
    super.bottomBar,
  });
}
