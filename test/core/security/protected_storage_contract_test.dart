import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/core/security/platform_protected_storage.dart';
import 'package:maestro/core/security/protected_storage.dart';

void main() {
  test(
    'GivenStoredSecret_WhenReadBack_ThenOnlyEncodedTextCrossesBoundary',
    () async {
      final strings = _FakeSecureStringStore();
      final storage = PlatformProtectedStorage(strings);
      final secret = Uint8List.fromList(utf8.encode('update-key-secret'));

      await storage.write('update-key', secret);

      expect(await storage.read('update-key'), secret);
      expect(strings.values['update-key'], base64Encode(secret));
      expect(
        strings.values['update-key'],
        isNot(contains('update-key-secret')),
      );
    },
  );
}

final class _FakeSecureStringStore implements SecureStringStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
