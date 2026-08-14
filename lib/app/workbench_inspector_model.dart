enum WorkbenchInspectorStatus { neutral, success, warning, error }

final class WorkbenchInspectorField {
  const WorkbenchInspectorField({
    required this.label,
    required this.value,
    this.status = WorkbenchInspectorStatus.neutral,
  });

  final String label;
  final String value;
  final WorkbenchInspectorStatus status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkbenchInspectorField &&
          other.label == label &&
          other.value == value &&
          other.status == status;

  @override
  int get hashCode => Object.hash(label, value, status);
}

final class WorkbenchInspectorSection {
  WorkbenchInspectorSection({
    required this.label,
    required Iterable<WorkbenchInspectorField> fields,
  }) : fields = List<WorkbenchInspectorField>.unmodifiable(fields);

  final String label;
  final List<WorkbenchInspectorField> fields;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkbenchInspectorSection &&
          other.label == label &&
          _listEquals(other.fields, fields);

  @override
  int get hashCode => Object.hash(label, Object.hashAll(fields));
}

final class WorkbenchInspectorSnapshot {
  WorkbenchInspectorSnapshot({
    required this.title,
    required Iterable<WorkbenchInspectorSection> sections,
    required this.emptyMessage,
  }) : sections = List<WorkbenchInspectorSection>.unmodifiable(sections);

  final String title;
  final List<WorkbenchInspectorSection> sections;
  final String? emptyMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkbenchInspectorSnapshot &&
          other.title == title &&
          other.emptyMessage == emptyMessage &&
          _listEquals(other.sections, sections);

  @override
  int get hashCode =>
      Object.hash(title, Object.hashAll(sections), emptyMessage);
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}
