import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/security/protected_storage.dart';
import 'package:maestro/features/authentication/data/protected_password_verifier_store.dart';

void main() {
  const verifierKey =
      'maestro.auth.verifier.0198a4f4-3980-7000-8000-000000000001';

  test(
    'GivenVerifier_WhenWrittenAndRead_ThenUtf8ValueRoundTripsUnderExactKey',
    () async {
      final storage = _MemoryProtectedStorage();
      final store = ProtectedPasswordVerifierStore(storage);
      const verifier = 'opaque-verifier-✓';

      await store.write(verifierKey, verifier);

      expect(storage.keys, <String>{verifierKey});
      expect(storage.valueFor(verifierKey), <int>[
        111,
        112,
        97,
        113,
        117,
        101,
        45,
        118,
        101,
        114,
        105,
        102,
        105,
        101,
        114,
        45,
        226,
        156,
        147,
      ]);
      expect(await store.read(verifierKey), verifier);
    },
  );

  test(
    'GivenStoredVerifier_WhenDeleted_ThenExactProtectedStorageEntryIsRemoved',
    () async {
      final storage = _MemoryProtectedStorage();
      final store = ProtectedPasswordVerifierStore(storage);

      await store.write(verifierKey, 'opaque-verifier');
      await store.delete(verifierKey);

      expect(storage.keys, isEmpty);
      expect(await store.read(verifierKey), isNull);
    },
  );
}

final class _MemoryProtectedStorage implements ProtectedStorage {
  final Map<String, Uint8List> _values = <String, Uint8List>{};

  Set<String> get keys => _values.keys.toSet();

  Uint8List? valueFor(String key) => _values[key];

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<Uint8List?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, Uint8List value) async {
    _values[key] = Uint8List.fromList(value);
  }
}
