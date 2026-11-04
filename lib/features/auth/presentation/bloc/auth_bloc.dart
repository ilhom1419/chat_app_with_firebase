import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/cache/hive_service.dart';
import '../../../../core/diagnostics/kakku_auth_trace.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<AppUser?>? _authStateSubscription;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignInRequested>(_onAuthSignInRequested);
    on<AuthSignUpRequested>(_onAuthSignUpRequested);
    on<AuthSignOutRequested>(_onAuthSignOutRequested);
    on<AuthPasswordResetRequested>(_onAuthPasswordResetRequested);
    on<AuthUserChanged>(_onAuthUserChanged);

    _listenToAuthStateChanges();
  }

  void _listenToAuthStateChanges() {
    _authStateSubscription?.cancel();
    KakkuAuthTrace.log('AUTH_LISTENER_ATTACHED');
    _authStateSubscription = _authRepository.onAuthStateChanged.listen((user) {
      add(AuthUserChanged(user));
    });
  }

  Future<void> _onAuthPasswordResetRequested(
      AuthPasswordResetRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authRepository.sendPasswordResetEmail(event.email);
      emit(AuthPasswordResetSuccess());
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    if (state is AuthAuthenticated) {
      KakkuAuthTrace.log('AUTH_CHECK_SKIPPED_ALREADY_AUTH', details: {
        'userHash':
            KakkuAuthTrace.safeUid((state as AuthAuthenticated).user.uid),
      });
      return;
    }

    emit(AuthLoading());
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        KakkuAuthTrace.log('AUTH_STATE_AUTHENTICATED', details: {
          'reason': 'initial_check_success',
          'userHash': KakkuAuthTrace.safeUid(user.uid),
        });
        emit(AuthAuthenticated(user));
        unawaited(NotificationService.syncToken(uid: user.uid));
      } else {
        KakkuAuthTrace.log('AUTH_STATE_UNAUTHENTICATED', details: {
          'reason': 'initial_check_no_user',
        });
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      // ABSOLUTE RULE: A generic exception is not proof that Firebase signed the user out.
      KakkuAuthTrace.log('AUTH_CHECK_ERROR', details: {'error': e.toString()});
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthUserChanged(
      AuthUserChanged event, Emitter<AuthState> emit) async {
    final incomingUser = event.user;
    final currentState = state;

    if (incomingUser != null) {
      KakkuAuthTrace.log('AUTH_USER_CHANGED_NON_NULL', details: {
        'userHash': KakkuAuthTrace.safeUid(incomingUser.uid),
        'priorState': currentState.runtimeType.toString(),
      });
      await HiveService.saveAuthSession(
        uid: incomingUser.uid,
        email: incomingUser.email,
        displayName: incomingUser.displayName,
        photoURL: incomingUser.photoURL,
      );
      if (currentState is AuthAuthenticated &&
          currentState.user.uid == incomingUser.uid) {
        if (currentState.user != incomingUser) {
          emit(AuthAuthenticated(incomingUser));
        }
      } else {
        emit(AuthAuthenticated(incomingUser));
        unawaited(NotificationService.syncToken(uid: incomingUser.uid));
      }
    } else {
      // Stream emitted null.
      // 1. If currently in cold-start startup (AuthInitial or AuthLoading),
      // authStateChanges() initially emits null before native disk restoration completes.
      if (currentState is AuthInitial || currentState is AuthLoading) {
        KakkuAuthTrace.log('AUTH_USER_CHANGED_IGNORED_STARTUP_NULL', details: {
          'priorState': currentState.runtimeType.toString(),
        });
        return;
      }

      // 2. If already Unauthenticated, no-op
      if (currentState is AuthUnauthenticated) {
        return;
      }

      // 3. If currently Authenticated, guard against transient null stream emissions
      // (such as during token refresh or temporary platform lifecycle transitions).
      final localSession = HiveService.getAuthSession();
      if (localSession != null) {
        KakkuAuthTrace.log('AUTH_STREAM_NULL_IGNORED_LOCAL_SESSION_VALID');
        return;
      }

      KakkuAuthTrace.log('AUTH_USER_CHANGED_VERIFYING_NULL', details: {
        'priorState': currentState.runtimeType.toString(),
      });
      final verifiedUser = await _authRepository.getCurrentUser();
      if (verifiedUser != null) {
        KakkuAuthTrace.log('AUTH_SESSION_PRESERVED_TRANSIENT_NULL', details: {
          'userHash': KakkuAuthTrace.safeUid(verifiedUser.uid),
        });
        emit(AuthAuthenticated(verifiedUser));
        return;
      }

      // Confirmed genuine signout or session revocation
      KakkuAuthTrace.log('AUTH_STATE_UNAUTHENTICATED', details: {
        'reason': 'stream_confirmed_signout',
      });
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthSignInRequested(
      AuthSignInRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signInWithEmailAndPassword(
        event.email,
        event.password,
      );
      if (user != null) {
        KakkuAuthTrace.log('AUTH_STATE_AUTHENTICATED', details: {
          'reason': 'signin_success',
          'userHash': KakkuAuthTrace.safeUid(user.uid),
        });
        await HiveService.saveAuthSession(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoURL: user.photoURL,
        );
        emit(AuthAuthenticated(user));
        unawaited(NotificationService.syncToken(uid: user.uid));
      } else {
        emit(const AuthFailure('Login failed. Please check credentials.'));
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthSignUpRequested(
      AuthSignUpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _authRepository.signUpWithEmailAndPassword(
        event.email,
        event.password,
        event.displayName,
      );
      if (user != null) {
        KakkuAuthTrace.log('AUTH_STATE_AUTHENTICATED', details: {
          'reason': 'signup_success',
          'userHash': KakkuAuthTrace.safeUid(user.uid),
        });
        await HiveService.saveAuthSession(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoURL: user.photoURL,
        );
        emit(AuthAuthenticated(user));
        unawaited(NotificationService.syncToken(uid: user.uid));
      } else {
        emit(const AuthFailure('Registration failed.'));
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthSignOutRequested(
      AuthSignOutRequested event, Emitter<AuthState> emit) async {
    KakkuAuthTrace.log('EXPLICIT_SIGNOUT_REQUESTED');
    emit(AuthLoading());
    try {
      NotificationService.stopListeningToUserNotifications();
      await HiveService.clearAuthSession();
      await _authRepository.signOut();
      emit(AuthUnauthenticated());
      KakkuAuthTrace.log('AUTH_STATE_UNAUTHENTICATED', details: {
        'reason': 'explicit_signout_done',
      });
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
