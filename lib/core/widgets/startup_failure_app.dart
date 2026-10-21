import 'package:flutter/material.dart';

/// Minimal full-screen error when public config / Supabase init fails.
/// Does not display secrets or raw config payloads.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0F1419),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accounts Manager',
                  style: TextStyle(
                    color: Color(0xFFE8EEF5),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to start',
                  style: TextStyle(
                    color: Color(0xFFFFB4A8),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFB8C4D0),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Public configuration failed to load. '
                  'Confirm the deployed client_config.json is readable and '
                  'points at https://api.ndmcore.com.',
                  style: TextStyle(color: Color(0xFF8A96A3), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
