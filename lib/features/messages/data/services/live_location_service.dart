import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/live_location_session.dart';

class LocationServiceDisabledException implements Exception {
  final String message;
  LocationServiceDisabledException([this.message = 'Location services are disabled on device.']);
  @override
  String toString() => message;
}

class LocationPermissionDeniedException implements Exception {
  final String message;
  LocationPermissionDeniedException([this.message = 'Location permission was denied.']);
  @override
  String toString() => message;
}

class LocationPermissionDeniedForeverException implements Exception {
  final String message;
  LocationPermissionDeniedForeverException([this.message = 'Location permission is permanently denied.']);
  @override
  String toString() => message;
}

/// Service managing real-time GPS tracking, duration expiration, and Firestore synchronization.
class LiveLocationService {
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Active tracking state
  LiveLocationSession? _currentSession;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _expirationTimer;
  DateTime? _lastUploadTime;

  final _activeSessionController = StreamController<LiveLocationSession?>.broadcast();

  LiveLocationService({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  LiveLocationSession? get currentSession => _currentSession;
  Stream<LiveLocationSession?> get onActiveSessionChanged => _activeSessionController.stream;
  bool get isSharing => _currentSession != null && _currentSession!.isActive;

  /// Verifies and requests location permissions.
  Future<bool> ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceDisabledException();
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationPermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionDeniedForeverException();
    }

    return true;
  }

  /// Starts a voluntary Live Location session for 15 minutes (900s) or 1 hour (3600s).
  Future<LiveLocationSession> startLiveLocation({
    required String chatId,
    required String senderId,
    required String senderName,
    required int durationSeconds, // 900 or 3600
  }) async {
    // 1. Permission check
    await ensureLocationPermission();

    // 2. Obtain current GPS coordinates
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );

    // 3. Stop any existing session before starting a new one
    if (_currentSession != null) {
      await stopLiveLocation(_currentSession!.chatId, _currentSession!.sessionId);
    }

    final sessionId = _uuid.v4();
    final now = DateTime.now();
    final expiresAt = now.add(Duration(seconds: durationSeconds));

    final session = LiveLocationSession(
      sessionId: sessionId,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      durationSeconds: durationSeconds,
      startedAt: now,
      expiresAt: expiresAt,
      status: LiveLocationStatus.active,
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      heading: pos.heading,
      lastUpdatedAt: now,
    );

    // 4. Save session document in Firestore
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('live_locations')
        .doc(sessionId)
        .set(session.toMap());

    _currentSession = session;
    _activeSessionController.add(session);
    _lastUploadTime = now;

    // 5. Begin listening for device movement with rate-limiting and distance threshold
    _startPositionListening(chatId, sessionId, expiresAt);

    // 6. Schedule expiration timer
    _expirationTimer?.cancel();
    _expirationTimer = Timer(Duration(seconds: durationSeconds), () {
      debugPrint('Live location session expired: $sessionId');
      stopLiveLocation(chatId, sessionId, isExpired: true);
    });

    return session;
  }

  void _startPositionListening(String chatId, String sessionId, DateTime expiresAt) {
    _positionSubscription?.cancel();

    // Distance threshold of 10m to minimize GPS polling and battery usage
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (pos) => _handlePositionUpdate(chatId, sessionId, pos, expiresAt),
      onError: (e) {
        debugPrint('Geolocator position stream error: $e');
      },
    );
  }

  Future<void> _handlePositionUpdate(
    String chatId,
    String sessionId,
    Position pos,
    DateTime expiresAt,
  ) async {
    // Verify session has not expired
    if (DateTime.now().isAfter(expiresAt)) {
      await stopLiveLocation(chatId, sessionId, isExpired: true);
      return;
    }

    if (_currentSession == null || _currentSession!.sessionId != sessionId) {
      return;
    }

    // Rate-limiting: at least 5 seconds between Firestore writes to avoid excessive traffic
    final now = DateTime.now();
    if (_lastUploadTime != null && now.difference(_lastUploadTime!).inSeconds < 5) {
      return;
    }
    _lastUploadTime = now;

    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('live_locations')
          .doc(sessionId)
          .update({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'heading': pos.heading,
        'lastUpdatedAt': Timestamp.fromDate(now),
      });

      _currentSession = _currentSession?.copyWith(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        heading: pos.heading,
        lastUpdatedAt: now,
      );
      _activeSessionController.add(_currentSession);
    } catch (e) {
      debugPrint('Failed to update live location in Firestore: $e');
    }
  }

  /// Stops an active live location session immediately and cleans up GPS resources.
  Future<void> stopLiveLocation(
    String chatId,
    String sessionId, {
    bool isExpired = false,
  }) async {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    _expirationTimer?.cancel();
    _expirationTimer = null;

    final targetStatus = isExpired ? 'expired' : 'stopped';

    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('live_locations')
          .doc(sessionId)
          .update({
        'status': targetStatus,
        'lastUpdatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Failed to mark live location session $targetStatus: $e');
    }

    if (_currentSession?.sessionId == sessionId) {
      _currentSession = _currentSession?.copyWith(
        status: isExpired ? LiveLocationStatus.expired : LiveLocationStatus.stopped,
      );
      _activeSessionController.add(_currentSession);
      _currentSession = null;
    }
  }

  /// Real-time subscription to a live location session for both sender and recipient.
  Stream<LiveLocationSession?> watchSession(String chatId, String sessionId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('live_locations')
        .doc(sessionId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return LiveLocationSession.fromFirestore(doc);
    });
  }

  /// Cleans up GPS subscriptions and timers upon logout or app dispose.
  void dispose() {
    _positionSubscription?.cancel();
    _expirationTimer?.cancel();
    _currentSession = null;
    _activeSessionController.close();
  }
}
