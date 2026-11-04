import '../entities/app_user.dart';

abstract class AuthRepository {
  Future<AppUser?> signInWithEmailAndPassword(String email, String password);
  Future<AppUser?> signUpWithEmailAndPassword(
      String email, String password, String displayName);
  Future<void> signOut();
  Future<AppUser?> getCurrentUser();
  Stream<AppUser?> get onAuthStateChanged;
  Future<void> sendPasswordResetEmail(String email);
}
