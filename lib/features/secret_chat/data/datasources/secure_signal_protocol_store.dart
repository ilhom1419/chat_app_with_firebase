import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

class SecureSignalProtocolStore implements SignalProtocolStore {
  final FlutterSecureStorage _storage;
  final String _prefix;

  IdentityKeyPair? _cachedIdentityKeyPair;
  int? _cachedRegistrationId;
  final Map<int, PreKeyRecord> _preKeyCache = {};
  final Map<int, SignedPreKeyRecord> _signedPreKeyCache = {};
  final Map<String, SessionRecord> _sessionCache = {};
  final Map<String, IdentityKey> _trustedIdentities = {};

  SecureSignalProtocolStore(this._storage, {String prefix = 'sec_signal_'})
      : _prefix = prefix;

  String _k(String key) => '$_prefix$key';

  // =========================================================================
  // IDENTITY KEY STORE
  // =========================================================================

  @override
  Future<IdentityKeyPair> getIdentityKeyPair() async {
    if (_cachedIdentityKeyPair != null) {
      return _cachedIdentityKeyPair!;
    }
    final raw = await _storage.read(key: _k('identity_key_pair'));
    if (raw == null) {
      throw InvalidKeyException('Identity key pair not found in secure storage');
    }
    final bytes = base64Decode(raw);
    _cachedIdentityKeyPair = IdentityKeyPair.fromSerialized(bytes);
    return _cachedIdentityKeyPair!;
  }

  Future<void> saveLocalIdentityKeyPair(IdentityKeyPair keyPair) async {
    _cachedIdentityKeyPair = keyPair;
    final bytes = keyPair.serialize();
    await _storage.write(
      key: _k('identity_key_pair'),
      value: base64Encode(bytes),
    );
  }

  @override
  Future<int> getLocalRegistrationId() async {
    if (_cachedRegistrationId != null) {
      return _cachedRegistrationId!;
    }
    final raw = await _storage.read(key: _k('registration_id'));
    if (raw == null) {
      throw InvalidKeyException('Registration ID not found in secure storage');
    }
    _cachedRegistrationId = int.parse(raw);
    return _cachedRegistrationId!;
  }

  Future<void> saveLocalRegistrationId(int registrationId) async {
    _cachedRegistrationId = registrationId;
    await _storage.write(
      key: _k('registration_id'),
      value: registrationId.toString(),
    );
  }

