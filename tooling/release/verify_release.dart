import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sodium/sodium.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: verify_release.dart <dist>');
    exitCode = 64;
    return;
  }
  final directory = Directory(arguments.single);
  final manifestFile = File(
    '${directory.path}${Platform.pathSeparator}release-manifest.json',
  );
  final decoded = jsonDecode(await manifestFile.readAsString());
  if (decoded is! Map<String, Object?> ||
      decoded['artifacts'] is! List<Object?>) {
    throw const FormatException('Release manifest is malformed.');
  }
  for (final value in decoded['artifacts']! as List<Object?>) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Release artifact is malformed.');
    }
    final file = File(
      '${directory.path}${Platform.pathSeparator}${value['fileName']}',
    );
    final digest = await sha256.bind(file.openRead()).first;
    if (await file.length() != value['size'] ||
        digest.toString() != value['sha256']) {
      throw StateError('Release artifact failed verification: ${file.path}');
    }
  }

  final signatureFile = File(
    '${directory.path}${Platform.pathSeparator}release-manifest.sig',
  );
  final encodedPublicKey =
      Platform.environment['MAESTRO_RELEASE_PUBLIC_KEY_BASE64'];
  if (await signatureFile.exists() || encodedPublicKey != null) {
    if (!await signatureFile.exists() ||
        encodedPublicKey == null ||
        encodedPublicKey.isEmpty) {
      throw StateError('Signing material is incomplete.');
    }
    final sodium = await SodiumInit.init();
    final valid = sodium.crypto.sign.verifyDetached(
      message: await manifestFile.readAsBytes(),
      signature: Uint8List.fromList(
        base64Decode((await signatureFile.readAsString()).trim()),
      ),
      publicKey: Uint8List.fromList(base64Decode(encodedPublicKey)),
    );
    if (!valid) {
      throw StateError('Release manifest signature is invalid.');
    }
    stdout.writeln('publisher-signing: verified');
  } else {
    stdout.writeln('publisher-signing: unconfigured');
  }
  stdout.writeln('release-verification: passed');
}
