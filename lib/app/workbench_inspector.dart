import 'package:flutter/material.dart';
import 'package:maestro/app/workbench_inspector_model.dart';

final class WorkbenchInspectorScope extends InheritedWidget {
  const WorkbenchInspectorScope({
    required this.onInspectorChanged,
    required super.child,
    super.key,
  });

  final ValueChanged<WorkbenchInspectorSnapshot> onInspectorChanged;

  static ValueChanged<WorkbenchInspectorSnapshot>? maybeOf(
    BuildContext context,
  ) => context
      .dependOnInheritedWidgetOfExactType<WorkbenchInspectorScope>()
      ?.onInspectorChanged;

  @override
  bool updateShouldNotify(WorkbenchInspectorScope oldWidget) =>
      oldWidget.onInspectorChanged != onInspectorChanged;
}

final class WorkbenchInspector extends StatelessWidget {
  const WorkbenchInspector({required this.snapshot, super.key});

  final WorkbenchInspectorSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(snapshot.title, style: theme.textTheme.titleSmall),
          if (snapshot.emptyMessage case final message?) ...<Widget>[
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodySmall),
          ],
          for (final section in snapshot.sections) ...<Widget>[
            const SizedBox(height: 16),
            Text(section.label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final field in section.fields) _InspectorField(field: field),
          ],
        ],
      ),
    );
  }
}

final class _InspectorField extends StatelessWidget {
  const _InspectorField({required this.field});

  final WorkbenchInspectorField field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueColor = switch (field.status) {
      WorkbenchInspectorStatus.neutral => theme.colorScheme.onSurface,
      WorkbenchInspectorStatus.success => theme.colorScheme.primary,
      WorkbenchInspectorStatus.warning => theme.colorScheme.tertiary,
      WorkbenchInspectorStatus.error => theme.colorScheme.error,
    };
    return Semantics(
      container: true,
      label: '${field.label}: ${field.value}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  field.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  field.value,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: valueColor,
                    fontWeight: field.status == WorkbenchInspectorStatus.neutral
                        ? null
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
