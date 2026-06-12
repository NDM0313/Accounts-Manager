import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/core/config/feature_flags.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_chat_widgets.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_transaction_audit_widgets.dart';
import 'package:accounts_manager/domain/models/fx_audit_log.dart';
import 'package:accounts_manager/domain/models/fx_conversation.dart';
import 'package:accounts_manager/domain/models/fx_message.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/messaging_providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Stitch transaction_audit_chat — unified audit discussion thread.
class TransactionAuditScreen extends ConsumerStatefulWidget {
  const TransactionAuditScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<TransactionAuditScreen> createState() =>
      _TransactionAuditScreenState();
}

class _AuditChatItem {
  _AuditChatItem({required this.at, required this.builder});

  final DateTime at;
  final Widget Function() builder;
}

class _TransactionAuditScreenState
    extends ConsumerState<TransactionAuditScreen> {
  final _input = TextEditingController();
  String? _conversationId;
  bool _sending = false;
  bool _loadingConversation = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureConversation());
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _ensureConversation() async {
    if (!FeatureFlags.messagingEnabled) {
      setState(() => _loadingConversation = false);
      return;
    }
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null) {
      setState(() => _loadingConversation = false);
      return;
    }
    try {
      final tx = await ref.read(
        transactionDetailProvider(widget.transactionId).future,
      );
      final id = await ref
          .read(messagingRepositoryProvider)
          .getOrCreateEntityConversation(
            branchId: profile.branchId,
            type: FxConversationType.transaction,
            transactionId: widget.transactionId,
            title: tx.transactionNo ?? 'Transaction',
          );
      if (mounted) {
        setState(() {
          _conversationId = id;
          _loadingConversation = false;
        });
        await ref.read(messagingRepositoryProvider).markRead(id);
        ref.read(messagingRefreshProvider.notifier).refresh();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingConversation = false);
    }
  }

  Future<void> _send() async {
    if (_conversationId == null) return;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagingRepositoryProvider).sendMessage(
            conversationId: _conversationId!,
            body: text,
          );
      _input.clear();
      ref.read(messagingRefreshProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attachFile() async {
    if (_conversationId == null) return;
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null) return;
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final msgId = await ref.read(messagingRepositoryProvider).sendMessage(
          conversationId: _conversationId!,
          body: file.name,
          type: file.extension == 'pdf'
              ? FxMessageType.file
              : FxMessageType.image,
          metadata: {'file_name': file.name},
        );

    await ref.read(attachmentRepositoryProvider).upload(
          branchId: profile.branchId,
          bytes: file.bytes!,
          fileName: file.name,
          mimeType:
              file.extension == 'pdf' ? 'application/pdf' : 'image/jpeg',
          messageId: msgId,
        );
    ref.read(messagingRefreshProvider.notifier).refresh();
  }

  String _statusLabel(String status) => switch (status) {
        'posted' => 'Posted',
        'draft' => 'Verification In Progress',
        'voided' => 'Voided',
        _ => status,
      };

  List<_AuditChatItem> _buildItems({
    required List<AuditLogRow> logs,
    required List<FxMessage> messages,
    required String? profileId,
  }) {
    final timeFmt = DateFormat('hh:mm a');
    final items = <_AuditChatItem>[];

    for (final log in logs) {
      final action = log.action.toLowerCase();
      if (action.contains('join') || action.contains('created')) {
        items.add(
          _AuditChatItem(
            at: log.createdAt,
            builder: () => FxStitchSystemChatEvent(
              message: '${log.reason ?? log.action} joined the verification channel',
            ),
          ),
        );
      } else if (action.contains('verify') ||
          action.contains('audit') ||
          action.contains('post')) {
        items.add(
          _AuditChatItem(
            at: log.createdAt,
            builder: () => FxStitchInternalAuditNoteCard(
              message: log.reason ?? '${log.action} recorded in audit trail.',
            ),
          ),
        );
      } else {
        items.add(
          _AuditChatItem(
            at: log.createdAt,
            builder: () => FxStitchSystemChatEvent(
              message: '${log.action}${log.reason != null ? ': ${log.reason}' : ''}',
            ),
          ),
        );
      }
    }

    for (final m in messages) {
      final isMine = profileId != null && m.senderId == profileId;
      final ts = timeFmt.format(m.createdAt.toLocal());

      if (m.messageType == FxMessageType.file &&
          m.metadata['file_name'] != null) {
        items.add(
          _AuditChatItem(
            at: m.createdAt,
            builder: () => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment:
                    isMine ? Alignment.centerRight : Alignment.centerLeft,
                child: FxStitchVoiceNoteBubble(fileSizeLabel: m.body),
              ),
            ),
          ),
        );
        continue;
      }

      items.add(
        _AuditChatItem(
          at: m.createdAt,
          builder: () => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: isMine
                ? FxStitchAuditSentBubble(
                    senderName: 'You (Verifier)',
                    timestamp: ts,
                    message: m.body,
                  )
                : FxStitchAuditReceivedBubble(
                    senderName: 'Team Member',
                    timestamp: ts,
                    message: m.body,
                  ),
          ),
        ),
      );
    }

    items.sort((a, b) => a.at.compareTo(b.at));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionDetailProvider(widget.transactionId));
    final logsAsync = ref.watch(
      auditLogsForEntityProvider(widget.transactionId),
    );
    final profile = ref.watch(currentProfileProvider).value;
    final messagesAsync = _conversationId == null
        ? const AsyncValue<List<FxMessage>>.data([])
        : ref.watch(messagesListProvider(_conversationId!));

    final refLabel = txAsync.whenOrNull(
          data: (tx) => tx.transactionNo ?? '#${widget.transactionId.substring(0, 8)}',
        ) ??
        '#TX-${widget.transactionId.substring(0, 6)}';
    final statusLabel = txAsync.whenOrNull(
          data: (tx) => _statusLabel(tx.status),
        ) ??
        'Verification In Progress';
    final threadId = 'TR-Chat-${widget.transactionId.substring(0, 6)}';

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.surface,
        foregroundColor: context.fx.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              refLabel,
              style: AppTypography.headlineSm(
                context.fx.primary,
                context: context,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: context.fx.tertiaryFixedDim,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabel.toUpperCase(),
                  style: AppTypography.labelCaps(
                    context.fx.secondary,
                    context: context,
                  ).copyWith(fontSize: 10, letterSpacing: 1),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(auditLogsForEntityProvider(widget.transactionId));
              ref.invalidate(transactionDetailProvider(widget.transactionId));
              if (_conversationId != null) {
                ref.invalidate(messagesListProvider(_conversationId!));
              }
              ref.read(messagingRefreshProvider.notifier).refresh();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: context.fx.surfaceContainerHighest,
              child: Text(
                (profile?.fullName ?? 'U')[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: context.fx.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: (_loadingConversation ||
                    txAsync.isLoading ||
                    logsAsync.isLoading ||
                    messagesAsync.isLoading)
                ? const Center(child: CircularProgressIndicator())
                : logsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (logs) {
                      final messages = messagesAsync.value ?? [];
                      final chatItems = _buildItems(
                        logs: logs,
                        messages: messages,
                        profileId: profile?.id,
                      );

                      if (chatItems.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            FxStitchAuditTrailBadge(threadId: threadId),
                            const SizedBox(height: 24),
                            FxStitchAuditReceivedBubble(
                              senderName: 'System',
                              timestamp: DateFormat('hh:mm a').format(
                                DateTime.now(),
                              ),
                              message:
                                  'No audit discussion yet. Add a comment below.',
                            ),
                          ],
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          FxStitchAuditTrailBadge(threadId: threadId),
                          const SizedBox(height: 16),
                          for (final item in chatItems) item.builder(),
                        ],
                      );
                    },
                  ),
          ),
          if (FeatureFlags.messagingEnabled)
            FxStitchChatInputDock(
              controller: _input,
              sending: _sending,
              onSend: _send,
              onAttach: _attachFile,
              hintText: 'Add a comment for audit...',
              useMicTrailing: true,
            ),
        ],
      ),
    );
  }
}
