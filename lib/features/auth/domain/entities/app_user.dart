import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final String? fcmToken;
  final bool isOnline;
  final DateTime? lastSeen;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.fcmToken,
    this.isOnline = false,
    this.lastSeen,
  });

  @override
  List<Object?> get props =>
      [uid, email, displayName, photoURL, fcmToken, isOnline, lastSeen];
}
