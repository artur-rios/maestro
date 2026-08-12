import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sodium/sodium.dart';

import 'release_artifacts.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: verify_release.dart <dist>');
    exitCode = 64;
    return;
  }
  final directory = Directory(arguments.single);
  final distributionFiles = await validateDistributionPackages(directory);
  final filesByName = <String, File>{
    for (final file in distributionFiles) file.uri.pathSegments.last: file,
  };
  final expectedSums = parseSha256Sums(
    await File(
      '${directory.path}${Platform.pathSeparator}SHA256SUMS',
    ).readAsString(),
  );
  final actualDigests = <String, String>{};
  for (final entry in filesByName.entries) {
    final digest = await sha256.bind(entry.value.openRead()).first;
    final actualDigest = digest.toString();
    actualDigests[entry.key] = actualDigest;
    if (expectedSums[entry.key] != actualDigest) {
      throw StateError('Release package failed checksum: ${entry.value.path}');
    }
  }
  final manifestFile = File(
    '${directory.path}${Platform.pathSeparator}release-manifest.json',
  );
  final decoded = jsonDecode(await manifestFile.readAsString());
  if (decoded is! Map<String, Object?> ||
      decoded['artifacts'] is! List<Object?>) {
    throw const FormatException('Release manifest is malformed.');
  }
  final artifacts = decoded['artifacts']! as List<Object?>;
  final manifestNames = <String>{};
  for (final value in artifacts) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Release artifact is malformed.');
    }
    final fileName = value['fileName'];
    if (fileName is! String ||
        !runtimePackageNames.contains(fileName) ||
        !manifestNames.add(fileName)) {
      throw const FormatException(
        'Release manifest contains an unexpected artifact.',
      );
    }
    final file = filesByName[fileName]!;
    if (await file.length() != value['size'] ||
        actualDigests[fileName] != value['sha256']) {
      throw StateError('Release artifact failed verification: ${file.path}');
    }
  }
  if (manifestNames.length != runtimePackageNames.length ||
      !manifestNames.containsAll(runtimePackageNames)) {
    throw const FormatException(
      'Release manifest does not contain the required runtime package set.',
    );
  }

  final signatureFile = File(
    '${directory.path}${Platform.pathSeparator}release-manifest.sig',
  );
  final encodedPublicKey = Platform
      .environment['MAESTRO_RELEASE_PUBLIC_KEY_BASE64']
      ?.trim();
  final encodedSignature = await signatureFile.exists()
      ? (await signatureFile.readAsString()).trim()
      : null;
  final signatureConfigured = encodedSignature?.isNotEmpty ?? false;
  final publicKeyConfigured = encodedPublicKey?.isNotEmpty ?? false;
  if (signatureConfigured || publicKeyConfigured) {
    if (!signatureConfigured || !publicKeyConfigured) {
      throw StateError('Signing material is incomplete.');
    }
    final sodium = await SodiumInit.init();
    final valid = sodium.crypto.sign.verifyDetached(
      message: await manifestFile.readAsBytes(),
      signature: Uint8List.fromList(base64Decode(encodedSignature!)),
      publicKey: Uint8List.fromList(base64Decode(encodedPublicKey!)),
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
