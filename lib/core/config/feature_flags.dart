/// Feature flags for gradual rollout.
abstract final class FeatureFlags {
  /// When true, FX Deals workflow is available (customer order first, multi-leg sourcing).
  static const dealsWorkflowEnabled = true;

  /// When true, Hawala / remittance module is available (requires DB migration).
  static const remittanceWorkflowEnabled = true;

  /// When true, internal team messaging is available (requires DB migration).
  static const messagingEnabled = true;

  /// When true, reference rate snapshots are persisted to DB (requires migration 202606180002).
  static const rateSnapshotColumnsEnabled = false;

  /// When true, rate deactivate (is_active) is available on the rate board.
  static const rateDeactivateEnabled = true;
}

/// Maps user-facing RMB label to ledger currency code.
String normalizeFxCurrencyCode(String code) {
  final upper = code.trim().toUpperCase();
  if (upper == 'RMB') return 'CNY';
  return upper;
}

String displayCurrencyCode(String code) {
  if (code.toUpperCase() == 'CNY') return 'RMB (CNY)';
  return code;
}
