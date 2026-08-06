import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:maestro/features/runs/domain/run_models.dart';
import 'package:path/path.dart' as p;

sealed class AttemptResultRead {
  const AttemptResultRead();
}

final class AttemptResultAccepted extends AttemptResultRead {
  const AttemptResultAccepted(this.context);

  final DeclaredContext context;
}

final class AttemptResultRejected extends AttemptResultRead {
  const AttemptResultRejected(this.code);

  final String code;
}

final class AttemptResultProtocol {
  AttemptResultProtocol({
    String Function()? quarantineToken,
    this._afterQuarantine,
  }) : _quarantineToken = quarantineToken ?? _randomToken;

  final String Function() _quarantineToken;
  final Future<void> Function(String path)? _afterQuarantine;
  static const int maximumBytes = 256 * 1024;
  static const Set<String> _fields = <String>{
    'schema',
    'attemptId',
    'nonce',
    'outcome',
    'context',
  };

  Future<AttemptResultRead> consume({
    required String path,
    required String resultRoot,
    required String attemptId,
    required String nonce,
  }) async {
    final root = p.normalize(p.absolute(resultRoot));
    final candidate = p.normalize(p.absolute(path));
    if (!p.isWithin(root, candidate)) {
      return const AttemptResultRejected('result.unsafe_path');
    }
    String? quarantined;
    try {
      final initialType = await FileSystemEntity.type(
        candidate,
        followLinks: false,
      );
      if (initialType == FileSystemEntityType.notFound) {
        return const AttemptResultRejected('result.missing');
      }
      if (initialType != FileSystemEntityType.file) {
        return const AttemptResultRejected('result.not_regular');
      }
      final quarantineRoot = p.join(root, '.quarantine');
      await Directory(quarantineRoot).create(recursive: true);
      quarantined = p.join(quarantineRoot, '${_quarantineToken()}.result');
      await File(candidate).rename(quarantined);
      await _afterQuarantine?.call(quarantined);
      final type = await FileSystemEntity.type(quarantined, followLinks: false);
      if (type != FileSystemEntityType.file) {
        return const AttemptResultRejected('result.not_regular');
      }
      final file = File(quarantined);
      final length = await file.length();
      if (length > maximumBytes) {
        return const AttemptResultRejected('result.oversized');
      }
      final bytes = await file
          .openRead(0, maximumBytes + 1)
          .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
      if (bytes.length > maximumBytes) {
        return const AttemptResultRejected('result.oversized');
      }
      final source = utf8.decode(bytes, allowMalformed: false);
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, Object?>) {
        return const AttemptResultRejected('result.malformed');
      }
      final keys = _topLevelKeys(source);
      if (keys == null) {
        return const AttemptResultRejected('result.malformed');
      }
      if (keys.length != keys.toSet().length) {
        return const AttemptResultRejected('result.duplicate_field');
      }
      if (keys.length != _fields.length || !keys.toSet().containsAll(_fields)) {
        return const AttemptResultRejected('result.unknown_field');
      }
      if (decoded['schema'] is! int ||
          decoded['schema'] != 1 ||
          decoded['attemptId'] is! String ||
          decoded['nonce'] is! String ||
          decoded['outcome'] != 'succeeded' ||
          decoded['context'] is! String) {
        return const AttemptResultRejected('result.malformed');
      }
      if (await FileSystemEntity.type(quarantined, followLinks: false) !=
          FileSystemEntityType.file) {
        return const AttemptResultRejected('result.not_regular');
      }
      if (decoded['attemptId'] != attemptId) {
        return const AttemptResultRejected('result.attempt_mismatch');
      }
      if (decoded['nonce'] != nonce) {
        return const AttemptResultRejected('result.nonce_mismatch');
      }
      try {
        return AttemptResultAccepted(
          DeclaredContext.parse(decoded['context']! as String),
        );
      } on DeclaredContextTooLarge {
        return const AttemptResultRejected('result.context_oversized');
      }
    } on FormatException {
      return const AttemptResultRejected('result.malformed');
    } on FileSystemException {
      return const AttemptResultRejected('result.missing');
    } finally {
      try {
        final path = quarantined;
        if (path != null) {
          final type = await FileSystemEntity.type(path, followLinks: false);
          if (type == FileSystemEntityType.link) {
            await Link(path).delete();
          } else if (type == FileSystemEntityType.file) {
            await File(path).delete();
          }
        }
      } on FileSystemException {
        // Missing and hostile file replacements remain typed read failures.
      }
    }
  }
}

String _randomToken() {
  final random = Random.secure();
  return List<String>.generate(
    4,
    (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
  ).join();
}

List<String>? _topLevelKeys(String source) {
  final keys = <String>[];
  var index = 0;
  var depth = 0;
  var expectsKey = false;
  while (index < source.length) {
    final code = source.codeUnitAt(index);
    if (code == 0x7b) {
      depth++;
      if (depth == 1) expectsKey = true;
      index++;
      continue;
    }
    if (code == 0x7d) {
      depth--;
      index++;
      continue;
    }
    if (code == 0x2c && depth == 1) {
      expectsKey = true;
      index++;
      continue;
    }
    if (code == 0x22) {
      final start = index++;
      var escaped = false;
      while (index < source.length) {
        final current = source.codeUnitAt(index++);
        if (escaped) {
          escaped = false;
        } else if (current == 0x5c) {
          escaped = true;
        } else if (current == 0x22) {
          break;
        }
      }
      if (expectsKey && depth == 1) {
        var cursor = index;
        while (cursor < source.length &&
            const <int>{
              0x20,
              0x09,
              0x0a,
              0x0d,
            }.contains(source.codeUnitAt(cursor))) {
          cursor++;
        }
        if (cursor >= source.length || source.codeUnitAt(cursor) != 0x3a) {
          return null;
        }
        keys.add(jsonDecode(source.substring(start, index)) as String);
        expectsKey = false;
      }
      continue;
    }
    index++;
  }
  return depth == 0 ? keys : null;
}
