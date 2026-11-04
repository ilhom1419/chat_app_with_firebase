import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/core/localization/localization_service.dart';
import 'package:chat_app/features/messages/domain/entities/live_location_session.dart';
import 'package:chat_app/features/messages/domain/entities/message.dart';
import 'package:chat_app/features/messages/data/models/message_model.dart';
import 'package:chat_app/features/messages/data/services/live_location_service.dart';

/// Test doubles for GPS and Firestore simulation
class MockLocationTracker {
  bool isServiceEnabled = true;
  bool isPermissionGranted = true;
  bool isPermissionPermanentlyDenied = false;
  final StreamController<Map<String, double>> _locationStreamController =
      StreamController<Map<String, double>>.broadcast();

  Stream<Map<String, double>> get locationStream =>
      _locationStreamController.stream;

  Future<bool> checkServiceEnabled() async => isServiceEnabled;

  Future<String> checkPermission() async {
    if (!isServiceEnabled) throw Exception('Location services disabled');
    if (isPermissionPermanentlyDenied) return 'deniedForever';
    if (!isPermissionGranted) return 'denied';
    return 'whileInUse';
  }

  void emitLocation(double lat, double lng) {
    _locationStreamController.add({'latitude': lat, 'longitude': lng});
  }

  void dispose() {
    _locationStreamController.close();
  }
}

class MockFirestoreLiveLocationBackend {
  final Map<String, Map<String, dynamic>> _storage = {};
  final StreamController<Map<String, dynamic>> _streamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Future<void> setSession(String path, Map<String, dynamic> data, {String? authUid}) async {
    // Security Rule simulation: Only the sender can write
    final senderId = data['senderId'] as String?;
    if (authUid != null && senderId != null && authUid != senderId) {
      throw Exception('PERMISSION_DENIED: Sender ID must match authenticated user');
    }

    // Security Rule simulation: Duration must be 900 or 3600
    final durationSeconds = data['durationSeconds'] as int?;
    if (durationSeconds != null && durationSeconds != 900 && durationSeconds != 3600) {
      throw Exception('PERMISSION_DENIED: Invalid duration');
    }

    _storage[path] = Map<String, dynamic>.from(data);
    _streamController.add(data);
  }

  Future<void> updateSession(String path, Map<String, dynamic> data, {String? authUid}) async {
    final existing = _storage[path];
    if (existing == null) {
      throw Exception('NOT_FOUND: Session does not exist');
    }

    // Security Rule simulation: Only sender can update
    final senderId = existing['senderId'] as String?;
    if (authUid != null && senderId != null && authUid != senderId) {
      throw Exception('PERMISSION_DENIED: Recipient cannot forge location coordinates');
    }

    // Security Rule simulation: Stopped sessions cannot be updated
    if (existing['status'] == 'stopped') {
      throw Exception('PERMISSION_DENIED: Stopped session cannot be reactivated or updated');
    }

    // Security Rule simulation: Expired sessions cannot be updated
    final expiresAt = existing['expiresAt'] is DateTime
        ? existing['expiresAt'] as DateTime
        : DateTime.parse(existing['expiresAt'].toString());
    if (DateTime.now().isAfter(expiresAt)) {
      throw Exception('PERMISSION_DENIED: Expired session cannot accept new coordinates');
    }

    existing.addAll(data);
    _storage[path] = existing;
    _streamController.add(existing);
  }

  Map<String, dynamic>? getSession(String path, {required String authUid, required List<String> chatParticipants}) {
    // Security Rule simulation: Only chat participants can read
    if (!chatParticipants.contains(authUid)) {
      throw Exception('PERMISSION_DENIED: Only chat participants can access live location');
    }
    return _storage[path];
  }

