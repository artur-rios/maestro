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

abstract class _$MaestroDatabase extends GeneratedDatabase {
  _$MaestroDatabase(QueryExecutor e) : super(e);
  $MaestroDatabaseManager get managers => $MaestroDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $DiagnosticLogSegmentsTable diagnosticLogSegments =
      $DiagnosticLogSegmentsTable(this);
  late final $OwnedResourcesTable ownedResources = $OwnedResourcesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    diagnosticLogSegments,
    ownedResources,
  ];
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

class $MaestroDatabaseManager {
  final _$MaestroDatabase _db;
  $MaestroDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$DiagnosticLogSegmentsTableTableManager get diagnosticLogSegments =>
      $$DiagnosticLogSegmentsTableTableManager(_db, _db.diagnosticLogSegments);
  $$OwnedResourcesTableTableManager get ownedResources =>
      $$OwnedResourcesTableTableManager(_db, _db.ownedResources);
}
