import 'dart:typed_data';

abstract interface class ProtectedStorage {
  Future<void> write(String key, Uint8List value);
  Future<Uint8List?> read(String key);
  Future<void> delete(String key);
}

abstract interface class SecureStringStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}
