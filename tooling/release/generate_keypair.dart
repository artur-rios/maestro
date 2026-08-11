import 'dart:convert';
import 'dart:io';

import 'package:sodium/sodium.dart';

Future<void> main() async {
  final sodium = await SodiumInit.init();
  final keys = sodium.crypto.sign.keyPair();
  try {
    stdout.writeln(
      'MAESTRO_RELEASE_SECRET_KEY_BASE64=${base64Encode(keys.secretKey.extractBytes())}',
    );
    stdout.writeln(
      'MAESTRO_RELEASE_PUBLIC_KEY_BASE64=${base64Encode(keys.publicKey)}',
    );
  } finally {
    keys.secretKey.dispose();
  }
}