  @override
  Future<bool> saveIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
  ) async {
    if (identityKey == null) return false;
    final addressKey = '${address.getName()}:${address.getDeviceId()}';
    final existing = _trustedIdentities[addressKey];
    if (existing == null || existing != identityKey) {
      _trustedIdentities[addressKey] = identityKey;
      await _storage.write(
        key: _k('trusted_id_$addressKey'),
        value: base64Encode(identityKey.serialize()),
      );
      return true;
    }
    return false;
  }

  @override
  Future<bool> isTrustedIdentity(
    SignalProtocolAddress address,
    IdentityKey? identityKey,
    Direction direction,
  ) async {
    if (identityKey == null) return false;
    final addressKey = '${address.getName()}:${address.getDeviceId()}';
    if (!_trustedIdentities.containsKey(addressKey)) {
      final raw = await _storage.read(key: _k('trusted_id_$addressKey'));
      if (raw != null) {
        _trustedIdentities[addressKey] =
            IdentityKey.fromBytes(base64Decode(raw), 0);
      }
    }
    final trusted = _trustedIdentities[addressKey];
    if (trusted == null) {
      // First time communicating with this identity -> trust on first use (TOFU)
      return true;
    }
    return trusted == identityKey;
  }

  @override
  Future<IdentityKey?> getIdentity(SignalProtocolAddress address) async {
    final addressKey = '${address.getName()}:${address.getDeviceId()}';
    if (_trustedIdentities.containsKey(addressKey)) {
      return _trustedIdentities[addressKey];
    }
    final raw = await _storage.read(key: _k('trusted_id_$addressKey'));
    if (raw != null) {
      final identity = IdentityKey.fromBytes(base64Decode(raw), 0);
      _trustedIdentities[addressKey] = identity;
      return identity;
    }
    return null;
  }

  // =========================================================================
  // PREKEY STORE
  // =========================================================================

  @override
  Future<PreKeyRecord> loadPreKey(int preKeyId) async {
    if (_preKeyCache.containsKey(preKeyId)) {
      return _preKeyCache[preKeyId]!;
    }
    final raw = await _storage.read(key: _k('prekey_$preKeyId'));
    if (raw == null) {
      throw InvalidKeyIdException('PreKeyRecord with id $preKeyId not found');
    }
    final record = PreKeyRecord.fromBuffer(base64Decode(raw));
    _preKeyCache[preKeyId] = record;
    return record;
  }

  @override
  Future<void> storePreKey(int preKeyId, PreKeyRecord record) async {
    _preKeyCache[preKeyId] = record;
    await _storage.write(
      key: _k('prekey_$preKeyId'),
      value: base64Encode(record.serialize()),
    );
  }

  @override
  Future<bool> containsPreKey(int preKeyId) async {
    if (_preKeyCache.containsKey(preKeyId)) return true;
    final raw = await _storage.read(key: _k('prekey_$preKeyId'));
    return raw != null;
  }

  @override
  Future<void> removePreKey(int preKeyId) async {
    _preKeyCache.remove(preKeyId);
    await _storage.delete(key: _k('prekey_$preKeyId'));
  }

  // =========================================================================
  // SIGNED PREKEY STORE
  // =========================================================================

  @override
  Future<SignedPreKeyRecord> loadSignedPreKey(int signedPreKeyId) async {
    if (_signedPreKeyCache.containsKey(signedPreKeyId)) {
      return _signedPreKeyCache[signedPreKeyId]!;
    }
    final raw = await _storage.read(key: _k('signed_prekey_$signedPreKeyId'));
    if (raw == null) {
      throw InvalidKeyIdException(
          'SignedPreKeyRecord with id $signedPreKeyId not found');
    }
    final record = SignedPreKeyRecord.fromSerialized(base64Decode(raw));
    _signedPreKeyCache[signedPreKeyId] = record;
    return record;
  }

  @override
  Future<List<SignedPreKeyRecord>> loadSignedPreKeys() async {
    // Return all cached and stored signed prekeys
    return _signedPreKeyCache.values.toList();
  }

  @override
  Future<void> storeSignedPreKey(
      int signedPreKeyId, SignedPreKeyRecord record) async {
    _signedPreKeyCache[signedPreKeyId] = record;
    await _storage.write(
      key: _k('signed_prekey_$signedPreKeyId'),
      value: base64Encode(record.serialize()),
    );
  }

  @override
  Future<bool> containsSignedPreKey(int signedPreKeyId) async {
    if (_signedPreKeyCache.containsKey(signedPreKeyId)) return true;
    final raw = await _storage.read(key: _k('signed_prekey_$signedPreKeyId'));
    return raw != null;
  }

  @override
  Future<void> removeSignedPreKey(int signedPreKeyId) async {
    _signedPreKeyCache.remove(signedPreKeyId);
    await _storage.delete(key: _k('signed_prekey_$signedPreKeyId'));
  }

  // =========================================================================
  // SESSION STORE
  // =========================================================================

  String _sessionKey(SignalProtocolAddress address) =>
      '${address.getName()}__${address.getDeviceId()}';

  @override
  Future<SessionRecord> loadSession(SignalProtocolAddress address) async {
    final sKey = _sessionKey(address);
    if (_sessionCache.containsKey(sKey)) {
      return _sessionCache[sKey]!;
    }
    final raw = await _storage.read(key: _k('session_$sKey'));
    if (raw != null) {
      final record = SessionRecord.fromSerialized(base64Decode(raw));
      _sessionCache[sKey] = record;
      return record;
    }
    // Return fresh new session record if none exists
    return SessionRecord();
  }

  @override
  Future<List<int>> getSubDeviceSessions(String name) async {
    // Single device per secret chat architecture for now
    return [];
  }

  @override
  Future<void> storeSession(
      SignalProtocolAddress address, SessionRecord record) async {
    final sKey = _sessionKey(address);
    _sessionCache[sKey] = record;
    await _storage.write(
      key: _k('session_$sKey'),
      value: base64Encode(record.serialize()),
    );
  }

  @override
  Future<bool> containsSession(SignalProtocolAddress address) async {
    final sKey = _sessionKey(address);
    if (_sessionCache.containsKey(sKey)) return true;
    final raw = await _storage.read(key: _k('session_$sKey'));
    return raw != null;
  }

  @override
  Future<void> deleteSession(SignalProtocolAddress address) async {
    final sKey = _sessionKey(address);
    _sessionCache.remove(sKey);
    await _storage.delete(key: _k('session_$sKey'));
  }

  @override
  Future<void> deleteAllSessions(String name) async {
    _sessionCache.removeWhere((k, _) => k.startsWith('${name}__'));
  }

  /// Purge all local Signal crypto material (e.g. on logout or key reset)
  Future<void> clearAll() async {
    _cachedIdentityKeyPair = null;
    _cachedRegistrationId = null;
    _preKeyCache.clear();
    _signedPreKeyCache.clear();
    _sessionCache.clear();
    _trustedIdentities.clear();
    await _storage.deleteAll();
  }
}
