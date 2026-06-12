import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';

/// Stitch login_screen form — caps labels, icon fields, biometric CTA.
class FxStitchLoginForm extends StatelessWidget {
  const FxStitchLoginForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    this.error,
    required this.onSignIn,
    required this.onBiometric,
    this.onContactAdmin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final String? error;
  final VoidCallback onSignIn;
  final VoidCallback onBiometric;
  final VoidCallback? onContactAdmin;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.asset(
            'assets/branding/executive_fx_logo.png',
            height: 128,
            errorBuilder: (_, _, _) => Icon(
              Icons.account_balance_wallet,
              size: 64,
              color: context.fx.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome Back',
            style: AppTypography.headlineLg(
              context.fx.primary,
              context: context,
            ).copyWith(fontSize: 32, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Securely manage your global FX ledger',
            style: AppTypography.bodyLg(
              context.fx.onSurfaceVariant,
              context: context,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _FieldLabel(text: 'EMAIL / USERNAME'),
          const SizedBox(height: 4),
          _IconField(
            controller: emailController,
            icon: Icons.mail_outlined,
            hint: 'e.g. treasury@corp.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                v != null && v.contains('@') ? null : 'Enter a valid email',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _FieldLabel(text: 'PASSWORD')),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'FORGOT PASSWORD?',
                  style: AppTypography.labelCaps(
                    context.fx.secondary,
                    context: context,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _IconField(
            controller: passwordController,
            icon: Icons.lock_outlined,
            hint: '••••••••',
            obscureText: true,
            validator: (v) =>
                v != null && v.length >= 6 ? null : 'Minimum 6 characters',
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.fx.errorContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Text(
                error!,
                style: AppTypography.bodyMd(context.fx.error, context: context),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: loading ? null : onSignIn,
              style: FilledButton.styleFrom(
                backgroundColor: context.fx.primary,
                foregroundColor: context.fx.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Sign In',
                      style: AppTypography.headlineSm(
                        context.fx.onPrimary,
                        context: context,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: context.fx.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR SECURE ACCESS',
                  style: AppTypography.labelCaps(
                    context.fx.outline,
                    context: context,
                  ).copyWith(fontSize: 9),
                ),
              ),
              Expanded(child: Divider(color: context.fx.outlineVariant)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onBiometric,
              style: OutlinedButton.styleFrom(
                foregroundColor: context.fx.onSurface,
                side: BorderSide(color: context.fx.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                ),
              ),
              icon: const Icon(Icons.fingerprint),
              label: Text(
                'Use Biometrics',
                style: AppTypography.dataMd(
                  context.fx.onSurface,
                  context: context,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "Don't have an account? ",
            style: AppTypography.bodySm(
              context.fx.onSurfaceVariant,
              context: context,
            ),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: onContactAdmin,
            child: Text(
              'Contact Admin',
              style: AppTypography.dataMd(
                context.fx.secondary,
                context: context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: AppTypography.labelCaps(
          context.fx.outline,
          context: context,
        ),
      ),
    );
  }
}

class _IconField extends StatelessWidget {
  const _IconField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTypography.bodyMd(context.fx.onSurface, context: context),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.bodyMd(
          context.fx.outline,
          context: context,
        ),
        prefixIcon: Icon(icon, color: context.fx.outline, size: 20),
        filled: true,
        fillColor: context.fx.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          borderSide: BorderSide(color: context.fx.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          borderSide: BorderSide(color: context.fx.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          borderSide: BorderSide(color: context.fx.secondary, width: 1.5),
        ),
      ),
    );
  }
}
