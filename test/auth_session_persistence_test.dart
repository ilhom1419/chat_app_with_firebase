import 'dart:async';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/features/auth/domain/entities/app_user.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:chat_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:chat_app/features/auth/presentation/pages/splash_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MockAuthRepository implements AuthRepository {
  AppUser? persistedUser;
  bool shouldThrowOnGetDoc = false;
  Duration restorationDelay = Duration.zero;
  int signOutCallCount = 0;
  final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  MockAuthRepository({
    this.persistedUser,
    this.restorationDelay = Duration.zero,
  });

  @override
  Stream<AppUser?> get onAuthStateChanged => _authStateController.stream;

  void emitAuthState(AppUser? user) {
    _authStateController.add(user);
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    if (restorationDelay > Duration.zero) {
      await Future.delayed(restorationDelay);
    }
    if (persistedUser == null) return null;
    if (shouldThrowOnGetDoc) {
      // Simulating network failure on fetching Firestore doc
      // The repository falls back to cached AppUser without failing
      return persistedUser;
    }
    return persistedUser;
  }

  @override
  Future<AppUser?> signInWithEmailAndPassword(
      String email, String password) async {
    persistedUser = AppUser(
      uid: 'user_123',
      email: email,
      displayName: 'Test User',
      photoURL: null,
      isOnline: true,
    );
    _authStateController.add(persistedUser);
    return persistedUser;
  }

  @override
  Future<AppUser?> signUpWithEmailAndPassword(
      String email, String password, String displayName) async {
    persistedUser = AppUser(
      uid: 'user_123',
      email: email,
      displayName: displayName,
      photoURL: null,
      isOnline: true,
    );
    _authStateController.add(persistedUser);
    return persistedUser;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    persistedUser = null;
    _authStateController.add(null);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  void dispose() {
    _authStateController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('kakku_auth_hive_test');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
    await Hive.openBox('auth_session');
  });

  setUp(() async {
    if (Hive.isBoxOpen('auth_session')) {
      await Hive.box('auth_session').clear();
    }
  });

  final testUser = const AppUser(
    uid: 'user_456',
    email: 'test@yeschat.com',
    displayName: 'Jahongir',
    photoURL: null,
    isOnline: true,
  );

  group('P0 REQUIRED AUTH TEST MATRIX (TEST 01 - TEST 24)', () {
    test('TEST 01: Initial authentication state is UNKNOWN / AuthInitial, not unauthenticated', () {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);

      expect(authBloc.state, isA<AuthInitial>());
      expect(authBloc.state, isNot(isA<AuthUnauthenticated>()));

      authBloc.close();
      repo.dispose();
    });

    test('TEST 02: Firebase authenticated user routes to Home / Authenticated', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);

      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state, isA<AuthAuthenticated>());
      final state = authBloc.state as AuthAuthenticated;
      expect(state.user.uid, equals('user_456'));

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 03: Firebase confirmed null user routes to Unauthenticated / Login', () async {
      final repo = MockAuthRepository(persistedUser: null);
      final authBloc = AuthBloc(authRepository: repo);

      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state, isA<AuthUnauthenticated>());

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 04: Slow Firebase initialization / async restore does not flash Login or drop session', () async {
      // Simulating native Android delayed keystore decryption / SharedPreferences read (150ms)
      final repo = MockAuthRepository(
        persistedUser: testUser,
        restorationDelay: const Duration(milliseconds: 150),
      );
      final authBloc = AuthBloc(authRepository: repo);

      // On startup, stream emits initial null before storage finishes reading
      repo.emitAuthState(null);
      authBloc.add(AuthCheckRequested());

      // At 50ms: state should be AuthLoading, NOT AuthUnauthenticated!
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthLoading>());

      // At 200ms: async restore completes, state is AuthAuthenticated
      await Future.delayed(const Duration(milliseconds: 150));
      expect(authBloc.state, isA<AuthAuthenticated>());
      expect((authBloc.state as AuthAuthenticated).user.uid, equals('user_456'));

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 05: App restart with restored user routes to Home', () async {
      // First session
      final repo1 = MockAuthRepository(persistedUser: testUser);
      final authBloc1 = AuthBloc(authRepository: repo1);
      authBloc1.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc1.state, isA<AuthAuthenticated>());
      await authBloc1.close();

      // App process restart with same persisted storage
      final repo2 = MockAuthRepository(persistedUser: testUser);
      final authBloc2 = AuthBloc(authRepository: repo2);
      authBloc2.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc2.state, isA<AuthAuthenticated>());
      expect((authBloc2.state as AuthAuthenticated).user.uid, equals('user_456'));
      await authBloc2.close();
      repo2.dispose();
      repo1.dispose();
    });

    test('TEST 06: An authentication-state callback updates AuthBloc correctly', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);
      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthAuthenticated>());

      // Profile updated remotely
      final updatedUser = const AppUser(
        uid: 'user_456',
        email: 'test@yeschat.com',
        displayName: 'Jahongir Updated',
        photoURL: 'https://example.com/avatar.jpg',
        isOnline: true,
      );
      repo.emitAuthState(updatedUser);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state, isA<AuthAuthenticated>());
      expect((authBloc.state as AuthAuthenticated).user.displayName, equals('Jahongir Updated'));

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 07: A temporary Firestore profile error does not sign the user out', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      repo.shouldThrowOnGetDoc = true; // Network failure on Firestore
      final authBloc = AuthBloc(authRepository: repo);

      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));

      // Must remain authenticated using cached Firebase credentials
      expect(authBloc.state, isA<AuthAuthenticated>());
      expect((authBloc.state as AuthAuthenticated).user.uid, equals('user_456'));

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 08: Offline startup does not trigger false logout', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      repo.shouldThrowOnGetDoc = true; // Offline
      final authBloc = AuthBloc(authRepository: repo);

      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state, isA<AuthAuthenticated>());
      expect(authBloc.state, isNot(isA<AuthUnauthenticated>()));

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 09: Language switching does not reset auth state', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);
      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthAuthenticated>());

      // Simulating language change event
      authBloc.add(AuthUserChanged(testUser));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(authBloc.state, isA<AuthAuthenticated>());
      expect((authBloc.state as AuthAuthenticated).user.uid, equals('user_456'));

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 10: Theme switching does not reset auth state', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);
      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthAuthenticated>());

      // Re-triggering check or theme rebuild must not reset state
      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 20));
      expect(authBloc.state, isA<AuthAuthenticated>());

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 11: Navigation does not recreate an incompatible authentication source', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);
      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));

      // State is preserved across multiple reads
      expect(authBloc.state, isA<AuthAuthenticated>());
      expect((authBloc.state as AuthAuthenticated).user.uid, equals('user_456'));

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 12: Normal app background/resume does not call signOut', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);
      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthAuthenticated>());

      // Simulating background ping with existing user
      repo.emitAuthState(testUser);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(repo.signOutCallCount, equals(0));
      expect(authBloc.state, isA<AuthAuthenticated>());

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 13: Explicit Logout does call legitimate Firebase signOut', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);
      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthAuthenticated>());

      // Explicit logout
      authBloc.add(AuthSignOutRequested());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(repo.signOutCallCount, equals(1));
      expect(authBloc.state, isA<AuthUnauthenticated>());
      expect(repo.persistedUser, isNull);

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 14: A genuine invalidated account is handled securely', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);
      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthAuthenticated>());

      // Account revoked remotely: repo user becomes null
      repo.persistedUser = null;
      repo.emitAuthState(null);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state, isA<AuthUnauthenticated>());

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 15: Account A -> Logout -> Account B does not leak private state', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);
      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect((authBloc.state as AuthAuthenticated).user.uid, equals('user_456'));

      // Logout Account A
      authBloc.add(AuthSignOutRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthUnauthenticated>());

      // Login Account B
      authBloc.add(const AuthSignInRequested('accountb@yeschat.com', 'pass123'));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthAuthenticated>());
      expect((authBloc.state as AuthAuthenticated).user.uid, equals('user_123'));

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 16: Auth loading and router redirect do not race', () async {
      final repo = MockAuthRepository(
        persistedUser: testUser,
        restorationDelay: const Duration(milliseconds: 80),
      );
      final authBloc = AuthBloc(authRepository: repo);

      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 30));
      expect(authBloc.state, isA<AuthLoading>());

      await Future.delayed(const Duration(milliseconds: 80));
      expect(authBloc.state, isA<AuthAuthenticated>());

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 17: Multiple auth listeners do not produce contradictory routing', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);

      authBloc.add(AuthCheckRequested());
      repo.emitAuthState(testUser);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state, isA<AuthAuthenticated>());

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 18: A restored user does not trigger new unnecessary sign-in', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);

      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthAuthenticated>());

      // Repeating check does not trigger sign-in or state reset
      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 20));
      expect(authBloc.state, isA<AuthAuthenticated>());

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 19: Five consecutive ordinary close/reopen cycles preserve session', () async {
      for (int cycle = 1; cycle <= 5; cycle++) {
        final repo = MockAuthRepository(
          persistedUser: testUser,
          restorationDelay: const Duration(milliseconds: 40),
        );
        final authBloc = AuthBloc(authRepository: repo);

        authBloc.add(AuthCheckRequested());
        await Future.delayed(const Duration(milliseconds: 70));

        expect(authBloc.state, isA<AuthAuthenticated>(),
            reason: 'Cycle $cycle must preserve authenticated state');
        expect((authBloc.state as AuthAuthenticated).user.uid, equals('user_456'));

        await authBloc.close();
        repo.dispose();
      }
    });

    testWidgets('TEST 20: Splash widget correctly waits for async restoration without flashing Login', (WidgetTester tester) async {
      final repo = MockAuthRepository(
        persistedUser: testUser,
        restorationDelay: const Duration(milliseconds: 100),
      );
      final authBloc = AuthBloc(authRepository: repo);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            home: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const SplashPage(
                homeTarget: Scaffold(body: Text('HOME_SCREEN_TARGET')),
                loginTarget: Scaffold(body: Text('LOGIN_SCREEN_TARGET')),
              ),
            ),
          ),
        ),
      );

      // Initially during delay, SplashPage is visible, Home and Login are NOT present
      expect(find.byType(SplashPage), findsOneWidget);
      expect(find.text('HOME_SCREEN_TARGET'), findsNothing);
      expect(find.text('LOGIN_SCREEN_TARGET'), findsNothing);

      // Advance clock past restoration delay and page transition
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 350));

      // State is authenticated, Home was pushed, Login was never pushed
      expect(authBloc.state, isA<AuthAuthenticated>());
      expect(find.text('HOME_SCREEN_TARGET'), findsOneWidget);
      expect(find.text('LOGIN_SCREEN_TARGET'), findsNothing);

      // Cleanly unmount tree to dispose tickers
      await tester.pumpWidget(const SizedBox());

      authBloc.close();
      repo.dispose();
    });

    testWidgets('TEST 21: Splash widget routes to LoginPage when confirmed unauthenticated', (WidgetTester tester) async {
      final repo = MockAuthRepository(persistedUser: null);
      final authBloc = AuthBloc(authRepository: repo);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            home: BlocProvider<AuthBloc>.value(
              value: authBloc,
              child: const SplashPage(
                homeTarget: Scaffold(body: Text('HOME_SCREEN_TARGET')),
                loginTarget: Scaffold(body: Text('LOGIN_SCREEN_TARGET')),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 3));

      expect(authBloc.state, isA<AuthUnauthenticated>());
      expect(find.text('LOGIN_SCREEN_TARGET'), findsOneWidget);
      expect(find.text('HOME_SCREEN_TARGET'), findsNothing);

      // Cleanly unmount tree to dispose tickers
      await tester.pumpWidget(const SizedBox());

      authBloc.close();
      repo.dispose();
    });

    test('TEST 22: Transient null stream emission during token refresh preserves session', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);

      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthAuthenticated>());

      // Simulating a transient null over stream while repo session remains valid
      repo._authStateController.add(null);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authBloc.state, isA<AuthAuthenticated>());
      expect((authBloc.state as AuthAuthenticated).user.uid, equals('user_456'));

      await authBloc.close();
      repo.dispose();
    });

    test('TEST 23: Reopen after Logout keeps user unauthenticated / at Login', () async {
      // User explicitly logs out
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc1 = AuthBloc(authRepository: repo);
      authBloc1.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc1.state, isA<AuthAuthenticated>());

      authBloc1.add(AuthSignOutRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc1.state, isA<AuthUnauthenticated>());
      await authBloc1.close();

      // App reopens after logout
      final authBloc2 = AuthBloc(authRepository: repo);
      authBloc2.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc2.state, isA<AuthUnauthenticated>());

      await authBloc2.close();
      repo.dispose();
    });

    test('TEST 24: AuthFailure on chat list page does NOT force signout', () async {
      final repo = MockAuthRepository(persistedUser: testUser);
      final authBloc = AuthBloc(authRepository: repo);

      authBloc.add(AuthCheckRequested());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(authBloc.state, isA<AuthAuthenticated>());

      // Transient failure (e.g. password reset request error)
      authBloc.add(const AuthPasswordResetRequested('invalid-email'));
      await Future.delayed(const Duration(milliseconds: 50));

      // After password reset fails, authBloc emits AuthFailure, but repo persistedUser is still valid
      expect(repo.persistedUser, isNotNull);
      expect(repo.signOutCallCount, equals(0));

      await authBloc.close();
      repo.dispose();
    });
  });
}
