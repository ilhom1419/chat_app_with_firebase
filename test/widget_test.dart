import 'package:flutter_test/flutter_test.dart';
import 'package:chat_app/features/auth/domain/entities/app_user.dart';

void main() {
  group('AppUser Entity Tests', () {
    test('AppUser instances with same properties should be equal', () {
      final now = DateTime.now();
      final user1 = AppUser(
        uid: '123',
        email: 'test@example.com',
        displayName: 'Test User',
        isOnline: true,
        lastSeen: now,
      );

      final user2 = AppUser(
        uid: '123',
        email: 'test@example.com',
        displayName: 'Test User',
        isOnline: true,
        lastSeen: now,
      );

      expect(user1, equals(user2));
    });

    test('AppUser instances with different properties should not be equal', () {
      final user1 = const AppUser(
        uid: '123',
        email: 'test@example.com',
        displayName: 'Test User',
        isOnline: true,
      );

      final user2 = const AppUser(
        uid: '124',
        email: 'test2@example.com',
        displayName: 'Test User 2',
        isOnline: false,
      );

      expect(user1, isNot(equals(user2)));
    });
  });
}
