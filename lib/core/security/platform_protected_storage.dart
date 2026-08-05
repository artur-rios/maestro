import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:maestro/core/security/protected_storage.dart';

final class PlatformProtectedStorage implements ProtectedStorage {
  const PlatformProtectedStorage(this._store);

  final SecureStringStore _store;

  @override
  Future<void> delete(String key) => _store.delete(key);

  @override
  Future<Uint8List?> read(String key) async {
    final encoded = await _store.read(key);
    return encoded == null ? null : base64Decode(encoded);
  }

  @override
  Future<void> write(String key, Uint8List value) {
    return _store.write(key, base64Encode(value));
  }
}

final class FlutterSecureStringStore implements SecureStringStore {
  const FlutterSecureStringStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }
}
