import 'package:accounts_manager/core/config/env.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Describes whether the configured API is expected to support full AM schema.
///
/// Does **not** auto-switch hosts. Does **not** perform write probes.
enum BackendReadinessLevel {
  /// Public client env validates; schema compatibility not yet proven.
  configOkSchemaUnverified,

  /// Explicitly marked as home API target awaiting DB reconciliation apply.
  homeApiAwaitingSchema,

  /// Legacy Cloud host still configured (explicit allowlist only).
  legacyCloudConfigured,

  /// Development loopback.
  localDevelopment,
}

class BackendReadiness {
  const BackendReadiness({
    required this.level,
    required this.apiHost,
    required this.messages,
    required this.blocksMoneyOperations,
  });

  final BackendReadinessLevel level;
  final String apiHost;
  final List<String> messages;

  /// When true, UI should treat posting as unsafe until DB validation passes.
  final bool blocksMoneyOperations;

  static BackendReadiness evaluate({
    String? apiUrlOverride,
    String? schemaReadyOverride,
  }) {
    final url = apiUrlOverride ?? Env.supabaseUrl;
    final host = Uri.parse(url).host.toLowerCase();
    String fromDotenv = '';
    if (schemaReadyOverride == null) {
      try {
        fromDotenv = dotenv.env['FX_SCHEMA_READY'] ?? '';
      } on Object {
        fromDotenv = '';
      }
    }
    final schemaReadyFlag =
        (schemaReadyOverride ?? fromDotenv).trim().toLowerCase();
    final schemaReady =
        schemaReadyFlag == '1' ||
        schemaReadyFlag == 'true' ||
        schemaReadyFlag == 'yes';

    if (host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '::1' ||
        host == '10.0.2.2') {
      return BackendReadiness(
        level: BackendReadinessLevel.localDevelopment,
        apiHost: host,
        messages: const [
          'Local development endpoint in use.',
          'Do not treat this as production validation.',
        ],
        blocksMoneyOperations: !schemaReady,
      );
    }

    if (host == 'api.ndmcore.com') {
      return BackendReadiness(
        level: BackendReadinessLevel.homeApiAwaitingSchema,
        apiHost: host,
        messages: [
          'Home API configured (api.ndmcore.com).',
          if (!schemaReady)
            'FX schema reconciliation not marked ready (FX_SCHEMA_READY). '
                'Money posting remains gated until disposable DB validation passes.',
          if (FeatureFlags.remittanceWorkflowEnabled)
            'Remittance UI is enabled in FeatureFlags — requires remittance RPCs on DB.',
          if (FeatureFlags.dealsWorkflowEnabled)
            'Deals UI is enabled — requires deal RPCs on DB.',
          if (FeatureFlags.messagingEnabled)
            'Messaging UI is enabled — requires messaging RPCs on DB.',
        ],
        blocksMoneyOperations: !schemaReady,
      );
    }

    if (host == 'ygidlcqhupmxvsdjmvnf.supabase.co') {
      return const BackendReadiness(
        level: BackendReadinessLevel.legacyCloudConfigured,
        apiHost: 'ygidlcqhupmxvsdjmvnf.supabase.co',
        messages: [
          'Legacy Cloud host is explicitly configured (not a silent fallback).',
          'Reachability/schema for this host is environment-dependent.',
        ],
        blocksMoneyOperations: true,
      );
    }

    return BackendReadiness(
      level: BackendReadinessLevel.configOkSchemaUnverified,
      apiHost: host,
      messages: const ['Unexpected allowlisted host classification.'],
      blocksMoneyOperations: true,
    );
  }
}
