import 'package:accounts_manager/app/theme/fx_design_tokens.dart';
import 'package:flutter/material.dart';

/// Persistent banner for AM_DEMO sample data screens and exports.
class DemoWorkspaceBanner extends StatelessWidget {
  const DemoWorkspaceBanner({super.key});

  static const label = 'DEMO — SAMPLE DATA, NOT REAL ACCOUNTS';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.fxAccentSurface(FxAccent.pending),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.science_outlined,
                color: context.fxAccent(FxAccent.pending),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: context.fxAccent(FxAccent.pending),
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
