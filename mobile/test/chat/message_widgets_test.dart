import 'package:datingapp/chat/domain/message.dart';
import 'package:datingapp/chat/domain/message_type.dart';
import 'package:datingapp/chat/presentation/message_widgets.dart';
import 'package:datingapp/core/theme/app_colors.dart';
import 'package:datingapp/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Message _text(String body, {DateTime? at}) => Message(
  id: 1,
  conversationId: 1,
  senderId: 1,
  body: body,
  type: MessageType.text,
  attachment: null,
  readAt: null,
  createdAt: at ?? DateTime(2026, 9, 19, 9, 5),
);

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(
    body: Align(alignment: Alignment.bottomCenter, child: child),
  ),
);

Color? _bubbleColor(WidgetTester tester, String text) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration?)?.color;
}

void main() {
  group('MessageBubble', () {
    testWidgets('an outgoing message is brand red with white text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _text('hello'),
            isMine: true,
            showReadReceipt: false,
          ),
        ),
      );

      expect(_bubbleColor(tester, 'hello'), AppColors.primary);
      final style = tester.widget<Text>(find.text('hello')).style;
      expect(style?.color, AppColors.onPrimary);
    });

    testWidgets('an incoming message is the neutral fill with theme text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _text('hello'),
            isMine: false,
            showReadReceipt: false,
          ),
        ),
      );

      expect(_bubbleColor(tester, 'hello'), AppColors.fillLight);
      expect(
        tester.widget<Text>(find.text('hello')).style?.color,
        AppColors.textPrimaryLight,
      );
    });

    testWidgets(
      'incoming text is legible in dark mode (light text on dark fill)',
      (tester) async {
        await tester.pumpWidget(
          _host(
            MessageBubble(
              message: _text('hello'),
              isMine: false,
              showReadReceipt: false,
            ),
            theme: AppTheme.dark,
          ),
        );

        expect(_bubbleColor(tester, 'hello'), AppColors.fillDark);
        expect(
          tester.widget<Text>(find.text('hello')).style?.color,
          AppColors.textPrimaryDark,
        );
      },
    );

    testWidgets('shows the time, and "Read" appended on the last own message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _text('hi'),
            isMine: true,
            showReadReceipt: true,
          ),
        ),
      );
      expect(find.text('09:05 · Read'), findsOneWidget);
    });

    testWidgets('a mid-run bubble shows no time', (tester) async {
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _text('hi'),
            isMine: true,
            showReadReceipt: false,
            showTime: false,
          ),
        ),
      );
      expect(find.text('09:05'), findsNothing);
    });

    testWidgets('draws a day divider only when given a label', (tester) async {
      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _text('hi'),
            isMine: false,
            showReadReceipt: false,
            dateLabel: 'Yesterday',
          ),
        ),
      );
      expect(find.text('Yesterday'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          MessageBubble(
            message: _text('hi'),
            isMine: false,
            showReadReceipt: false,
          ),
        ),
      );
      expect(find.text('Yesterday'), findsNothing);
    });

    testWidgets('a gif with no url falls back to the placeholder', (
      tester,
    ) async {
      final gif = Message(
        id: 2,
        conversationId: 1,
        senderId: 1,
        body: null,
        type: MessageType.gif,
        attachment: null,
        readAt: null,
        createdAt: DateTime(2026, 9, 19, 9, 5),
      );
      await tester.pumpWidget(
        _host(
          MessageBubble(message: gif, isMine: true, showReadReceipt: false),
        ),
      );
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });
  });

  group('MessageComposer', () {
    Widget composer({
      required TextEditingController controller,
      bool sending = false,
      bool attachmentBusy = false,
      VoidCallback? onSend,
      VoidCallback? onAttachment,
      ValueChanged<String>? onChanged,
    }) => _host(
      MessageComposer(
        controller: controller,
        sending: sending,
        attachmentBusy: attachmentBusy,
        onChanged: onChanged ?? (_) {},
        onSend: onSend ?? () {},
        onAttachment: onAttachment ?? () {},
      ),
    );

    testWidgets('send turns brand red once there is text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(composer(controller: controller));

      Color sendColor() => tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.byIcon(Icons.arrow_upward_rounded),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;

      expect(sendColor(), AppColors.fillLight);
      controller.text = 'hey';
      await tester.pump();
      expect(sendColor(), AppColors.primary);
    });

    testWidgets('typing reports changes, send and attach fire callbacks', (
      tester,
    ) async {
      final controller = TextEditingController();
      var sent = 0;
      var attached = 0;
      String? changed;
      await tester.pumpWidget(
        composer(
          controller: controller,
          onSend: () => sent++,
          onAttachment: () => attached++,
          onChanged: (v) => changed = v,
        ),
      );

      await tester.enterText(find.byType(TextField), 'hi there');
      expect(changed, 'hi there');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.tap(find.byIcon(Icons.add_rounded));

      expect(sent, 1);
      expect(attached, 1);
    });

    testWidgets('while sending, neither button fires', (tester) async {
      final controller = TextEditingController();
      var sent = 0;
      var attached = 0;
      await tester.pumpWidget(
        composer(
          controller: controller,
          sending: true,
          onSend: () => sent++,
          onAttachment: () => attached++,
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      // The send button shows a spinner while sending.
      await tester.tap(find.byType(CircularProgressIndicator));

      expect(sent, 0);
      expect(attached, 0);
    });
  });

  group('RecordingBar', () {
    testWidgets('shows elapsed time; stop and discard fire callbacks', (
      tester,
    ) async {
      var stopped = 0;
      var cancelled = 0;
      await tester.pumpWidget(
        _host(
          RecordingBar(
            elapsed: const Duration(minutes: 1, seconds: 5),
            onCancel: () => cancelled++,
            onStop: () => stopped++,
          ),
        ),
      );

      expect(find.text('Recording… 1:05'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      expect(stopped, 1);
      expect(cancelled, 1);
    });
  });

  group('SubscriptionRequiredBanner', () {
    testWidgets('Upgrade calls back', (tester) async {
      var upgraded = 0;
      await tester.pumpWidget(
        _host(SubscriptionRequiredBanner(onUpgrade: () async => upgraded++)),
      );

      expect(find.textContaining('Subscribe to message'), findsOneWidget);
      await tester.tap(find.text('Upgrade'));
      expect(upgraded, 1);
    });
  });
}
