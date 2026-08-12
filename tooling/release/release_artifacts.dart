import 'dart:io';

import 'package:crypto/crypto.dart';

const runtimePackageNames = <String>{
  'maestro-windows-x64.zip',
  'maestro-windows-x64.msix',
  'maestro-linux-x64.AppImage',
  'maestro-linux-amd64.deb',
};

const distributionPackageNames = <String>{
  ...runtimePackageNames,
  'maestro-windows-x64-setup.exe',
};

const _managedPackageExtensions = <String>{
  '.zip',
  '.msix',
  '.exe',
  '.appimage',
  '.deb',
};

Future<List<File>> validateDistributionPackages(Directory directory) async {
  final managedFiles = directory
      .listSync()
      .whereType<File>()
      .where((file) => _isManagedPackage(_fileName(file)))
      .toList(growable: false);
  final actualNames = managedFiles.map(_fileName).toSet();
  if (actualNames.length != distributionPackageNames.length ||
      !actualNames.containsAll(distributionPackageNames)) {
    throw StateError(
      'Distribution packages do not match the required package set.',
    );
  }
  for (final file in managedFiles) {
    if (await file.length() == 0) {
      throw StateError('Distribution package is empty: ${_fileName(file)}');
    }
  }
  managedFiles.sort(
    (first, second) => _fileName(first).compareTo(_fileName(second)),
  );
  return managedFiles;
}

Future<String> createSha256Sums(Iterable<File> files) async {
  final entries = <({String digest, String fileName})>[];
  for (final file in files) {
    final digest = await sha256.bind(file.openRead()).first;
    entries.add((digest: digest.toString(), fileName: _fileName(file)));
  }
  entries.sort((first, second) => first.fileName.compareTo(second.fileName));
  return entries.map((entry) => '${entry.digest}  ${entry.fileName}\n').join();
}

Map<String, String> parseSha256Sums(String source) {
  final result = <String, String>{};
  final lines = source.split(RegExp(r'\r?\n'));
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  for (final line in lines) {
    final match = RegExp(r'^([0-9a-fA-F]{64})  ([^\\/]+)$').firstMatch(line);
    if (match == null) {
      throw const FormatException('SHA256SUMS contains a malformed entry.');
    }
    final fileName = match.group(2)!;
    if (!distributionPackageNames.contains(fileName) ||
        result.containsKey(fileName)) {
      throw const FormatException('SHA256SUMS contains an unexpected entry.');
    }
    result[fileName] = match.group(1)!.toLowerCase();
  }
  if (result.length != distributionPackageNames.length ||
      !result.keys.toSet().containsAll(distributionPackageNames)) {
    throw const FormatException(
      'SHA256SUMS does not contain the required package set.',
    );
  }
  return result;
}

bool _isManagedPackage(String fileName) {
  final lower = fileName.toLowerCase();
  return _managedPackageExtensions.any(lower.endsWith);
}

String _fileName(File file) => file.uri.pathSegments.last;
