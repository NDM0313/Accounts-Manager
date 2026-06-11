import 'package:accounts_manager/features/messaging/widgets/message_bubble.dart';
import 'package:accounts_manager/domain/models/fx_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MessageBubble renders body', (tester) async {
    final msg = FxMessage(
      id: 'm1',
      conversationId: 'c1',
      senderId: 'u1',
      messageType: FxMessageType.text,
      body: 'Hello team',
      createdAt: DateTime.now(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MessageBubble(message: msg, isMine: true)),
      ),
    );
    expect(find.text('Hello team'), findsOneWidget);
  });
}
