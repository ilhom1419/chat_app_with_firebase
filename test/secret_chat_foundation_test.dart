import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:chat_app/features/secret_chat/domain/entities/device_identity.dart';
import 'package:chat_app/features/secret_chat/domain/entities/secret_chat_session.dart';
import 'package:chat_app/features/secret_chat/domain/entities/secret_message.dart';
import 'package:chat_app/features/secret_chat/domain/entities/secret_media_payload.dart';
import 'package:chat_app/features/secret_chat/data/datasources/secure_signal_protocol_store.dart';
import 'package:chat_app/features/secret_chat/domain/repositories/secret_chat_repository.dart';
import 'package:chat_app/features/secret_chat/presentation/bloc/secret_chat_bloc.dart';
import 'package:chat_app/features/secret_chat/presentation/bloc/secret_chat_event.dart';
import 'package:chat_app/features/secret_chat/presentation/bloc/secret_chat_state.dart';

class MockSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async {
    _data.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSecretChatRepository implements SecretChatRepository {
  SecretChatSession? currentSession;

  @override
  Future<DeviceIdentity> getOrCreateLocalDeviceIdentity(String userId) async {
    return DeviceIdentity(
      deviceId: 'dev_test_1',
      registrationId: 101,
      identityPublicKey: 'TestPubKeyBase64==',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<DeviceIdentity?> getRecipientDevice(String recipientUid) async {
    return DeviceIdentity(
      deviceId: 'dev_recipient_1',
      registrationId: 202,
      identityPublicKey: 'RecipientPubKeyBase64==',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<SecretChatSession> createSecretChatSession({
    required String recipientUid,
    required int selfDestructDuration,
  }) async {
    final session = SecretChatSession(
      chatId: 'secret_test_123',
      initiatorUid: 'my_uid',
      initiatorDeviceId: 'dev_test_1',
      recipientUid: recipientUid,
      recipientDeviceId: 'dev_recipient_1',
      participants: ['my_uid', recipientUid],
      selfDestructDuration: selfDestructDuration,
      status: 'active',
      createdAt: DateTime.now(),
    );
    currentSession = session;
    return session;
  }

  @override
  Stream<SecretChatSession?> watchSecretChatSession(String chatId) {
    return Stream.value(currentSession);
  }

  @override
  Future<void> terminateSecretChat(String chatId) async {
    if (currentSession != null) {
      currentSession = currentSession!.copyWith(status: 'terminated');
    }
  }

  @override
  Future<void> updateSelfDestructDuration(
      String chatId, int durationInSeconds) async {
    if (currentSession != null) {
      currentSession = currentSession!
          .copyWith(selfDestructDuration: durationInSeconds);
    }
  }

  @override
  Stream<List<SecretMessage>> watchSecretMessages(String chatId) {
    return Stream.value([]);
  }

  @override
  Future<void> sendSecretMessage({
    required SecretChatSession session,
    required String plaintext,
  }) async {}

  @override
  Future<String> decryptSecretMessage({
    required SecretMessage message,
    required SecretChatSession session,
  }) async {
    return message.decryptedText ?? 'Decrypted text';
  }

  @override
  Future<bool> hasEstablishedSession({
    required SecretChatSession session,
  }) async {
    return true;
  }

  @override
  Future<String> getSafetyNumber({
    required SecretChatSession session,
  }) async {
    return '11111 22222 33333 44444 55555 66666 77777 88888 99999 00000 12345 67890';
  }

  @override
  Future<void> markMessageAsRead({
    required String chatId,
    required String messageId,
  }) async {}

  @override
  Future<void> deleteSecretMessage({
    required String chatId,
    required String messageId,
  }) async {}

  @override
  Future<void> sendSecretImage({
    required SecretChatSession session,
    required List<int> imageBytes,
    String? caption,
    int? width,
    int? height,
    String mimeType = 'image/jpeg',
  }) async {}

  @override
  Future<void> sendSecretVoice({
    required SecretChatSession session,
    required List<int> audioBytes,
    required int durationSeconds,
    String mimeType = 'audio/m4a',
  }) async {}

  @override
  Future<List<int>> downloadAndDecryptMedia({
    required SecretMediaPayload payload,
  }) async {
    return <int>[];
  }
}

void main() {
  group('Secret Chat Domain Entity Tests', () {
    test('DeviceIdentity serialization and props', () {
      final now = DateTime.now();
      final identity = DeviceIdentity(
        deviceId: 'uuid-1234',
        registrationId: 4567,
        identityPublicKey: 'Base64PublicKey==',
        createdAt: now,
        revoked: false,
      );

      expect(identity.deviceId, 'uuid-1234');
      expect(identity.registrationId, 4567);
      expect(identity.revoked, isFalse);
      expect(identity.toMap()['deviceId'], 'uuid-1234');
    });

    test('SecretChatSession state methods and participants lookup', () {
      final now = DateTime.now();
      final session = SecretChatSession(
        chatId: 'secret_abc',
        initiatorUid: 'user_alice',
        initiatorDeviceId: 'dev_alice_1',
        recipientUid: 'user_bob',
        recipientDeviceId: 'dev_bob_1',
        participants: const ['user_alice', 'user_bob'],
        selfDestructDuration: 5,
        status: 'active',
        createdAt: now,
      );

      expect(session.isActive, isTrue);
      expect(session.isTerminated, isFalse);
      expect(session.getOtherUserId('user_alice'), 'user_bob');
      expect(session.getOtherUserId('user_bob'), 'user_alice');
      expect(session.getMyDeviceId('user_alice'), 'dev_alice_1');
      expect(session.getOtherDeviceId('user_alice'), 'dev_bob_1');

      final terminated = session.copyWith(status: 'terminated');
      expect(terminated.isActive, isFalse);
      expect(terminated.isTerminated, isTrue);
    });
  });

  group('SecureSignalProtocolStore Tests', () {
    late MockSecureStorage mockStorage;
    late SecureSignalProtocolStore store;

    setUp(() {
      mockStorage = MockSecureStorage();
      store = SecureSignalProtocolStore(mockStorage);
    });

    test('IdentityKeyPair and RegistrationId storage round-trip', () async {
      final identityKeyPair = generateIdentityKeyPair();
      final registrationId = generateRegistrationId(false);

      await store.saveLocalIdentityKeyPair(identityKeyPair);
      await store.saveLocalRegistrationId(registrationId);

      final loadedKeyPair = await store.getIdentityKeyPair();
      final loadedRegId = await store.getLocalRegistrationId();

      expect(loadedRegId, registrationId);
      expect(loadedKeyPair.getPublicKey().serialize(),
          identityKeyPair.getPublicKey().serialize());
    });

    test('PreKeyRecord storage, retrieval, and removal', () async {
      final preKeys = generatePreKeys(1, 5);
      final pk = preKeys.first;

      await store.storePreKey(pk.id, pk);
      expect(await store.containsPreKey(pk.id), isTrue);

      final loaded = await store.loadPreKey(pk.id);
      expect(loaded.id, pk.id);

      await store.removePreKey(pk.id);
      expect(await store.containsPreKey(pk.id), isFalse);
    });

    test('SignedPreKeyRecord storage and retrieval', () async {
      final identityKeyPair = generateIdentityKeyPair();
      final signedPreKey = generateSignedPreKey(identityKeyPair, 1);

      await store.storeSignedPreKey(signedPreKey.id, signedPreKey);
      expect(await store.containsSignedPreKey(signedPreKey.id), isTrue);

      final loaded = await store.loadSignedPreKey(signedPreKey.id);
      expect(loaded.id, signedPreKey.id);
      expect(loaded.signature, signedPreKey.signature);
    });

    test('SessionRecord storage, retrieval and clearAll', () async {
      final address = SignalProtocolAddress('bob_user', 1);
      final sessionRecord = SessionRecord();

      await store.storeSession(address, sessionRecord);
      expect(await store.containsSession(address), isTrue);

      final loaded = await store.loadSession(address);
      expect(loaded, isNotNull);

      await store.clearAll();
      expect(await store.containsSession(address), isFalse);
    });
  });

  group('SecretChatBloc Tests', () {
    test('StartSecretChatSession flow works and transitions state', () async {
      final repo = FakeSecretChatRepository();
      final bloc = SecretChatBloc(
        repository: repo,
        currentUserId: 'my_uid',
      );

      expect(bloc.state, equals(const SecretChatInitial()));

      bloc.add(const StartSecretChatSession(
        recipientUid: 'user_bob',
        selfDestructDuration: 60,
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          const SecretChatLoading(),
          isA<SecretChatActive>()
              .having((s) => s.session.chatId, 'chatId', 'secret_test_123')
              .having((s) => s.session.selfDestructDuration, 'duration', 60),
        ]),
      );

      await bloc.close();
    });

    test('TerminateSecretChatSession terminates the session', () async {
      final repo = FakeSecretChatRepository();
      final bloc = SecretChatBloc(
        repository: repo,
        currentUserId: 'my_uid',
      );

      bloc.add(const StartSecretChatSession(recipientUid: 'user_bob'));

      await bloc.stream.firstWhere((s) => s is SecretChatActive);

      bloc.add(const TerminateSecretChatSession('secret_test_123'));

      await expectLater(
        bloc.stream,
        emits(isA<SecretChatTerminated>()),
      );

      await bloc.close();
    });
  });
}
