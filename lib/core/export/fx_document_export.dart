import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';

enum FxExportMode { customerFacing, internal }

enum FxExportFormat { text, csv, print, pdf }

class FxExportDocument {
  const FxExportDocument({
    required this.title,
    required this.textBody,
    this.csvBody,
    this.pdfBytes,
    this.subject,
    this.companyName,
    this.branchName,
  });

  final String title;
  final String textBody;
  final String? csvBody;
  final Uint8List? pdfBytes;
  final String? subject;
  final String? companyName;
  final String? branchName;
}

Future<void> showFxExportSheet(
  BuildContext context, {
  required FxExportDocument document,
  FxExportMode mode = FxExportMode.internal,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: context.fx.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
          border: Border.all(color: context.fx.outlineVariant),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.fx.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share & export',
                      style: AppTypography.labelCaps(context.fx.onSurfaceVariant, context: context),
                    ),
                    const SizedBox(height: 4),
                    Text(document.title, style: AppTypography.headlineSm(context.fx.onSurface, context: context)),
                    Text(
                      mode == FxExportMode.customerFacing ? 'Customer copy' : 'Internal copy',
                      style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.share_outlined, color: context.fx.primary),
                title: const Text('Share as text'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await SharePlus.instance.share(ShareParams(
                    text: document.textBody,
                    subject: document.subject ?? document.title,
                  ));
                },
              ),
              if (document.csvBody != null)
                ListTile(
                  leading: Icon(Icons.table_chart_outlined, color: context.fx.primary),
                  title: const Text('Share as CSV'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await SharePlus.instance.share(ShareParams(
                      text: document.csvBody!,
                      subject: '${document.subject ?? document.title} CSV',
                    ));
                  },
                ),
              if (document.pdfBytes != null) ...[
                ListTile(
                  leading: Icon(Icons.picture_as_pdf_outlined, color: context.fx.primary),
                  title: const Text('Share PDF'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Printing.sharePdf(
                      bytes: document.pdfBytes!,
                      filename: '${document.title.replaceAll(' ', '_')}.pdf',
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.print_outlined, color: context.fx.primary),
                  title: const Text('Print PDF'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Printing.layoutPdf(onLayout: (_) async => document.pdfBytes!);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
