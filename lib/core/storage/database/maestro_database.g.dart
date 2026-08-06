// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'maestro_database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const Setting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Setting copyWith({String? key, String? value, DateTime? updatedAt}) =>
      Setting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiagnosticLogSegmentsTable extends DiagnosticLogSegments
    with TableInfo<$DiagnosticLogSegmentsTable, DiagnosticLogSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiagnosticLogSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sequenceStartMeta = const VerificationMeta(
    'sequenceStart',
  );
  @override
  late final GeneratedColumn<int> sequenceStart = GeneratedColumn<int>(
    'sequence_start',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceEndMeta = const VerificationMeta(
    'sequenceEnd',
  );
  @override
  late final GeneratedColumn<int> sequenceEnd = GeneratedColumn<int>(
    'sequence_end',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalByteLengthMeta =
      const VerificationMeta('originalByteLength');
  @override
  late final GeneratedColumn<int> originalByteLength = GeneratedColumn<int>(
    'original_byte_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _compressedByteLengthMeta =
      const VerificationMeta('compressedByteLength');
  @override
  late final GeneratedColumn<int> compressedByteLength = GeneratedColumn<int>(
    'compressed_byte_length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _compressedBytesMeta = const VerificationMeta(
    'compressedBytes',
  );
  @override
  late final GeneratedColumn<Uint8List> compressedBytes =
      GeneratedColumn<Uint8List>(
        'compressed_bytes',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    sequenceStart,
    sequenceEnd,
    originalByteLength,
    compressedByteLength,
    compressedBytes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diagnostic_log_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiagnosticLogSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('sequence_start')) {
      context.handle(
        _sequenceStartMeta,
        sequenceStart.isAcceptableOrUnknown(
          data['sequence_start']!,
          _sequenceStartMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sequenceStartMeta);
    }
    if (data.containsKey('sequence_end')) {
      context.handle(
        _sequenceEndMeta,
        sequenceEnd.isAcceptableOrUnknown(
          data['sequence_end']!,
          _sequenceEndMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sequenceEndMeta);
    }
    if (data.containsKey('original_byte_length')) {
      context.handle(
        _originalByteLengthMeta,
        originalByteLength.isAcceptableOrUnknown(
          data['original_byte_length']!,
          _originalByteLengthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalByteLengthMeta);
    }
    if (data.containsKey('compressed_byte_length')) {
      context.handle(
        _compressedByteLengthMeta,
        compressedByteLength.isAcceptableOrUnknown(
          data['compressed_byte_length']!,
          _compressedByteLengthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_compressedByteLengthMeta);
    }
    if (data.containsKey('compressed_bytes')) {
      context.handle(
        _compressedBytesMeta,
        compressedBytes.isAcceptableOrUnknown(
          data['compressed_bytes']!,
          _compressedBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_compressedBytesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiagnosticLogSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiagnosticLogSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      sequenceStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence_start'],
      )!,
      sequenceEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence_end'],
      )!,
      originalByteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}original_byte_length'],
      )!,
      compressedByteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}compressed_byte_length'],
      )!,
      compressedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}compressed_bytes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DiagnosticLogSegmentsTable createAlias(String alias) {
    return $DiagnosticLogSegmentsTable(attachedDatabase, alias);
  }
}

class DiagnosticLogSegment extends DataClass
    implements Insertable<DiagnosticLogSegment> {
  final String id;
  final String? runId;
  final int sequenceStart;
  final int sequenceEnd;
  final int originalByteLength;
  final int compressedByteLength;
  final Uint8List compressedBytes;
  final DateTime createdAt;
  const DiagnosticLogSegment({
    required this.id,
    this.runId,
    required this.sequenceStart,
    required this.sequenceEnd,
    required this.originalByteLength,
    required this.compressedByteLength,
    required this.compressedBytes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    map['sequence_start'] = Variable<int>(sequenceStart);
    map['sequence_end'] = Variable<int>(sequenceEnd);
    map['original_byte_length'] = Variable<int>(originalByteLength);
    map['compressed_byte_length'] = Variable<int>(compressedByteLength);
    map['compressed_bytes'] = Variable<Uint8List>(compressedBytes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DiagnosticLogSegmentsCompanion toCompanion(bool nullToAbsent) {
    return DiagnosticLogSegmentsCompanion(
      id: Value(id),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      sequenceStart: Value(sequenceStart),
      sequenceEnd: Value(sequenceEnd),
      originalByteLength: Value(originalByteLength),
      compressedByteLength: Value(compressedByteLength),
      compressedBytes: Value(compressedBytes),
      createdAt: Value(createdAt),
    );
  }

  factory DiagnosticLogSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiagnosticLogSegment(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String?>(json['runId']),
      sequenceStart: serializer.fromJson<int>(json['sequenceStart']),
      sequenceEnd: serializer.fromJson<int>(json['sequenceEnd']),
      originalByteLength: serializer.fromJson<int>(json['originalByteLength']),
      compressedByteLength: serializer.fromJson<int>(
        json['compressedByteLength'],
      ),
      compressedBytes: serializer.fromJson<Uint8List>(json['compressedBytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String?>(runId),
      'sequenceStart': serializer.toJson<int>(sequenceStart),
      'sequenceEnd': serializer.toJson<int>(sequenceEnd),
      'originalByteLength': serializer.toJson<int>(originalByteLength),
      'compressedByteLength': serializer.toJson<int>(compressedByteLength),
      'compressedBytes': serializer.toJson<Uint8List>(compressedBytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DiagnosticLogSegment copyWith({
    String? id,
    Value<String?> runId = const Value.absent(),
    int? sequenceStart,
    int? sequenceEnd,
    int? originalByteLength,
    int? compressedByteLength,
    Uint8List? compressedBytes,
    DateTime? createdAt,
  }) => DiagnosticLogSegment(
    id: id ?? this.id,
    runId: runId.present ? runId.value : this.runId,
    sequenceStart: sequenceStart ?? this.sequenceStart,
    sequenceEnd: sequenceEnd ?? this.sequenceEnd,
    originalByteLength: originalByteLength ?? this.originalByteLength,
    compressedByteLength: compressedByteLength ?? this.compressedByteLength,
    compressedBytes: compressedBytes ?? this.compressedBytes,
    createdAt: createdAt ?? this.createdAt,
  );
  DiagnosticLogSegment copyWithCompanion(DiagnosticLogSegmentsCompanion data) {
    return DiagnosticLogSegment(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      sequenceStart: data.sequenceStart.present
          ? data.sequenceStart.value
          : this.sequenceStart,
      sequenceEnd: data.sequenceEnd.present
          ? data.sequenceEnd.value
          : this.sequenceEnd,
      originalByteLength: data.originalByteLength.present
          ? data.originalByteLength.value
          : this.originalByteLength,
      compressedByteLength: data.compressedByteLength.present
          ? data.compressedByteLength.value
          : this.compressedByteLength,
      compressedBytes: data.compressedBytes.present
          ? data.compressedBytes.value
          : this.compressedBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiagnosticLogSegment(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('sequenceStart: $sequenceStart, ')
          ..write('sequenceEnd: $sequenceEnd, ')
          ..write('originalByteLength: $originalByteLength, ')
          ..write('compressedByteLength: $compressedByteLength, ')
          ..write('compressedBytes: $compressedBytes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    sequenceStart,
    sequenceEnd,
    originalByteLength,
    compressedByteLength,
    $driftBlobEquality.hash(compressedBytes),
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiagnosticLogSegment &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.sequenceStart == this.sequenceStart &&
          other.sequenceEnd == this.sequenceEnd &&
          other.originalByteLength == this.originalByteLength &&
          other.compressedByteLength == this.compressedByteLength &&
          $driftBlobEquality.equals(
            other.compressedBytes,
            this.compressedBytes,
          ) &&
          other.createdAt == this.createdAt);
}

class DiagnosticLogSegmentsCompanion
    extends UpdateCompanion<DiagnosticLogSegment> {
  final Value<String> id;
  final Value<String?> runId;
  final Value<int> sequenceStart;
  final Value<int> sequenceEnd;
  final Value<int> originalByteLength;
  final Value<int> compressedByteLength;
  final Value<Uint8List> compressedBytes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DiagnosticLogSegmentsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.sequenceStart = const Value.absent(),
    this.sequenceEnd = const Value.absent(),
    this.originalByteLength = const Value.absent(),
    this.compressedByteLength = const Value.absent(),
    this.compressedBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiagnosticLogSegmentsCompanion.insert({
    required String id,
    this.runId = const Value.absent(),
    required int sequenceStart,
    required int sequenceEnd,
    required int originalByteLength,
    required int compressedByteLength,
    required Uint8List compressedBytes,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sequenceStart = Value(sequenceStart),
       sequenceEnd = Value(sequenceEnd),
       originalByteLength = Value(originalByteLength),
       compressedByteLength = Value(compressedByteLength),
       compressedBytes = Value(compressedBytes);
  static Insertable<DiagnosticLogSegment> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<int>? sequenceStart,
    Expression<int>? sequenceEnd,
    Expression<int>? originalByteLength,
    Expression<int>? compressedByteLength,
    Expression<Uint8List>? compressedBytes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (sequenceStart != null) 'sequence_start': sequenceStart,
      if (sequenceEnd != null) 'sequence_end': sequenceEnd,
      if (originalByteLength != null)
        'original_byte_length': originalByteLength,
      if (compressedByteLength != null)
        'compressed_byte_length': compressedByteLength,
      if (compressedBytes != null) 'compressed_bytes': compressedBytes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiagnosticLogSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String?>? runId,
    Value<int>? sequenceStart,
    Value<int>? sequenceEnd,
    Value<int>? originalByteLength,
    Value<int>? compressedByteLength,
    Value<Uint8List>? compressedBytes,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DiagnosticLogSegmentsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      sequenceStart: sequenceStart ?? this.sequenceStart,
      sequenceEnd: sequenceEnd ?? this.sequenceEnd,
      originalByteLength: originalByteLength ?? this.originalByteLength,
      compressedByteLength: compressedByteLength ?? this.compressedByteLength,
      compressedBytes: compressedBytes ?? this.compressedBytes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (sequenceStart.present) {
      map['sequence_start'] = Variable<int>(sequenceStart.value);
    }
    if (sequenceEnd.present) {
      map['sequence_end'] = Variable<int>(sequenceEnd.value);
    }
    if (originalByteLength.present) {
      map['original_byte_length'] = Variable<int>(originalByteLength.value);
    }
    if (compressedByteLength.present) {
      map['compressed_byte_length'] = Variable<int>(compressedByteLength.value);
    }
    if (compressedBytes.present) {
      map['compressed_bytes'] = Variable<Uint8List>(compressedBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiagnosticLogSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('sequenceStart: $sequenceStart, ')
          ..write('sequenceEnd: $sequenceEnd, ')
          ..write('originalByteLength: $originalByteLength, ')
          ..write('compressedByteLength: $compressedByteLength, ')
          ..write('compressedBytes: $compressedBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OwnedResourcesTable extends OwnedResources
    with TableInfo<$OwnedResourcesTable, OwnedResource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OwnedResourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _processIdMeta = const VerificationMeta(
    'processId',
  );
  @override
  late final GeneratedColumn<int> processId = GeneratedColumn<int>(
    'process_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastReconciledAtMeta = const VerificationMeta(
    'lastReconciledAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReconciledAt =
      GeneratedColumn<DateTime>(
        'last_reconciled_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    path,
    runId,
    processId,
    state,
    createdAt,
    lastReconciledAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'owned_resources';
  @override
  VerificationContext validateIntegrity(
    Insertable<OwnedResource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    }
    if (data.containsKey('process_id')) {
      context.handle(
        _processIdMeta,
        processId.isAcceptableOrUnknown(data['process_id']!, _processIdMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('last_reconciled_at')) {
      context.handle(
        _lastReconciledAtMeta,
        lastReconciledAt.isAcceptableOrUnknown(
          data['last_reconciled_at']!,
          _lastReconciledAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OwnedResource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OwnedResource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      ),
      processId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}process_id'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastReconciledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_reconciled_at'],
      ),
    );
  }

  @override
  $OwnedResourcesTable createAlias(String alias) {
    return $OwnedResourcesTable(attachedDatabase, alias);
  }
}

class OwnedResource extends DataClass implements Insertable<OwnedResource> {
  final String id;
  final String kind;
  final String path;
  final String? runId;
  final int? processId;
  final String state;
  final DateTime createdAt;
  final DateTime? lastReconciledAt;
  const OwnedResource({
    required this.id,
    required this.kind,
    required this.path,
    this.runId,
    this.processId,
    required this.state,
    required this.createdAt,
    this.lastReconciledAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || runId != null) {
      map['run_id'] = Variable<String>(runId);
    }
    if (!nullToAbsent || processId != null) {
      map['process_id'] = Variable<int>(processId);
    }
    map['state'] = Variable<String>(state);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastReconciledAt != null) {
      map['last_reconciled_at'] = Variable<DateTime>(lastReconciledAt);
    }
    return map;
  }

  OwnedResourcesCompanion toCompanion(bool nullToAbsent) {
    return OwnedResourcesCompanion(
      id: Value(id),
      kind: Value(kind),
      path: Value(path),
      runId: runId == null && nullToAbsent
          ? const Value.absent()
          : Value(runId),
      processId: processId == null && nullToAbsent
          ? const Value.absent()
          : Value(processId),
      state: Value(state),
      createdAt: Value(createdAt),
      lastReconciledAt: lastReconciledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReconciledAt),
    );
  }

  factory OwnedResource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OwnedResource(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      path: serializer.fromJson<String>(json['path']),
      runId: serializer.fromJson<String?>(json['runId']),
      processId: serializer.fromJson<int?>(json['processId']),
      state: serializer.fromJson<String>(json['state']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastReconciledAt: serializer.fromJson<DateTime?>(
        json['lastReconciledAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'path': serializer.toJson<String>(path),
      'runId': serializer.toJson<String?>(runId),
      'processId': serializer.toJson<int?>(processId),
      'state': serializer.toJson<String>(state),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastReconciledAt': serializer.toJson<DateTime?>(lastReconciledAt),
    };
  }

  OwnedResource copyWith({
    String? id,
    String? kind,
    String? path,
    Value<String?> runId = const Value.absent(),
    Value<int?> processId = const Value.absent(),
    String? state,
    DateTime? createdAt,
    Value<DateTime?> lastReconciledAt = const Value.absent(),
  }) => OwnedResource(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    path: path ?? this.path,
    runId: runId.present ? runId.value : this.runId,
    processId: processId.present ? processId.value : this.processId,
    state: state ?? this.state,
    createdAt: createdAt ?? this.createdAt,
    lastReconciledAt: lastReconciledAt.present
        ? lastReconciledAt.value
        : this.lastReconciledAt,
  );
  OwnedResource copyWithCompanion(OwnedResourcesCompanion data) {
    return OwnedResource(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      path: data.path.present ? data.path.value : this.path,
      runId: data.runId.present ? data.runId.value : this.runId,
      processId: data.processId.present ? data.processId.value : this.processId,
      state: data.state.present ? data.state.value : this.state,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastReconciledAt: data.lastReconciledAt.present
          ? data.lastReconciledAt.value
          : this.lastReconciledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OwnedResource(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('runId: $runId, ')
          ..write('processId: $processId, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastReconciledAt: $lastReconciledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    path,
    runId,
    processId,
    state,
    createdAt,
    lastReconciledAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OwnedResource &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.path == this.path &&
          other.runId == this.runId &&
          other.processId == this.processId &&
          other.state == this.state &&
          other.createdAt == this.createdAt &&
          other.lastReconciledAt == this.lastReconciledAt);
}

class OwnedResourcesCompanion extends UpdateCompanion<OwnedResource> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> path;
  final Value<String?> runId;
  final Value<int?> processId;
  final Value<String> state;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastReconciledAt;
  final Value<int> rowid;
  const OwnedResourcesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.path = const Value.absent(),
    this.runId = const Value.absent(),
    this.processId = const Value.absent(),
    this.state = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastReconciledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OwnedResourcesCompanion.insert({
    required String id,
    required String kind,
    required String path,
    this.runId = const Value.absent(),
    this.processId = const Value.absent(),
    required String state,
    this.createdAt = const Value.absent(),
    this.lastReconciledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       path = Value(path),
       state = Value(state);
  static Insertable<OwnedResource> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? path,
    Expression<String>? runId,
    Expression<int>? processId,
    Expression<String>? state,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastReconciledAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (path != null) 'path': path,
      if (runId != null) 'run_id': runId,
      if (processId != null) 'process_id': processId,
      if (state != null) 'state': state,
      if (createdAt != null) 'created_at': createdAt,
      if (lastReconciledAt != null) 'last_reconciled_at': lastReconciledAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OwnedResourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? path,
    Value<String?>? runId,
    Value<int?>? processId,
    Value<String>? state,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastReconciledAt,
    Value<int>? rowid,
  }) {
    return OwnedResourcesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      path: path ?? this.path,
      runId: runId ?? this.runId,
      processId: processId ?? this.processId,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      lastReconciledAt: lastReconciledAt ?? this.lastReconciledAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (processId.present) {
      map['process_id'] = Variable<int>(processId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastReconciledAt.present) {
      map['last_reconciled_at'] = Variable<DateTime>(lastReconciledAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OwnedResourcesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('path: $path, ')
          ..write('runId: $runId, ')
          ..write('processId: $processId, ')
          ..write('state: $state, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastReconciledAt: $lastReconciledAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalUsersTable extends LocalUsers
    with TableInfo<$LocalUsersTable, LocalUser> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalUsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _authMethodMeta = const VerificationMeta(
    'authMethod',
  );
  @override
  late final GeneratedColumn<String> authMethod = GeneratedColumn<String>(
    'auth_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verifierKeyMeta = const VerificationMeta(
    'verifierKey',
  );
  @override
  late final GeneratedColumn<String> verifierKey = GeneratedColumn<String>(
    'verifier_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAuthenticatedAtMeta =
      const VerificationMeta('lastAuthenticatedAt');
  @override
  late final GeneratedColumn<DateTime> lastAuthenticatedAt =
      GeneratedColumn<DateTime>(
        'last_authenticated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    authMethod,
    verifierKey,
    createdAt,
    lastAuthenticatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_users';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalUser> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('auth_method')) {
      context.handle(
        _authMethodMeta,
        authMethod.isAcceptableOrUnknown(data['auth_method']!, _authMethodMeta),
      );
    } else if (isInserting) {
      context.missing(_authMethodMeta);
    }
    if (data.containsKey('verifier_key')) {
      context.handle(
        _verifierKeyMeta,
        verifierKey.isAcceptableOrUnknown(
          data['verifier_key']!,
          _verifierKeyMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_authenticated_at')) {
      context.handle(
        _lastAuthenticatedAtMeta,
        lastAuthenticatedAt.isAcceptableOrUnknown(
          data['last_authenticated_at']!,
          _lastAuthenticatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalUser map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalUser(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      authMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}auth_method'],
      )!,
      verifierKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verifier_key'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastAuthenticatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_authenticated_at'],
      ),
    );
  }

  @override
  $LocalUsersTable createAlias(String alias) {
    return $LocalUsersTable(attachedDatabase, alias);
  }
}

class LocalUser extends DataClass implements Insertable<LocalUser> {
  final String id;
  final String? email;
  final String authMethod;
  final String? verifierKey;
  final DateTime createdAt;
  final DateTime? lastAuthenticatedAt;
  const LocalUser({
    required this.id,
    this.email,
    required this.authMethod,
    this.verifierKey,
    required this.createdAt,
    this.lastAuthenticatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    map['auth_method'] = Variable<String>(authMethod);
    if (!nullToAbsent || verifierKey != null) {
      map['verifier_key'] = Variable<String>(verifierKey);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastAuthenticatedAt != null) {
      map['last_authenticated_at'] = Variable<DateTime>(lastAuthenticatedAt);
    }
    return map;
  }

  LocalUsersCompanion toCompanion(bool nullToAbsent) {
    return LocalUsersCompanion(
      id: Value(id),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      authMethod: Value(authMethod),
      verifierKey: verifierKey == null && nullToAbsent
          ? const Value.absent()
          : Value(verifierKey),
      createdAt: Value(createdAt),
      lastAuthenticatedAt: lastAuthenticatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAuthenticatedAt),
    );
  }

  factory LocalUser.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalUser(
      id: serializer.fromJson<String>(json['id']),
      email: serializer.fromJson<String?>(json['email']),
      authMethod: serializer.fromJson<String>(json['authMethod']),
      verifierKey: serializer.fromJson<String?>(json['verifierKey']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAuthenticatedAt: serializer.fromJson<DateTime?>(
        json['lastAuthenticatedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'email': serializer.toJson<String?>(email),
      'authMethod': serializer.toJson<String>(authMethod),
      'verifierKey': serializer.toJson<String?>(verifierKey),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAuthenticatedAt': serializer.toJson<DateTime?>(lastAuthenticatedAt),
    };
  }

  LocalUser copyWith({
    String? id,
    Value<String?> email = const Value.absent(),
    String? authMethod,
    Value<String?> verifierKey = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> lastAuthenticatedAt = const Value.absent(),
  }) => LocalUser(
    id: id ?? this.id,
    email: email.present ? email.value : this.email,
    authMethod: authMethod ?? this.authMethod,
    verifierKey: verifierKey.present ? verifierKey.value : this.verifierKey,
    createdAt: createdAt ?? this.createdAt,
    lastAuthenticatedAt: lastAuthenticatedAt.present
        ? lastAuthenticatedAt.value
        : this.lastAuthenticatedAt,
  );
  LocalUser copyWithCompanion(LocalUsersCompanion data) {
    return LocalUser(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      authMethod: data.authMethod.present
          ? data.authMethod.value
          : this.authMethod,
      verifierKey: data.verifierKey.present
          ? data.verifierKey.value
          : this.verifierKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAuthenticatedAt: data.lastAuthenticatedAt.present
          ? data.lastAuthenticatedAt.value
          : this.lastAuthenticatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalUser(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('authMethod: $authMethod, ')
          ..write('verifierKey: $verifierKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAuthenticatedAt: $lastAuthenticatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    email,
    authMethod,
    verifierKey,
    createdAt,
    lastAuthenticatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalUser &&
          other.id == this.id &&
          other.email == this.email &&
          other.authMethod == this.authMethod &&
          other.verifierKey == this.verifierKey &&
          other.createdAt == this.createdAt &&
          other.lastAuthenticatedAt == this.lastAuthenticatedAt);
}

class LocalUsersCompanion extends UpdateCompanion<LocalUser> {
  final Value<String> id;
  final Value<String?> email;
  final Value<String> authMethod;
  final Value<String?> verifierKey;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastAuthenticatedAt;
  final Value<int> rowid;
  const LocalUsersCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.authMethod = const Value.absent(),
    this.verifierKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAuthenticatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalUsersCompanion.insert({
    required String id,
    this.email = const Value.absent(),
    required String authMethod,
    this.verifierKey = const Value.absent(),
    required DateTime createdAt,
    this.lastAuthenticatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       authMethod = Value(authMethod),
       createdAt = Value(createdAt);
  static Insertable<LocalUser> custom({
    Expression<String>? id,
    Expression<String>? email,
    Expression<String>? authMethod,
    Expression<String>? verifierKey,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAuthenticatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (authMethod != null) 'auth_method': authMethod,
      if (verifierKey != null) 'verifier_key': verifierKey,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAuthenticatedAt != null)
        'last_authenticated_at': lastAuthenticatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalUsersCompanion copyWith({
    Value<String>? id,
    Value<String?>? email,
    Value<String>? authMethod,
    Value<String?>? verifierKey,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastAuthenticatedAt,
    Value<int>? rowid,
  }) {
    return LocalUsersCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      authMethod: authMethod ?? this.authMethod,
      verifierKey: verifierKey ?? this.verifierKey,
      createdAt: createdAt ?? this.createdAt,
      lastAuthenticatedAt: lastAuthenticatedAt ?? this.lastAuthenticatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (authMethod.present) {
      map['auth_method'] = Variable<String>(authMethod.value);
    }
    if (verifierKey.present) {
      map['verifier_key'] = Variable<String>(verifierKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAuthenticatedAt.present) {
      map['last_authenticated_at'] = Variable<DateTime>(
        lastAuthenticatedAt.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalUsersCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('authMethod: $authMethod, ')
          ..write('verifierKey: $verifierKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAuthenticatedAt: $lastAuthenticatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditEventsTable extends AuditEvents
    with TableInfo<$AuditEventsTable, AuditEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
    'actor_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    actorId,
    action,
    target,
    outcome,
    occurredAt,
    details,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    } else if (isInserting) {
      context.missing(_actorIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    } else if (isInserting) {
      context.missing(_detailsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      )!,
    );
  }

  @override
  $AuditEventsTable createAlias(String alias) {
    return $AuditEventsTable(attachedDatabase, alias);
  }
}

class AuditEvent extends DataClass implements Insertable<AuditEvent> {
  final String id;
  final String actorId;
  final String action;
  final String target;
  final String outcome;
  final DateTime occurredAt;
  final String details;
  const AuditEvent({
    required this.id,
    required this.actorId,
    required this.action,
    required this.target,
    required this.outcome,
    required this.occurredAt,
    required this.details,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['actor_id'] = Variable<String>(actorId);
    map['action'] = Variable<String>(action);
    map['target'] = Variable<String>(target);
    map['outcome'] = Variable<String>(outcome);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['details'] = Variable<String>(details);
    return map;
  }

  AuditEventsCompanion toCompanion(bool nullToAbsent) {
    return AuditEventsCompanion(
      id: Value(id),
      actorId: Value(actorId),
      action: Value(action),
      target: Value(target),
      outcome: Value(outcome),
      occurredAt: Value(occurredAt),
      details: Value(details),
    );
  }

  factory AuditEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditEvent(
      id: serializer.fromJson<String>(json['id']),
      actorId: serializer.fromJson<String>(json['actorId']),
      action: serializer.fromJson<String>(json['action']),
      target: serializer.fromJson<String>(json['target']),
      outcome: serializer.fromJson<String>(json['outcome']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      details: serializer.fromJson<String>(json['details']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'actorId': serializer.toJson<String>(actorId),
      'action': serializer.toJson<String>(action),
      'target': serializer.toJson<String>(target),
      'outcome': serializer.toJson<String>(outcome),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'details': serializer.toJson<String>(details),
    };
  }

  AuditEvent copyWith({
    String? id,
    String? actorId,
    String? action,
    String? target,
    String? outcome,
    DateTime? occurredAt,
    String? details,
  }) => AuditEvent(
    id: id ?? this.id,
    actorId: actorId ?? this.actorId,
    action: action ?? this.action,
    target: target ?? this.target,
    outcome: outcome ?? this.outcome,
    occurredAt: occurredAt ?? this.occurredAt,
    details: details ?? this.details,
  );
  AuditEvent copyWithCompanion(AuditEventsCompanion data) {
    return AuditEvent(
      id: data.id.present ? data.id.value : this.id,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      action: data.action.present ? data.action.value : this.action,
      target: data.target.present ? data.target.value : this.target,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      details: data.details.present ? data.details.value : this.details,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditEvent(')
          ..write('id: $id, ')
          ..write('actorId: $actorId, ')
          ..write('action: $action, ')
          ..write('target: $target, ')
          ..write('outcome: $outcome, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('details: $details')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, actorId, action, target, outcome, occurredAt, details);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditEvent &&
          other.id == this.id &&
          other.actorId == this.actorId &&
          other.action == this.action &&
          other.target == this.target &&
          other.outcome == this.outcome &&
          other.occurredAt == this.occurredAt &&
          other.details == this.details);
}

class AuditEventsCompanion extends UpdateCompanion<AuditEvent> {
  final Value<String> id;
  final Value<String> actorId;
  final Value<String> action;
  final Value<String> target;
  final Value<String> outcome;
  final Value<DateTime> occurredAt;
  final Value<String> details;
  final Value<int> rowid;
  const AuditEventsCompanion({
    this.id = const Value.absent(),
    this.actorId = const Value.absent(),
    this.action = const Value.absent(),
    this.target = const Value.absent(),
    this.outcome = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.details = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditEventsCompanion.insert({
    required String id,
    required String actorId,
    required String action,
    required String target,
    required String outcome,
    required DateTime occurredAt,
    required String details,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       actorId = Value(actorId),
       action = Value(action),
       target = Value(target),
       outcome = Value(outcome),
       occurredAt = Value(occurredAt),
       details = Value(details);
  static Insertable<AuditEvent> custom({
    Expression<String>? id,
    Expression<String>? actorId,
    Expression<String>? action,
    Expression<String>? target,
    Expression<String>? outcome,
    Expression<DateTime>? occurredAt,
    Expression<String>? details,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (actorId != null) 'actor_id': actorId,
      if (action != null) 'action': action,
      if (target != null) 'target': target,
      if (outcome != null) 'outcome': outcome,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (details != null) 'details': details,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? actorId,
    Value<String>? action,
    Value<String>? target,
    Value<String>? outcome,
    Value<DateTime>? occurredAt,
    Value<String>? details,
    Value<int>? rowid,
  }) {
    return AuditEventsCompanion(
      id: id ?? this.id,
      actorId: actorId ?? this.actorId,
      action: action ?? this.action,
      target: target ?? this.target,
      outcome: outcome ?? this.outcome,
      occurredAt: occurredAt ?? this.occurredAt,
      details: details ?? this.details,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditEventsCompanion(')
          ..write('id: $id, ')
          ..write('actorId: $actorId, ')
          ..write('action: $action, ')
          ..write('target: $target, ')
          ..write('outcome: $outcome, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('details: $details, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL COLLATE NOCASE UNIQUE',
  );
  static const VerificationMeta _folderPathMeta = const VerificationMeta(
    'folderPath',
  );
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
    'folder_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    normalizedName,
    folderPath,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('folder_path')) {
      context.handle(
        _folderPathMeta,
        folderPath.isAcceptableOrUnknown(data['folder_path']!, _folderPathMeta),
      );
    } else if (isInserting) {
      context.missing(_folderPathMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      folderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_path'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String name;
  final String normalizedName;
  final String folderPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Project({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.folderPath,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    map['folder_path'] = Variable<String>(folderPath);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      folderPath: Value(folderPath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      folderPath: serializer.fromJson<String>(json['folderPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'folderPath': serializer.toJson<String>(folderPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    String? normalizedName,
    String? folderPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Project(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    folderPath: folderPath ?? this.folderPath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      folderPath: data.folderPath.present
          ? data.folderPath.value
          : this.folderPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('folderPath: $folderPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    normalizedName,
    folderPath,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.folderPath == this.folderPath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<String> folderPath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    required String normalizedName,
    required String folderPath,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       normalizedName = Value(normalizedName),
       folderPath = Value(folderPath),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<String>? folderPath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (folderPath != null) 'folder_path': folderPath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<String>? folderPath,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      folderPath: folderPath ?? this.folderPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('folderPath: $folderPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkflowsTable extends Workflows
    with TableInfo<$WorkflowsTable, Workflow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkflowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    check: () => ComparableExpr(revision).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isReusableMeta = const VerificationMeta(
    'isReusable',
  );
  @override
  late final GeneratedColumn<bool> isReusable = GeneratedColumn<bool>(
    'is_reusable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_reusable" IN (0, 1))',
    ),
  );
  static const VerificationMeta _unitTypeMeta = const VerificationMeta(
    'unitType',
  );
  @override
  late final GeneratedColumn<String> unitType = GeneratedColumn<String>(
    'unit_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supervisedDeliveryMeta =
      const VerificationMeta('supervisedDelivery');
  @override
  late final GeneratedColumn<bool> supervisedDelivery = GeneratedColumn<bool>(
    'supervised_delivery',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supervised_delivery" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    revision,
    name,
    isReusable,
    unitType,
    supervisedDelivery,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workflows';
  @override
  VerificationContext validateIntegrity(
    Insertable<Workflow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('is_reusable')) {
      context.handle(
        _isReusableMeta,
        isReusable.isAcceptableOrUnknown(data['is_reusable']!, _isReusableMeta),
      );
    } else if (isInserting) {
      context.missing(_isReusableMeta);
    }
    if (data.containsKey('unit_type')) {
      context.handle(
        _unitTypeMeta,
        unitType.isAcceptableOrUnknown(data['unit_type']!, _unitTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_unitTypeMeta);
    }
    if (data.containsKey('supervised_delivery')) {
      context.handle(
        _supervisedDeliveryMeta,
        supervisedDelivery.isAcceptableOrUnknown(
          data['supervised_delivery']!,
          _supervisedDeliveryMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Workflow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Workflow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      isReusable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_reusable'],
      )!,
      unitType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_type'],
      )!,
      supervisedDelivery: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supervised_delivery'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $WorkflowsTable createAlias(String alias) {
    return $WorkflowsTable(attachedDatabase, alias);
  }
}

class Workflow extends DataClass implements Insertable<Workflow> {
  final String id;
  final int revision;
  final String? name;
  final bool isReusable;
  final String unitType;
  final bool supervisedDelivery;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Workflow({
    required this.id,
    required this.revision,
    this.name,
    required this.isReusable,
    required this.unitType,
    required this.supervisedDelivery,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['is_reusable'] = Variable<bool>(isReusable);
    map['unit_type'] = Variable<String>(unitType);
    map['supervised_delivery'] = Variable<bool>(supervisedDelivery);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  WorkflowsCompanion toCompanion(bool nullToAbsent) {
    return WorkflowsCompanion(
      id: Value(id),
      revision: Value(revision),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      isReusable: Value(isReusable),
      unitType: Value(unitType),
      supervisedDelivery: Value(supervisedDelivery),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Workflow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Workflow(
      id: serializer.fromJson<String>(json['id']),
      revision: serializer.fromJson<int>(json['revision']),
      name: serializer.fromJson<String?>(json['name']),
      isReusable: serializer.fromJson<bool>(json['isReusable']),
      unitType: serializer.fromJson<String>(json['unitType']),
      supervisedDelivery: serializer.fromJson<bool>(json['supervisedDelivery']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'revision': serializer.toJson<int>(revision),
      'name': serializer.toJson<String?>(name),
      'isReusable': serializer.toJson<bool>(isReusable),
      'unitType': serializer.toJson<String>(unitType),
      'supervisedDelivery': serializer.toJson<bool>(supervisedDelivery),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Workflow copyWith({
    String? id,
    int? revision,
    Value<String?> name = const Value.absent(),
    bool? isReusable,
    String? unitType,
    bool? supervisedDelivery,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Workflow(
    id: id ?? this.id,
    revision: revision ?? this.revision,
    name: name.present ? name.value : this.name,
    isReusable: isReusable ?? this.isReusable,
    unitType: unitType ?? this.unitType,
    supervisedDelivery: supervisedDelivery ?? this.supervisedDelivery,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Workflow copyWithCompanion(WorkflowsCompanion data) {
    return Workflow(
      id: data.id.present ? data.id.value : this.id,
      revision: data.revision.present ? data.revision.value : this.revision,
      name: data.name.present ? data.name.value : this.name,
      isReusable: data.isReusable.present
          ? data.isReusable.value
          : this.isReusable,
      unitType: data.unitType.present ? data.unitType.value : this.unitType,
      supervisedDelivery: data.supervisedDelivery.present
          ? data.supervisedDelivery.value
          : this.supervisedDelivery,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workflow(')
          ..write('id: $id, ')
          ..write('revision: $revision, ')
          ..write('name: $name, ')
          ..write('isReusable: $isReusable, ')
          ..write('unitType: $unitType, ')
          ..write('supervisedDelivery: $supervisedDelivery, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    revision,
    name,
    isReusable,
    unitType,
    supervisedDelivery,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workflow &&
          other.id == this.id &&
          other.revision == this.revision &&
          other.name == this.name &&
          other.isReusable == this.isReusable &&
          other.unitType == this.unitType &&
          other.supervisedDelivery == this.supervisedDelivery &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class WorkflowsCompanion extends UpdateCompanion<Workflow> {
  final Value<String> id;
  final Value<int> revision;
  final Value<String?> name;
  final Value<bool> isReusable;
  final Value<String> unitType;
  final Value<bool> supervisedDelivery;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const WorkflowsCompanion({
    this.id = const Value.absent(),
    this.revision = const Value.absent(),
    this.name = const Value.absent(),
    this.isReusable = const Value.absent(),
    this.unitType = const Value.absent(),
    this.supervisedDelivery = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkflowsCompanion.insert({
    required String id,
    required int revision,
    this.name = const Value.absent(),
    required bool isReusable,
    required String unitType,
    this.supervisedDelivery = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       revision = Value(revision),
       isReusable = Value(isReusable),
       unitType = Value(unitType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Workflow> custom({
    Expression<String>? id,
    Expression<int>? revision,
    Expression<String>? name,
    Expression<bool>? isReusable,
    Expression<String>? unitType,
    Expression<bool>? supervisedDelivery,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (revision != null) 'revision': revision,
      if (name != null) 'name': name,
      if (isReusable != null) 'is_reusable': isReusable,
      if (unitType != null) 'unit_type': unitType,
      if (supervisedDelivery != null) 'supervised_delivery': supervisedDelivery,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkflowsCompanion copyWith({
    Value<String>? id,
    Value<int>? revision,
    Value<String?>? name,
    Value<bool>? isReusable,
    Value<String>? unitType,
    Value<bool>? supervisedDelivery,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WorkflowsCompanion(
      id: id ?? this.id,
      revision: revision ?? this.revision,
      name: name ?? this.name,
      isReusable: isReusable ?? this.isReusable,
      unitType: unitType ?? this.unitType,
      supervisedDelivery: supervisedDelivery ?? this.supervisedDelivery,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isReusable.present) {
      map['is_reusable'] = Variable<bool>(isReusable.value);
    }
    if (unitType.present) {
      map['unit_type'] = Variable<String>(unitType.value);
    }
    if (supervisedDelivery.present) {
      map['supervised_delivery'] = Variable<bool>(supervisedDelivery.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowsCompanion(')
          ..write('id: $id, ')
          ..write('revision: $revision, ')
          ..write('name: $name, ')
          ..write('isReusable: $isReusable, ')
          ..write('unitType: $unitType, ')
          ..write('supervisedDelivery: $supervisedDelivery, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkflowStepsTable extends WorkflowSteps
    with TableInfo<$WorkflowStepsTable, WorkflowStep> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkflowStepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workflowIdMeta = const VerificationMeta(
    'workflowId',
  );
  @override
  late final GeneratedColumn<String> workflowId = GeneratedColumn<String>(
    'workflow_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workflows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    check: () => ComparableExpr(position).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cliMeta = const VerificationMeta('cli');
  @override
  late final GeneratedColumn<String> cli = GeneratedColumn<String>(
    'cli',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK ((cli IS NULL) = (model IS NULL))',
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _configurationMeta = const VerificationMeta(
    'configuration',
  );
  @override
  late final GeneratedColumn<String> configuration = GeneratedColumn<String>(
    'configuration',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workflowId,
    position,
    kind,
    name,
    cli,
    model,
    configuration,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workflow_steps';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkflowStep> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workflow_id')) {
      context.handle(
        _workflowIdMeta,
        workflowId.isAcceptableOrUnknown(data['workflow_id']!, _workflowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workflowIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cli')) {
      context.handle(
        _cliMeta,
        cli.isAcceptableOrUnknown(data['cli']!, _cliMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('configuration')) {
      context.handle(
        _configurationMeta,
        configuration.isAcceptableOrUnknown(
          data['configuration']!,
          _configurationMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkflowStep map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkflowStep(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workflowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cli: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cli'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      configuration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}configuration'],
      )!,
    );
  }

  @override
  $WorkflowStepsTable createAlias(String alias) {
    return $WorkflowStepsTable(attachedDatabase, alias);
  }
}

class WorkflowStep extends DataClass implements Insertable<WorkflowStep> {
  final String id;
  final String workflowId;
  final int position;
  final String kind;
  final String name;
  final String? cli;
  final String? model;
  final String configuration;
  const WorkflowStep({
    required this.id,
    required this.workflowId,
    required this.position,
    required this.kind,
    required this.name,
    this.cli,
    this.model,
    required this.configuration,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workflow_id'] = Variable<String>(workflowId);
    map['position'] = Variable<int>(position);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || cli != null) {
      map['cli'] = Variable<String>(cli);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    map['configuration'] = Variable<String>(configuration);
    return map;
  }

  WorkflowStepsCompanion toCompanion(bool nullToAbsent) {
    return WorkflowStepsCompanion(
      id: Value(id),
      workflowId: Value(workflowId),
      position: Value(position),
      kind: Value(kind),
      name: Value(name),
      cli: cli == null && nullToAbsent ? const Value.absent() : Value(cli),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      configuration: Value(configuration),
    );
  }

  factory WorkflowStep.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkflowStep(
      id: serializer.fromJson<String>(json['id']),
      workflowId: serializer.fromJson<String>(json['workflowId']),
      position: serializer.fromJson<int>(json['position']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      cli: serializer.fromJson<String?>(json['cli']),
      model: serializer.fromJson<String?>(json['model']),
      configuration: serializer.fromJson<String>(json['configuration']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workflowId': serializer.toJson<String>(workflowId),
      'position': serializer.toJson<int>(position),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'cli': serializer.toJson<String?>(cli),
      'model': serializer.toJson<String?>(model),
      'configuration': serializer.toJson<String>(configuration),
    };
  }

  WorkflowStep copyWith({
    String? id,
    String? workflowId,
    int? position,
    String? kind,
    String? name,
    Value<String?> cli = const Value.absent(),
    Value<String?> model = const Value.absent(),
    String? configuration,
  }) => WorkflowStep(
    id: id ?? this.id,
    workflowId: workflowId ?? this.workflowId,
    position: position ?? this.position,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    cli: cli.present ? cli.value : this.cli,
    model: model.present ? model.value : this.model,
    configuration: configuration ?? this.configuration,
  );
  WorkflowStep copyWithCompanion(WorkflowStepsCompanion data) {
    return WorkflowStep(
      id: data.id.present ? data.id.value : this.id,
      workflowId: data.workflowId.present
          ? data.workflowId.value
          : this.workflowId,
      position: data.position.present ? data.position.value : this.position,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      cli: data.cli.present ? data.cli.value : this.cli,
      model: data.model.present ? data.model.value : this.model,
      configuration: data.configuration.present
          ? data.configuration.value
          : this.configuration,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowStep(')
          ..write('id: $id, ')
          ..write('workflowId: $workflowId, ')
          ..write('position: $position, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('cli: $cli, ')
          ..write('model: $model, ')
          ..write('configuration: $configuration')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workflowId,
    position,
    kind,
    name,
    cli,
    model,
    configuration,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkflowStep &&
          other.id == this.id &&
          other.workflowId == this.workflowId &&
          other.position == this.position &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.cli == this.cli &&
          other.model == this.model &&
          other.configuration == this.configuration);
}

class WorkflowStepsCompanion extends UpdateCompanion<WorkflowStep> {
  final Value<String> id;
  final Value<String> workflowId;
  final Value<int> position;
  final Value<String> kind;
  final Value<String> name;
  final Value<String?> cli;
  final Value<String?> model;
  final Value<String> configuration;
  final Value<int> rowid;
  const WorkflowStepsCompanion({
    this.id = const Value.absent(),
    this.workflowId = const Value.absent(),
    this.position = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.cli = const Value.absent(),
    this.model = const Value.absent(),
    this.configuration = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkflowStepsCompanion.insert({
    required String id,
    required String workflowId,
    required int position,
    required String kind,
    required String name,
    this.cli = const Value.absent(),
    this.model = const Value.absent(),
    this.configuration = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workflowId = Value(workflowId),
       position = Value(position),
       kind = Value(kind),
       name = Value(name);
  static Insertable<WorkflowStep> custom({
    Expression<String>? id,
    Expression<String>? workflowId,
    Expression<int>? position,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? cli,
    Expression<String>? model,
    Expression<String>? configuration,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workflowId != null) 'workflow_id': workflowId,
      if (position != null) 'position': position,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (cli != null) 'cli': cli,
      if (model != null) 'model': model,
      if (configuration != null) 'configuration': configuration,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkflowStepsCompanion copyWith({
    Value<String>? id,
    Value<String>? workflowId,
    Value<int>? position,
    Value<String>? kind,
    Value<String>? name,
    Value<String?>? cli,
    Value<String?>? model,
    Value<String>? configuration,
    Value<int>? rowid,
  }) {
    return WorkflowStepsCompanion(
      id: id ?? this.id,
      workflowId: workflowId ?? this.workflowId,
      position: position ?? this.position,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      cli: cli ?? this.cli,
      model: model ?? this.model,
      configuration: configuration ?? this.configuration,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workflowId.present) {
      map['workflow_id'] = Variable<String>(workflowId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cli.present) {
      map['cli'] = Variable<String>(cli.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (configuration.present) {
      map['configuration'] = Variable<String>(configuration.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowStepsCompanion(')
          ..write('id: $id, ')
          ..write('workflowId: $workflowId, ')
          ..write('position: $position, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('cli: $cli, ')
          ..write('model: $model, ')
          ..write('configuration: $configuration, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkflowProjectRefsTable extends WorkflowProjectRefs
    with TableInfo<$WorkflowProjectRefsTable, WorkflowProjectRef> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkflowProjectRefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _workflowIdMeta = const VerificationMeta(
    'workflowId',
  );
  @override
  late final GeneratedColumn<String> workflowId = GeneratedColumn<String>(
    'workflow_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workflows (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [workflowId, projectId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workflow_project_refs';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkflowProjectRef> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('workflow_id')) {
      context.handle(
        _workflowIdMeta,
        workflowId.isAcceptableOrUnknown(data['workflow_id']!, _workflowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workflowIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {workflowId, projectId};
  @override
  WorkflowProjectRef map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkflowProjectRef(
      workflowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
    );
  }

  @override
  $WorkflowProjectRefsTable createAlias(String alias) {
    return $WorkflowProjectRefsTable(attachedDatabase, alias);
  }
}

class WorkflowProjectRef extends DataClass
    implements Insertable<WorkflowProjectRef> {
  final String workflowId;
  final String projectId;
  const WorkflowProjectRef({required this.workflowId, required this.projectId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['workflow_id'] = Variable<String>(workflowId);
    map['project_id'] = Variable<String>(projectId);
    return map;
  }

  WorkflowProjectRefsCompanion toCompanion(bool nullToAbsent) {
    return WorkflowProjectRefsCompanion(
      workflowId: Value(workflowId),
      projectId: Value(projectId),
    );
  }

  factory WorkflowProjectRef.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkflowProjectRef(
      workflowId: serializer.fromJson<String>(json['workflowId']),
      projectId: serializer.fromJson<String>(json['projectId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'workflowId': serializer.toJson<String>(workflowId),
      'projectId': serializer.toJson<String>(projectId),
    };
  }

  WorkflowProjectRef copyWith({String? workflowId, String? projectId}) =>
      WorkflowProjectRef(
        workflowId: workflowId ?? this.workflowId,
        projectId: projectId ?? this.projectId,
      );
  WorkflowProjectRef copyWithCompanion(WorkflowProjectRefsCompanion data) {
    return WorkflowProjectRef(
      workflowId: data.workflowId.present
          ? data.workflowId.value
          : this.workflowId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowProjectRef(')
          ..write('workflowId: $workflowId, ')
          ..write('projectId: $projectId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(workflowId, projectId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkflowProjectRef &&
          other.workflowId == this.workflowId &&
          other.projectId == this.projectId);
}

class WorkflowProjectRefsCompanion extends UpdateCompanion<WorkflowProjectRef> {
  final Value<String> workflowId;
  final Value<String> projectId;
  final Value<int> rowid;
  const WorkflowProjectRefsCompanion({
    this.workflowId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkflowProjectRefsCompanion.insert({
    required String workflowId,
    required String projectId,
    this.rowid = const Value.absent(),
  }) : workflowId = Value(workflowId),
       projectId = Value(projectId);
  static Insertable<WorkflowProjectRef> custom({
    Expression<String>? workflowId,
    Expression<String>? projectId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (workflowId != null) 'workflow_id': workflowId,
      if (projectId != null) 'project_id': projectId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkflowProjectRefsCompanion copyWith({
    Value<String>? workflowId,
    Value<String>? projectId,
    Value<int>? rowid,
  }) {
    return WorkflowProjectRefsCompanion(
      workflowId: workflowId ?? this.workflowId,
      projectId: projectId ?? this.projectId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (workflowId.present) {
      map['workflow_id'] = Variable<String>(workflowId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowProjectRefsCompanion(')
          ..write('workflowId: $workflowId, ')
          ..write('projectId: $projectId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkflowRunsTable extends WorkflowRuns
    with TableInfo<$WorkflowRunsTable, WorkflowRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkflowRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _workflowIdMeta = const VerificationMeta(
    'workflowId',
  );
  @override
  late final GeneratedColumn<String> workflowId = GeneratedColumn<String>(
    'workflow_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workflows (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentStepPositionMeta =
      const VerificationMeta('currentStepPosition');
  @override
  late final GeneratedColumn<int> currentStepPosition = GeneratedColumn<int>(
    'current_step_position',
    aliasedName,
    false,
    check: () => ComparableExpr(currentStepPosition).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchNameMeta = const VerificationMeta(
    'branchName',
  );
  @override
  late final GeneratedColumn<String> branchName = GeneratedColumn<String>(
    'branch_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _worktreePathMeta = const VerificationMeta(
    'worktreePath',
  );
  @override
  late final GeneratedColumn<String> worktreePath = GeneratedColumn<String>(
    'worktree_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    workflowId,
    label,
    status,
    currentStepPosition,
    branchName,
    worktreePath,
    createdAt,
    updatedAt,
    startedAt,
    completedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workflow_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkflowRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    }
    if (data.containsKey('workflow_id')) {
      context.handle(
        _workflowIdMeta,
        workflowId.isAcceptableOrUnknown(data['workflow_id']!, _workflowIdMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('current_step_position')) {
      context.handle(
        _currentStepPositionMeta,
        currentStepPosition.isAcceptableOrUnknown(
          data['current_step_position']!,
          _currentStepPositionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentStepPositionMeta);
    }
    if (data.containsKey('branch_name')) {
      context.handle(
        _branchNameMeta,
        branchName.isAcceptableOrUnknown(data['branch_name']!, _branchNameMeta),
      );
    }
    if (data.containsKey('worktree_path')) {
      context.handle(
        _worktreePathMeta,
        worktreePath.isAcceptableOrUnknown(
          data['worktree_path']!,
          _worktreePathMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkflowRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkflowRun(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      ),
      workflowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workflow_id'],
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      currentStepPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_step_position'],
      )!,
      branchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch_name'],
      ),
      worktreePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}worktree_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $WorkflowRunsTable createAlias(String alias) {
    return $WorkflowRunsTable(attachedDatabase, alias);
  }
}

class WorkflowRun extends DataClass implements Insertable<WorkflowRun> {
  final String id;
  final String? projectId;
  final String? workflowId;
  final String label;
  final String status;
  final int currentStepPosition;
  final String? branchName;
  final String? worktreePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? deletedAt;
  const WorkflowRun({
    required this.id,
    this.projectId,
    this.workflowId,
    required this.label,
    required this.status,
    required this.currentStepPosition,
    this.branchName,
    this.worktreePath,
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.completedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || projectId != null) {
      map['project_id'] = Variable<String>(projectId);
    }
    if (!nullToAbsent || workflowId != null) {
      map['workflow_id'] = Variable<String>(workflowId);
    }
    map['label'] = Variable<String>(label);
    map['status'] = Variable<String>(status);
    map['current_step_position'] = Variable<int>(currentStepPosition);
    if (!nullToAbsent || branchName != null) {
      map['branch_name'] = Variable<String>(branchName);
    }
    if (!nullToAbsent || worktreePath != null) {
      map['worktree_path'] = Variable<String>(worktreePath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  WorkflowRunsCompanion toCompanion(bool nullToAbsent) {
    return WorkflowRunsCompanion(
      id: Value(id),
      projectId: projectId == null && nullToAbsent
          ? const Value.absent()
          : Value(projectId),
      workflowId: workflowId == null && nullToAbsent
          ? const Value.absent()
          : Value(workflowId),
      label: Value(label),
      status: Value(status),
      currentStepPosition: Value(currentStepPosition),
      branchName: branchName == null && nullToAbsent
          ? const Value.absent()
          : Value(branchName),
      worktreePath: worktreePath == null && nullToAbsent
          ? const Value.absent()
          : Value(worktreePath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory WorkflowRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkflowRun(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String?>(json['projectId']),
      workflowId: serializer.fromJson<String?>(json['workflowId']),
      label: serializer.fromJson<String>(json['label']),
      status: serializer.fromJson<String>(json['status']),
      currentStepPosition: serializer.fromJson<int>(
        json['currentStepPosition'],
      ),
      branchName: serializer.fromJson<String?>(json['branchName']),
      worktreePath: serializer.fromJson<String?>(json['worktreePath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String?>(projectId),
      'workflowId': serializer.toJson<String?>(workflowId),
      'label': serializer.toJson<String>(label),
      'status': serializer.toJson<String>(status),
      'currentStepPosition': serializer.toJson<int>(currentStepPosition),
      'branchName': serializer.toJson<String?>(branchName),
      'worktreePath': serializer.toJson<String?>(worktreePath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  WorkflowRun copyWith({
    String? id,
    Value<String?> projectId = const Value.absent(),
    Value<String?> workflowId = const Value.absent(),
    String? label,
    String? status,
    int? currentStepPosition,
    Value<String?> branchName = const Value.absent(),
    Value<String?> worktreePath = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => WorkflowRun(
    id: id ?? this.id,
    projectId: projectId.present ? projectId.value : this.projectId,
    workflowId: workflowId.present ? workflowId.value : this.workflowId,
    label: label ?? this.label,
    status: status ?? this.status,
    currentStepPosition: currentStepPosition ?? this.currentStepPosition,
    branchName: branchName.present ? branchName.value : this.branchName,
    worktreePath: worktreePath.present ? worktreePath.value : this.worktreePath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  WorkflowRun copyWithCompanion(WorkflowRunsCompanion data) {
    return WorkflowRun(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      workflowId: data.workflowId.present
          ? data.workflowId.value
          : this.workflowId,
      label: data.label.present ? data.label.value : this.label,
      status: data.status.present ? data.status.value : this.status,
      currentStepPosition: data.currentStepPosition.present
          ? data.currentStepPosition.value
          : this.currentStepPosition,
      branchName: data.branchName.present
          ? data.branchName.value
          : this.branchName,
      worktreePath: data.worktreePath.present
          ? data.worktreePath.value
          : this.worktreePath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowRun(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('workflowId: $workflowId, ')
          ..write('label: $label, ')
          ..write('status: $status, ')
          ..write('currentStepPosition: $currentStepPosition, ')
          ..write('branchName: $branchName, ')
          ..write('worktreePath: $worktreePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    workflowId,
    label,
    status,
    currentStepPosition,
    branchName,
    worktreePath,
    createdAt,
    updatedAt,
    startedAt,
    completedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkflowRun &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.workflowId == this.workflowId &&
          other.label == this.label &&
          other.status == this.status &&
          other.currentStepPosition == this.currentStepPosition &&
          other.branchName == this.branchName &&
          other.worktreePath == this.worktreePath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.deletedAt == this.deletedAt);
}

class WorkflowRunsCompanion extends UpdateCompanion<WorkflowRun> {
  final Value<String> id;
  final Value<String?> projectId;
  final Value<String?> workflowId;
  final Value<String> label;
  final Value<String> status;
  final Value<int> currentStepPosition;
  final Value<String?> branchName;
  final Value<String?> worktreePath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> completedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const WorkflowRunsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.workflowId = const Value.absent(),
    this.label = const Value.absent(),
    this.status = const Value.absent(),
    this.currentStepPosition = const Value.absent(),
    this.branchName = const Value.absent(),
    this.worktreePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkflowRunsCompanion.insert({
    required String id,
    this.projectId = const Value.absent(),
    this.workflowId = const Value.absent(),
    required String label,
    required String status,
    required int currentStepPosition,
    this.branchName = const Value.absent(),
    this.worktreePath = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       status = Value(status),
       currentStepPosition = Value(currentStepPosition),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WorkflowRun> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? workflowId,
    Expression<String>? label,
    Expression<String>? status,
    Expression<int>? currentStepPosition,
    Expression<String>? branchName,
    Expression<String>? worktreePath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (workflowId != null) 'workflow_id': workflowId,
      if (label != null) 'label': label,
      if (status != null) 'status': status,
      if (currentStepPosition != null)
        'current_step_position': currentStepPosition,
      if (branchName != null) 'branch_name': branchName,
      if (worktreePath != null) 'worktree_path': worktreePath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkflowRunsCompanion copyWith({
    Value<String>? id,
    Value<String?>? projectId,
    Value<String?>? workflowId,
    Value<String>? label,
    Value<String>? status,
    Value<int>? currentStepPosition,
    Value<String?>? branchName,
    Value<String?>? worktreePath,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? completedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return WorkflowRunsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      workflowId: workflowId ?? this.workflowId,
      label: label ?? this.label,
      status: status ?? this.status,
      currentStepPosition: currentStepPosition ?? this.currentStepPosition,
      branchName: branchName ?? this.branchName,
      worktreePath: worktreePath ?? this.worktreePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (workflowId.present) {
      map['workflow_id'] = Variable<String>(workflowId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (currentStepPosition.present) {
      map['current_step_position'] = Variable<int>(currentStepPosition.value);
    }
    if (branchName.present) {
      map['branch_name'] = Variable<String>(branchName.value);
    }
    if (worktreePath.present) {
      map['worktree_path'] = Variable<String>(worktreePath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkflowRunsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('workflowId: $workflowId, ')
          ..write('label: $label, ')
          ..write('status: $status, ')
          ..write('currentStepPosition: $currentStepPosition, ')
          ..write('branchName: $branchName, ')
          ..write('worktreePath: $worktreePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunSnapshotsTable extends RunSnapshots
    with TableInfo<$RunSnapshotsTable, RunSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workflow_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    check: () => ComparableExpr(schemaVersion).isBiggerOrEqualValue(1),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalPayloadMeta = const VerificationMeta(
    'canonicalPayload',
  );
  @override
  late final GeneratedColumn<String> canonicalPayload = GeneratedColumn<String>(
    'canonical_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    runId,
    schemaVersion,
    canonicalPayload,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('canonical_payload')) {
      context.handle(
        _canonicalPayloadMeta,
        canonicalPayload.isAcceptableOrUnknown(
          data['canonical_payload']!,
          _canonicalPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalPayloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {runId};
  @override
  RunSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunSnapshot(
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      canonicalPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RunSnapshotsTable createAlias(String alias) {
    return $RunSnapshotsTable(attachedDatabase, alias);
  }
}

class RunSnapshot extends DataClass implements Insertable<RunSnapshot> {
  final String runId;
  final int schemaVersion;
  final String canonicalPayload;
  final DateTime createdAt;
  const RunSnapshot({
    required this.runId,
    required this.schemaVersion,
    required this.canonicalPayload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['run_id'] = Variable<String>(runId);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['canonical_payload'] = Variable<String>(canonicalPayload);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RunSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return RunSnapshotsCompanion(
      runId: Value(runId),
      schemaVersion: Value(schemaVersion),
      canonicalPayload: Value(canonicalPayload),
      createdAt: Value(createdAt),
    );
  }

  factory RunSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunSnapshot(
      runId: serializer.fromJson<String>(json['runId']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      canonicalPayload: serializer.fromJson<String>(json['canonicalPayload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'runId': serializer.toJson<String>(runId),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'canonicalPayload': serializer.toJson<String>(canonicalPayload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RunSnapshot copyWith({
    String? runId,
    int? schemaVersion,
    String? canonicalPayload,
    DateTime? createdAt,
  }) => RunSnapshot(
    runId: runId ?? this.runId,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    canonicalPayload: canonicalPayload ?? this.canonicalPayload,
    createdAt: createdAt ?? this.createdAt,
  );
  RunSnapshot copyWithCompanion(RunSnapshotsCompanion data) {
    return RunSnapshot(
      runId: data.runId.present ? data.runId.value : this.runId,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      canonicalPayload: data.canonicalPayload.present
          ? data.canonicalPayload.value
          : this.canonicalPayload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunSnapshot(')
          ..write('runId: $runId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('canonicalPayload: $canonicalPayload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(runId, schemaVersion, canonicalPayload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunSnapshot &&
          other.runId == this.runId &&
          other.schemaVersion == this.schemaVersion &&
          other.canonicalPayload == this.canonicalPayload &&
          other.createdAt == this.createdAt);
}

class RunSnapshotsCompanion extends UpdateCompanion<RunSnapshot> {
  final Value<String> runId;
  final Value<int> schemaVersion;
  final Value<String> canonicalPayload;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RunSnapshotsCompanion({
    this.runId = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.canonicalPayload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunSnapshotsCompanion.insert({
    required String runId,
    required int schemaVersion,
    required String canonicalPayload,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : runId = Value(runId),
       schemaVersion = Value(schemaVersion),
       canonicalPayload = Value(canonicalPayload),
       createdAt = Value(createdAt);
  static Insertable<RunSnapshot> custom({
    Expression<String>? runId,
    Expression<int>? schemaVersion,
    Expression<String>? canonicalPayload,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (runId != null) 'run_id': runId,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (canonicalPayload != null) 'canonical_payload': canonicalPayload,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunSnapshotsCompanion copyWith({
    Value<String>? runId,
    Value<int>? schemaVersion,
    Value<String>? canonicalPayload,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RunSnapshotsCompanion(
      runId: runId ?? this.runId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      canonicalPayload: canonicalPayload ?? this.canonicalPayload,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (canonicalPayload.present) {
      map['canonical_payload'] = Variable<String>(canonicalPayload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunSnapshotsCompanion(')
          ..write('runId: $runId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('canonicalPayload: $canonicalPayload, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunSnapshotStepsTable extends RunSnapshotSteps
    with TableInfo<$RunSnapshotStepsTable, RunSnapshotStep> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunSnapshotStepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workflow_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceWorkflowStepIdMeta =
      const VerificationMeta('sourceWorkflowStepId');
  @override
  late final GeneratedColumn<String> sourceWorkflowStepId =
      GeneratedColumn<String>(
        'source_workflow_step_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    check: () => ComparableExpr(position).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cliMeta = const VerificationMeta('cli');
  @override
  late final GeneratedColumn<String> cli = GeneratedColumn<String>(
    'cli',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK ((cli IS NULL) = (model IS NULL))',
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _configurationMeta = const VerificationMeta(
    'configuration',
  );
  @override
  late final GeneratedColumn<String> configuration = GeneratedColumn<String>(
    'configuration',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    sourceWorkflowStepId,
    position,
    kind,
    name,
    cli,
    model,
    configuration,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_snapshot_steps';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunSnapshotStep> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('source_workflow_step_id')) {
      context.handle(
        _sourceWorkflowStepIdMeta,
        sourceWorkflowStepId.isAcceptableOrUnknown(
          data['source_workflow_step_id']!,
          _sourceWorkflowStepIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceWorkflowStepIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cli')) {
      context.handle(
        _cliMeta,
        cli.isAcceptableOrUnknown(data['cli']!, _cliMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('configuration')) {
      context.handle(
        _configurationMeta,
        configuration.isAcceptableOrUnknown(
          data['configuration']!,
          _configurationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_configurationMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RunSnapshotStep map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunSnapshotStep(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      sourceWorkflowStepId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_workflow_step_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cli: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cli'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      configuration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}configuration'],
      )!,
    );
  }

  @override
  $RunSnapshotStepsTable createAlias(String alias) {
    return $RunSnapshotStepsTable(attachedDatabase, alias);
  }
}

class RunSnapshotStep extends DataClass implements Insertable<RunSnapshotStep> {
  final String id;
  final String runId;
  final String sourceWorkflowStepId;
  final int position;
  final String kind;
  final String name;
  final String? cli;
  final String? model;
  final String configuration;
  const RunSnapshotStep({
    required this.id,
    required this.runId,
    required this.sourceWorkflowStepId,
    required this.position,
    required this.kind,
    required this.name,
    this.cli,
    this.model,
    required this.configuration,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['source_workflow_step_id'] = Variable<String>(sourceWorkflowStepId);
    map['position'] = Variable<int>(position);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || cli != null) {
      map['cli'] = Variable<String>(cli);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    map['configuration'] = Variable<String>(configuration);
    return map;
  }

  RunSnapshotStepsCompanion toCompanion(bool nullToAbsent) {
    return RunSnapshotStepsCompanion(
      id: Value(id),
      runId: Value(runId),
      sourceWorkflowStepId: Value(sourceWorkflowStepId),
      position: Value(position),
      kind: Value(kind),
      name: Value(name),
      cli: cli == null && nullToAbsent ? const Value.absent() : Value(cli),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      configuration: Value(configuration),
    );
  }

  factory RunSnapshotStep.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunSnapshotStep(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      sourceWorkflowStepId: serializer.fromJson<String>(
        json['sourceWorkflowStepId'],
      ),
      position: serializer.fromJson<int>(json['position']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      cli: serializer.fromJson<String?>(json['cli']),
      model: serializer.fromJson<String?>(json['model']),
      configuration: serializer.fromJson<String>(json['configuration']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'sourceWorkflowStepId': serializer.toJson<String>(sourceWorkflowStepId),
      'position': serializer.toJson<int>(position),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'cli': serializer.toJson<String?>(cli),
      'model': serializer.toJson<String?>(model),
      'configuration': serializer.toJson<String>(configuration),
    };
  }

  RunSnapshotStep copyWith({
    String? id,
    String? runId,
    String? sourceWorkflowStepId,
    int? position,
    String? kind,
    String? name,
    Value<String?> cli = const Value.absent(),
    Value<String?> model = const Value.absent(),
    String? configuration,
  }) => RunSnapshotStep(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    sourceWorkflowStepId: sourceWorkflowStepId ?? this.sourceWorkflowStepId,
    position: position ?? this.position,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    cli: cli.present ? cli.value : this.cli,
    model: model.present ? model.value : this.model,
    configuration: configuration ?? this.configuration,
  );
  RunSnapshotStep copyWithCompanion(RunSnapshotStepsCompanion data) {
    return RunSnapshotStep(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      sourceWorkflowStepId: data.sourceWorkflowStepId.present
          ? data.sourceWorkflowStepId.value
          : this.sourceWorkflowStepId,
      position: data.position.present ? data.position.value : this.position,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      cli: data.cli.present ? data.cli.value : this.cli,
      model: data.model.present ? data.model.value : this.model,
      configuration: data.configuration.present
          ? data.configuration.value
          : this.configuration,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunSnapshotStep(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('sourceWorkflowStepId: $sourceWorkflowStepId, ')
          ..write('position: $position, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('cli: $cli, ')
          ..write('model: $model, ')
          ..write('configuration: $configuration')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    sourceWorkflowStepId,
    position,
    kind,
    name,
    cli,
    model,
    configuration,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunSnapshotStep &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.sourceWorkflowStepId == this.sourceWorkflowStepId &&
          other.position == this.position &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.cli == this.cli &&
          other.model == this.model &&
          other.configuration == this.configuration);
}

class RunSnapshotStepsCompanion extends UpdateCompanion<RunSnapshotStep> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String> sourceWorkflowStepId;
  final Value<int> position;
  final Value<String> kind;
  final Value<String> name;
  final Value<String?> cli;
  final Value<String?> model;
  final Value<String> configuration;
  final Value<int> rowid;
  const RunSnapshotStepsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.sourceWorkflowStepId = const Value.absent(),
    this.position = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.cli = const Value.absent(),
    this.model = const Value.absent(),
    this.configuration = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunSnapshotStepsCompanion.insert({
    required String id,
    required String runId,
    required String sourceWorkflowStepId,
    required int position,
    required String kind,
    required String name,
    this.cli = const Value.absent(),
    this.model = const Value.absent(),
    required String configuration,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       sourceWorkflowStepId = Value(sourceWorkflowStepId),
       position = Value(position),
       kind = Value(kind),
       name = Value(name),
       configuration = Value(configuration);
  static Insertable<RunSnapshotStep> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? sourceWorkflowStepId,
    Expression<int>? position,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? cli,
    Expression<String>? model,
    Expression<String>? configuration,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (sourceWorkflowStepId != null)
        'source_workflow_step_id': sourceWorkflowStepId,
      if (position != null) 'position': position,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (cli != null) 'cli': cli,
      if (model != null) 'model': model,
      if (configuration != null) 'configuration': configuration,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunSnapshotStepsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String>? sourceWorkflowStepId,
    Value<int>? position,
    Value<String>? kind,
    Value<String>? name,
    Value<String?>? cli,
    Value<String?>? model,
    Value<String>? configuration,
    Value<int>? rowid,
  }) {
    return RunSnapshotStepsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      sourceWorkflowStepId: sourceWorkflowStepId ?? this.sourceWorkflowStepId,
      position: position ?? this.position,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      cli: cli ?? this.cli,
      model: model ?? this.model,
      configuration: configuration ?? this.configuration,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (sourceWorkflowStepId.present) {
      map['source_workflow_step_id'] = Variable<String>(
        sourceWorkflowStepId.value,
      );
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cli.present) {
      map['cli'] = Variable<String>(cli.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (configuration.present) {
      map['configuration'] = Variable<String>(configuration.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunSnapshotStepsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('sourceWorkflowStepId: $sourceWorkflowStepId, ')
          ..write('position: $position, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('cli: $cli, ')
          ..write('model: $model, ')
          ..write('configuration: $configuration, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunAttemptsTable extends RunAttempts
    with TableInfo<$RunAttemptsTable, RunAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workflow_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _snapshotStepIdMeta = const VerificationMeta(
    'snapshotStepId',
  );
  @override
  late final GeneratedColumn<String> snapshotStepId = GeneratedColumn<String>(
    'snapshot_step_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES run_snapshot_steps (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _attemptNumberMeta = const VerificationMeta(
    'attemptNumber',
  );
  @override
  late final GeneratedColumn<int> attemptNumber = GeneratedColumn<int>(
    'attempt_number',
    aliasedName,
    false,
    check: () => ComparableExpr(attemptNumber).isBiggerThanValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exitCodeMeta = const VerificationMeta(
    'exitCode',
  );
  @override
  late final GeneratedColumn<int> exitCode = GeneratedColumn<int>(
    'exit_code',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureCodeMeta = const VerificationMeta(
    'failureCode',
  );
  @override
  late final GeneratedColumn<String> failureCode = GeneratedColumn<String>(
    'failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _declaredContextMeta = const VerificationMeta(
    'declaredContext',
  );
  @override
  late final GeneratedColumn<String> declaredContext = GeneratedColumn<String>(
    'declared_context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    snapshotStepId,
    attemptNumber,
    status,
    startedAt,
    completedAt,
    exitCode,
    failureCode,
    declaredContext,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('snapshot_step_id')) {
      context.handle(
        _snapshotStepIdMeta,
        snapshotStepId.isAcceptableOrUnknown(
          data['snapshot_step_id']!,
          _snapshotStepIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotStepIdMeta);
    }
    if (data.containsKey('attempt_number')) {
      context.handle(
        _attemptNumberMeta,
        attemptNumber.isAcceptableOrUnknown(
          data['attempt_number']!,
          _attemptNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attemptNumberMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('exit_code')) {
      context.handle(
        _exitCodeMeta,
        exitCode.isAcceptableOrUnknown(data['exit_code']!, _exitCodeMeta),
      );
    }
    if (data.containsKey('failure_code')) {
      context.handle(
        _failureCodeMeta,
        failureCode.isAcceptableOrUnknown(
          data['failure_code']!,
          _failureCodeMeta,
        ),
      );
    }
    if (data.containsKey('declared_context')) {
      context.handle(
        _declaredContextMeta,
        declaredContext.isAcceptableOrUnknown(
          data['declared_context']!,
          _declaredContextMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RunAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunAttempt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      snapshotStepId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_step_id'],
      )!,
      attemptNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_number'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      exitCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exit_code'],
      ),
      failureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_code'],
      ),
      declaredContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}declared_context'],
      ),
    );
  }

  @override
  $RunAttemptsTable createAlias(String alias) {
    return $RunAttemptsTable(attachedDatabase, alias);
  }
}

class RunAttempt extends DataClass implements Insertable<RunAttempt> {
  final String id;
  final String runId;
  final String snapshotStepId;
  final int attemptNumber;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? exitCode;
  final String? failureCode;
  final String? declaredContext;
  const RunAttempt({
    required this.id,
    required this.runId,
    required this.snapshotStepId,
    required this.attemptNumber,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.exitCode,
    this.failureCode,
    this.declaredContext,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['snapshot_step_id'] = Variable<String>(snapshotStepId);
    map['attempt_number'] = Variable<int>(attemptNumber);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || exitCode != null) {
      map['exit_code'] = Variable<int>(exitCode);
    }
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    if (!nullToAbsent || declaredContext != null) {
      map['declared_context'] = Variable<String>(declaredContext);
    }
    return map;
  }

  RunAttemptsCompanion toCompanion(bool nullToAbsent) {
    return RunAttemptsCompanion(
      id: Value(id),
      runId: Value(runId),
      snapshotStepId: Value(snapshotStepId),
      attemptNumber: Value(attemptNumber),
      status: Value(status),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      exitCode: exitCode == null && nullToAbsent
          ? const Value.absent()
          : Value(exitCode),
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
      declaredContext: declaredContext == null && nullToAbsent
          ? const Value.absent()
          : Value(declaredContext),
    );
  }

  factory RunAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunAttempt(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      snapshotStepId: serializer.fromJson<String>(json['snapshotStepId']),
      attemptNumber: serializer.fromJson<int>(json['attemptNumber']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      exitCode: serializer.fromJson<int?>(json['exitCode']),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
      declaredContext: serializer.fromJson<String?>(json['declaredContext']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'snapshotStepId': serializer.toJson<String>(snapshotStepId),
      'attemptNumber': serializer.toJson<int>(attemptNumber),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'exitCode': serializer.toJson<int?>(exitCode),
      'failureCode': serializer.toJson<String?>(failureCode),
      'declaredContext': serializer.toJson<String?>(declaredContext),
    };
  }

  RunAttempt copyWith({
    String? id,
    String? runId,
    String? snapshotStepId,
    int? attemptNumber,
    String? status,
    DateTime? startedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    Value<int?> exitCode = const Value.absent(),
    Value<String?> failureCode = const Value.absent(),
    Value<String?> declaredContext = const Value.absent(),
  }) => RunAttempt(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    snapshotStepId: snapshotStepId ?? this.snapshotStepId,
    attemptNumber: attemptNumber ?? this.attemptNumber,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    exitCode: exitCode.present ? exitCode.value : this.exitCode,
    failureCode: failureCode.present ? failureCode.value : this.failureCode,
    declaredContext: declaredContext.present
        ? declaredContext.value
        : this.declaredContext,
  );
  RunAttempt copyWithCompanion(RunAttemptsCompanion data) {
    return RunAttempt(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      snapshotStepId: data.snapshotStepId.present
          ? data.snapshotStepId.value
          : this.snapshotStepId,
      attemptNumber: data.attemptNumber.present
          ? data.attemptNumber.value
          : this.attemptNumber,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      exitCode: data.exitCode.present ? data.exitCode.value : this.exitCode,
      failureCode: data.failureCode.present
          ? data.failureCode.value
          : this.failureCode,
      declaredContext: data.declaredContext.present
          ? data.declaredContext.value
          : this.declaredContext,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunAttempt(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('snapshotStepId: $snapshotStepId, ')
          ..write('attemptNumber: $attemptNumber, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('exitCode: $exitCode, ')
          ..write('failureCode: $failureCode, ')
          ..write('declaredContext: $declaredContext')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    snapshotStepId,
    attemptNumber,
    status,
    startedAt,
    completedAt,
    exitCode,
    failureCode,
    declaredContext,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunAttempt &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.snapshotStepId == this.snapshotStepId &&
          other.attemptNumber == this.attemptNumber &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.exitCode == this.exitCode &&
          other.failureCode == this.failureCode &&
          other.declaredContext == this.declaredContext);
}

class RunAttemptsCompanion extends UpdateCompanion<RunAttempt> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String> snapshotStepId;
  final Value<int> attemptNumber;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<int?> exitCode;
  final Value<String?> failureCode;
  final Value<String?> declaredContext;
  final Value<int> rowid;
  const RunAttemptsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.snapshotStepId = const Value.absent(),
    this.attemptNumber = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.exitCode = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.declaredContext = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunAttemptsCompanion.insert({
    required String id,
    required String runId,
    required String snapshotStepId,
    required int attemptNumber,
    required String status,
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    this.exitCode = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.declaredContext = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       snapshotStepId = Value(snapshotStepId),
       attemptNumber = Value(attemptNumber),
       status = Value(status),
       startedAt = Value(startedAt);
  static Insertable<RunAttempt> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? snapshotStepId,
    Expression<int>? attemptNumber,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? exitCode,
    Expression<String>? failureCode,
    Expression<String>? declaredContext,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (snapshotStepId != null) 'snapshot_step_id': snapshotStepId,
      if (attemptNumber != null) 'attempt_number': attemptNumber,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (exitCode != null) 'exit_code': exitCode,
      if (failureCode != null) 'failure_code': failureCode,
      if (declaredContext != null) 'declared_context': declaredContext,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunAttemptsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String>? snapshotStepId,
    Value<int>? attemptNumber,
    Value<String>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? completedAt,
    Value<int?>? exitCode,
    Value<String?>? failureCode,
    Value<String?>? declaredContext,
    Value<int>? rowid,
  }) {
    return RunAttemptsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      snapshotStepId: snapshotStepId ?? this.snapshotStepId,
      attemptNumber: attemptNumber ?? this.attemptNumber,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      exitCode: exitCode ?? this.exitCode,
      failureCode: failureCode ?? this.failureCode,
      declaredContext: declaredContext ?? this.declaredContext,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (snapshotStepId.present) {
      map['snapshot_step_id'] = Variable<String>(snapshotStepId.value);
    }
    if (attemptNumber.present) {
      map['attempt_number'] = Variable<int>(attemptNumber.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (exitCode.present) {
      map['exit_code'] = Variable<int>(exitCode.value);
    }
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
    }
    if (declaredContext.present) {
      map['declared_context'] = Variable<String>(declaredContext.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunAttemptsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('snapshotStepId: $snapshotStepId, ')
          ..write('attemptNumber: $attemptNumber, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('exitCode: $exitCode, ')
          ..write('failureCode: $failureCode, ')
          ..write('declaredContext: $declaredContext, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunLogSegmentsTable extends RunLogSegments
    with TableInfo<$RunLogSegmentsTable, RunLogSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunLogSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workflow_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES run_attempts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _snapshotStepIdMeta = const VerificationMeta(
    'snapshotStepId',
  );
  @override
  late final GeneratedColumn<String> snapshotStepId = GeneratedColumn<String>(
    'snapshot_step_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES run_snapshot_steps (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    false,
    check: () => ComparableExpr(sequence).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _channelMeta = const VerificationMeta(
    'channel',
  );
  @override
  late final GeneratedColumn<String> channel = GeneratedColumn<String>(
    'channel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _compressionMeta = const VerificationMeta(
    'compression',
  );
  @override
  late final GeneratedColumn<String> compression = GeneratedColumn<String>(
    'compression',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _originalByteLengthMeta =
      const VerificationMeta('originalByteLength');
  @override
  late final GeneratedColumn<int> originalByteLength = GeneratedColumn<int>(
    'original_byte_length',
    aliasedName,
    false,
    check: () => ComparableExpr(originalByteLength).isBiggerOrEqualValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    attemptId,
    snapshotStepId,
    sequence,
    channel,
    bytes,
    compression,
    originalByteLength,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_log_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunLogSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_attemptIdMeta);
    }
    if (data.containsKey('snapshot_step_id')) {
      context.handle(
        _snapshotStepIdMeta,
        snapshotStepId.isAcceptableOrUnknown(
          data['snapshot_step_id']!,
          _snapshotStepIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotStepIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sequenceMeta);
    }
    if (data.containsKey('channel')) {
      context.handle(
        _channelMeta,
        channel.isAcceptableOrUnknown(data['channel']!, _channelMeta),
      );
    } else if (isInserting) {
      context.missing(_channelMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('compression')) {
      context.handle(
        _compressionMeta,
        compression.isAcceptableOrUnknown(
          data['compression']!,
          _compressionMeta,
        ),
      );
    }
    if (data.containsKey('original_byte_length')) {
      context.handle(
        _originalByteLengthMeta,
        originalByteLength.isAcceptableOrUnknown(
          data['original_byte_length']!,
          _originalByteLengthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalByteLengthMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RunLogSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunLogSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      )!,
      snapshotStepId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_step_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      )!,
      channel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      compression: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compression'],
      )!,
      originalByteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}original_byte_length'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RunLogSegmentsTable createAlias(String alias) {
    return $RunLogSegmentsTable(attachedDatabase, alias);
  }
}

class RunLogSegment extends DataClass implements Insertable<RunLogSegment> {
  final String id;
  final String runId;
  final String attemptId;
  final String snapshotStepId;
  final int sequence;
  final String channel;
  final Uint8List bytes;
  final String compression;
  final int originalByteLength;
  final DateTime createdAt;
  const RunLogSegment({
    required this.id,
    required this.runId,
    required this.attemptId,
    required this.snapshotStepId,
    required this.sequence,
    required this.channel,
    required this.bytes,
    required this.compression,
    required this.originalByteLength,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    map['attempt_id'] = Variable<String>(attemptId);
    map['snapshot_step_id'] = Variable<String>(snapshotStepId);
    map['sequence'] = Variable<int>(sequence);
    map['channel'] = Variable<String>(channel);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['compression'] = Variable<String>(compression);
    map['original_byte_length'] = Variable<int>(originalByteLength);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RunLogSegmentsCompanion toCompanion(bool nullToAbsent) {
    return RunLogSegmentsCompanion(
      id: Value(id),
      runId: Value(runId),
      attemptId: Value(attemptId),
      snapshotStepId: Value(snapshotStepId),
      sequence: Value(sequence),
      channel: Value(channel),
      bytes: Value(bytes),
      compression: Value(compression),
      originalByteLength: Value(originalByteLength),
      createdAt: Value(createdAt),
    );
  }

  factory RunLogSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunLogSegment(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      attemptId: serializer.fromJson<String>(json['attemptId']),
      snapshotStepId: serializer.fromJson<String>(json['snapshotStepId']),
      sequence: serializer.fromJson<int>(json['sequence']),
      channel: serializer.fromJson<String>(json['channel']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      compression: serializer.fromJson<String>(json['compression']),
      originalByteLength: serializer.fromJson<int>(json['originalByteLength']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'attemptId': serializer.toJson<String>(attemptId),
      'snapshotStepId': serializer.toJson<String>(snapshotStepId),
      'sequence': serializer.toJson<int>(sequence),
      'channel': serializer.toJson<String>(channel),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'compression': serializer.toJson<String>(compression),
      'originalByteLength': serializer.toJson<int>(originalByteLength),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RunLogSegment copyWith({
    String? id,
    String? runId,
    String? attemptId,
    String? snapshotStepId,
    int? sequence,
    String? channel,
    Uint8List? bytes,
    String? compression,
    int? originalByteLength,
    DateTime? createdAt,
  }) => RunLogSegment(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    attemptId: attemptId ?? this.attemptId,
    snapshotStepId: snapshotStepId ?? this.snapshotStepId,
    sequence: sequence ?? this.sequence,
    channel: channel ?? this.channel,
    bytes: bytes ?? this.bytes,
    compression: compression ?? this.compression,
    originalByteLength: originalByteLength ?? this.originalByteLength,
    createdAt: createdAt ?? this.createdAt,
  );
  RunLogSegment copyWithCompanion(RunLogSegmentsCompanion data) {
    return RunLogSegment(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      snapshotStepId: data.snapshotStepId.present
          ? data.snapshotStepId.value
          : this.snapshotStepId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      channel: data.channel.present ? data.channel.value : this.channel,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      compression: data.compression.present
          ? data.compression.value
          : this.compression,
      originalByteLength: data.originalByteLength.present
          ? data.originalByteLength.value
          : this.originalByteLength,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunLogSegment(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('attemptId: $attemptId, ')
          ..write('snapshotStepId: $snapshotStepId, ')
          ..write('sequence: $sequence, ')
          ..write('channel: $channel, ')
          ..write('bytes: $bytes, ')
          ..write('compression: $compression, ')
          ..write('originalByteLength: $originalByteLength, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    runId,
    attemptId,
    snapshotStepId,
    sequence,
    channel,
    $driftBlobEquality.hash(bytes),
    compression,
    originalByteLength,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunLogSegment &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.attemptId == this.attemptId &&
          other.snapshotStepId == this.snapshotStepId &&
          other.sequence == this.sequence &&
          other.channel == this.channel &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.compression == this.compression &&
          other.originalByteLength == this.originalByteLength &&
          other.createdAt == this.createdAt);
}

class RunLogSegmentsCompanion extends UpdateCompanion<RunLogSegment> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String> attemptId;
  final Value<String> snapshotStepId;
  final Value<int> sequence;
  final Value<String> channel;
  final Value<Uint8List> bytes;
  final Value<String> compression;
  final Value<int> originalByteLength;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RunLogSegmentsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.snapshotStepId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.channel = const Value.absent(),
    this.bytes = const Value.absent(),
    this.compression = const Value.absent(),
    this.originalByteLength = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunLogSegmentsCompanion.insert({
    required String id,
    required String runId,
    required String attemptId,
    required String snapshotStepId,
    required int sequence,
    required String channel,
    required Uint8List bytes,
    this.compression = const Value.absent(),
    required int originalByteLength,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       attemptId = Value(attemptId),
       snapshotStepId = Value(snapshotStepId),
       sequence = Value(sequence),
       channel = Value(channel),
       bytes = Value(bytes),
       originalByteLength = Value(originalByteLength),
       createdAt = Value(createdAt);
  static Insertable<RunLogSegment> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? attemptId,
    Expression<String>? snapshotStepId,
    Expression<int>? sequence,
    Expression<String>? channel,
    Expression<Uint8List>? bytes,
    Expression<String>? compression,
    Expression<int>? originalByteLength,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (attemptId != null) 'attempt_id': attemptId,
      if (snapshotStepId != null) 'snapshot_step_id': snapshotStepId,
      if (sequence != null) 'sequence': sequence,
      if (channel != null) 'channel': channel,
      if (bytes != null) 'bytes': bytes,
      if (compression != null) 'compression': compression,
      if (originalByteLength != null)
        'original_byte_length': originalByteLength,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunLogSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String>? attemptId,
    Value<String>? snapshotStepId,
    Value<int>? sequence,
    Value<String>? channel,
    Value<Uint8List>? bytes,
    Value<String>? compression,
    Value<int>? originalByteLength,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RunLogSegmentsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      attemptId: attemptId ?? this.attemptId,
      snapshotStepId: snapshotStepId ?? this.snapshotStepId,
      sequence: sequence ?? this.sequence,
      channel: channel ?? this.channel,
      bytes: bytes ?? this.bytes,
      compression: compression ?? this.compression,
      originalByteLength: originalByteLength ?? this.originalByteLength,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (snapshotStepId.present) {
      map['snapshot_step_id'] = Variable<String>(snapshotStepId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (channel.present) {
      map['channel'] = Variable<String>(channel.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (compression.present) {
      map['compression'] = Variable<String>(compression.value);
    }
    if (originalByteLength.present) {
      map['original_byte_length'] = Variable<int>(originalByteLength.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunLogSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('attemptId: $attemptId, ')
          ..write('snapshotStepId: $snapshotStepId, ')
          ..write('sequence: $sequence, ')
          ..write('channel: $channel, ')
          ..write('bytes: $bytes, ')
          ..write('compression: $compression, ')
          ..write('originalByteLength: $originalByteLength, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RunRecoveryRequestsTable extends RunRecoveryRequests
    with TableInfo<$RunRecoveryRequestsTable, RunRecoveryRequest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunRecoveryRequestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workflow_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _attemptIdMeta = const VerificationMeta(
    'attemptId',
  );
  @override
  late final GeneratedColumn<String> attemptId = GeneratedColumn<String>(
    'attempt_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES run_attempts (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestedAtMeta = const VerificationMeta(
    'requestedAt',
  );
  @override
  late final GeneratedColumn<DateTime> requestedAt = GeneratedColumn<DateTime>(
    'requested_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    runId,
    attemptId,
    action,
    status,
    requestedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'run_recovery_requests';
  @override
  VerificationContext validateIntegrity(
    Insertable<RunRecoveryRequest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('attempt_id')) {
      context.handle(
        _attemptIdMeta,
        attemptId.isAcceptableOrUnknown(data['attempt_id']!, _attemptIdMeta),
      );
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('requested_at')) {
      context.handle(
        _requestedAtMeta,
        requestedAt.isAcceptableOrUnknown(
          data['requested_at']!,
          _requestedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RunRecoveryRequest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RunRecoveryRequest(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      attemptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attempt_id'],
      ),
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      requestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}requested_at'],
      )!,
    );
  }

  @override
  $RunRecoveryRequestsTable createAlias(String alias) {
    return $RunRecoveryRequestsTable(attachedDatabase, alias);
  }
}

class RunRecoveryRequest extends DataClass
    implements Insertable<RunRecoveryRequest> {
  final String id;
  final String runId;
  final String? attemptId;
  final String action;
  final String status;
  final DateTime requestedAt;
  const RunRecoveryRequest({
    required this.id,
    required this.runId,
    this.attemptId,
    required this.action,
    required this.status,
    required this.requestedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['run_id'] = Variable<String>(runId);
    if (!nullToAbsent || attemptId != null) {
      map['attempt_id'] = Variable<String>(attemptId);
    }
    map['action'] = Variable<String>(action);
    map['status'] = Variable<String>(status);
    map['requested_at'] = Variable<DateTime>(requestedAt);
    return map;
  }

  RunRecoveryRequestsCompanion toCompanion(bool nullToAbsent) {
    return RunRecoveryRequestsCompanion(
      id: Value(id),
      runId: Value(runId),
      attemptId: attemptId == null && nullToAbsent
          ? const Value.absent()
          : Value(attemptId),
      action: Value(action),
      status: Value(status),
      requestedAt: Value(requestedAt),
    );
  }

  factory RunRecoveryRequest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RunRecoveryRequest(
      id: serializer.fromJson<String>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      attemptId: serializer.fromJson<String?>(json['attemptId']),
      action: serializer.fromJson<String>(json['action']),
      status: serializer.fromJson<String>(json['status']),
      requestedAt: serializer.fromJson<DateTime>(json['requestedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'runId': serializer.toJson<String>(runId),
      'attemptId': serializer.toJson<String?>(attemptId),
      'action': serializer.toJson<String>(action),
      'status': serializer.toJson<String>(status),
      'requestedAt': serializer.toJson<DateTime>(requestedAt),
    };
  }

  RunRecoveryRequest copyWith({
    String? id,
    String? runId,
    Value<String?> attemptId = const Value.absent(),
    String? action,
    String? status,
    DateTime? requestedAt,
  }) => RunRecoveryRequest(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    attemptId: attemptId.present ? attemptId.value : this.attemptId,
    action: action ?? this.action,
    status: status ?? this.status,
    requestedAt: requestedAt ?? this.requestedAt,
  );
  RunRecoveryRequest copyWithCompanion(RunRecoveryRequestsCompanion data) {
    return RunRecoveryRequest(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      attemptId: data.attemptId.present ? data.attemptId.value : this.attemptId,
      action: data.action.present ? data.action.value : this.action,
      status: data.status.present ? data.status.value : this.status,
      requestedAt: data.requestedAt.present
          ? data.requestedAt.value
          : this.requestedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RunRecoveryRequest(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('attemptId: $attemptId, ')
          ..write('action: $action, ')
          ..write('status: $status, ')
          ..write('requestedAt: $requestedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, runId, attemptId, action, status, requestedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RunRecoveryRequest &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.attemptId == this.attemptId &&
          other.action == this.action &&
          other.status == this.status &&
          other.requestedAt == this.requestedAt);
}

class RunRecoveryRequestsCompanion extends UpdateCompanion<RunRecoveryRequest> {
  final Value<String> id;
  final Value<String> runId;
  final Value<String?> attemptId;
  final Value<String> action;
  final Value<String> status;
  final Value<DateTime> requestedAt;
  final Value<int> rowid;
  const RunRecoveryRequestsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.attemptId = const Value.absent(),
    this.action = const Value.absent(),
    this.status = const Value.absent(),
    this.requestedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RunRecoveryRequestsCompanion.insert({
    required String id,
    required String runId,
    this.attemptId = const Value.absent(),
    required String action,
    required String status,
    required DateTime requestedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       runId = Value(runId),
       action = Value(action),
       status = Value(status),
       requestedAt = Value(requestedAt);
  static Insertable<RunRecoveryRequest> custom({
    Expression<String>? id,
    Expression<String>? runId,
    Expression<String>? attemptId,
    Expression<String>? action,
    Expression<String>? status,
    Expression<DateTime>? requestedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (attemptId != null) 'attempt_id': attemptId,
      if (action != null) 'action': action,
      if (status != null) 'status': status,
      if (requestedAt != null) 'requested_at': requestedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RunRecoveryRequestsCompanion copyWith({
    Value<String>? id,
    Value<String>? runId,
    Value<String?>? attemptId,
    Value<String>? action,
    Value<String>? status,
    Value<DateTime>? requestedAt,
    Value<int>? rowid,
  }) {
    return RunRecoveryRequestsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      attemptId: attemptId ?? this.attemptId,
      action: action ?? this.action,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (attemptId.present) {
      map['attempt_id'] = Variable<String>(attemptId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (requestedAt.present) {
      map['requested_at'] = Variable<DateTime>(requestedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunRecoveryRequestsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('attemptId: $attemptId, ')
          ..write('action: $action, ')
          ..write('status: $status, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MaestroDatabase extends GeneratedDatabase {
  _$MaestroDatabase(QueryExecutor e) : super(e);
  $MaestroDatabaseManager get managers => $MaestroDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $DiagnosticLogSegmentsTable diagnosticLogSegments =
      $DiagnosticLogSegmentsTable(this);
  late final $OwnedResourcesTable ownedResources = $OwnedResourcesTable(this);
  late final $LocalUsersTable localUsers = $LocalUsersTable(this);
  late final $AuditEventsTable auditEvents = $AuditEventsTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $WorkflowsTable workflows = $WorkflowsTable(this);
  late final $WorkflowStepsTable workflowSteps = $WorkflowStepsTable(this);
  late final $WorkflowProjectRefsTable workflowProjectRefs =
      $WorkflowProjectRefsTable(this);
  late final $WorkflowRunsTable workflowRuns = $WorkflowRunsTable(this);
  late final $RunSnapshotsTable runSnapshots = $RunSnapshotsTable(this);
  late final $RunSnapshotStepsTable runSnapshotSteps = $RunSnapshotStepsTable(
    this,
  );
  late final $RunAttemptsTable runAttempts = $RunAttemptsTable(this);
  late final $RunLogSegmentsTable runLogSegments = $RunLogSegmentsTable(this);
  late final $RunRecoveryRequestsTable runRecoveryRequests =
      $RunRecoveryRequestsTable(this);
  late final Index localUsersSingleOperatingSystem = Index(
    'local_users_single_operating_system',
    'CREATE UNIQUE INDEX local_users_single_operating_system ON local_users (auth_method) WHERE auth_method = \'operatingSystem\'',
  );
  late final Index workflowStepsWorkflowPosition = Index(
    'workflow_steps_workflow_position',
    'CREATE UNIQUE INDEX workflow_steps_workflow_position ON workflow_steps (workflow_id, position)',
  );
  late final Index workflowProjectRefsProject = Index(
    'workflow_project_refs_project',
    'CREATE INDEX workflow_project_refs_project ON workflow_project_refs (project_id)',
  );
  late final Index workflowRunsProjectStatus = Index(
    'workflow_runs_project_status',
    'CREATE INDEX workflow_runs_project_status ON workflow_runs (project_id, status)',
  );
  late final Index workflowRunsStatus = Index(
    'workflow_runs_status',
    'CREATE INDEX workflow_runs_status ON workflow_runs (status)',
  );
  late final Index runSnapshotStepsRunPosition = Index(
    'run_snapshot_steps_run_position',
    'CREATE UNIQUE INDEX run_snapshot_steps_run_position ON run_snapshot_steps (run_id, position)',
  );
  late final Index runSnapshotStepsRunIdentity = Index(
    'run_snapshot_steps_run_identity',
    'CREATE UNIQUE INDEX run_snapshot_steps_run_identity ON run_snapshot_steps (run_id, id)',
  );
  late final Index runAttemptsStepNumber = Index(
    'run_attempts_step_number',
    'CREATE UNIQUE INDEX run_attempts_step_number ON run_attempts (run_id, snapshot_step_id, attempt_number)',
  );
  late final Index runAttemptsRunStatus = Index(
    'run_attempts_run_status',
    'CREATE INDEX run_attempts_run_status ON run_attempts (run_id, status)',
  );
  late final Index runAttemptsRunIdentity = Index(
    'run_attempts_run_identity',
    'CREATE UNIQUE INDEX run_attempts_run_identity ON run_attempts (run_id, id)',
  );
  late final Index runAttemptsRunIdentityStep = Index(
    'run_attempts_run_identity_step',
    'CREATE UNIQUE INDEX run_attempts_run_identity_step ON run_attempts (run_id, id, snapshot_step_id)',
  );
  late final Index runAttemptsOneActiveStep = Index(
    'run_attempts_one_active_step',
    'CREATE UNIQUE INDEX run_attempts_one_active_step ON run_attempts (run_id, snapshot_step_id) WHERE status IN (\'starting\', \'running\')',
  );
  late final Index runLogSegmentsAttemptSequence = Index(
    'run_log_segments_attempt_sequence',
    'CREATE UNIQUE INDEX run_log_segments_attempt_sequence ON run_log_segments (attempt_id, sequence)',
  );
  late final Index runLogSegmentsRun = Index(
    'run_log_segments_run',
    'CREATE INDEX run_log_segments_run ON run_log_segments (run_id)',
  );
  late final Index runRecoveryRequestsRunStatus = Index(
    'run_recovery_requests_run_status',
    'CREATE INDEX run_recovery_requests_run_status ON run_recovery_requests (run_id, status)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    diagnosticLogSegments,
    ownedResources,
    localUsers,
    auditEvents,
    projects,
    workflows,
    workflowSteps,
    workflowProjectRefs,
    workflowRuns,
    runSnapshots,
    runSnapshotSteps,
    runAttempts,
    runLogSegments,
    runRecoveryRequests,
    localUsersSingleOperatingSystem,
    workflowStepsWorkflowPosition,
    workflowProjectRefsProject,
    workflowRunsProjectStatus,
    workflowRunsStatus,
    runSnapshotStepsRunPosition,
    runSnapshotStepsRunIdentity,
    runAttemptsStepNumber,
    runAttemptsRunStatus,
    runAttemptsRunIdentity,
    runAttemptsRunIdentityStep,
    runAttemptsOneActiveStep,
    runLogSegmentsAttemptSequence,
    runLogSegmentsRun,
    runRecoveryRequestsRunStatus,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workflows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workflow_steps', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workflows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workflow_project_refs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workflow_project_refs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'projects',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workflow_runs', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workflows',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workflow_runs', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workflow_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('run_snapshots', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workflow_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('run_snapshot_steps', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workflow_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('run_attempts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workflow_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('run_log_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'run_attempts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('run_log_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workflow_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('run_recovery_requests', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$MaestroDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$MaestroDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$MaestroDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$MaestroDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$DiagnosticLogSegmentsTableCreateCompanionBuilder =
    DiagnosticLogSegmentsCompanion Function({
      required String id,
      Value<String?> runId,
      required int sequenceStart,
      required int sequenceEnd,
      required int originalByteLength,
      required int compressedByteLength,
      required Uint8List compressedBytes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$DiagnosticLogSegmentsTableUpdateCompanionBuilder =
    DiagnosticLogSegmentsCompanion Function({
      Value<String> id,
      Value<String?> runId,
      Value<int> sequenceStart,
      Value<int> sequenceEnd,
      Value<int> originalByteLength,
      Value<int> compressedByteLength,
      Value<Uint8List> compressedBytes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$DiagnosticLogSegmentsTableFilterComposer
    extends Composer<_$MaestroDatabase, $DiagnosticLogSegmentsTable> {
  $$DiagnosticLogSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequenceStart => $composableBuilder(
    column: $table.sequenceStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequenceEnd => $composableBuilder(
    column: $table.sequenceEnd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originalByteLength => $composableBuilder(
    column: $table.originalByteLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get compressedByteLength => $composableBuilder(
    column: $table.compressedByteLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get compressedBytes => $composableBuilder(
    column: $table.compressedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiagnosticLogSegmentsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $DiagnosticLogSegmentsTable> {
  $$DiagnosticLogSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequenceStart => $composableBuilder(
    column: $table.sequenceStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequenceEnd => $composableBuilder(
    column: $table.sequenceEnd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originalByteLength => $composableBuilder(
    column: $table.originalByteLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get compressedByteLength => $composableBuilder(
    column: $table.compressedByteLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get compressedBytes => $composableBuilder(
    column: $table.compressedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiagnosticLogSegmentsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $DiagnosticLogSegmentsTable> {
  $$DiagnosticLogSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<int> get sequenceStart => $composableBuilder(
    column: $table.sequenceStart,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sequenceEnd => $composableBuilder(
    column: $table.sequenceEnd,
    builder: (column) => column,
  );

  GeneratedColumn<int> get originalByteLength => $composableBuilder(
    column: $table.originalByteLength,
    builder: (column) => column,
  );

  GeneratedColumn<int> get compressedByteLength => $composableBuilder(
    column: $table.compressedByteLength,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get compressedBytes => $composableBuilder(
    column: $table.compressedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DiagnosticLogSegmentsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $DiagnosticLogSegmentsTable,
          DiagnosticLogSegment,
          $$DiagnosticLogSegmentsTableFilterComposer,
          $$DiagnosticLogSegmentsTableOrderingComposer,
          $$DiagnosticLogSegmentsTableAnnotationComposer,
          $$DiagnosticLogSegmentsTableCreateCompanionBuilder,
          $$DiagnosticLogSegmentsTableUpdateCompanionBuilder,
          (
            DiagnosticLogSegment,
            BaseReferences<
              _$MaestroDatabase,
              $DiagnosticLogSegmentsTable,
              DiagnosticLogSegment
            >,
          ),
          DiagnosticLogSegment,
          PrefetchHooks Function()
        > {
  $$DiagnosticLogSegmentsTableTableManager(
    _$MaestroDatabase db,
    $DiagnosticLogSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiagnosticLogSegmentsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DiagnosticLogSegmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DiagnosticLogSegmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<int> sequenceStart = const Value.absent(),
                Value<int> sequenceEnd = const Value.absent(),
                Value<int> originalByteLength = const Value.absent(),
                Value<int> compressedByteLength = const Value.absent(),
                Value<Uint8List> compressedBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiagnosticLogSegmentsCompanion(
                id: id,
                runId: runId,
                sequenceStart: sequenceStart,
                sequenceEnd: sequenceEnd,
                originalByteLength: originalByteLength,
                compressedByteLength: compressedByteLength,
                compressedBytes: compressedBytes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> runId = const Value.absent(),
                required int sequenceStart,
                required int sequenceEnd,
                required int originalByteLength,
                required int compressedByteLength,
                required Uint8List compressedBytes,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiagnosticLogSegmentsCompanion.insert(
                id: id,
                runId: runId,
                sequenceStart: sequenceStart,
                sequenceEnd: sequenceEnd,
                originalByteLength: originalByteLength,
                compressedByteLength: compressedByteLength,
                compressedBytes: compressedBytes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiagnosticLogSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $DiagnosticLogSegmentsTable,
      DiagnosticLogSegment,
      $$DiagnosticLogSegmentsTableFilterComposer,
      $$DiagnosticLogSegmentsTableOrderingComposer,
      $$DiagnosticLogSegmentsTableAnnotationComposer,
      $$DiagnosticLogSegmentsTableCreateCompanionBuilder,
      $$DiagnosticLogSegmentsTableUpdateCompanionBuilder,
      (
        DiagnosticLogSegment,
        BaseReferences<
          _$MaestroDatabase,
          $DiagnosticLogSegmentsTable,
          DiagnosticLogSegment
        >,
      ),
      DiagnosticLogSegment,
      PrefetchHooks Function()
    >;
typedef $$OwnedResourcesTableCreateCompanionBuilder =
    OwnedResourcesCompanion Function({
      required String id,
      required String kind,
      required String path,
      Value<String?> runId,
      Value<int?> processId,
      required String state,
      Value<DateTime> createdAt,
      Value<DateTime?> lastReconciledAt,
      Value<int> rowid,
    });
typedef $$OwnedResourcesTableUpdateCompanionBuilder =
    OwnedResourcesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> path,
      Value<String?> runId,
      Value<int?> processId,
      Value<String> state,
      Value<DateTime> createdAt,
      Value<DateTime?> lastReconciledAt,
      Value<int> rowid,
    });

class $$OwnedResourcesTableFilterComposer
    extends Composer<_$MaestroDatabase, $OwnedResourcesTable> {
  $$OwnedResourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get processId => $composableBuilder(
    column: $table.processId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReconciledAt => $composableBuilder(
    column: $table.lastReconciledAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OwnedResourcesTableOrderingComposer
    extends Composer<_$MaestroDatabase, $OwnedResourcesTable> {
  $$OwnedResourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runId => $composableBuilder(
    column: $table.runId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get processId => $composableBuilder(
    column: $table.processId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReconciledAt => $composableBuilder(
    column: $table.lastReconciledAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OwnedResourcesTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $OwnedResourcesTable> {
  $$OwnedResourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get runId =>
      $composableBuilder(column: $table.runId, builder: (column) => column);

  GeneratedColumn<int> get processId =>
      $composableBuilder(column: $table.processId, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReconciledAt => $composableBuilder(
    column: $table.lastReconciledAt,
    builder: (column) => column,
  );
}

class $$OwnedResourcesTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $OwnedResourcesTable,
          OwnedResource,
          $$OwnedResourcesTableFilterComposer,
          $$OwnedResourcesTableOrderingComposer,
          $$OwnedResourcesTableAnnotationComposer,
          $$OwnedResourcesTableCreateCompanionBuilder,
          $$OwnedResourcesTableUpdateCompanionBuilder,
          (
            OwnedResource,
            BaseReferences<
              _$MaestroDatabase,
              $OwnedResourcesTable,
              OwnedResource
            >,
          ),
          OwnedResource,
          PrefetchHooks Function()
        > {
  $$OwnedResourcesTableTableManager(
    _$MaestroDatabase db,
    $OwnedResourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OwnedResourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OwnedResourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OwnedResourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String?> runId = const Value.absent(),
                Value<int?> processId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastReconciledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OwnedResourcesCompanion(
                id: id,
                kind: kind,
                path: path,
                runId: runId,
                processId: processId,
                state: state,
                createdAt: createdAt,
                lastReconciledAt: lastReconciledAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String path,
                Value<String?> runId = const Value.absent(),
                Value<int?> processId = const Value.absent(),
                required String state,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastReconciledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OwnedResourcesCompanion.insert(
                id: id,
                kind: kind,
                path: path,
                runId: runId,
                processId: processId,
                state: state,
                createdAt: createdAt,
                lastReconciledAt: lastReconciledAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OwnedResourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $OwnedResourcesTable,
      OwnedResource,
      $$OwnedResourcesTableFilterComposer,
      $$OwnedResourcesTableOrderingComposer,
      $$OwnedResourcesTableAnnotationComposer,
      $$OwnedResourcesTableCreateCompanionBuilder,
      $$OwnedResourcesTableUpdateCompanionBuilder,
      (
        OwnedResource,
        BaseReferences<_$MaestroDatabase, $OwnedResourcesTable, OwnedResource>,
      ),
      OwnedResource,
      PrefetchHooks Function()
    >;
typedef $$LocalUsersTableCreateCompanionBuilder =
    LocalUsersCompanion Function({
      required String id,
      Value<String?> email,
      required String authMethod,
      Value<String?> verifierKey,
      required DateTime createdAt,
      Value<DateTime?> lastAuthenticatedAt,
      Value<int> rowid,
    });
typedef $$LocalUsersTableUpdateCompanionBuilder =
    LocalUsersCompanion Function({
      Value<String> id,
      Value<String?> email,
      Value<String> authMethod,
      Value<String?> verifierKey,
      Value<DateTime> createdAt,
      Value<DateTime?> lastAuthenticatedAt,
      Value<int> rowid,
    });

class $$LocalUsersTableFilterComposer
    extends Composer<_$MaestroDatabase, $LocalUsersTable> {
  $$LocalUsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verifierKey => $composableBuilder(
    column: $table.verifierKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAuthenticatedAt => $composableBuilder(
    column: $table.lastAuthenticatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalUsersTableOrderingComposer
    extends Composer<_$MaestroDatabase, $LocalUsersTable> {
  $$LocalUsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verifierKey => $composableBuilder(
    column: $table.verifierKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAuthenticatedAt => $composableBuilder(
    column: $table.lastAuthenticatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalUsersTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $LocalUsersTable> {
  $$LocalUsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get authMethod => $composableBuilder(
    column: $table.authMethod,
    builder: (column) => column,
  );

  GeneratedColumn<String> get verifierKey => $composableBuilder(
    column: $table.verifierKey,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAuthenticatedAt => $composableBuilder(
    column: $table.lastAuthenticatedAt,
    builder: (column) => column,
  );
}

class $$LocalUsersTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $LocalUsersTable,
          LocalUser,
          $$LocalUsersTableFilterComposer,
          $$LocalUsersTableOrderingComposer,
          $$LocalUsersTableAnnotationComposer,
          $$LocalUsersTableCreateCompanionBuilder,
          $$LocalUsersTableUpdateCompanionBuilder,
          (
            LocalUser,
            BaseReferences<_$MaestroDatabase, $LocalUsersTable, LocalUser>,
          ),
          LocalUser,
          PrefetchHooks Function()
        > {
  $$LocalUsersTableTableManager(_$MaestroDatabase db, $LocalUsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalUsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalUsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalUsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String> authMethod = const Value.absent(),
                Value<String?> verifierKey = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastAuthenticatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalUsersCompanion(
                id: id,
                email: email,
                authMethod: authMethod,
                verifierKey: verifierKey,
                createdAt: createdAt,
                lastAuthenticatedAt: lastAuthenticatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> email = const Value.absent(),
                required String authMethod,
                Value<String?> verifierKey = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastAuthenticatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalUsersCompanion.insert(
                id: id,
                email: email,
                authMethod: authMethod,
                verifierKey: verifierKey,
                createdAt: createdAt,
                lastAuthenticatedAt: lastAuthenticatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalUsersTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $LocalUsersTable,
      LocalUser,
      $$LocalUsersTableFilterComposer,
      $$LocalUsersTableOrderingComposer,
      $$LocalUsersTableAnnotationComposer,
      $$LocalUsersTableCreateCompanionBuilder,
      $$LocalUsersTableUpdateCompanionBuilder,
      (
        LocalUser,
        BaseReferences<_$MaestroDatabase, $LocalUsersTable, LocalUser>,
      ),
      LocalUser,
      PrefetchHooks Function()
    >;
typedef $$AuditEventsTableCreateCompanionBuilder =
    AuditEventsCompanion Function({
      required String id,
      required String actorId,
      required String action,
      required String target,
      required String outcome,
      required DateTime occurredAt,
      required String details,
      Value<int> rowid,
    });
typedef $$AuditEventsTableUpdateCompanionBuilder =
    AuditEventsCompanion Function({
      Value<String> id,
      Value<String> actorId,
      Value<String> action,
      Value<String> target,
      Value<String> outcome,
      Value<DateTime> occurredAt,
      Value<String> details,
      Value<int> rowid,
    });

class $$AuditEventsTableFilterComposer
    extends Composer<_$MaestroDatabase, $AuditEventsTable> {
  $$AuditEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuditEventsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $AuditEventsTable> {
  $$AuditEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorId => $composableBuilder(
    column: $table.actorId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditEventsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $AuditEventsTable> {
  $$AuditEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);
}

class $$AuditEventsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $AuditEventsTable,
          AuditEvent,
          $$AuditEventsTableFilterComposer,
          $$AuditEventsTableOrderingComposer,
          $$AuditEventsTableAnnotationComposer,
          $$AuditEventsTableCreateCompanionBuilder,
          $$AuditEventsTableUpdateCompanionBuilder,
          (
            AuditEvent,
            BaseReferences<_$MaestroDatabase, $AuditEventsTable, AuditEvent>,
          ),
          AuditEvent,
          PrefetchHooks Function()
        > {
  $$AuditEventsTableTableManager(_$MaestroDatabase db, $AuditEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> actorId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> details = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditEventsCompanion(
                id: id,
                actorId: actorId,
                action: action,
                target: target,
                outcome: outcome,
                occurredAt: occurredAt,
                details: details,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String actorId,
                required String action,
                required String target,
                required String outcome,
                required DateTime occurredAt,
                required String details,
                Value<int> rowid = const Value.absent(),
              }) => AuditEventsCompanion.insert(
                id: id,
                actorId: actorId,
                action: action,
                target: target,
                outcome: outcome,
                occurredAt: occurredAt,
                details: details,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuditEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $AuditEventsTable,
      AuditEvent,
      $$AuditEventsTableFilterComposer,
      $$AuditEventsTableOrderingComposer,
      $$AuditEventsTableAnnotationComposer,
      $$AuditEventsTableCreateCompanionBuilder,
      $$AuditEventsTableUpdateCompanionBuilder,
      (
        AuditEvent,
        BaseReferences<_$MaestroDatabase, $AuditEventsTable, AuditEvent>,
      ),
      AuditEvent,
      PrefetchHooks Function()
    >;
typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String id,
      required String name,
      required String normalizedName,
      required String folderPath,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> normalizedName,
      Value<String> folderPath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$MaestroDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $WorkflowProjectRefsTable,
    List<WorkflowProjectRef>
  >
  _workflowProjectRefsRefsTable(_$MaestroDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workflowProjectRefs,
        aliasName: 'projects__id__workflow_project_refs__project_id',
      );

  $$WorkflowProjectRefsTableProcessedTableManager get workflowProjectRefsRefs {
    final manager = $$WorkflowProjectRefsTableTableManager(
      $_db,
      $_db.workflowProjectRefs,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workflowProjectRefsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkflowRunsTable, List<WorkflowRun>>
  _workflowRunsRefsTable(_$MaestroDatabase db) => MultiTypedResultKey.fromTable(
    db.workflowRuns,
    aliasName: 'projects__id__workflow_runs__project_id',
  );

  $$WorkflowRunsTableProcessedTableManager get workflowRunsRefs {
    final manager = $$WorkflowRunsTableTableManager(
      $_db,
      $_db.workflowRuns,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workflowRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$MaestroDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workflowProjectRefsRefs(
    Expression<bool> Function($$WorkflowProjectRefsTableFilterComposer f) f,
  ) {
    final $$WorkflowProjectRefsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workflowProjectRefs,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowProjectRefsTableFilterComposer(
            $db: $db,
            $table: $db.workflowProjectRefs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workflowRunsRefs(
    Expression<bool> Function($$WorkflowRunsTableFilterComposer f) f,
  ) {
    final $$WorkflowRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableFilterComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> workflowProjectRefsRefs<T extends Object>(
    Expression<T> Function($$WorkflowProjectRefsTableAnnotationComposer a) f,
  ) {
    final $$WorkflowProjectRefsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workflowProjectRefs,
          getReferencedColumn: (t) => t.projectId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkflowProjectRefsTableAnnotationComposer(
                $db: $db,
                $table: $db.workflowProjectRefs,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> workflowRunsRefs<T extends Object>(
    Expression<T> Function($$WorkflowRunsTableAnnotationComposer a) f,
  ) {
    final $$WorkflowRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({
            bool workflowProjectRefsRefs,
            bool workflowRunsRefs,
          })
        > {
  $$ProjectsTableTableManager(_$MaestroDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<String> folderPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
                folderPath: folderPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String normalizedName,
                required String folderPath,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
                folderPath: folderPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({workflowProjectRefsRefs = false, workflowRunsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workflowProjectRefsRefs) db.workflowProjectRefs,
                    if (workflowRunsRefs) db.workflowRuns,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workflowProjectRefsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          WorkflowProjectRef
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._workflowProjectRefsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).workflowProjectRefsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workflowRunsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          WorkflowRun
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._workflowRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).workflowRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({
        bool workflowProjectRefsRefs,
        bool workflowRunsRefs,
      })
    >;
typedef $$WorkflowsTableCreateCompanionBuilder =
    WorkflowsCompanion Function({
      required String id,
      required int revision,
      Value<String?> name,
      required bool isReusable,
      required String unitType,
      Value<bool> supervisedDelivery,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$WorkflowsTableUpdateCompanionBuilder =
    WorkflowsCompanion Function({
      Value<String> id,
      Value<int> revision,
      Value<String?> name,
      Value<bool> isReusable,
      Value<String> unitType,
      Value<bool> supervisedDelivery,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$WorkflowsTableReferences
    extends BaseReferences<_$MaestroDatabase, $WorkflowsTable, Workflow> {
  $$WorkflowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WorkflowStepsTable, List<WorkflowStep>>
  _workflowStepsRefsTable(_$MaestroDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workflowSteps,
        aliasName: 'workflows__id__workflow_steps__workflow_id',
      );

  $$WorkflowStepsTableProcessedTableManager get workflowStepsRefs {
    final manager = $$WorkflowStepsTableTableManager(
      $_db,
      $_db.workflowSteps,
    ).filter((f) => f.workflowId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workflowStepsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WorkflowProjectRefsTable,
    List<WorkflowProjectRef>
  >
  _workflowProjectRefsRefsTable(_$MaestroDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workflowProjectRefs,
        aliasName: 'workflows__id__workflow_project_refs__workflow_id',
      );

  $$WorkflowProjectRefsTableProcessedTableManager get workflowProjectRefsRefs {
    final manager = $$WorkflowProjectRefsTableTableManager(
      $_db,
      $_db.workflowProjectRefs,
    ).filter((f) => f.workflowId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workflowProjectRefsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WorkflowRunsTable, List<WorkflowRun>>
  _workflowRunsRefsTable(_$MaestroDatabase db) => MultiTypedResultKey.fromTable(
    db.workflowRuns,
    aliasName: 'workflows__id__workflow_runs__workflow_id',
  );

  $$WorkflowRunsTableProcessedTableManager get workflowRunsRefs {
    final manager = $$WorkflowRunsTableTableManager(
      $_db,
      $_db.workflowRuns,
    ).filter((f) => f.workflowId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workflowRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkflowsTableFilterComposer
    extends Composer<_$MaestroDatabase, $WorkflowsTable> {
  $$WorkflowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReusable => $composableBuilder(
    column: $table.isReusable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unitType => $composableBuilder(
    column: $table.unitType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supervisedDelivery => $composableBuilder(
    column: $table.supervisedDelivery,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workflowStepsRefs(
    Expression<bool> Function($$WorkflowStepsTableFilterComposer f) f,
  ) {
    final $$WorkflowStepsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workflowSteps,
      getReferencedColumn: (t) => t.workflowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowStepsTableFilterComposer(
            $db: $db,
            $table: $db.workflowSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workflowProjectRefsRefs(
    Expression<bool> Function($$WorkflowProjectRefsTableFilterComposer f) f,
  ) {
    final $$WorkflowProjectRefsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workflowProjectRefs,
      getReferencedColumn: (t) => t.workflowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowProjectRefsTableFilterComposer(
            $db: $db,
            $table: $db.workflowProjectRefs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> workflowRunsRefs(
    Expression<bool> Function($$WorkflowRunsTableFilterComposer f) f,
  ) {
    final $$WorkflowRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.workflowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableFilterComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkflowsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $WorkflowsTable> {
  $$WorkflowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReusable => $composableBuilder(
    column: $table.isReusable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unitType => $composableBuilder(
    column: $table.unitType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supervisedDelivery => $composableBuilder(
    column: $table.supervisedDelivery,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkflowsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $WorkflowsTable> {
  $$WorkflowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isReusable => $composableBuilder(
    column: $table.isReusable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unitType =>
      $composableBuilder(column: $table.unitType, builder: (column) => column);

  GeneratedColumn<bool> get supervisedDelivery => $composableBuilder(
    column: $table.supervisedDelivery,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> workflowStepsRefs<T extends Object>(
    Expression<T> Function($$WorkflowStepsTableAnnotationComposer a) f,
  ) {
    final $$WorkflowStepsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workflowSteps,
      getReferencedColumn: (t) => t.workflowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowStepsTableAnnotationComposer(
            $db: $db,
            $table: $db.workflowSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> workflowProjectRefsRefs<T extends Object>(
    Expression<T> Function($$WorkflowProjectRefsTableAnnotationComposer a) f,
  ) {
    final $$WorkflowProjectRefsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workflowProjectRefs,
          getReferencedColumn: (t) => t.workflowId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkflowProjectRefsTableAnnotationComposer(
                $db: $db,
                $table: $db.workflowProjectRefs,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> workflowRunsRefs<T extends Object>(
    Expression<T> Function($$WorkflowRunsTableAnnotationComposer a) f,
  ) {
    final $$WorkflowRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.workflowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkflowsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $WorkflowsTable,
          Workflow,
          $$WorkflowsTableFilterComposer,
          $$WorkflowsTableOrderingComposer,
          $$WorkflowsTableAnnotationComposer,
          $$WorkflowsTableCreateCompanionBuilder,
          $$WorkflowsTableUpdateCompanionBuilder,
          (Workflow, $$WorkflowsTableReferences),
          Workflow,
          PrefetchHooks Function({
            bool workflowStepsRefs,
            bool workflowProjectRefsRefs,
            bool workflowRunsRefs,
          })
        > {
  $$WorkflowsTableTableManager(_$MaestroDatabase db, $WorkflowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkflowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkflowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkflowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<bool> isReusable = const Value.absent(),
                Value<String> unitType = const Value.absent(),
                Value<bool> supervisedDelivery = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkflowsCompanion(
                id: id,
                revision: revision,
                name: name,
                isReusable: isReusable,
                unitType: unitType,
                supervisedDelivery: supervisedDelivery,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int revision,
                Value<String?> name = const Value.absent(),
                required bool isReusable,
                required String unitType,
                Value<bool> supervisedDelivery = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkflowsCompanion.insert(
                id: id,
                revision: revision,
                name: name,
                isReusable: isReusable,
                unitType: unitType,
                supervisedDelivery: supervisedDelivery,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkflowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                workflowStepsRefs = false,
                workflowProjectRefsRefs = false,
                workflowRunsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workflowStepsRefs) db.workflowSteps,
                    if (workflowProjectRefsRefs) db.workflowProjectRefs,
                    if (workflowRunsRefs) db.workflowRuns,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workflowStepsRefs)
                        await $_getPrefetchedData<
                          Workflow,
                          $WorkflowsTable,
                          WorkflowStep
                        >(
                          currentTable: table,
                          referencedTable: $$WorkflowsTableReferences
                              ._workflowStepsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkflowsTableReferences(
                                db,
                                table,
                                p0,
                              ).workflowStepsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workflowId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workflowProjectRefsRefs)
                        await $_getPrefetchedData<
                          Workflow,
                          $WorkflowsTable,
                          WorkflowProjectRef
                        >(
                          currentTable: table,
                          referencedTable: $$WorkflowsTableReferences
                              ._workflowProjectRefsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkflowsTableReferences(
                                db,
                                table,
                                p0,
                              ).workflowProjectRefsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workflowId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (workflowRunsRefs)
                        await $_getPrefetchedData<
                          Workflow,
                          $WorkflowsTable,
                          WorkflowRun
                        >(
                          currentTable: table,
                          referencedTable: $$WorkflowsTableReferences
                              ._workflowRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkflowsTableReferences(
                                db,
                                table,
                                p0,
                              ).workflowRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.workflowId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WorkflowsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $WorkflowsTable,
      Workflow,
      $$WorkflowsTableFilterComposer,
      $$WorkflowsTableOrderingComposer,
      $$WorkflowsTableAnnotationComposer,
      $$WorkflowsTableCreateCompanionBuilder,
      $$WorkflowsTableUpdateCompanionBuilder,
      (Workflow, $$WorkflowsTableReferences),
      Workflow,
      PrefetchHooks Function({
        bool workflowStepsRefs,
        bool workflowProjectRefsRefs,
        bool workflowRunsRefs,
      })
    >;
typedef $$WorkflowStepsTableCreateCompanionBuilder =
    WorkflowStepsCompanion Function({
      required String id,
      required String workflowId,
      required int position,
      required String kind,
      required String name,
      Value<String?> cli,
      Value<String?> model,
      Value<String> configuration,
      Value<int> rowid,
    });
typedef $$WorkflowStepsTableUpdateCompanionBuilder =
    WorkflowStepsCompanion Function({
      Value<String> id,
      Value<String> workflowId,
      Value<int> position,
      Value<String> kind,
      Value<String> name,
      Value<String?> cli,
      Value<String?> model,
      Value<String> configuration,
      Value<int> rowid,
    });

final class $$WorkflowStepsTableReferences
    extends
        BaseReferences<_$MaestroDatabase, $WorkflowStepsTable, WorkflowStep> {
  $$WorkflowStepsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkflowsTable _workflowIdTable(_$MaestroDatabase db) =>
      db.workflows.createAlias('workflow_steps__workflow_id__workflows__id');

  $$WorkflowsTableProcessedTableManager get workflowId {
    final $_column = $_itemColumn<String>('workflow_id')!;

    final manager = $$WorkflowsTableTableManager(
      $_db,
      $_db.workflows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workflowIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkflowStepsTableFilterComposer
    extends Composer<_$MaestroDatabase, $WorkflowStepsTable> {
  $$WorkflowStepsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cli => $composableBuilder(
    column: $table.cli,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkflowsTableFilterComposer get workflowId {
    final $$WorkflowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workflowId,
      referencedTable: $db.workflows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowsTableFilterComposer(
            $db: $db,
            $table: $db.workflows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkflowStepsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $WorkflowStepsTable> {
  $$WorkflowStepsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cli => $composableBuilder(
    column: $table.cli,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkflowsTableOrderingComposer get workflowId {
    final $$WorkflowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workflowId,
      referencedTable: $db.workflows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowsTableOrderingComposer(
            $db: $db,
            $table: $db.workflows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkflowStepsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $WorkflowStepsTable> {
  $$WorkflowStepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get cli =>
      $composableBuilder(column: $table.cli, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => column,
  );

  $$WorkflowsTableAnnotationComposer get workflowId {
    final $$WorkflowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workflowId,
      referencedTable: $db.workflows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowsTableAnnotationComposer(
            $db: $db,
            $table: $db.workflows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkflowStepsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $WorkflowStepsTable,
          WorkflowStep,
          $$WorkflowStepsTableFilterComposer,
          $$WorkflowStepsTableOrderingComposer,
          $$WorkflowStepsTableAnnotationComposer,
          $$WorkflowStepsTableCreateCompanionBuilder,
          $$WorkflowStepsTableUpdateCompanionBuilder,
          (WorkflowStep, $$WorkflowStepsTableReferences),
          WorkflowStep,
          PrefetchHooks Function({bool workflowId})
        > {
  $$WorkflowStepsTableTableManager(
    _$MaestroDatabase db,
    $WorkflowStepsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkflowStepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkflowStepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkflowStepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> workflowId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> cli = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String> configuration = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkflowStepsCompanion(
                id: id,
                workflowId: workflowId,
                position: position,
                kind: kind,
                name: name,
                cli: cli,
                model: model,
                configuration: configuration,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String workflowId,
                required int position,
                required String kind,
                required String name,
                Value<String?> cli = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String> configuration = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkflowStepsCompanion.insert(
                id: id,
                workflowId: workflowId,
                position: position,
                kind: kind,
                name: name,
                cli: cli,
                model: model,
                configuration: configuration,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkflowStepsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workflowId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (workflowId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.workflowId,
                                referencedTable: $$WorkflowStepsTableReferences
                                    ._workflowIdTable(db),
                                referencedColumn: $$WorkflowStepsTableReferences
                                    ._workflowIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WorkflowStepsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $WorkflowStepsTable,
      WorkflowStep,
      $$WorkflowStepsTableFilterComposer,
      $$WorkflowStepsTableOrderingComposer,
      $$WorkflowStepsTableAnnotationComposer,
      $$WorkflowStepsTableCreateCompanionBuilder,
      $$WorkflowStepsTableUpdateCompanionBuilder,
      (WorkflowStep, $$WorkflowStepsTableReferences),
      WorkflowStep,
      PrefetchHooks Function({bool workflowId})
    >;
typedef $$WorkflowProjectRefsTableCreateCompanionBuilder =
    WorkflowProjectRefsCompanion Function({
      required String workflowId,
      required String projectId,
      Value<int> rowid,
    });
typedef $$WorkflowProjectRefsTableUpdateCompanionBuilder =
    WorkflowProjectRefsCompanion Function({
      Value<String> workflowId,
      Value<String> projectId,
      Value<int> rowid,
    });

final class $$WorkflowProjectRefsTableReferences
    extends
        BaseReferences<
          _$MaestroDatabase,
          $WorkflowProjectRefsTable,
          WorkflowProjectRef
        > {
  $$WorkflowProjectRefsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkflowsTable _workflowIdTable(_$MaestroDatabase db) => db.workflows
      .createAlias('workflow_project_refs__workflow_id__workflows__id');

  $$WorkflowsTableProcessedTableManager get workflowId {
    final $_column = $_itemColumn<String>('workflow_id')!;

    final manager = $$WorkflowsTableTableManager(
      $_db,
      $_db.workflows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workflowIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectsTable _projectIdTable(_$MaestroDatabase db) => db.projects
      .createAlias('workflow_project_refs__project_id__projects__id');

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkflowProjectRefsTableFilterComposer
    extends Composer<_$MaestroDatabase, $WorkflowProjectRefsTable> {
  $$WorkflowProjectRefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$WorkflowsTableFilterComposer get workflowId {
    final $$WorkflowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workflowId,
      referencedTable: $db.workflows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowsTableFilterComposer(
            $db: $db,
            $table: $db.workflows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkflowProjectRefsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $WorkflowProjectRefsTable> {
  $$WorkflowProjectRefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$WorkflowsTableOrderingComposer get workflowId {
    final $$WorkflowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workflowId,
      referencedTable: $db.workflows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowsTableOrderingComposer(
            $db: $db,
            $table: $db.workflows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkflowProjectRefsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $WorkflowProjectRefsTable> {
  $$WorkflowProjectRefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$WorkflowsTableAnnotationComposer get workflowId {
    final $$WorkflowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workflowId,
      referencedTable: $db.workflows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowsTableAnnotationComposer(
            $db: $db,
            $table: $db.workflows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkflowProjectRefsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $WorkflowProjectRefsTable,
          WorkflowProjectRef,
          $$WorkflowProjectRefsTableFilterComposer,
          $$WorkflowProjectRefsTableOrderingComposer,
          $$WorkflowProjectRefsTableAnnotationComposer,
          $$WorkflowProjectRefsTableCreateCompanionBuilder,
          $$WorkflowProjectRefsTableUpdateCompanionBuilder,
          (WorkflowProjectRef, $$WorkflowProjectRefsTableReferences),
          WorkflowProjectRef,
          PrefetchHooks Function({bool workflowId, bool projectId})
        > {
  $$WorkflowProjectRefsTableTableManager(
    _$MaestroDatabase db,
    $WorkflowProjectRefsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkflowProjectRefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkflowProjectRefsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkflowProjectRefsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> workflowId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkflowProjectRefsCompanion(
                workflowId: workflowId,
                projectId: projectId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String workflowId,
                required String projectId,
                Value<int> rowid = const Value.absent(),
              }) => WorkflowProjectRefsCompanion.insert(
                workflowId: workflowId,
                projectId: projectId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkflowProjectRefsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workflowId = false, projectId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (workflowId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.workflowId,
                                referencedTable:
                                    $$WorkflowProjectRefsTableReferences
                                        ._workflowIdTable(db),
                                referencedColumn:
                                    $$WorkflowProjectRefsTableReferences
                                        ._workflowIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (projectId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.projectId,
                                referencedTable:
                                    $$WorkflowProjectRefsTableReferences
                                        ._projectIdTable(db),
                                referencedColumn:
                                    $$WorkflowProjectRefsTableReferences
                                        ._projectIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WorkflowProjectRefsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $WorkflowProjectRefsTable,
      WorkflowProjectRef,
      $$WorkflowProjectRefsTableFilterComposer,
      $$WorkflowProjectRefsTableOrderingComposer,
      $$WorkflowProjectRefsTableAnnotationComposer,
      $$WorkflowProjectRefsTableCreateCompanionBuilder,
      $$WorkflowProjectRefsTableUpdateCompanionBuilder,
      (WorkflowProjectRef, $$WorkflowProjectRefsTableReferences),
      WorkflowProjectRef,
      PrefetchHooks Function({bool workflowId, bool projectId})
    >;
typedef $$WorkflowRunsTableCreateCompanionBuilder =
    WorkflowRunsCompanion Function({
      required String id,
      Value<String?> projectId,
      Value<String?> workflowId,
      required String label,
      required String status,
      required int currentStepPosition,
      Value<String?> branchName,
      Value<String?> worktreePath,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$WorkflowRunsTableUpdateCompanionBuilder =
    WorkflowRunsCompanion Function({
      Value<String> id,
      Value<String?> projectId,
      Value<String?> workflowId,
      Value<String> label,
      Value<String> status,
      Value<int> currentStepPosition,
      Value<String?> branchName,
      Value<String?> worktreePath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$WorkflowRunsTableReferences
    extends BaseReferences<_$MaestroDatabase, $WorkflowRunsTable, WorkflowRun> {
  $$WorkflowRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProjectsTable _projectIdTable(_$MaestroDatabase db) =>
      db.projects.createAlias('workflow_runs__project_id__projects__id');

  $$ProjectsTableProcessedTableManager? get projectId {
    final $_column = $_itemColumn<String>('project_id');
    if ($_column == null) return null;
    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkflowsTable _workflowIdTable(_$MaestroDatabase db) =>
      db.workflows.createAlias('workflow_runs__workflow_id__workflows__id');

  $$WorkflowsTableProcessedTableManager? get workflowId {
    final $_column = $_itemColumn<String>('workflow_id');
    if ($_column == null) return null;
    final manager = $$WorkflowsTableTableManager(
      $_db,
      $_db.workflows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workflowIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RunSnapshotsTable, List<RunSnapshot>>
  _runSnapshotsRefsTable(_$MaestroDatabase db) => MultiTypedResultKey.fromTable(
    db.runSnapshots,
    aliasName: 'workflow_runs__id__run_snapshots__run_id',
  );

  $$RunSnapshotsTableProcessedTableManager get runSnapshotsRefs {
    final manager = $$RunSnapshotsTableTableManager(
      $_db,
      $_db.runSnapshots,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_runSnapshotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RunSnapshotStepsTable, List<RunSnapshotStep>>
  _runSnapshotStepsRefsTable(_$MaestroDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.runSnapshotSteps,
        aliasName: 'workflow_runs__id__run_snapshot_steps__run_id',
      );

  $$RunSnapshotStepsTableProcessedTableManager get runSnapshotStepsRefs {
    final manager = $$RunSnapshotStepsTableTableManager(
      $_db,
      $_db.runSnapshotSteps,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _runSnapshotStepsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RunAttemptsTable, List<RunAttempt>>
  _runAttemptsRefsTable(_$MaestroDatabase db) => MultiTypedResultKey.fromTable(
    db.runAttempts,
    aliasName: 'workflow_runs__id__run_attempts__run_id',
  );

  $$RunAttemptsTableProcessedTableManager get runAttemptsRefs {
    final manager = $$RunAttemptsTableTableManager(
      $_db,
      $_db.runAttempts,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_runAttemptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RunLogSegmentsTable, List<RunLogSegment>>
  _runLogSegmentsRefsTable(_$MaestroDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.runLogSegments,
        aliasName: 'workflow_runs__id__run_log_segments__run_id',
      );

  $$RunLogSegmentsTableProcessedTableManager get runLogSegmentsRefs {
    final manager = $$RunLogSegmentsTableTableManager(
      $_db,
      $_db.runLogSegments,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_runLogSegmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $RunRecoveryRequestsTable,
    List<RunRecoveryRequest>
  >
  _runRecoveryRequestsRefsTable(_$MaestroDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.runRecoveryRequests,
        aliasName: 'workflow_runs__id__run_recovery_requests__run_id',
      );

  $$RunRecoveryRequestsTableProcessedTableManager get runRecoveryRequestsRefs {
    final manager = $$RunRecoveryRequestsTableTableManager(
      $_db,
      $_db.runRecoveryRequests,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _runRecoveryRequestsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkflowRunsTableFilterComposer
    extends Composer<_$MaestroDatabase, $WorkflowRunsTable> {
  $$WorkflowRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentStepPosition => $composableBuilder(
    column: $table.currentStepPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkflowsTableFilterComposer get workflowId {
    final $$WorkflowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workflowId,
      referencedTable: $db.workflows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowsTableFilterComposer(
            $db: $db,
            $table: $db.workflows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> runSnapshotsRefs(
    Expression<bool> Function($$RunSnapshotsTableFilterComposer f) f,
  ) {
    final $$RunSnapshotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runSnapshots,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunSnapshotsTableFilterComposer(
            $db: $db,
            $table: $db.runSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> runSnapshotStepsRefs(
    Expression<bool> Function($$RunSnapshotStepsTableFilterComposer f) f,
  ) {
    final $$RunSnapshotStepsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runSnapshotSteps,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunSnapshotStepsTableFilterComposer(
            $db: $db,
            $table: $db.runSnapshotSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> runAttemptsRefs(
    Expression<bool> Function($$RunAttemptsTableFilterComposer f) f,
  ) {
    final $$RunAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runAttempts,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.runAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> runLogSegmentsRefs(
    Expression<bool> Function($$RunLogSegmentsTableFilterComposer f) f,
  ) {
    final $$RunLogSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runLogSegments,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunLogSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.runLogSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> runRecoveryRequestsRefs(
    Expression<bool> Function($$RunRecoveryRequestsTableFilterComposer f) f,
  ) {
    final $$RunRecoveryRequestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runRecoveryRequests,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunRecoveryRequestsTableFilterComposer(
            $db: $db,
            $table: $db.runRecoveryRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkflowRunsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $WorkflowRunsTable> {
  $$WorkflowRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentStepPosition => $composableBuilder(
    column: $table.currentStepPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkflowsTableOrderingComposer get workflowId {
    final $$WorkflowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workflowId,
      referencedTable: $db.workflows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowsTableOrderingComposer(
            $db: $db,
            $table: $db.workflows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkflowRunsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $WorkflowRunsTable> {
  $$WorkflowRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get currentStepPosition => $composableBuilder(
    column: $table.currentStepPosition,
    builder: (column) => column,
  );

  GeneratedColumn<String> get branchName => $composableBuilder(
    column: $table.branchName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkflowsTableAnnotationComposer get workflowId {
    final $$WorkflowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workflowId,
      referencedTable: $db.workflows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowsTableAnnotationComposer(
            $db: $db,
            $table: $db.workflows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> runSnapshotsRefs<T extends Object>(
    Expression<T> Function($$RunSnapshotsTableAnnotationComposer a) f,
  ) {
    final $$RunSnapshotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runSnapshots,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunSnapshotsTableAnnotationComposer(
            $db: $db,
            $table: $db.runSnapshots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> runSnapshotStepsRefs<T extends Object>(
    Expression<T> Function($$RunSnapshotStepsTableAnnotationComposer a) f,
  ) {
    final $$RunSnapshotStepsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runSnapshotSteps,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunSnapshotStepsTableAnnotationComposer(
            $db: $db,
            $table: $db.runSnapshotSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> runAttemptsRefs<T extends Object>(
    Expression<T> Function($$RunAttemptsTableAnnotationComposer a) f,
  ) {
    final $$RunAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runAttempts,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.runAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> runLogSegmentsRefs<T extends Object>(
    Expression<T> Function($$RunLogSegmentsTableAnnotationComposer a) f,
  ) {
    final $$RunLogSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runLogSegments,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunLogSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.runLogSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> runRecoveryRequestsRefs<T extends Object>(
    Expression<T> Function($$RunRecoveryRequestsTableAnnotationComposer a) f,
  ) {
    final $$RunRecoveryRequestsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.runRecoveryRequests,
          getReferencedColumn: (t) => t.runId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RunRecoveryRequestsTableAnnotationComposer(
                $db: $db,
                $table: $db.runRecoveryRequests,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkflowRunsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $WorkflowRunsTable,
          WorkflowRun,
          $$WorkflowRunsTableFilterComposer,
          $$WorkflowRunsTableOrderingComposer,
          $$WorkflowRunsTableAnnotationComposer,
          $$WorkflowRunsTableCreateCompanionBuilder,
          $$WorkflowRunsTableUpdateCompanionBuilder,
          (WorkflowRun, $$WorkflowRunsTableReferences),
          WorkflowRun,
          PrefetchHooks Function({
            bool projectId,
            bool workflowId,
            bool runSnapshotsRefs,
            bool runSnapshotStepsRefs,
            bool runAttemptsRefs,
            bool runLogSegmentsRefs,
            bool runRecoveryRequestsRefs,
          })
        > {
  $$WorkflowRunsTableTableManager(
    _$MaestroDatabase db,
    $WorkflowRunsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkflowRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkflowRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkflowRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> projectId = const Value.absent(),
                Value<String?> workflowId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> currentStepPosition = const Value.absent(),
                Value<String?> branchName = const Value.absent(),
                Value<String?> worktreePath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkflowRunsCompanion(
                id: id,
                projectId: projectId,
                workflowId: workflowId,
                label: label,
                status: status,
                currentStepPosition: currentStepPosition,
                branchName: branchName,
                worktreePath: worktreePath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                startedAt: startedAt,
                completedAt: completedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> projectId = const Value.absent(),
                Value<String?> workflowId = const Value.absent(),
                required String label,
                required String status,
                required int currentStepPosition,
                Value<String?> branchName = const Value.absent(),
                Value<String?> worktreePath = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkflowRunsCompanion.insert(
                id: id,
                projectId: projectId,
                workflowId: workflowId,
                label: label,
                status: status,
                currentStepPosition: currentStepPosition,
                branchName: branchName,
                worktreePath: worktreePath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                startedAt: startedAt,
                completedAt: completedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkflowRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectId = false,
                workflowId = false,
                runSnapshotsRefs = false,
                runSnapshotStepsRefs = false,
                runAttemptsRefs = false,
                runLogSegmentsRefs = false,
                runRecoveryRequestsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (runSnapshotsRefs) db.runSnapshots,
                    if (runSnapshotStepsRefs) db.runSnapshotSteps,
                    if (runAttemptsRefs) db.runAttempts,
                    if (runLogSegmentsRefs) db.runLogSegments,
                    if (runRecoveryRequestsRefs) db.runRecoveryRequests,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$WorkflowRunsTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$WorkflowRunsTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (workflowId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.workflowId,
                                    referencedTable:
                                        $$WorkflowRunsTableReferences
                                            ._workflowIdTable(db),
                                    referencedColumn:
                                        $$WorkflowRunsTableReferences
                                            ._workflowIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (runSnapshotsRefs)
                        await $_getPrefetchedData<
                          WorkflowRun,
                          $WorkflowRunsTable,
                          RunSnapshot
                        >(
                          currentTable: table,
                          referencedTable: $$WorkflowRunsTableReferences
                              ._runSnapshotsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkflowRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).runSnapshotsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.runId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (runSnapshotStepsRefs)
                        await $_getPrefetchedData<
                          WorkflowRun,
                          $WorkflowRunsTable,
                          RunSnapshotStep
                        >(
                          currentTable: table,
                          referencedTable: $$WorkflowRunsTableReferences
                              ._runSnapshotStepsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkflowRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).runSnapshotStepsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.runId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (runAttemptsRefs)
                        await $_getPrefetchedData<
                          WorkflowRun,
                          $WorkflowRunsTable,
                          RunAttempt
                        >(
                          currentTable: table,
                          referencedTable: $$WorkflowRunsTableReferences
                              ._runAttemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkflowRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).runAttemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.runId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (runLogSegmentsRefs)
                        await $_getPrefetchedData<
                          WorkflowRun,
                          $WorkflowRunsTable,
                          RunLogSegment
                        >(
                          currentTable: table,
                          referencedTable: $$WorkflowRunsTableReferences
                              ._runLogSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkflowRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).runLogSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.runId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (runRecoveryRequestsRefs)
                        await $_getPrefetchedData<
                          WorkflowRun,
                          $WorkflowRunsTable,
                          RunRecoveryRequest
                        >(
                          currentTable: table,
                          referencedTable: $$WorkflowRunsTableReferences
                              ._runRecoveryRequestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkflowRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).runRecoveryRequestsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.runId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WorkflowRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $WorkflowRunsTable,
      WorkflowRun,
      $$WorkflowRunsTableFilterComposer,
      $$WorkflowRunsTableOrderingComposer,
      $$WorkflowRunsTableAnnotationComposer,
      $$WorkflowRunsTableCreateCompanionBuilder,
      $$WorkflowRunsTableUpdateCompanionBuilder,
      (WorkflowRun, $$WorkflowRunsTableReferences),
      WorkflowRun,
      PrefetchHooks Function({
        bool projectId,
        bool workflowId,
        bool runSnapshotsRefs,
        bool runSnapshotStepsRefs,
        bool runAttemptsRefs,
        bool runLogSegmentsRefs,
        bool runRecoveryRequestsRefs,
      })
    >;
typedef $$RunSnapshotsTableCreateCompanionBuilder =
    RunSnapshotsCompanion Function({
      required String runId,
      required int schemaVersion,
      required String canonicalPayload,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$RunSnapshotsTableUpdateCompanionBuilder =
    RunSnapshotsCompanion Function({
      Value<String> runId,
      Value<int> schemaVersion,
      Value<String> canonicalPayload,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$RunSnapshotsTableReferences
    extends BaseReferences<_$MaestroDatabase, $RunSnapshotsTable, RunSnapshot> {
  $$RunSnapshotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkflowRunsTable _runIdTable(_$MaestroDatabase db) =>
      db.workflowRuns.createAlias('run_snapshots__run_id__workflow_runs__id');

  $$WorkflowRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$WorkflowRunsTableTableManager(
      $_db,
      $_db.workflowRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RunSnapshotsTableFilterComposer
    extends Composer<_$MaestroDatabase, $RunSnapshotsTable> {
  $$RunSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalPayload => $composableBuilder(
    column: $table.canonicalPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkflowRunsTableFilterComposer get runId {
    final $$WorkflowRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableFilterComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunSnapshotsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $RunSnapshotsTable> {
  $$RunSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalPayload => $composableBuilder(
    column: $table.canonicalPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkflowRunsTableOrderingComposer get runId {
    final $$WorkflowRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableOrderingComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunSnapshotsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $RunSnapshotsTable> {
  $$RunSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get canonicalPayload => $composableBuilder(
    column: $table.canonicalPayload,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$WorkflowRunsTableAnnotationComposer get runId {
    final $$WorkflowRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunSnapshotsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $RunSnapshotsTable,
          RunSnapshot,
          $$RunSnapshotsTableFilterComposer,
          $$RunSnapshotsTableOrderingComposer,
          $$RunSnapshotsTableAnnotationComposer,
          $$RunSnapshotsTableCreateCompanionBuilder,
          $$RunSnapshotsTableUpdateCompanionBuilder,
          (RunSnapshot, $$RunSnapshotsTableReferences),
          RunSnapshot,
          PrefetchHooks Function({bool runId})
        > {
  $$RunSnapshotsTableTableManager(
    _$MaestroDatabase db,
    $RunSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> runId = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> canonicalPayload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunSnapshotsCompanion(
                runId: runId,
                schemaVersion: schemaVersion,
                canonicalPayload: canonicalPayload,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String runId,
                required int schemaVersion,
                required String canonicalPayload,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RunSnapshotsCompanion.insert(
                runId: runId,
                schemaVersion: schemaVersion,
                canonicalPayload: canonicalPayload,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RunSnapshotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (runId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.runId,
                                referencedTable: $$RunSnapshotsTableReferences
                                    ._runIdTable(db),
                                referencedColumn: $$RunSnapshotsTableReferences
                                    ._runIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RunSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $RunSnapshotsTable,
      RunSnapshot,
      $$RunSnapshotsTableFilterComposer,
      $$RunSnapshotsTableOrderingComposer,
      $$RunSnapshotsTableAnnotationComposer,
      $$RunSnapshotsTableCreateCompanionBuilder,
      $$RunSnapshotsTableUpdateCompanionBuilder,
      (RunSnapshot, $$RunSnapshotsTableReferences),
      RunSnapshot,
      PrefetchHooks Function({bool runId})
    >;
typedef $$RunSnapshotStepsTableCreateCompanionBuilder =
    RunSnapshotStepsCompanion Function({
      required String id,
      required String runId,
      required String sourceWorkflowStepId,
      required int position,
      required String kind,
      required String name,
      Value<String?> cli,
      Value<String?> model,
      required String configuration,
      Value<int> rowid,
    });
typedef $$RunSnapshotStepsTableUpdateCompanionBuilder =
    RunSnapshotStepsCompanion Function({
      Value<String> id,
      Value<String> runId,
      Value<String> sourceWorkflowStepId,
      Value<int> position,
      Value<String> kind,
      Value<String> name,
      Value<String?> cli,
      Value<String?> model,
      Value<String> configuration,
      Value<int> rowid,
    });

final class $$RunSnapshotStepsTableReferences
    extends
        BaseReferences<
          _$MaestroDatabase,
          $RunSnapshotStepsTable,
          RunSnapshotStep
        > {
  $$RunSnapshotStepsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkflowRunsTable _runIdTable(_$MaestroDatabase db) => db.workflowRuns
      .createAlias('run_snapshot_steps__run_id__workflow_runs__id');

  $$WorkflowRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$WorkflowRunsTableTableManager(
      $_db,
      $_db.workflowRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RunAttemptsTable, List<RunAttempt>>
  _runAttemptsRefsTable(_$MaestroDatabase db) => MultiTypedResultKey.fromTable(
    db.runAttempts,
    aliasName: 'run_snapshot_steps__id__run_attempts__snapshot_step_id',
  );

  $$RunAttemptsTableProcessedTableManager get runAttemptsRefs {
    final manager = $$RunAttemptsTableTableManager(
      $_db,
      $_db.runAttempts,
    ).filter((f) => f.snapshotStepId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_runAttemptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RunLogSegmentsTable, List<RunLogSegment>>
  _runLogSegmentsRefsTable(_$MaestroDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.runLogSegments,
        aliasName: 'run_snapshot_steps__id__run_log_segments__snapshot_step_id',
      );

  $$RunLogSegmentsTableProcessedTableManager get runLogSegmentsRefs {
    final manager = $$RunLogSegmentsTableTableManager(
      $_db,
      $_db.runLogSegments,
    ).filter((f) => f.snapshotStepId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_runLogSegmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RunSnapshotStepsTableFilterComposer
    extends Composer<_$MaestroDatabase, $RunSnapshotStepsTable> {
  $$RunSnapshotStepsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceWorkflowStepId => $composableBuilder(
    column: $table.sourceWorkflowStepId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cli => $composableBuilder(
    column: $table.cli,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkflowRunsTableFilterComposer get runId {
    final $$WorkflowRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableFilterComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> runAttemptsRefs(
    Expression<bool> Function($$RunAttemptsTableFilterComposer f) f,
  ) {
    final $$RunAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runAttempts,
      getReferencedColumn: (t) => t.snapshotStepId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.runAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> runLogSegmentsRefs(
    Expression<bool> Function($$RunLogSegmentsTableFilterComposer f) f,
  ) {
    final $$RunLogSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runLogSegments,
      getReferencedColumn: (t) => t.snapshotStepId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunLogSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.runLogSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RunSnapshotStepsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $RunSnapshotStepsTable> {
  $$RunSnapshotStepsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceWorkflowStepId => $composableBuilder(
    column: $table.sourceWorkflowStepId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cli => $composableBuilder(
    column: $table.cli,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkflowRunsTableOrderingComposer get runId {
    final $$WorkflowRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableOrderingComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunSnapshotStepsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $RunSnapshotStepsTable> {
  $$RunSnapshotStepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceWorkflowStepId => $composableBuilder(
    column: $table.sourceWorkflowStepId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get cli =>
      $composableBuilder(column: $table.cli, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => column,
  );

  $$WorkflowRunsTableAnnotationComposer get runId {
    final $$WorkflowRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> runAttemptsRefs<T extends Object>(
    Expression<T> Function($$RunAttemptsTableAnnotationComposer a) f,
  ) {
    final $$RunAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runAttempts,
      getReferencedColumn: (t) => t.snapshotStepId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.runAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> runLogSegmentsRefs<T extends Object>(
    Expression<T> Function($$RunLogSegmentsTableAnnotationComposer a) f,
  ) {
    final $$RunLogSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runLogSegments,
      getReferencedColumn: (t) => t.snapshotStepId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunLogSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.runLogSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RunSnapshotStepsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $RunSnapshotStepsTable,
          RunSnapshotStep,
          $$RunSnapshotStepsTableFilterComposer,
          $$RunSnapshotStepsTableOrderingComposer,
          $$RunSnapshotStepsTableAnnotationComposer,
          $$RunSnapshotStepsTableCreateCompanionBuilder,
          $$RunSnapshotStepsTableUpdateCompanionBuilder,
          (RunSnapshotStep, $$RunSnapshotStepsTableReferences),
          RunSnapshotStep,
          PrefetchHooks Function({
            bool runId,
            bool runAttemptsRefs,
            bool runLogSegmentsRefs,
          })
        > {
  $$RunSnapshotStepsTableTableManager(
    _$MaestroDatabase db,
    $RunSnapshotStepsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunSnapshotStepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunSnapshotStepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunSnapshotStepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String> sourceWorkflowStepId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> cli = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String> configuration = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunSnapshotStepsCompanion(
                id: id,
                runId: runId,
                sourceWorkflowStepId: sourceWorkflowStepId,
                position: position,
                kind: kind,
                name: name,
                cli: cli,
                model: model,
                configuration: configuration,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                required String sourceWorkflowStepId,
                required int position,
                required String kind,
                required String name,
                Value<String?> cli = const Value.absent(),
                Value<String?> model = const Value.absent(),
                required String configuration,
                Value<int> rowid = const Value.absent(),
              }) => RunSnapshotStepsCompanion.insert(
                id: id,
                runId: runId,
                sourceWorkflowStepId: sourceWorkflowStepId,
                position: position,
                kind: kind,
                name: name,
                cli: cli,
                model: model,
                configuration: configuration,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RunSnapshotStepsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                runId = false,
                runAttemptsRefs = false,
                runLogSegmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (runAttemptsRefs) db.runAttempts,
                    if (runLogSegmentsRefs) db.runLogSegments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (runId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.runId,
                                    referencedTable:
                                        $$RunSnapshotStepsTableReferences
                                            ._runIdTable(db),
                                    referencedColumn:
                                        $$RunSnapshotStepsTableReferences
                                            ._runIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (runAttemptsRefs)
                        await $_getPrefetchedData<
                          RunSnapshotStep,
                          $RunSnapshotStepsTable,
                          RunAttempt
                        >(
                          currentTable: table,
                          referencedTable: $$RunSnapshotStepsTableReferences
                              ._runAttemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RunSnapshotStepsTableReferences(
                                db,
                                table,
                                p0,
                              ).runAttemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.snapshotStepId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (runLogSegmentsRefs)
                        await $_getPrefetchedData<
                          RunSnapshotStep,
                          $RunSnapshotStepsTable,
                          RunLogSegment
                        >(
                          currentTable: table,
                          referencedTable: $$RunSnapshotStepsTableReferences
                              ._runLogSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RunSnapshotStepsTableReferences(
                                db,
                                table,
                                p0,
                              ).runLogSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.snapshotStepId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RunSnapshotStepsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $RunSnapshotStepsTable,
      RunSnapshotStep,
      $$RunSnapshotStepsTableFilterComposer,
      $$RunSnapshotStepsTableOrderingComposer,
      $$RunSnapshotStepsTableAnnotationComposer,
      $$RunSnapshotStepsTableCreateCompanionBuilder,
      $$RunSnapshotStepsTableUpdateCompanionBuilder,
      (RunSnapshotStep, $$RunSnapshotStepsTableReferences),
      RunSnapshotStep,
      PrefetchHooks Function({
        bool runId,
        bool runAttemptsRefs,
        bool runLogSegmentsRefs,
      })
    >;
typedef $$RunAttemptsTableCreateCompanionBuilder =
    RunAttemptsCompanion Function({
      required String id,
      required String runId,
      required String snapshotStepId,
      required int attemptNumber,
      required String status,
      required DateTime startedAt,
      Value<DateTime?> completedAt,
      Value<int?> exitCode,
      Value<String?> failureCode,
      Value<String?> declaredContext,
      Value<int> rowid,
    });
typedef $$RunAttemptsTableUpdateCompanionBuilder =
    RunAttemptsCompanion Function({
      Value<String> id,
      Value<String> runId,
      Value<String> snapshotStepId,
      Value<int> attemptNumber,
      Value<String> status,
      Value<DateTime> startedAt,
      Value<DateTime?> completedAt,
      Value<int?> exitCode,
      Value<String?> failureCode,
      Value<String?> declaredContext,
      Value<int> rowid,
    });

final class $$RunAttemptsTableReferences
    extends BaseReferences<_$MaestroDatabase, $RunAttemptsTable, RunAttempt> {
  $$RunAttemptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkflowRunsTable _runIdTable(_$MaestroDatabase db) =>
      db.workflowRuns.createAlias('run_attempts__run_id__workflow_runs__id');

  $$WorkflowRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$WorkflowRunsTableTableManager(
      $_db,
      $_db.workflowRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RunSnapshotStepsTable _snapshotStepIdTable(_$MaestroDatabase db) => db
      .runSnapshotSteps
      .createAlias('run_attempts__snapshot_step_id__run_snapshot_steps__id');

  $$RunSnapshotStepsTableProcessedTableManager get snapshotStepId {
    final $_column = $_itemColumn<String>('snapshot_step_id')!;

    final manager = $$RunSnapshotStepsTableTableManager(
      $_db,
      $_db.runSnapshotSteps,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_snapshotStepIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RunLogSegmentsTable, List<RunLogSegment>>
  _runLogSegmentsRefsTable(_$MaestroDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.runLogSegments,
        aliasName: 'run_attempts__id__run_log_segments__attempt_id',
      );

  $$RunLogSegmentsTableProcessedTableManager get runLogSegmentsRefs {
    final manager = $$RunLogSegmentsTableTableManager(
      $_db,
      $_db.runLogSegments,
    ).filter((f) => f.attemptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_runLogSegmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $RunRecoveryRequestsTable,
    List<RunRecoveryRequest>
  >
  _runRecoveryRequestsRefsTable(_$MaestroDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.runRecoveryRequests,
        aliasName: 'run_attempts__id__run_recovery_requests__attempt_id',
      );

  $$RunRecoveryRequestsTableProcessedTableManager get runRecoveryRequestsRefs {
    final manager = $$RunRecoveryRequestsTableTableManager(
      $_db,
      $_db.runRecoveryRequests,
    ).filter((f) => f.attemptId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _runRecoveryRequestsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RunAttemptsTableFilterComposer
    extends Composer<_$MaestroDatabase, $RunAttemptsTable> {
  $$RunAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptNumber => $composableBuilder(
    column: $table.attemptNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get declaredContext => $composableBuilder(
    column: $table.declaredContext,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkflowRunsTableFilterComposer get runId {
    final $$WorkflowRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableFilterComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunSnapshotStepsTableFilterComposer get snapshotStepId {
    final $$RunSnapshotStepsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotStepId,
      referencedTable: $db.runSnapshotSteps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunSnapshotStepsTableFilterComposer(
            $db: $db,
            $table: $db.runSnapshotSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> runLogSegmentsRefs(
    Expression<bool> Function($$RunLogSegmentsTableFilterComposer f) f,
  ) {
    final $$RunLogSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runLogSegments,
      getReferencedColumn: (t) => t.attemptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunLogSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.runLogSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> runRecoveryRequestsRefs(
    Expression<bool> Function($$RunRecoveryRequestsTableFilterComposer f) f,
  ) {
    final $$RunRecoveryRequestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runRecoveryRequests,
      getReferencedColumn: (t) => t.attemptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunRecoveryRequestsTableFilterComposer(
            $db: $db,
            $table: $db.runRecoveryRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RunAttemptsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $RunAttemptsTable> {
  $$RunAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptNumber => $composableBuilder(
    column: $table.attemptNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get exitCode => $composableBuilder(
    column: $table.exitCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get declaredContext => $composableBuilder(
    column: $table.declaredContext,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkflowRunsTableOrderingComposer get runId {
    final $$WorkflowRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableOrderingComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunSnapshotStepsTableOrderingComposer get snapshotStepId {
    final $$RunSnapshotStepsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotStepId,
      referencedTable: $db.runSnapshotSteps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunSnapshotStepsTableOrderingComposer(
            $db: $db,
            $table: $db.runSnapshotSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunAttemptsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $RunAttemptsTable> {
  $$RunAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get attemptNumber => $composableBuilder(
    column: $table.attemptNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get exitCode =>
      $composableBuilder(column: $table.exitCode, builder: (column) => column);

  GeneratedColumn<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get declaredContext => $composableBuilder(
    column: $table.declaredContext,
    builder: (column) => column,
  );

  $$WorkflowRunsTableAnnotationComposer get runId {
    final $$WorkflowRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunSnapshotStepsTableAnnotationComposer get snapshotStepId {
    final $$RunSnapshotStepsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotStepId,
      referencedTable: $db.runSnapshotSteps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunSnapshotStepsTableAnnotationComposer(
            $db: $db,
            $table: $db.runSnapshotSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> runLogSegmentsRefs<T extends Object>(
    Expression<T> Function($$RunLogSegmentsTableAnnotationComposer a) f,
  ) {
    final $$RunLogSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runLogSegments,
      getReferencedColumn: (t) => t.attemptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunLogSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.runLogSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> runRecoveryRequestsRefs<T extends Object>(
    Expression<T> Function($$RunRecoveryRequestsTableAnnotationComposer a) f,
  ) {
    final $$RunRecoveryRequestsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.runRecoveryRequests,
          getReferencedColumn: (t) => t.attemptId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RunRecoveryRequestsTableAnnotationComposer(
                $db: $db,
                $table: $db.runRecoveryRequests,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$RunAttemptsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $RunAttemptsTable,
          RunAttempt,
          $$RunAttemptsTableFilterComposer,
          $$RunAttemptsTableOrderingComposer,
          $$RunAttemptsTableAnnotationComposer,
          $$RunAttemptsTableCreateCompanionBuilder,
          $$RunAttemptsTableUpdateCompanionBuilder,
          (RunAttempt, $$RunAttemptsTableReferences),
          RunAttempt,
          PrefetchHooks Function({
            bool runId,
            bool snapshotStepId,
            bool runLogSegmentsRefs,
            bool runRecoveryRequestsRefs,
          })
        > {
  $$RunAttemptsTableTableManager(_$MaestroDatabase db, $RunAttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunAttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String> snapshotStepId = const Value.absent(),
                Value<int> attemptNumber = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int?> exitCode = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<String?> declaredContext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunAttemptsCompanion(
                id: id,
                runId: runId,
                snapshotStepId: snapshotStepId,
                attemptNumber: attemptNumber,
                status: status,
                startedAt: startedAt,
                completedAt: completedAt,
                exitCode: exitCode,
                failureCode: failureCode,
                declaredContext: declaredContext,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                required String snapshotStepId,
                required int attemptNumber,
                required String status,
                required DateTime startedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int?> exitCode = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<String?> declaredContext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunAttemptsCompanion.insert(
                id: id,
                runId: runId,
                snapshotStepId: snapshotStepId,
                attemptNumber: attemptNumber,
                status: status,
                startedAt: startedAt,
                completedAt: completedAt,
                exitCode: exitCode,
                failureCode: failureCode,
                declaredContext: declaredContext,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RunAttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                runId = false,
                snapshotStepId = false,
                runLogSegmentsRefs = false,
                runRecoveryRequestsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (runLogSegmentsRefs) db.runLogSegments,
                    if (runRecoveryRequestsRefs) db.runRecoveryRequests,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (runId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.runId,
                                    referencedTable:
                                        $$RunAttemptsTableReferences
                                            ._runIdTable(db),
                                    referencedColumn:
                                        $$RunAttemptsTableReferences
                                            ._runIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (snapshotStepId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.snapshotStepId,
                                    referencedTable:
                                        $$RunAttemptsTableReferences
                                            ._snapshotStepIdTable(db),
                                    referencedColumn:
                                        $$RunAttemptsTableReferences
                                            ._snapshotStepIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (runLogSegmentsRefs)
                        await $_getPrefetchedData<
                          RunAttempt,
                          $RunAttemptsTable,
                          RunLogSegment
                        >(
                          currentTable: table,
                          referencedTable: $$RunAttemptsTableReferences
                              ._runLogSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RunAttemptsTableReferences(
                                db,
                                table,
                                p0,
                              ).runLogSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.attemptId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (runRecoveryRequestsRefs)
                        await $_getPrefetchedData<
                          RunAttempt,
                          $RunAttemptsTable,
                          RunRecoveryRequest
                        >(
                          currentTable: table,
                          referencedTable: $$RunAttemptsTableReferences
                              ._runRecoveryRequestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RunAttemptsTableReferences(
                                db,
                                table,
                                p0,
                              ).runRecoveryRequestsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.attemptId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RunAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $RunAttemptsTable,
      RunAttempt,
      $$RunAttemptsTableFilterComposer,
      $$RunAttemptsTableOrderingComposer,
      $$RunAttemptsTableAnnotationComposer,
      $$RunAttemptsTableCreateCompanionBuilder,
      $$RunAttemptsTableUpdateCompanionBuilder,
      (RunAttempt, $$RunAttemptsTableReferences),
      RunAttempt,
      PrefetchHooks Function({
        bool runId,
        bool snapshotStepId,
        bool runLogSegmentsRefs,
        bool runRecoveryRequestsRefs,
      })
    >;
typedef $$RunLogSegmentsTableCreateCompanionBuilder =
    RunLogSegmentsCompanion Function({
      required String id,
      required String runId,
      required String attemptId,
      required String snapshotStepId,
      required int sequence,
      required String channel,
      required Uint8List bytes,
      Value<String> compression,
      required int originalByteLength,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$RunLogSegmentsTableUpdateCompanionBuilder =
    RunLogSegmentsCompanion Function({
      Value<String> id,
      Value<String> runId,
      Value<String> attemptId,
      Value<String> snapshotStepId,
      Value<int> sequence,
      Value<String> channel,
      Value<Uint8List> bytes,
      Value<String> compression,
      Value<int> originalByteLength,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$RunLogSegmentsTableReferences
    extends
        BaseReferences<_$MaestroDatabase, $RunLogSegmentsTable, RunLogSegment> {
  $$RunLogSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkflowRunsTable _runIdTable(_$MaestroDatabase db) => db.workflowRuns
      .createAlias('run_log_segments__run_id__workflow_runs__id');

  $$WorkflowRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$WorkflowRunsTableTableManager(
      $_db,
      $_db.workflowRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RunAttemptsTable _attemptIdTable(_$MaestroDatabase db) => db
      .runAttempts
      .createAlias('run_log_segments__attempt_id__run_attempts__id');

  $$RunAttemptsTableProcessedTableManager get attemptId {
    final $_column = $_itemColumn<String>('attempt_id')!;

    final manager = $$RunAttemptsTableTableManager(
      $_db,
      $_db.runAttempts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attemptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RunSnapshotStepsTable _snapshotStepIdTable(_$MaestroDatabase db) =>
      db.runSnapshotSteps.createAlias(
        'run_log_segments__snapshot_step_id__run_snapshot_steps__id',
      );

  $$RunSnapshotStepsTableProcessedTableManager get snapshotStepId {
    final $_column = $_itemColumn<String>('snapshot_step_id')!;

    final manager = $$RunSnapshotStepsTableTableManager(
      $_db,
      $_db.runSnapshotSteps,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_snapshotStepIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RunLogSegmentsTableFilterComposer
    extends Composer<_$MaestroDatabase, $RunLogSegmentsTable> {
  $$RunLogSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compression => $composableBuilder(
    column: $table.compression,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get originalByteLength => $composableBuilder(
    column: $table.originalByteLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkflowRunsTableFilterComposer get runId {
    final $$WorkflowRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableFilterComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunAttemptsTableFilterComposer get attemptId {
    final $$RunAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.runAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.runAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunSnapshotStepsTableFilterComposer get snapshotStepId {
    final $$RunSnapshotStepsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotStepId,
      referencedTable: $db.runSnapshotSteps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunSnapshotStepsTableFilterComposer(
            $db: $db,
            $table: $db.runSnapshotSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunLogSegmentsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $RunLogSegmentsTable> {
  $$RunLogSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channel => $composableBuilder(
    column: $table.channel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compression => $composableBuilder(
    column: $table.compression,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get originalByteLength => $composableBuilder(
    column: $table.originalByteLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkflowRunsTableOrderingComposer get runId {
    final $$WorkflowRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableOrderingComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunAttemptsTableOrderingComposer get attemptId {
    final $$RunAttemptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.runAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunAttemptsTableOrderingComposer(
            $db: $db,
            $table: $db.runAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunSnapshotStepsTableOrderingComposer get snapshotStepId {
    final $$RunSnapshotStepsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotStepId,
      referencedTable: $db.runSnapshotSteps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunSnapshotStepsTableOrderingComposer(
            $db: $db,
            $table: $db.runSnapshotSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunLogSegmentsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $RunLogSegmentsTable> {
  $$RunLogSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get channel =>
      $composableBuilder(column: $table.channel, builder: (column) => column);

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get compression => $composableBuilder(
    column: $table.compression,
    builder: (column) => column,
  );

  GeneratedColumn<int> get originalByteLength => $composableBuilder(
    column: $table.originalByteLength,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$WorkflowRunsTableAnnotationComposer get runId {
    final $$WorkflowRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunAttemptsTableAnnotationComposer get attemptId {
    final $$RunAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.runAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.runAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunSnapshotStepsTableAnnotationComposer get snapshotStepId {
    final $$RunSnapshotStepsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.snapshotStepId,
      referencedTable: $db.runSnapshotSteps,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunSnapshotStepsTableAnnotationComposer(
            $db: $db,
            $table: $db.runSnapshotSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunLogSegmentsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $RunLogSegmentsTable,
          RunLogSegment,
          $$RunLogSegmentsTableFilterComposer,
          $$RunLogSegmentsTableOrderingComposer,
          $$RunLogSegmentsTableAnnotationComposer,
          $$RunLogSegmentsTableCreateCompanionBuilder,
          $$RunLogSegmentsTableUpdateCompanionBuilder,
          (RunLogSegment, $$RunLogSegmentsTableReferences),
          RunLogSegment,
          PrefetchHooks Function({
            bool runId,
            bool attemptId,
            bool snapshotStepId,
          })
        > {
  $$RunLogSegmentsTableTableManager(
    _$MaestroDatabase db,
    $RunLogSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunLogSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunLogSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunLogSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String> attemptId = const Value.absent(),
                Value<String> snapshotStepId = const Value.absent(),
                Value<int> sequence = const Value.absent(),
                Value<String> channel = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<String> compression = const Value.absent(),
                Value<int> originalByteLength = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunLogSegmentsCompanion(
                id: id,
                runId: runId,
                attemptId: attemptId,
                snapshotStepId: snapshotStepId,
                sequence: sequence,
                channel: channel,
                bytes: bytes,
                compression: compression,
                originalByteLength: originalByteLength,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                required String attemptId,
                required String snapshotStepId,
                required int sequence,
                required String channel,
                required Uint8List bytes,
                Value<String> compression = const Value.absent(),
                required int originalByteLength,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RunLogSegmentsCompanion.insert(
                id: id,
                runId: runId,
                attemptId: attemptId,
                snapshotStepId: snapshotStepId,
                sequence: sequence,
                channel: channel,
                bytes: bytes,
                compression: compression,
                originalByteLength: originalByteLength,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RunLogSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({runId = false, attemptId = false, snapshotStepId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (runId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.runId,
                                    referencedTable:
                                        $$RunLogSegmentsTableReferences
                                            ._runIdTable(db),
                                    referencedColumn:
                                        $$RunLogSegmentsTableReferences
                                            ._runIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (attemptId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.attemptId,
                                    referencedTable:
                                        $$RunLogSegmentsTableReferences
                                            ._attemptIdTable(db),
                                    referencedColumn:
                                        $$RunLogSegmentsTableReferences
                                            ._attemptIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (snapshotStepId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.snapshotStepId,
                                    referencedTable:
                                        $$RunLogSegmentsTableReferences
                                            ._snapshotStepIdTable(db),
                                    referencedColumn:
                                        $$RunLogSegmentsTableReferences
                                            ._snapshotStepIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$RunLogSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $RunLogSegmentsTable,
      RunLogSegment,
      $$RunLogSegmentsTableFilterComposer,
      $$RunLogSegmentsTableOrderingComposer,
      $$RunLogSegmentsTableAnnotationComposer,
      $$RunLogSegmentsTableCreateCompanionBuilder,
      $$RunLogSegmentsTableUpdateCompanionBuilder,
      (RunLogSegment, $$RunLogSegmentsTableReferences),
      RunLogSegment,
      PrefetchHooks Function({bool runId, bool attemptId, bool snapshotStepId})
    >;
typedef $$RunRecoveryRequestsTableCreateCompanionBuilder =
    RunRecoveryRequestsCompanion Function({
      required String id,
      required String runId,
      Value<String?> attemptId,
      required String action,
      required String status,
      required DateTime requestedAt,
      Value<int> rowid,
    });
typedef $$RunRecoveryRequestsTableUpdateCompanionBuilder =
    RunRecoveryRequestsCompanion Function({
      Value<String> id,
      Value<String> runId,
      Value<String?> attemptId,
      Value<String> action,
      Value<String> status,
      Value<DateTime> requestedAt,
      Value<int> rowid,
    });

final class $$RunRecoveryRequestsTableReferences
    extends
        BaseReferences<
          _$MaestroDatabase,
          $RunRecoveryRequestsTable,
          RunRecoveryRequest
        > {
  $$RunRecoveryRequestsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkflowRunsTable _runIdTable(_$MaestroDatabase db) => db.workflowRuns
      .createAlias('run_recovery_requests__run_id__workflow_runs__id');

  $$WorkflowRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$WorkflowRunsTableTableManager(
      $_db,
      $_db.workflowRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RunAttemptsTable _attemptIdTable(_$MaestroDatabase db) => db
      .runAttempts
      .createAlias('run_recovery_requests__attempt_id__run_attempts__id');

  $$RunAttemptsTableProcessedTableManager? get attemptId {
    final $_column = $_itemColumn<String>('attempt_id');
    if ($_column == null) return null;
    final manager = $$RunAttemptsTableTableManager(
      $_db,
      $_db.runAttempts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attemptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RunRecoveryRequestsTableFilterComposer
    extends Composer<_$MaestroDatabase, $RunRecoveryRequestsTable> {
  $$RunRecoveryRequestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkflowRunsTableFilterComposer get runId {
    final $$WorkflowRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableFilterComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunAttemptsTableFilterComposer get attemptId {
    final $$RunAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.runAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.runAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunRecoveryRequestsTableOrderingComposer
    extends Composer<_$MaestroDatabase, $RunRecoveryRequestsTable> {
  $$RunRecoveryRequestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkflowRunsTableOrderingComposer get runId {
    final $$WorkflowRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableOrderingComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunAttemptsTableOrderingComposer get attemptId {
    final $$RunAttemptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.runAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunAttemptsTableOrderingComposer(
            $db: $db,
            $table: $db.runAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunRecoveryRequestsTableAnnotationComposer
    extends Composer<_$MaestroDatabase, $RunRecoveryRequestsTable> {
  $$RunRecoveryRequestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get requestedAt => $composableBuilder(
    column: $table.requestedAt,
    builder: (column) => column,
  );

  $$WorkflowRunsTableAnnotationComposer get runId {
    final $$WorkflowRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.workflowRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkflowRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.workflowRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RunAttemptsTableAnnotationComposer get attemptId {
    final $$RunAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attemptId,
      referencedTable: $db.runAttempts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.runAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunRecoveryRequestsTableTableManager
    extends
        RootTableManager<
          _$MaestroDatabase,
          $RunRecoveryRequestsTable,
          RunRecoveryRequest,
          $$RunRecoveryRequestsTableFilterComposer,
          $$RunRecoveryRequestsTableOrderingComposer,
          $$RunRecoveryRequestsTableAnnotationComposer,
          $$RunRecoveryRequestsTableCreateCompanionBuilder,
          $$RunRecoveryRequestsTableUpdateCompanionBuilder,
          (RunRecoveryRequest, $$RunRecoveryRequestsTableReferences),
          RunRecoveryRequest,
          PrefetchHooks Function({bool runId, bool attemptId})
        > {
  $$RunRecoveryRequestsTableTableManager(
    _$MaestroDatabase db,
    $RunRecoveryRequestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunRecoveryRequestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunRecoveryRequestsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RunRecoveryRequestsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<String?> attemptId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> requestedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RunRecoveryRequestsCompanion(
                id: id,
                runId: runId,
                attemptId: attemptId,
                action: action,
                status: status,
                requestedAt: requestedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String runId,
                Value<String?> attemptId = const Value.absent(),
                required String action,
                required String status,
                required DateTime requestedAt,
                Value<int> rowid = const Value.absent(),
              }) => RunRecoveryRequestsCompanion.insert(
                id: id,
                runId: runId,
                attemptId: attemptId,
                action: action,
                status: status,
                requestedAt: requestedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RunRecoveryRequestsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false, attemptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (runId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.runId,
                                referencedTable:
                                    $$RunRecoveryRequestsTableReferences
                                        ._runIdTable(db),
                                referencedColumn:
                                    $$RunRecoveryRequestsTableReferences
                                        ._runIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (attemptId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.attemptId,
                                referencedTable:
                                    $$RunRecoveryRequestsTableReferences
                                        ._attemptIdTable(db),
                                referencedColumn:
                                    $$RunRecoveryRequestsTableReferences
                                        ._attemptIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RunRecoveryRequestsTableProcessedTableManager =
    ProcessedTableManager<
      _$MaestroDatabase,
      $RunRecoveryRequestsTable,
      RunRecoveryRequest,
      $$RunRecoveryRequestsTableFilterComposer,
      $$RunRecoveryRequestsTableOrderingComposer,
      $$RunRecoveryRequestsTableAnnotationComposer,
      $$RunRecoveryRequestsTableCreateCompanionBuilder,
      $$RunRecoveryRequestsTableUpdateCompanionBuilder,
      (RunRecoveryRequest, $$RunRecoveryRequestsTableReferences),
      RunRecoveryRequest,
      PrefetchHooks Function({bool runId, bool attemptId})
    >;

class $MaestroDatabaseManager {
  final _$MaestroDatabase _db;
  $MaestroDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$DiagnosticLogSegmentsTableTableManager get diagnosticLogSegments =>
      $$DiagnosticLogSegmentsTableTableManager(_db, _db.diagnosticLogSegments);
  $$OwnedResourcesTableTableManager get ownedResources =>
      $$OwnedResourcesTableTableManager(_db, _db.ownedResources);
  $$LocalUsersTableTableManager get localUsers =>
      $$LocalUsersTableTableManager(_db, _db.localUsers);
  $$AuditEventsTableTableManager get auditEvents =>
      $$AuditEventsTableTableManager(_db, _db.auditEvents);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$WorkflowsTableTableManager get workflows =>
      $$WorkflowsTableTableManager(_db, _db.workflows);
  $$WorkflowStepsTableTableManager get workflowSteps =>
      $$WorkflowStepsTableTableManager(_db, _db.workflowSteps);
  $$WorkflowProjectRefsTableTableManager get workflowProjectRefs =>
      $$WorkflowProjectRefsTableTableManager(_db, _db.workflowProjectRefs);
  $$WorkflowRunsTableTableManager get workflowRuns =>
      $$WorkflowRunsTableTableManager(_db, _db.workflowRuns);
  $$RunSnapshotsTableTableManager get runSnapshots =>
      $$RunSnapshotsTableTableManager(_db, _db.runSnapshots);
  $$RunSnapshotStepsTableTableManager get runSnapshotSteps =>
      $$RunSnapshotStepsTableTableManager(_db, _db.runSnapshotSteps);
  $$RunAttemptsTableTableManager get runAttempts =>
      $$RunAttemptsTableTableManager(_db, _db.runAttempts);
  $$RunLogSegmentsTableTableManager get runLogSegments =>
      $$RunLogSegmentsTableTableManager(_db, _db.runLogSegments);
  $$RunRecoveryRequestsTableTableManager get runRecoveryRequests =>
      $$RunRecoveryRequestsTableTableManager(_db, _db.runRecoveryRequests);
}
