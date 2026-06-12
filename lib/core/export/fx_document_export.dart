import 'package:accounts_manager/core/widgets/premium/fx_export_hub_sheet.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_export_widgets.dart';
import 'package:flutter/material.dart';
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
  String? refLabel,
  String? statusLabel,
  List<(String label, String value)> summaryLines = const [],
  List<FxStitchExportLifecycleStep> lifecycleSteps = const [],
  String? shareUrl,
}) async {
  await FxExportHubSheet.show(
    context,
    document: document,
    mode: mode,
    refLabel: refLabel ?? document.title,
    statusLabel: statusLabel,
    summaryLines: summaryLines,
    lifecycleSteps: lifecycleSteps,
    shareUrl: shareUrl,
  );
}
