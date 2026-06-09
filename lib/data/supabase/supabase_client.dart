import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Supabase client accessor.
///
/// Uses publishable/anon key only — never service_role.
SupabaseClient get supabase => Supabase.instance.client;
