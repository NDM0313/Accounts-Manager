import 'package:flutter/material.dart';

/// Persistent banner for AM_DEMO sample data screens and exports.
class DemoWorkspaceBanner extends StatelessWidget {
  const DemoWorkspaceBanner({super.key});

  static const label = 'DEMO — SAMPLE DATA, NOT REAL ACCOUNTS';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF7A4E00),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.science_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
