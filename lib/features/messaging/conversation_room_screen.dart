import 'package:accounts_manager/app/theme/app_colors.dart';
import 'package:accounts_manager/core/widgets/obsidian/fx_page_scaffold.dart';
import 'package:accounts_manager/domain/models/fx_message.dart';
import 'package:accounts_manager/features/auth/providers/app_providers.dart';
import 'package:accounts_manager/features/auth/providers/messaging_providers.dart';
import 'package:accounts_manager/features/messaging/widgets/message_bubble.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      messagesListProvider(widget.conversationId),
    );
    final profile = ref.watch(currentProfileProvider).value;

    return FxPageScaffold(
      title: const Text('Conversation'),
      fallbackRoute: '/messages',
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (messages) => ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, i) => MessageBubble(
                  message: messages[i],
                  isMine: profile != null && messages[i].senderId == profile.id,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _attachFile,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: InputDecoration(
                        hintText: 'Message…',
                        filled: true,
                        fillColor: context.fx.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: _sending ? null : (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: _sending ? null : () => _send(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
