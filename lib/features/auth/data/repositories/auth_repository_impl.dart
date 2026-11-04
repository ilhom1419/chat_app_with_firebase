import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../../core/cache/hive_service.dart';
import '../../../../core/diagnostics/kakku_auth_trace.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final fb.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl({
    fb.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  AppUser? _mapFirebaseUser(fb.User? user, {String? displayName}) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? displayName ?? 'User',
      photoURL: user.photoURL,
      isOnline: true,
    );
  }

  Future<AppUser> _resolveUserProfile(fb.User user) async {
    KakkuAuthTrace.log('PROFILE_LOAD_STARTED', details: {
      'userHash': KakkuAuthTrace.safeUid(user.uid),
    });
    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 2));
      if (doc.exists) {
        KakkuAuthTrace.log('PROFILE_LOAD_SUCCESS', details: {
          'userHash': KakkuAuthTrace.safeUid(user.uid),
          'source': 'firestore',
        });
        return UserModel.fromFirestore(doc);
      }
    } catch (e) {
      KakkuAuthTrace.log('PROFILE_LOAD_FAILED', details: {
        'userHash': KakkuAuthTrace.safeUid(user.uid),
        'fallback': 'firebase_user_cached',
        'error': e.toString(),
      });
    }
    return _mapFirebaseUser(user)!;
  }

  @override
  Stream<AppUser?> get onAuthStateChanged {
    return _firebaseAuth
        .authStateChanges()
        .map((user) => _mapFirebaseUser(user));
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    // 1. Immediate memory check
    fb.User? user = _firebaseAuth.currentUser;
    if (user != null) {
      KakkuAuthTrace.log('AUTH_INITIAL_STATE_RECEIVED', details: {
        'hasFirebaseUser': true,
        'source': 'memory_cache',
        'userHash': KakkuAuthTrace.safeUid(user.uid),
      });
      final appUser = await _resolveUserProfile(user);
      await HiveService.saveAuthSession(
        uid: appUser.uid,
        email: appUser.email,
        displayName: appUser.displayName,
        photoURL: appUser.photoURL,
      );
      return appUser;
    }

    // 2. Check local persistent session in Hive immediately
    final localSession = HiveService.getAuthSession();
    AppUser? fallbackUser;
    if (localSession != null) {
      fallbackUser = AppUser(
        uid: localSession['uid'] as String,
        email: localSession['email'] as String,
        displayName: localSession['displayName'] as String,
        photoURL: localSession['photoURL'] as String?,
        isOnline: true,
      );
    }

    // 3. On Android cold start, wait briefly for native Firebase Auth restoration (up to 1500ms)
    KakkuAuthTrace.log('AUTH_INITIAL_STATE_PENDING', details: {
      'hasFirebaseUser': false,
      'hasLocalSession': fallbackUser != null,
      'action': 'waiting_for_native_persistence',
    });

    final completer = Completer<fb.User?>();
    StreamSubscription<fb.User?>? sub;

    sub = _firebaseAuth.authStateChanges().listen((streamUser) {
      if (streamUser != null && !completer.isCompleted) {
        completer.complete(streamUser);
      }
    });

    Timer? pollTimer;
    int polls = 0;
    pollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      polls++;
      final current = _firebaseAuth.currentUser;
      if (current != null && !completer.isCompleted) {
        completer.complete(current);
        timer.cancel();
      } else if (polls >= 30) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        timer.cancel();
      }
    });

    try {
      user = await completer.future.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => _firebaseAuth.currentUser,
      );
    } catch (_) {
      user = _firebaseAuth.currentUser;
    } finally {
      pollTimer.cancel();
      await sub.cancel();
    }

    if (user != null) {
      KakkuAuthTrace.log('AUTH_INITIAL_STATE_RECEIVED', details: {
        'hasFirebaseUser': true,
        'source': 'native_storage_restored',
        'userHash': KakkuAuthTrace.safeUid(user.uid),
      });
      final appUser = await _resolveUserProfile(user);
      await HiveService.saveAuthSession(
        uid: appUser.uid,
        email: appUser.email,
        displayName: appUser.displayName,
        photoURL: appUser.photoURL,
      );
      return appUser;
    }

    // 4. Native Firebase timed out or delayed by Android OS, but local session is active
    if (fallbackUser != null) {
      KakkuAuthTrace.log('AUTH_INITIAL_STATE_RECEIVED', details: {
        'hasFirebaseUser': false,
        'source': 'local_hive_cache_restored',
        'userHash': KakkuAuthTrace.safeUid(fallbackUser.uid),
      });
      return fallbackUser;
    }

    KakkuAuthTrace.log('AUTH_INITIAL_STATE_RECEIVED', details: {
      'hasFirebaseUser': false,
      'source': 'confirmed_no_session',
    });
    return null;
  }

  @override
  Future<AppUser?> signInWithEmailAndPassword(
      String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final appUser = _mapFirebaseUser(credential.user);
    if (appUser != null) {
      await HiveService.saveAuthSession(
        uid: appUser.uid,
        email: appUser.email,
        displayName: appUser.displayName,
        photoURL: appUser.photoURL,
      );
      unawaited(_updateUserFirestore(appUser));
    }
    return appUser;
  }

  @override
  Future<AppUser?> signUpWithEmailAndPassword(
      String email, String password, String displayName) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Profile yangilash
    await credential.user?.updateDisplayName(displayName);

    final appUser = _mapFirebaseUser(credential.user, displayName: displayName);
    if (appUser != null) {
      await HiveService.saveAuthSession(
        uid: appUser.uid,
        email: appUser.email,
        displayName: appUser.displayName,
        photoURL: appUser.photoURL,
      );
      unawaited(_updateUserFirestore(appUser));
    }
    return appUser;
  }

  @override
  Future<void> signOut() async {
    KakkuAuthTrace.log('FIREBASE_SIGNOUT_CALLED');
    await HiveService.clearAuthSession();
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null) {
        // Offline qilish va push tokenini o'chirish
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 1));
      }
    } catch (e) {
      print("Firestore signout status update error (ignored): $e");
    }
    await _firebaseAuth.signOut();
  }

  Future<void> _updateUserFirestore(AppUser user) async {
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      print('FCM Token generation error: $e');
    }

    final userModel = UserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      fcmToken: fcmToken,
      isOnline: true,
      lastSeen: DateTime.now(),
    );

    try {
      await _firestore.collection('users').doc(user.uid).set(
            userModel.toJson(),
            SetOptions(merge: true),
          );
    } catch (e) {
      print('Firestore update user error: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }
}
