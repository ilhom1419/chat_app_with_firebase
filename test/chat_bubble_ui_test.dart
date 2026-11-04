import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:chat_app/features/messages/domain/entities/message.dart';
import 'package:chat_app/features/messages/presentation/widgets/chat_bubble_theme.dart';
import 'package:chat_app/features/messages/presentation/widgets/location_message_bubble.dart';
import 'package:chat_app/features/messages/presentation/widgets/file_bubble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatBubbleTheme — Morphology & Radii', () {
    test('Outgoing bubble radii follow Telegram/iMessage design system', () {
      final singleRadius =
          ChatBubbleTheme.getBubbleRadius(true, MessageGroupPosition.single);
      final firstRadius =
          ChatBubbleTheme.getBubbleRadius(true, MessageGroupPosition.first);
      final middleRadius =
          ChatBubbleTheme.getBubbleRadius(true, MessageGroupPosition.middle);
      final lastRadius =
          ChatBubbleTheme.getBubbleRadius(true, MessageGroupPosition.last);

      // Single: 18 all corners except bottom-right 4
      expect(singleRadius.topLeft, const Radius.circular(18));
      expect(singleRadius.topRight, const Radius.circular(18));
      expect(singleRadius.bottomLeft, const Radius.circular(18));
      expect(singleRadius.bottomRight, const Radius.circular(4));

      // First: 18 all corners except bottom-right 6
      expect(firstRadius.topLeft, const Radius.circular(18));
      expect(firstRadius.topRight, const Radius.circular(18));
      expect(firstRadius.bottomLeft, const Radius.circular(18));
      expect(firstRadius.bottomRight, const Radius.circular(6));

      // Middle: Left 18, Right 6
      expect(middleRadius.topLeft, const Radius.circular(18));
      expect(middleRadius.topRight, const Radius.circular(6));
      expect(middleRadius.bottomLeft, const Radius.circular(18));
      expect(middleRadius.bottomRight, const Radius.circular(6));

      // Last: Left 18, Top-right 6, Bottom-right 4
      expect(lastRadius.topLeft, const Radius.circular(18));
      expect(lastRadius.topRight, const Radius.circular(6));
      expect(lastRadius.bottomLeft, const Radius.circular(18));
      expect(lastRadius.bottomRight, const Radius.circular(4));
    });

    test('Incoming bubble radii follow coordinated mirrored corners', () {
      final singleRadius =
          ChatBubbleTheme.getBubbleRadius(false, MessageGroupPosition.single);
      final firstRadius =
          ChatBubbleTheme.getBubbleRadius(false, MessageGroupPosition.first);
      final middleRadius =
          ChatBubbleTheme.getBubbleRadius(false, MessageGroupPosition.middle);
      final lastRadius =
          ChatBubbleTheme.getBubbleRadius(false, MessageGroupPosition.last);

      // Single: 18 all corners except bottom-left 4
      expect(singleRadius.topLeft, const Radius.circular(18));
      expect(singleRadius.topRight, const Radius.circular(18));
      expect(singleRadius.bottomRight, const Radius.circular(18));
      expect(singleRadius.bottomLeft, const Radius.circular(4));

      // First: 18 all corners except bottom-left 6
      expect(firstRadius.topLeft, const Radius.circular(18));
      expect(firstRadius.topRight, const Radius.circular(18));
      expect(firstRadius.bottomRight, const Radius.circular(18));
      expect(firstRadius.bottomLeft, const Radius.circular(6));

      // Middle: Right 18, Left 6
      expect(middleRadius.topRight, const Radius.circular(18));
      expect(middleRadius.bottomRight, const Radius.circular(18));
      expect(middleRadius.topLeft, const Radius.circular(6));
      expect(middleRadius.bottomLeft, const Radius.circular(6));

      // Last: Right 18, Top-left 6, Bottom-left 4
      expect(lastRadius.topRight, const Radius.circular(18));
      expect(lastRadius.bottomRight, const Radius.circular(18));
      expect(lastRadius.topLeft, const Radius.circular(6));
      expect(lastRadius.bottomLeft, const Radius.circular(4));
    });
  });

  group('ChatBubbleTheme — Spacing & Margins', () {
    test('Grouped messages have compact 2.5px spacing vs 9px for separated', () {
      final singleMargin =
          ChatBubbleTheme.getBubbleMargin(MessageGroupPosition.single);
      final firstMargin =
          ChatBubbleTheme.getBubbleMargin(MessageGroupPosition.first);
      final middleMargin =
          ChatBubbleTheme.getBubbleMargin(MessageGroupPosition.middle);
      final lastMargin =
          ChatBubbleTheme.getBubbleMargin(MessageGroupPosition.last);

      expect(singleMargin.bottom, equals(9.0));
      expect(firstMargin.bottom, equals(2.5));
      expect(middleMargin.bottom, equals(2.5));
      expect(lastMargin.bottom, equals(9.0));
    });
  });

  group('ChatBubbleTheme — Grouping Calculation Algorithm', () {
    test('Calculates single, first, middle, last for consecutive messages within 5 mins', () {
      final baseTime = DateTime(2026, 10, 22, 14, 0);

      // 3 consecutive messages from 'userA' within 1 minute each
      final msg1 = Message(
        id: '1',
        senderId: 'userA',
        text: 'First',
        type: MessageType.text,
        isRead: true,
        timestamp: baseTime,
      );
      final msg2 = Message(
        id: '2',
        senderId: 'userA',
        text: 'Second',
        type: MessageType.text,
        isRead: true,
        timestamp: baseTime.add(const Duration(seconds: 30)),
      );
      final msg3 = Message(
        id: '3',
        senderId: 'userA',
        text: 'Third',
        type: MessageType.text,
        isRead: true,
        timestamp: baseTime.add(const Duration(minutes: 1)),
      );

      final messages = [msg1, msg2, msg3];

      expect(ChatBubbleTheme.calculateGroupPosition(messages, 0, 'userA'),
          equals(MessageGroupPosition.first));
      expect(ChatBubbleTheme.calculateGroupPosition(messages, 1, 'userA'),
          equals(MessageGroupPosition.middle));
      expect(ChatBubbleTheme.calculateGroupPosition(messages, 2, 'userA'),
          equals(MessageGroupPosition.last));
    });

    test('Messages > 5 mins apart are treated as separate groups', () {
      final baseTime = DateTime(2026, 10, 22, 14, 0);

      final msg1 = Message(
        id: '1',
        senderId: 'userA',
        text: 'Old msg',
        type: MessageType.text,
        isRead: true,
        timestamp: baseTime,
      );
      final msg2 = Message(
        id: '2',
        senderId: 'userA',
        text: 'New msg after 10 mins',
        type: MessageType.text,
        isRead: true,
        timestamp: baseTime.add(const Duration(minutes: 10)),
      );

      final messages = [msg1, msg2];

      expect(ChatBubbleTheme.calculateGroupPosition(messages, 0, 'userA'),
          equals(MessageGroupPosition.single));
      expect(ChatBubbleTheme.calculateGroupPosition(messages, 1, 'userA'),
          equals(MessageGroupPosition.single));
    });

    test('Alternating sender IDs produce single message positions', () {
      final baseTime = DateTime(2026, 10, 22, 14, 0);

      final msg1 = Message(
        id: '1',
        senderId: 'userA',
        text: 'Hello',
        type: MessageType.text,
        isRead: true,
        timestamp: baseTime,
      );
      final msg2 = Message(
        id: '2',
        senderId: 'userB',
        text: 'Hi',
        type: MessageType.text,
        isRead: true,
        timestamp: baseTime.add(const Duration(seconds: 10)),
      );

      final messages = [msg1, msg2];

      expect(ChatBubbleTheme.calculateGroupPosition(messages, 0, 'userA'),
          equals(MessageGroupPosition.single));
      expect(ChatBubbleTheme.calculateGroupPosition(messages, 1, 'userA'),
          equals(MessageGroupPosition.single));
    });
  });

  group('ChatBubbleTheme — Visual Brand Identity & Colors', () {
    test('Outgoing decoration uses Kakku Indigo-Violet LinearGradient', () {
      final dec = ChatBubbleTheme.getBubbleDecoration(
        isMe: true,
        isDark: false,
        position: MessageGroupPosition.single,
      );

      expect(dec.gradient, isNotNull);
      final gradient = dec.gradient as LinearGradient;
      expect(gradient.colors.first, equals(const Color(0xFF6366F1))); // Indigo-500
      expect(gradient.colors.last, equals(const Color(0xFF4F46E5))); // Indigo-600
    });

    test('Incoming light decoration has crisp white background with subtle border', () {
      final dec = ChatBubbleTheme.getBubbleDecoration(
        isMe: false,
        isDark: false,
        position: MessageGroupPosition.single,
      );

      expect(dec.color, equals(Colors.white));
      expect(dec.border, isNotNull);
    });

    test('Incoming dark decoration uses sleek dark slate (#1E293B)', () {
      final dec = ChatBubbleTheme.getBubbleDecoration(
        isMe: false,
        isDark: true,
        position: MessageGroupPosition.single,
      );

      expect(dec.color, equals(const Color(0xFF1E293B)));
    });

    test('High-contrast typography colors for readability', () {
      // Outgoing: pure white text
      expect(ChatBubbleTheme.getTextColor(isMe: true, isDark: false),
          equals(Colors.white));
      expect(ChatBubbleTheme.getTextColor(isMe: true, isDark: true),
          equals(Colors.white));

      // Incoming: light mode dark slate, dark mode crisp slate-50
      expect(ChatBubbleTheme.getTextColor(isMe: false, isDark: false),
          equals(const Color(0xFF0F172A)));
      expect(ChatBubbleTheme.getTextColor(isMe: false, isDark: true),
          equals(const Color(0xFFF8FAFC)));
    });
  });

  group('LocationMessageBubble — Widget Rendering', () {
    testWidgets('Renders modern 140px OSM map preview, red pin, address and time',
        (tester) async {
      final testMsg = Message(
        id: 'loc_1',
        senderId: 'user_1',
        type: MessageType.location,
        isRead: true,
        timestamp: DateTime(2026, 10, 22, 14, 30),
        latitude: 41.311081,
        longitude: 69.240562,
        address: 'Tashkent City, Amir Temur Square',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LocationMessageBubble(
                message: testMsg,
                isMe: true,
                position: MessageGroupPosition.single,
                statusWidget: const Icon(Icons.done_all, size: 14),
              ),
            ),
          ),
        ),
      );

      // Address text should be visible
      expect(find.text('Tashkent City, Amir Temur Square'), findsOneWidget);

      // Pin marker should be rendered
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);

      // Formatted timestamp (14:30) should be present
      expect(find.text('14:30'), findsOneWidget);

      // Status icon should be present
      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });
  });

  group('FileBubble — Widget Rendering', () {
    testWidgets('Renders clean file badge, filename, and file size',
        (tester) async {
      final fileMsg = Message(
        id: 'file_1',
        senderId: 'user_1',
        type: MessageType.file,
        isRead: true,
        timestamp: DateTime(2026, 10, 22, 15, 0),
        fileUrl: 'https://example.com/project_spec.pdf',
        fileName: 'project_spec.pdf',
        fileSize: '2.4 MB',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FileBubble(
                message: fileMsg,
                isMe: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('project_spec.pdf'), findsOneWidget);
      expect(find.text('2.4 MB'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);
    });
  });

  group('Chat Bubble Layout — Short vs Multiline Intrinsic Sizing', () {
    testWidgets('Short message hugs text content without expanding to full width',
        (tester) async {
      const shortText = 'Ok';
      final isDark = false;
      final isMe = true;
      final decoration = ChatBubbleTheme.getBubbleDecoration(
        isMe: isMe,
        isDark: isDark,
        position: MessageGroupPosition.single,
      );

      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  key: key,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  constraints: const BoxConstraints(maxWidth: 400 * 0.78),
                  decoration: decoration,
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          shortText,
                          style: TextStyle(fontSize: 15),
                        ),
                        SizedBox(height: 3),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '12:00',
                                style: TextStyle(fontSize: 10),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.done, size: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final RenderBox renderBox =
          key.currentContext!.findRenderObject() as RenderBox;
      final bubbleWidth = renderBox.size.width;

      // Max width allowed was 400 * 0.78 = 312px.
      // A short message "Ok" + "12:00" + padding should hug around 70-100px and be far less than 312px!
      expect(bubbleWidth, lessThan(120.0));
      expect(bubbleWidth, greaterThan(40.0));
    });

    testWidgets('Multiline text wraps within maxWidth and trailing timestamp does not overlap text',
        (tester) async {
      const longText =
          'This is a comprehensive multiline message designed to test proper wrapping, padding, and edge alignment without colliding with the bottom-right timestamp.';
      final isDark = false;
      final isMe = false;
      final decoration = ChatBubbleTheme.getBubbleDecoration(
        isMe: isMe,
        isDark: isDark,
        position: MessageGroupPosition.single,
      );

      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  key: key,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  constraints: const BoxConstraints(maxWidth: 400 * 0.78),
                  decoration: decoration,
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          longText,
                          style: TextStyle(fontSize: 15),
                        ),
                        SizedBox(height: 3),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '12:05',
                                style: TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final RenderBox renderBox =
          key.currentContext!.findRenderObject() as RenderBox;
      final bubbleWidth = renderBox.size.width;

      // Bounded by maxWidth (400 * 0.78 = 312px)
      expect(bubbleWidth, lessThanOrEqualTo(312.0));
      // Text and timestamp are distinct widgets separated vertically
      expect(find.text(longText), findsOneWidget);
      expect(find.text('12:05'), findsOneWidget);
    });
  });

  group('Date Separator Formatting', () {
    test('Correctly identifies Today and Yesterday and formats older dates', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10, 30);
      final yesterday = today.subtract(const Duration(days: 1));
      final older = DateTime(2026, 5, 15, 9, 0);

      String formatDate(DateTime dt, String locale) {
        final dNow = DateTime.now();
        final isToday = dt.year == dNow.year &&
            dt.month == dNow.month &&
            dt.day == dNow.day;
        final dYesterday = dNow.subtract(const Duration(days: 1));
        final isYesterday = dt.year == dYesterday.year &&
            dt.month == dYesterday.month &&
            dt.day == dYesterday.day;

        if (isToday) {
          return locale == 'uz'
              ? 'Bugun'
              : (locale == 'ru' ? 'Сегодня' : 'Today');
        }
        if (isYesterday) {
          return locale == 'uz'
              ? 'Kecha'
              : (locale == 'ru' ? 'Вчера' : 'Yesterday');
        }
        return DateFormat('d MMMM').format(dt);
      }

      expect(formatDate(today, 'uz'), equals('Bugun'));
      expect(formatDate(today, 'en'), equals('Today'));
      expect(formatDate(yesterday, 'uz'), equals('Kecha'));
      expect(formatDate(yesterday, 'ru'), equals('Вчера'));
      expect(formatDate(older, 'en'), equals('15 May'));
    });
  });
}
