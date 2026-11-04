import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';
import 'package:chat_app/features/messages/domain/entities/message.dart';
import 'package:chat_app/features/messages/presentation/pages/fullscreen_map_viewer_page.dart';
import 'package:chat_app/features/messages/presentation/widgets/chat_bubble_theme.dart';
import 'package:chat_app/features/messages/presentation/widgets/location_message_bubble.dart';
import 'package:chat_app/features/messages/presentation/widgets/location_picker_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocalizationService.setLanguage('uz');
  });

  group('TASK 1 & 3: LocationMessageBubble UI & Text Label Removal', () {
    final sampleMessage = Message(
      id: 'loc_test_1',
      senderId: 'user_sender',
      type: MessageType.location,
      isRead: true,
      timestamp: DateTime(2026, 10, 27, 10, 15),
      latitude: 41.311081,
      longitude: 69.240562,
      address: 'Amir Temur Square, Tashkent',
    );

    testWidgets('Confirms "Xarita", "Map", and "Карта" text labels are NOT displayed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LocationMessageBubble(
                message: sampleMessage,
                isMe: true,
              ),
            ),
          ),
        ),
      );

      // Verify that decorative map labels are strictly absent
      expect(find.text('Xarita'), findsNothing);
      expect(find.text('Map'), findsNothing);
      expect(find.text('Карта'), findsNothing);

      // Verify essential address, timestamp, and location pin are visible
      expect(find.text('Amir Temur Square, Tashkent'), findsOneWidget);
      expect(find.text('10:15'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('Fallback coordinates are formatted cleanly when address is null',
        (tester) async {
      final messageWithoutAddress = Message(
        id: 'loc_test_2',
        senderId: 'user_sender',
        type: MessageType.location,
        isRead: true,
        timestamp: DateTime(2026, 10, 27, 11, 00),
        latitude: 41.311081,
        longitude: 69.240562,
        address: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LocationMessageBubble(
                message: messageWithoutAddress,
                isMe: false,
              ),
            ),
          ),
        ),
      );

      // Formatted coordinates should be shown as fallback
      expect(find.text('41.31108, 69.24056'), findsOneWidget);
      expect(find.text('Xarita'), findsNothing);
    });

    testWidgets('Renders properly for both outgoing and incoming message bubble orientations',
        (tester) async {
      final outgoingMsg = sampleMessage;
      final incomingMsg = sampleMessage;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LocationMessageBubble(
                  message: outgoingMsg,
                  isMe: true,
                  position: MessageGroupPosition.single,
                ),
                LocationMessageBubble(
                  message: incomingMsg,
                  isMe: false,
                  position: MessageGroupPosition.single,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(LocationMessageBubble), findsNWidgets(2));
      expect(find.byType(FlutterMap), findsNWidgets(2));
    });
  });

  group('TASK 2, 4 & 5: FullscreenMapViewerPage Navigation & Interaction', () {
    final sampleMessage = Message(
      id: 'loc_test_nav',
      senderId: 'user_sender',
      type: MessageType.location,
      isRead: true,
      timestamp: DateTime(2026, 10, 27, 12, 30),
      latitude: 41.299496,
      longitude: 69.240073,
      address: 'Navoi Theater, Tashkent',
    );

    testWidgets('Tapping LocationMessageBubble opens FullscreenMapViewerPage with exact coordinates',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LocationMessageBubble(
                message: sampleMessage,
                isMe: true,
              ),
            ),
          ),
        ),
      );

      // Verify bubble is rendered
      expect(find.byType(LocationMessageBubble), findsOneWidget);

      // Tap on the location message bubble
      await tester.tap(find.byType(LocationMessageBubble));
      await tester.pumpAndSettle();

      // Verify FullscreenMapViewerPage has opened
      expect(find.byType(FullscreenMapViewerPage), findsOneWidget);

      // Verify exact location address and coordinate formatting in fullscreen viewer
      expect(find.text('Navoi Theater, Tashkent'), findsAtLeastNWidgets(1));
      expect(find.text('41.299496, 69.240073'), findsOneWidget);

      // Verify controls: zoom in, zoom out, recenter, back button
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsAtLeastNWidgets(1));
    });

    testWidgets('Tapping back button in FullscreenMapViewerPage returns to previous screen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LocationMessageBubble(
                message: sampleMessage,
                isMe: true,
              ),
            ),
          ),
        ),
      );

      // Open fullscreen map
      await tester.tap(find.byType(LocationMessageBubble));
      await tester.pumpAndSettle();
      expect(find.byType(FullscreenMapViewerPage), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Confirms returned back to chat screen
      expect(find.byType(FullscreenMapViewerPage), findsNothing);
      expect(find.byType(LocationMessageBubble), findsOneWidget);
    });

    testWidgets('Copy coordinates button copies to clipboard and displays snackbar',
        (tester) async {
      final List<MethodCall> methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        methodCalls.add(call);
        return null;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenMapViewerPage(
            latitude: 41.299496,
            longitude: 69.240073,
            address: 'Navoi Theater, Tashkent',
            messageTime: DateTime(2026, 10, 27, 12, 30),
          ),
        ),
      );

      // Tap copy button in app bar
      final copyButtons = find.byIcon(Icons.copy_rounded);
      expect(copyButtons, findsAtLeastNWidgets(1));
      await tester.tap(copyButtons.first);
      await tester.pump();

      // Verify SnackBar appears with localized confirmation
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(LocalizationService.translate('coordinates_copied')),
        findsOneWidget,
      );

      // Verify clipboard call was made
      final clipboardCalls = methodCalls
          .where((call) => call.method == 'Clipboard.setData')
          .toList();
      expect(clipboardCalls.isNotEmpty, isTrue);
      expect(
        clipboardCalls.first.arguments['text'],
        '41.299496, 69.240073',
      );
    });

    testWidgets('Gracefully handles invalid coordinates (NaN / out-of-range)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FullscreenMapViewerPage(
            latitude: double.nan,
            longitude: 195.0, // Invalid longitude > 180
            address: 'Unknown Point',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Does not render broken map tiles when coordinates are invalid
      expect(find.byType(FlutterMap), findsNothing);

      // Shows graceful error icon and message
      expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);
      expect(
        find.text(LocalizationService.translate('invalid_coordinates')),
        findsOneWidget,
      );

      // Back button is provided to safely return
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('LocationViewerDialog shows FullscreenMapViewerPage for backwards compatibility',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (dialogCtx) => LocationViewerDialog(
                      latitude: 41.311081,
                      longitude: 69.240562,
                      address: 'Tashkent Square',
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Dialog opens FullscreenMapViewerPage directly
      expect(find.byType(FullscreenMapViewerPage), findsOneWidget);
      expect(find.text('Tashkent Square'), findsAtLeastNWidgets(1));
    });
  });
}
