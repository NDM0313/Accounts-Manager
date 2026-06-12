import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/widgets/premium/fx_expiry_segmented_control.dart';
import 'package:accounts_manager/core/widgets/premium/fx_permission_toggle_row.dart';
import 'package:accounts_manager/core/widgets/premium/fx_stitch_scaffold.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_secure_share_widgets.dart';
import 'package:accounts_manager/data/repositories/secure_share_repository.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ShareSecureLinkScreen extends ConsumerStatefulWidget {
  const ShareSecureLinkScreen({
    super.key,
    required this.entityType,
    required this.entityId,
    this.title,
    this.subtitle,
  });

  final String entityType;
  final String entityId;
  final String? title;
  final String? subtitle;

  @override
  ConsumerState<ShareSecureLinkScreen> createState() =>
      _ShareSecureLinkScreenState();
}

class _ShareSecureLinkScreenState extends ConsumerState<ShareSecureLinkScreen> {
  int _expiryIndex = 0;
  bool _allowDownload = true;
  bool _passwordEnabled = false;
  bool _emailVerification = false;
  final _passwordCtrl = TextEditingController();
  bool _busy = false;
  String? _generatedUrl;

  static const _expiryOptions = ['1 Hour', '24 Hours', '7 Days', 'Custom'];

  DateTime _expiryFromIndex() {
    final now = DateTime.now();
    return switch (_expiryIndex) {
      0 => now.add(const Duration(hours: 1)),
      1 => now.add(const Duration(hours: 24)),
      2 => now.add(const Duration(days: 7)),
      _ => now.add(const Duration(days: 30)),
    };
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final link = await ref.read(secureShareRepositoryProvider).createLink(
            entityType: widget.entityType,
            entityId: widget.entityId,
            expiresAt: _expiryFromIndex(),
            allowDownload: _allowDownload,
            password: _passwordEnabled ? _passwordCtrl.text : null,
          );
      setState(() => _generatedUrl = link.shareUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Secure link generated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final horizontal = MediaQuery.sizeOf(context).width >= 900
        ? AppSpacing.marginDesktop
        : AppSpacing.marginMobile;
    final generatedSubtitle = widget.subtitle ??
        'GENERATED ON ${DateFormat('MMM d, yyyy').format(DateTime.now()).toUpperCase()}';
    final previewUrl = _generatedUrl ??
        'https://secure.fxledger.com/share/${widget.entityType}/${widget.entityId}?token=…';

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.surface,
        foregroundColor: context.fx.primary,
        title: Text(
          'Share Configuration',
          style: AppTypography.headlineSm(
            context.fx.primary,
            context: context,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: profileAsync.when(
              loading: () => const SizedBox(width: 32, height: 32),
              error: (_, _) => const SizedBox.shrink(),
              data: (profile) {
                final name = profile?.fullName ?? 'U';
                final initials = name
                    .split(' ')
                    .map((p) => p.isNotEmpty ? p[0] : '')
                    .take(2)
                    .join()
                    .toUpperCase();
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: context.fx.surfaceContainerHigh,
                  child: Text(
                    initials,
                    style: AppTypography.labelCaps(
                      context.fx.primary,
                      context: context,
                    ).copyWith(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: FxStitchScaffold(
        padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 88),
        child: ListView(
          children: [
            FxStitchSecureShareSummaryCard(
              title: widget.title ?? 'Shared document',
              subtitle: generatedSubtitle,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Link Expiry',
                  style: AppTypography.headlineSm(
                    context.fx.onSurface,
                    context: context,
                  ),
                ),
                Icon(Icons.schedule, color: context.fx.outline, size: 22),
              ],
            ),
            const SizedBox(height: 12),
            FxExpirySegmentedControl(
              options: _expiryOptions,
              selectedIndex: _expiryIndex,
              onSelected: (i) => setState(() => _expiryIndex = i),
            ),
            const SizedBox(height: 24),
            Text(
              'Security Permissions',
              style: AppTypography.headlineSm(
                context.fx.onSurface,
                context: context,
              ),
            ),
            const SizedBox(height: 12),
            FxPermissionToggleRow(
              icon: Icons.download_outlined,
              title: 'Allow Download (PDF)',
              subtitle: 'Recipient can save a local copy',
              value: _allowDownload,
              onChanged: (v) => setState(() => _allowDownload = v),
            ),
            const SizedBox(height: 12),
            FxPermissionToggleRow(
              icon: Icons.lock_outline,
              title: 'Password Protection',
              subtitle: 'Encryption layer for link access',
              value: _passwordEnabled,
              onChanged: (v) => setState(() => _passwordEnabled = v),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Enter secure password',
                      filled: true,
                      fillColor: context.fx.surface,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14, color: context.fx.outline),
                      const SizedBox(width: 4),
                      Text(
                        'Minimum 12 characters recommended.',
                        style: AppTypography.bodySm(
                          context.fx.outline,
                          context: context,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FxPermissionToggleRow(
              icon: Icons.verified_user_outlined,
              title: 'Require Email Verification',
              subtitle: 'One-time code sent to recipient',
              value: _emailVerification,
              onChanged: (v) => setState(() => _emailVerification = v),
            ),
            const SizedBox(height: 24),
            FxStitchSecureShareLinkPreview(
              url: previewUrl,
              onCopy: _generatedUrl == null
                  ? null
                  : () {
                      Clipboard.setData(
                        ClipboardData(text: _generatedUrl!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    },
            ),
            const SizedBox(height: 24),
            FxStitchSecureShareGenerateCta(
              busy: _busy,
              onPressed: _generate,
            ),
          ],
        ),
      ),
    );
  }
}
