import 'package:accounts_manager/app/app.dart';
import 'package:accounts_manager/core/config/client_config.dart';
import 'package:accounts_manager/core/config/env.dart';
import 'package:accounts_manager/core/widgets/startup_failure_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Public JSON config (API URL + publishable/anon key only).
    // Avoids *.env filenames that static servers often block or chmod-restrict.
    await ClientConfig.loadIntoDotenv();
    Env.assertNoPrivilegedSecretsInClientEnv();

    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );

    runApp(const ProviderScope(child: FxApp()));
  } catch (e) {
    runApp(StartupFailureApp(message: ClientConfig.sanitizeError(e)));
  }
}
