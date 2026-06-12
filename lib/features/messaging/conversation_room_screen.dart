import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/app/theme/app_typography.dart';
import 'package:accounts_manager/domain/models/fx_conversation.dart';
import 'package:accounts_manager/domain/models/fx_message.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/messaging_providers.dart';
import 'package:accounts_manager/core/widgets/premium/fx_chat_bubble.dart';
import 'package:accounts_manager/core/widgets/premium/stitch/fx_stitch_chat_widgets.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConversationRoomScreen extends ConsumerStatefulWidget {
  const ConversationRoomScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationRoomScreen> createState() =>
      _ConversationRoomScreenState();
}

class _ConversationRoomScreenState
    extends ConsumerState<ConversationRoomScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messagingRepositoryProvider).markRead(widget.conversationId);
      ref.read(messagingRefreshProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send({
    FxMessageType type = FxMessageType.text,
    Map<String, dynamic> metadata = const {},
  }) async {
    final text = _input.text.trim();
    if (text.isEmpty && type == FxMessageType.text) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(messagingRepositoryProvider)
          .sendMessage(
            conversationId: widget.conversationId,
            body: text,
            type: type,
            metadata: metadata,
          );
      _input.clear();
      ref.read(messagingRefreshProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attachFile() async {
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

    final msgId = await ref
        .read(messagingRepositoryProvider)
        .sendMessage(
          conversationId: widget.conversationId,
          body: file.name,
          type: file.extension == 'pdf'
              ? FxMessageType.file
              : FxMessageType.image,
          metadata: {'file_name': file.name},
        );

    await ref
        .read(attachmentRepositoryProvider)
        .upload(
          branchId: profile.branchId,
          bytes: file.bytes!,
          fileName: file.name,
          mimeType: file.extension == 'pdf' ? 'application/pdf' : 'image/jpeg',
          messageId: msgId,
        );
    ref.read(messagingRefreshProvider.notifier).refresh();
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return 'JD';
    return name.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      messagesListProvider(widget.conversationId),
    );
    final conversationsAsync = ref.watch(conversationsListProvider);
    final profile = ref.watch(currentProfileProvider).value;
    FxConversation? conversation;
    if (conversationsAsync.hasValue) {
      for (final c in conversationsAsync.value!) {
        if (c.id == widget.conversationId) {
          conversation = c;
          break;
        }
      }
    }
    final convTitle = conversation?.title;

    return Scaffold(
      backgroundColor: context.fx.background,
      appBar: AppBar(
        backgroundColor: context.fx.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'FX Cash Ledger',
          style: AppTypography.headlineSm(
            context.fx.primary,
            context: context,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(messagesListProvider(widget.conversationId));
              ref.read(messagingRefreshProvider.notifier).refresh();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: context.fx.secondaryContainer,
              child: Text(
                _initials(profile?.fullName ?? profile?.email),
                style: TextStyle(
                  color: context.fx.onSecondaryContainer,
                  fontSize: 11,
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
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (messages) {
                final dayFmt = DateFormat('EEEE, MMM d');
                final timeFmt = DateFormat('hh:mm a');
                final items = <Widget>[];

                if (convTitle != null && convTitle.isNotEmpty) {
                  items.add(
                    FxStitchLinkedTransactionCard(
                      refLabel: convTitle,
                      subtitle: conversation?.type.name.toUpperCase() ?? 'Deal',
                      amountLabel: '—',
                      statusLabel: 'PENDING APPROVAL',
                    ),
                  );
                  items.add(const SizedBox(height: 12));
                }

                String? lastDay;
                for (final m in messages) {
                  final day = dayFmt.format(m.createdAt.toLocal());
                  if (day != lastDay) {
                    lastDay = day;
                    items.add(FxStitchChatDayDivider(label: day));
                  }
                  final isMine =
                      profile != null && m.senderId == profile.id;
                  final ts = timeFmt.format(m.createdAt.toLocal());

                  if (m.messageType == FxMessageType.file &&
                      m.metadata['file_name'] != null) {
                    items.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: FxStitchVoiceNoteBubble(
                          fileSizeLabel: m.body,
                        ),
                      ),
                    );
                    continue;
                  }

                  items.add(
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FxChatBubble(
                        message: m.body,
                        timestamp: ts,
                        isSelf: isMine,
                        senderName: isMine ? 'You' : 'Team',
                        readReceipt: isMine ? 'Read' : null,
                      ),
                    ),
                  );
                }

                if (items.isEmpty) {
                  items.add(
                    FxStitchChatDayDivider(
                      label: dayFmt.format(DateTime.now()),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: items,
                );
              },
            ),
          ),
          FxStitchChatInputDock(
            controller: _input,
            sending: _sending,
            onSend: () => _send(),
            onAttach: _attachFile,
          ),
        ],
      ),
    );
  }
}
