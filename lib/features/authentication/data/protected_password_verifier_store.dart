import 'dart:convert';
import 'dart:typed_data';

import 'package:maestro/core/security/protected_storage.dart';
import 'package:maestro/features/authentication/application/authentication_service.dart';

final class ProtectedPasswordVerifierStore implements PasswordVerifierStore {
  const ProtectedPasswordVerifierStore(this._storage);

  final ProtectedStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key);

  @override
  Future<String?> read(String key) async {
    final value = await _storage.read(key);
    return value == null ? null : utf8.decode(value);
  }

  @override
  Future<void> write(String key, String verifier) {
    return _storage.write(key, Uint8List.fromList(utf8.encode(verifier)));
  }
}
