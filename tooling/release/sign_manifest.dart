import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sodium/sodium.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: sign_manifest.dart <dist>');
    exitCode = 64;
    return;
  }
  final encodedKey = Platform.environment['MAESTRO_RELEASE_SECRET_KEY_BASE64'];
  if (encodedKey == null || encodedKey.isEmpty) {
    stderr.writeln('publisher-signing: unconfigured');
    exitCode = 78;
    return;
  }
  final directory = Directory(arguments.single);
  final manifest = await File(
    '${directory.path}${Platform.pathSeparator}release-manifest.json',
  ).readAsBytes();
  final sodium = await SodiumInit.init();
  final secretKey = sodium.secureCopy(
    Uint8List.fromList(base64Decode(encodedKey)),
  );
  try {
    final signature = sodium.crypto.sign.detached(
      message: manifest,
      secretKey: secretKey,
    );
    await File(
      '${directory.path}${Platform.pathSeparator}release-manifest.sig',
    ).writeAsString(base64Encode(signature));
  } finally {
    secretKey.dispose();
  }
}
