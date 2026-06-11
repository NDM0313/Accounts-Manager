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
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(document.title),
            subtitle: Text(mode == FxExportMode.customerFacing ? 'Customer copy' : 'Internal copy'),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
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
              leading: const Icon(Icons.table_chart_outlined),
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
              leading: const Icon(Icons.picture_as_pdf_outlined),
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
              leading: const Icon(Icons.print_outlined),
              title: const Text('Print'),
              onTap: () async {
                Navigator.pop(ctx);
                await Printing.layoutPdf(onLayout: (_) async => document.pdfBytes!);
              },
            ),
          ],
        ],
      ),
    ),
  );
}
