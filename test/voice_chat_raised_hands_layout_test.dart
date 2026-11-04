import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/design_system/app_colors.dart';
import 'package:chat_app/core/localization/localization_service.dart';
import 'package:chat_app/features/voice_chat/domain/entities/voice_chat.dart';
import 'package:chat_app/features/voice_chat/presentation/pages/voice_chat_room_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocalizationService.langNotifier.value = 'uz';
  });

  final testParticipant = VoiceChatParticipant(
    userId: 'user_anna_123',
    name: 'Anna Mariya',
    photo: null,
    isHost: false,
    canSpeak: false,
    isMuted: true,
    isSpeaking: false,
    isHandRaised: true,
    joinedAt: DateTime(2026, 1, 1),
  );

  group('Voice Chat Raised Hands Layout & Moderator Actions Tests', () {
    testWidgets('1 & 2 & 3: Both action icons display with correct semantic colors (Green check, Red X)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceChatHandRaisedItem(
              participant: testParticipant,
              isHostUser: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find icons
      final checkIconFinder = find.byIcon(Icons.check_rounded);
      final closeIconFinder = find.byIcon(Icons.close_rounded);

      expect(checkIconFinder, findsOneWidget);
      expect(closeIconFinder, findsOneWidget);

      final checkIcon = tester.widget<Icon>(checkIconFinder);
      final closeIcon = tester.widget<Icon>(closeIconFinder);

      expect(checkIcon.color, equals(AppColors.online));
      expect(closeIcon.color, equals(Colors.redAccent));
    });

    testWidgets('4 & 5: Both action buttons have identical visual sizing and meet >=44dp touch target standards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceChatHandRaisedItem(
              participant: testParticipant,
              isHostUser: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final inkWells = find.descendant(
        of: find.byType(VoiceChatHandRaisedItem),
        matching: find.byType(InkWell),
      );
      expect(inkWells, findsNWidgets(2));

      final approveSize = tester.getSize(inkWells.first);
      final rejectSize = tester.getSize(inkWells.last);

      // Sizing parity
      expect(approveSize.width, equals(rejectSize.width));
      expect(approveSize.height, equals(rejectSize.height));

      // Minimum practical touch target >= 44x44
      expect(approveSize.width, greaterThanOrEqualTo(44.0));
      expect(approveSize.height, greaterThanOrEqualTo(44.0));

      // Both buttons are vertically aligned along the same center line
      final approveCenter = tester.getCenter(inkWells.first);
      final rejectCenter = tester.getCenter(inkWells.last);
      expect((approveCenter.dy - rejectCenter.dy).abs(), lessThan(1.0));
    });

    testWidgets('6 & 7: Participant name and raised-hand status display clearly without overlapping actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceChatHandRaisedItem(
              participant: testParticipant,
              isHostUser: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anna Mariya'), findsOneWidget);
      expect(find.text("So'z olmoqchi (Raised Hand)"), findsOneWidget);

      final nameRect = tester.getRect(find.text('Anna Mariya'));
      final approveRect = tester.getRect(find.byIcon(Icons.check_rounded));
      final rejectRect = tester.getRect(find.byIcon(Icons.close_rounded));

      // Name must be to the left of the actions with positive spacing
      expect(nameRect.right, lessThan(approveRect.left));
      expect(approveRect.right, lessThan(rejectRect.left));
    });

    testWidgets('8: Extremely long participant names do not overflow or overlap actions', (tester) async {
      final longNameParticipant = VoiceChatParticipant(
        userId: 'user_long_name',
        name: 'Alexander Maximilian Ferdinand von Hohenzollern-Sigmaringen The Third',
        photo: null,
        isHost: false,
        canSpeak: false,
        isMuted: true,
        isSpeaking: false,
        isHandRaised: true,
        joinedAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: VoiceChatHandRaisedItem(
                participant: longNameParticipant,
                isHostUser: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      final nameRect = tester.getRect(find.text(longNameParticipant.name));
      final approveRect = tester.getRect(find.byIcon(Icons.check_rounded));
      expect(nameRect.right, lessThanOrEqualTo(approveRect.left));
    });

    testWidgets('9: Narrow / small screen widths (280dp) adapt responsively without RenderFlex overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 270,
              child: VoiceChatHandRaisedItem(
                participant: testParticipant,
                isHostUser: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('10: High text scale factor (2.0x) remains usable and does not throw RenderFlex error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SizedBox(
                width: 360,
                child: VoiceChatHandRaisedItem(
                  participant: testParticipant,
                  isHostUser: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('11 & 12: Approve and Reject callbacks are properly invoked on tap', (tester) async {
      bool approved = false;
      bool rejected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceChatHandRaisedItem(
              participant: testParticipant,
              isHostUser: true,
              onApprove: () => approved = true,
              onReject: () => rejected = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap approve
      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();
      expect(approved, isTrue);
      expect(rejected, isFalse);

      // Tap reject
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(rejected, isTrue);
    });

    testWidgets('13: Non-host participants (isHostUser: false) do not see moderator action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceChatHandRaisedItem(
              participant: testParticipant,
              isHostUser: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.text('Anna Mariya'), findsOneWidget);
    });

    testWidgets('14: Accessibility semantics and tooltips are localized across Uzbek, English, and Russian', (tester) async {
      for (final lang in ['uz', 'en', 'ru']) {
        LocalizationService.langNotifier.value = lang;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceChatHandRaisedItem(
                participant: testParticipant,
                isHostUser: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final approveTooltip = LocalizationService.translate('voice_chat_approve_speaker');
        final rejectTooltip = LocalizationService.translate('voice_chat_reject_speaker');

        expect(find.byTooltip(approveTooltip), findsOneWidget);
        expect(find.byTooltip(rejectTooltip), findsOneWidget);

        expect(find.bySemanticsLabel(approveTooltip), findsOneWidget);
        expect(find.bySemanticsLabel(rejectTooltip), findsOneWidget);
      }
    });
  });
}
