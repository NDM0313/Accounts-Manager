import 'package:accounts_manager/app/app.dart';
import 'package:accounts_manager/core/config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Public client config only (API URL + publishable/anon key).
  // Never bundle DB passwords / service_role / JWT secrets in this asset.
  await dotenv.load(fileName: 'assets/config/client.env');
  Env.assertNoPrivilegedSecretsInClientEnv();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  runApp(const ProviderScope(child: FxApp()));
}