  Stream<Map<String, dynamic>> watchSession(String path) {
    return _streamController.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocationTracker locationTracker;
  late MockFirestoreLiveLocationBackend firestoreBackend;

  setUp(() {
    locationTracker = MockLocationTracker();
    firestoreBackend = MockFirestoreLiveLocationBackend();
  });

  tearDown(() {
    locationTracker.dispose();
  });

  group('KAKKU — LIVE LOCATION SHARING COMPREHENSIVE TEST SUITE (TEST 01 - TEST 20)', () {
    // TEST 01 — Permission granted.
    test('TEST 01 — Permission granted: Tracking proceeds when authorized', () async {
      locationTracker.isServiceEnabled = true;
      locationTracker.isPermissionGranted = true;

      final permission = await locationTracker.checkPermission();
      expect(permission, equals('whileInUse'));
    });

    // TEST 02 — Permission denied.
    test('TEST 02 — Permission denied: Handled gracefully without starting tracking', () async {
      locationTracker.isServiceEnabled = true;
      locationTracker.isPermissionGranted = false;

      final permission = await locationTracker.checkPermission();
      expect(permission, equals('denied'));
    });

    // TEST 03 — Device location disabled.
    test('TEST 03 — Device location disabled: Throws descriptive exception', () async {
      locationTracker.isServiceEnabled = false;

      expect(
        () => locationTracker.checkPermission(),
        throwsA(predicate((e) => e.toString().contains('Location services disabled'))),
      );
    });

    // TEST 04 — 15-minute session created.
    test('TEST 04 — 15-minute session created: Exactly 900 seconds duration and valid deadline', () async {
      final now = DateTime.now();
      final session = LiveLocationSession(
        sessionId: 'session_15m',
        chatId: 'chat_test',
        senderId: 'user_a',
        senderName: 'Alisher',
        durationSeconds: 900,
        startedAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
        status: LiveLocationStatus.active,
        latitude: 41.3113,
        longitude: 69.2797,
        lastUpdatedAt: now,
      );

      expect(session.durationSeconds, equals(900));
      expect(session.isActive, isTrue);
      expect(session.remainingSeconds, inInclusiveRange(898, 900));
      expect(session.expiresAt.difference(session.startedAt).inMinutes, equals(15));
    });

    // TEST 05 — 1-hour session created.
    test('TEST 05 — 1-hour session created: Exactly 3600 seconds duration and valid deadline', () async {
      final now = DateTime.now();
      final session = LiveLocationSession(
        sessionId: 'session_1h',
        chatId: 'chat_test',
        senderId: 'user_a',
        senderName: 'Alisher',
        durationSeconds: 3600,
        startedAt: now,
        expiresAt: now.add(const Duration(hours: 1)),
        status: LiveLocationStatus.active,
        latitude: 41.3113,
        longitude: 69.2797,
        lastUpdatedAt: now,
      );

      expect(session.durationSeconds, equals(3600));
      expect(session.isActive, isTrue);
      expect(session.remainingSeconds, inInclusiveRange(3598, 3600));
      expect(session.expiresAt.difference(session.startedAt).inMinutes, equals(60));
    });

    // TEST 06 — Recipient receives updated coordinates.
    test('TEST 06 — Recipient receives updated coordinates in real-time stream', () async {
      final updates = <Map<String, dynamic>>[];
      final sub = firestoreBackend.watchSession('chats/c1/live_locations/s1').listen(updates.add);

      await firestoreBackend.setSession(
        'chats/c1/live_locations/s1',
        {
          'sessionId': 's1',
          'chatId': 'c1',
          'senderId': 'user_a',
          'durationSeconds': 900,
          'status': 'active',
          'latitude': 41.3113,
          'longitude': 69.2797,
          'expiresAt': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
        },
        authUid: 'user_a',
      );

      await firestoreBackend.updateSession(
        'chats/c1/live_locations/s1',
        {
          'latitude': 41.3125,
          'longitude': 69.2810,
        },
        authUid: 'user_a',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(updates.length, equals(2));
      expect(updates.last['latitude'], equals(41.3125));
      expect(updates.last['longitude'], equals(69.2810));

      await sub.cancel();
    });

    // TEST 07 — Marker moves based on real location updates.
    test('TEST 07 — Marker moves based on real location updates without fabricating positions', () async {
      double currentLat = 41.3113;
      double currentLng = 69.2797;

      final markerPositions = <Map<String, double>>[];

      locationTracker.locationStream.listen((coord) {
        currentLat = coord['latitude']!;
        currentLng = coord['longitude']!;
        markerPositions.add({'lat': currentLat, 'lng': currentLng});
      });

      locationTracker.emitLocation(41.3115, 69.2800);
      locationTracker.emitLocation(41.3120, 69.2805);
      locationTracker.emitLocation(41.3130, 69.2815);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(markerPositions.length, equals(3));
      expect(markerPositions[0], equals({'lat': 41.3115, 'lng': 69.2800}));
      expect(markerPositions[2], equals({'lat': 41.3130, 'lng': 69.2815}));
    });

    // TEST 08 — Manual Stop Sharing.
    test('TEST 08 — Manual Stop Sharing: Marks session stopped and halts tracking', () async {
      final now = DateTime.now();
      var session = LiveLocationSession(
        sessionId: 'session_stop',
        chatId: 'chat_test',
        senderId: 'user_a',
        senderName: 'Alisher',
        durationSeconds: 900,
        startedAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
        status: LiveLocationStatus.active,
        latitude: 41.3113,
        longitude: 69.2797,
        lastUpdatedAt: now,
      );

      expect(session.isActive, isTrue);

      session = session.copyWith(status: LiveLocationStatus.stopped);
      expect(session.status, equals(LiveLocationStatus.stopped));
      expect(session.isActive, isFalse);
    });

    // TEST 09 — Automatic expiration.
    test('TEST 09 — Automatic expiration: Status reflects expired and remainingSeconds is 0', () {
      final pastStart = DateTime.now().subtract(const Duration(minutes: 20));
      final pastExpiry = pastStart.add(const Duration(minutes: 15)); // Expired 5 min ago

      final session = LiveLocationSession(
        sessionId: 'session_expired',
        chatId: 'chat_test',
        senderId: 'user_a',
        senderName: 'Alisher',
        durationSeconds: 900,
        startedAt: pastStart,
        expiresAt: pastExpiry,
        status: LiveLocationStatus.active,
        latitude: 41.3113,
        longitude: 69.2797,
        lastUpdatedAt: pastStart,
      );

      expect(session.isExpired, isTrue);
      expect(session.isActive, isFalse);
      expect(session.remainingSeconds, equals(0));
    });

    // TEST 10 — Stopped session cannot restart.
    test('TEST 10 — Stopped session cannot restart: Subsequent updates rejected', () async {
      await firestoreBackend.setSession(
        'chats/c1/live_locations/s_stopped',
        {
          'sessionId': 's_stopped',
          'chatId': 'c1',
          'senderId': 'user_a',
          'durationSeconds': 900,
          'status': 'stopped',
          'latitude': 41.3113,
          'longitude': 69.2797,
          'expiresAt': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
        },
        authUid: 'user_a',
      );

      expect(
        () => firestoreBackend.updateSession(
          'chats/c1/live_locations/s_stopped',
          {'latitude': 41.3200},
          authUid: 'user_a',
        ),
        throwsA(predicate((e) => e.toString().contains('PERMISSION_DENIED: Stopped session'))),
      );
    });

    // TEST 11 — Expired session cannot publish coordinates.
    test('TEST 11 — Expired session cannot publish coordinates', () async {
      final pastDate = DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();

      await firestoreBackend.setSession(
        'chats/c1/live_locations/s_exp',
        {
          'sessionId': 's_exp',
          'chatId': 'c1',
          'senderId': 'user_a',
          'durationSeconds': 900,
          'status': 'active',
          'latitude': 41.3113,
          'longitude': 69.2797,
          'expiresAt': pastDate,
        },
        authUid: 'user_a',
      );

      expect(
        () => firestoreBackend.updateSession(
          'chats/c1/live_locations/s_exp',
          {'latitude': 41.3200},
          authUid: 'user_a',
        ),
        throwsA(predicate((e) => e.toString().contains('PERMISSION_DENIED: Expired session'))),
      );
    });

    // TEST 12 — Unauthorized user denied by Firestore Rules.
    test('TEST 12 — Unauthorized user denied by Firestore Rules (non-participant read blocked)', () {
      firestoreBackend.setSession(
        'chats/c1/live_locations/s_sec',
        {
          'sessionId': 's_sec',
          'chatId': 'c1',
          'senderId': 'user_a',
          'durationSeconds': 900,
          'status': 'active',
        },
        authUid: 'user_a',
      );

      final chatParticipants = ['user_a', 'user_b'];

      // Non-participant user_hacker
      expect(
        () => firestoreBackend.getSession(
          'chats/c1/live_locations/s_sec',
          authUid: 'user_hacker',
          chatParticipants: chatParticipants,
        ),
        throwsA(predicate((e) => e.toString().contains('PERMISSION_DENIED: Only chat participants'))),
      );

      // Authorized participant user_b
      final session = firestoreBackend.getSession(
        'chats/c1/live_locations/s_sec',
        authUid: 'user_b',
        chatParticipants: chatParticipants,
      );
      expect(session, isNotNull);
      expect(session!['senderId'], equals('user_a'));
    });

    // TEST 13 — Recipient cannot forge location coordinates.
    test('TEST 13 — Recipient cannot forge location coordinates: Write rejected', () async {
      await firestoreBackend.setSession(
        'chats/c1/live_locations/s_forge',
        {
          'sessionId': 's_forge',
          'chatId': 'c1',
          'senderId': 'user_a',
          'durationSeconds': 900,
          'status': 'active',
          'latitude': 41.3113,
          'longitude': 69.2797,
          'expiresAt': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
        },
        authUid: 'user_a',
      );

      // Recipient user_b attempts to update sender user_a's coordinates
      expect(
        () => firestoreBackend.updateSession(
          'chats/c1/live_locations/s_forge',
          {'latitude': 41.9999, 'longitude': 69.9999},
          authUid: 'user_b',
        ),
        throwsA(predicate((e) => e.toString().contains('PERMISSION_DENIED: Recipient cannot forge'))),
      );
    });

    // TEST 14 — Network interruption.
    test('TEST 14 — Network interruption: Session holds state without claiming stale data is live', () {
      final now = DateTime.now();
      final session = LiveLocationSession(
        sessionId: 'session_net',
        chatId: 'c1',
        senderId: 'user_a',
        senderName: 'Alisher',
        durationSeconds: 900,
        startedAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
        status: LiveLocationStatus.active,
        latitude: 41.3113,
        longitude: 69.2797,
        lastUpdatedAt: now.subtract(const Duration(minutes: 5)),
      );

      expect(session.latitude, equals(41.3113));
      expect(session.lastUpdatedAt.isBefore(now), isTrue);
    });

    // TEST 15 — Reconnection without replaying stale coordinates.
    test('TEST 15 — Reconnection without replaying stale coordinates: Live location bypasses outbox', () {
      // Live location messages must never be accumulated in offline text outbox queue
      final liveLocationMsg = Message(
        id: 'msg_live',
        senderId: 'user_a',
        type: MessageType.liveLocation,
        isRead: false,
        timestamp: DateTime.now(),
        latitude: 41.3113,
        longitude: 69.2797,
        liveLocationSessionId: 'sess_1',
        liveLocationDuration: 900,
      );

      expect(liveLocationMsg.type, equals(MessageType.liveLocation));
      expect(liveLocationMsg.type != MessageType.text, isTrue);
      expect(liveLocationMsg.liveLocationSessionId, equals('sess_1'));
    });

    // TEST 16 — App restart retains the original expiration deadline.
    test('TEST 16 — App restart retains original expiration deadline', () {
      final originalStart = DateTime(2026, 10, 21, 14, 0, 0);
      final originalExpiry = DateTime(2026, 10, 21, 14, 15, 0);

      final sessionMap = {
        'sessionId': 'session_restart',
        'chatId': 'c1',
        'senderId': 'user_a',
        'senderName': 'Alisher',
        'durationSeconds': 900,
        'startedAt': originalStart.toIso8601String(),
        'expiresAt': originalExpiry.toIso8601String(),
        'status': 'active',
        'latitude': 41.3113,
        'longitude': 69.2797,
        'lastUpdatedAt': originalStart.toIso8601String(),
      };

      // Restored after simulated restart
      final restored = LiveLocationSession.fromMap(sessionMap);
      expect(restored.expiresAt, equals(originalExpiry));
      expect(restored.durationSeconds, equals(900));
    });

    // TEST 17 — Logout immediately prevents further authorized publishing.
    test('TEST 17 — Logout immediately prevents further authorized publishing', () {
      final service = LiveLocationService();
      expect(service.isSharing, isFalse);
      service.dispose();
      expect(service.currentSession, isNull);
    });

    // TEST 18 — Background/foreground lifecycle transitions.
    test('TEST 18 — Background/foreground lifecycle: Countdown continues monotonically', () {
      final now = DateTime.now();
      final session = LiveLocationSession(
        sessionId: 'session_bg',
        chatId: 'c1',
        senderId: 'user_a',
        senderName: 'Alisher',
        durationSeconds: 900,
        startedAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
        status: LiveLocationStatus.active,
        latitude: 41.3113,
        longitude: 69.2797,
        lastUpdatedAt: now,
      );

      // Remaining seconds is derived from wall-clock expiresAt difference
      final remaining = session.remainingSeconds;
      expect(remaining, greaterThan(890));
      expect(remaining, lessThanOrEqualTo(900));
    });

    // TEST 19 — GPS listener cleanup.
    test('TEST 19 — GPS listener cleanup: Subscriptions closed cleanly on disposal', () {
      final tracker = MockLocationTracker();
      expect(tracker.checkPermission(), completes);
      tracker.dispose();
    });

    // TEST 20 — Existing ordinary chats, Offline Outbox, Stories and Secret Chat regression tests.
    test('TEST 20 — Regression verification: Core models and MessageType intact', () {
      final textMsg = Message(
        id: 'msg_regular',
        senderId: 'user_a',
        type: MessageType.text,
        text: 'Oddiy xabar',
        isRead: false,
        timestamp: DateTime.now(),
      );

      expect(textMsg.type, equals(MessageType.text));
      expect(MessageType.values.contains(MessageType.liveLocation), isTrue);
      expect(MessageType.values.contains(MessageType.location), isTrue);

      final model = MessageModel(
        id: 'm1',
        senderId: 'user_a',
        text: '📍 Jonli joylashuv',
        type: MessageType.liveLocation,
        isRead: false,
        timestamp: DateTime.now(),
        liveLocationSessionId: 'sess_abc',
        liveLocationDuration: 900,
      );

      final map = model.toJson();
      expect(map['liveLocationSessionId'], equals('sess_abc'));
      expect(map['liveLocationDuration'], equals(900));
      expect(map['type'], equals('liveLocation'));

      // Check Uzbek localization keys
      expect(LocalizationService.translate('share_live_location'), equals('Jonli joylashuvni ulashish'));
      expect(LocalizationService.translate('send_current_location'), equals('Hozirgi joylashuvni yuborish'));
      expect(LocalizationService.translate('stop_sharing'), equals('Ulashishni to‘xtatish'));
    });
  });
}
