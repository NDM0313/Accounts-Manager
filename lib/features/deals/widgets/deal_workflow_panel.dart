import 'dart:typed_data';

import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/utils/pending_proof_upload.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_obsidian_report_panel.dart';
import 'package:accounts_manager/domain/models/fx_deal.dart';
import 'package:accounts_manager/domain/models/fx_deal_leg.dart';
import 'package:accounts_manager/domain/services/deal_workflow_guide.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DealWorkflowPanel extends StatefulWidget {
  const DealWorkflowPanel({
    super.key,
    required this.deal,
    required this.legs,
    this.onReceivePayment,
  });

  final FxDeal deal;
  final List<FxDealLeg> legs;
  final VoidCallback? onReceivePayment;

  @override
  State<DealWorkflowPanel> createState() => _DealWorkflowPanelState();
}

class _DealWorkflowPanelState extends State<DealWorkflowPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final view = DealWorkflowGuide.build(deal: widget.deal, legs: widget.legs);
    final fx = context.fx;

    return FxObsidianReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WORKFLOW', style: AppTypography.labelCaps(fx.primary, context: context)),
          const SizedBox(height: 8),
          Text(view.statusLabel, style: AppTypography.headlineMd(fx.onSurface, context: context).copyWith(fontSize: 18)),
          if (view.warningText != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    view.warningText!,
                    style: AppTypography.bodyMd(Colors.orange.shade700, context: context).copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text('Next: ${view.nextActionTitle}', style: AppTypography.bodyMd(fx.onSurfaceVariant, context: context)),
          const SizedBox(height: 12),
          if (!view.isCompleted)
            FilledButton(
              onPressed: () {
                if (view.nextActionRoute == null) {
                  widget.onReceivePayment?.call();
                } else {
                  context.push(view.nextActionRoute!);
                }
              },
              child: Text(view.nextActionTitle),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_expanded ? 'Hide checklist' : 'Show step checklist'),
          ),
          if (_expanded) ...[
            const Divider(height: 16),
            ...view.steps.where((s) => s.status != DealWorkflowStepStatus.skipped).map((s) => _StepRow(step: s)),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final DealWorkflowStep step;

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final icon = switch (step.status) {
      DealWorkflowStepStatus.completed => Icon(Icons.check_circle, color: fx.primary, size: 18),
      DealWorkflowStepStatus.partial => Icon(Icons.timelapse, color: Colors.orange.shade700, size: 18),
      DealWorkflowStepStatus.pending => Icon(Icons.radio_button_unchecked, color: fx.outline, size: 18),
      DealWorkflowStepStatus.skipped => const SizedBox.shrink(),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.label, style: AppTypography.bodyMd(fx.onSurface, context: context).copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                if (step.amountLabel != null)
                  Text(step.amountLabel!, style: AppTypography.bodyMd(fx.onSurfaceVariant, context: context).copyWith(fontSize: 11)),
                if (step.partyName != null)
                  Text(step.partyName!, style: AppTypography.bodyMd(fx.onSurfaceVariant, context: context).copyWith(fontSize: 11)),
                if (step.attachmentCount > 0)
                  Text('📎 ${step.attachmentCount} proof(s)', style: AppTypography.bodyMd(fx.tertiary, context: context).copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pick files before leg save; upload after legId is returned.
class FxPendingProofPicker extends StatefulWidget {
  const FxPendingProofPicker({super.key, this.enabled = true});

  final bool enabled;

  @override
  State<FxPendingProofPicker> createState() => FxPendingProofPickerState();
}

class FxPendingProofPickerState extends State<FxPendingProofPicker> {
  final List<PendingProofFile> files = [];

  Future<void> pickFiles() async {
    if (!widget.enabled) return;
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    if (result == null) return;
    for (final f in result.files) {
      if (f.bytes == null) continue;
      files.add(PendingProofFile(fileName: f.name, bytes: f.bytes!, mimeType: _mime(f.extension)));
    }
    setState(() {});
  }

  String? _mime(String? ext) => switch (ext?.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: pickFiles,
          icon: const Icon(Icons.attach_file),
          label: const Text('Attach proof (optional)'),
        ),
        if (files.isNotEmpty)
          ...files.map((f) => Text('• ${f.fileName}', style: AppTypography.bodyMd(context.fx.onSurfaceVariant, context: context).copyWith(fontSize: 12))),
      ],
    );
  }
}
