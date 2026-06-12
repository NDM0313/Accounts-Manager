import 'dart:ui';

import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/export/fx_document_export.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_export_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Stitch share_export_options bottom sheet with transaction context header.
class FxExportHubSheet extends StatelessWidget {
  const FxExportHubSheet({
    super.key,
    required this.document,
    this.refLabel,
    this.statusLabel,
    this.summaryLines = const [],
    this.lifecycleSteps = const [],
    this.shareUrl,
    this.mode = FxExportMode.internal,
  });

  final FxExportDocument document;
  final String? refLabel;
  final String? statusLabel;
  final List<(String label, String value)> summaryLines;
  final List<FxStitchExportLifecycleStep> lifecycleSteps;
  final String? shareUrl;
  final FxExportMode mode;

  static Future<void> show(
    BuildContext context, {
    required FxExportDocument document,
    String? refLabel,
    String? statusLabel,
    List<(String label, String value)> summaryLines = const [],
    List<FxStitchExportLifecycleStep> lifecycleSteps = const [],
    String? shareUrl,
    FxExportMode mode = FxExportMode.internal,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (ctx) => FxExportHubSheet(
        document: document,
        refLabel: refLabel,
        statusLabel: statusLabel,
        summaryLines: summaryLines,
        lifecycleSteps: lifecycleSteps,
        shareUrl: shareUrl,
        mode: mode,
      ),
    );
  }

  Future<void> _copyLink(BuildContext context) async {
    final link = shareUrl ?? document.textBody;
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: ColoredBox(
              color: fx.onSurface.withValues(alpha: 0.2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: fx.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusXl),
                ),
                border: Border(top: BorderSide(color: fx.outlineVariant)),
                boxShadow: [
                  BoxShadow(
                    color: fx.primary.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: fx.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  FxStitchExportSheetHeader(),
                  if (refLabel != null) ...[
                    const SizedBox(height: 16),
                    FxStitchExportContextCard(
                      refLabel: refLabel!,
                      statusLabel: statusLabel,
                      summaryLines: summaryLines,
                    ),
                  ],
                  if (lifecycleSteps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FxStitchExportLifecycleTimeline(steps: lifecycleSteps),
                  ],
                  const SizedBox(height: 8),
                  if (document.pdfBytes != null)
                    FxStitchExportOptionRow(
                      icon: Icons.picture_as_pdf,
                      title: 'Share as PDF',
                      subtitle: 'Standard audit-grade document',
                      style: FxStitchExportOptionStyle.pdf,
                      onTap: () async {
                        Navigator.pop(context);
                        await Printing.sharePdf(
                          bytes: document.pdfBytes!,
                          filename:
                              '${document.title.replaceAll(' ', '_')}.pdf',
                        );
                      },
                    ),
                  if (document.pdfBytes != null)
                    FxStitchExportOptionRow(
                      icon: Icons.print,
                      title: 'Print Transaction',
                      subtitle: 'Direct to connected network printer',
                      style: FxStitchExportOptionStyle.print,
                      onTap: () async {
                        Navigator.pop(context);
                        await Printing.layoutPdf(
                          onLayout: (_) async => document.pdfBytes!,
                        );
                      },
                    ),
                  FxStitchExportOptionRow(
                    icon: Icons.image_outlined,
                    title: 'Share Image',
                    subtitle: 'High-resolution deal confirmation',
                    style: FxStitchExportOptionStyle.image,
                    onTap: () async {
                      Navigator.pop(context);
                      await SharePlus.instance.share(
                        ShareParams(
                          text: document.textBody,
                          subject: document.subject ?? document.title,
                        ),
                      );
                    },
                  ),
                  FxStitchExportOptionRow(
                    icon: Icons.mail_outline,
                    title: 'Send via Email',
                    subtitle: 'To finance or treasury contact',
                    style: FxStitchExportOptionStyle.email,
                    onTap: () async {
                      Navigator.pop(context);
                      await SharePlus.instance.share(
                        ShareParams(
                          text: document.textBody,
                          subject: document.subject ?? document.title,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  FxStitchExportCopyLinkButton(
                    onTap: () => _copyLink(context),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
