import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/app/workbench_inspector.dart';
import 'package:maestro/app/workbench_inspector_model.dart';
import 'package:maestro/features/foundation/domain/foundation_status.dart';
import 'package:maestro/features/foundation/presentation/foundation_controller.dart';

final class FoundationPage extends ConsumerWidget {
  const FoundationPage({this.onInspectorChanged, super.key});

  final ValueChanged<WorkbenchInspectorSnapshot>? onInspectorChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(foundationControllerProvider);
    return state.when(
      data: (report) => FoundationReportView(
        report: report,
        onInspectorChanged: onInspectorChanged,
      ),
      error: (error, _) => FoundationReportView(
        report: FoundationReport(<FoundationCheck>[
          FoundationCheck(
            id: 'bootstrap',
            health: FoundationHealth.blocked,
            message: 'Foundation initialization failed: $error',
            remediation: 'Restart Maestro and inspect the diagnostic log.',
          ),
        ]),
        onInspectorChanged: onInspectorChanged,
      ),
      loading: () => Material(
        key: const Key('foundation-section'),
        color:
            Theme.of(
              context,
            ).extension<MaestroThemeTokens>()?.workspaceSurface ??
            Theme.of(context).colorScheme.surface,
        child: Semantics(
          label: 'Foundation status',
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

final class FoundationReportView extends StatefulWidget {
  const FoundationReportView({
    required this.report,
    this.onInspectorChanged,
    super.key,
  });

  final FoundationReport report;
  final ValueChanged<WorkbenchInspectorSnapshot>? onInspectorChanged;

  @override
  State<FoundationReportView> createState() => _FoundationReportViewState();
}

final class _FoundationReportViewState extends State<FoundationReportView> {
  WorkbenchInspectorSnapshot? _lastInspectorSnapshot;
  WorkbenchInspectorSnapshot? _scheduledInspectorSnapshot;
  ValueChanged<WorkbenchInspectorSnapshot>? _lastInspectorPublisher;
  ValueChanged<WorkbenchInspectorSnapshot>? _scheduledInspectorPublisher;

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final health = report.health.name;
    _scheduleInspector(
      _foundationInspectorSnapshot(report),
      widget.onInspectorChanged ?? WorkbenchInspectorScope.maybeOf(context),
    );
    final theme = Theme.of(context);
    final tokens = theme.extension<MaestroThemeTokens>();
    return Material(
      key: const Key('foundation-section'),
      color: tokens?.workspaceSurface ?? theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: tokens?.toolbarHeight ?? 36,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Maestro', style: theme.textTheme.titleSmall),
              ),
            ),
          ),
          Divider(height: 1, color: tokens?.subtleBorder),
          Expanded(
            child: Semantics(
              label: 'Foundation $health',
              child: report.checks.isEmpty
                  ? const Center(child: Text('Foundation ready'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: <Widget>[
                        Text(
                          'System diagnostics: $health',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        for (final check in report.checks) ...<Widget>[
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            title: Text(check.message),
                            subtitle: check.remediation == null
                                ? null
                                : Text(check.remediation!),
                          ),
                          Divider(height: 1, color: tokens?.subtleBorder),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleInspector(
    WorkbenchInspectorSnapshot snapshot,
    ValueChanged<WorkbenchInspectorSnapshot>? publisher,
  ) {
    if (publisher == null ||
        (snapshot == _lastInspectorSnapshot &&
            publisher == _lastInspectorPublisher) ||
        (snapshot == _scheduledInspectorSnapshot &&
            publisher == _scheduledInspectorPublisher)) {
      return;
    }
    _scheduledInspectorSnapshot = snapshot;
    _scheduledInspectorPublisher = publisher;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _scheduledInspectorSnapshot != snapshot ||
          _scheduledInspectorPublisher != publisher) {
        return;
      }
      _scheduledInspectorSnapshot = null;
      _scheduledInspectorPublisher = null;
      if (snapshot == _lastInspectorSnapshot &&
          publisher == _lastInspectorPublisher) {
        return;
      }
      _lastInspectorSnapshot = snapshot;
      _lastInspectorPublisher = publisher;
      publisher(snapshot);
    });
  }
}

WorkbenchInspectorSnapshot _foundationInspectorSnapshot(
  FoundationReport report,
) => WorkbenchInspectorSnapshot(
  title: 'Health details',
  emptyMessage:
      !report.checks.any((check) => check.health != FoundationHealth.ready)
      ? 'No degraded or failed foundation probes.'
      : null,
  sections: <WorkbenchInspectorSection>[
    WorkbenchInspectorSection(
      label: 'Foundation',
      fields: <WorkbenchInspectorField>[
        WorkbenchInspectorField(
          label: 'Status',
          value: _healthLabel(report.health),
          status: switch (report.health) {
            FoundationHealth.ready => WorkbenchInspectorStatus.success,
            FoundationHealth.degraded => WorkbenchInspectorStatus.warning,
            FoundationHealth.blocked => WorkbenchInspectorStatus.error,
          },
        ),
      ],
    ),
    for (final check in report.checks)
      if (check.health != FoundationHealth.ready)
        WorkbenchInspectorSection(
          label: check.id,
          fields: <WorkbenchInspectorField>[
            WorkbenchInspectorField(label: 'Probe', value: check.message),
            if (check.remediation case final remediation?)
              WorkbenchInspectorField(label: 'Remediation', value: remediation),
          ],
        ),
  ],
);

String _healthLabel(FoundationHealth health) => switch (health) {
  FoundationHealth.ready => 'Ready',
  FoundationHealth.degraded => 'Degraded',
  FoundationHealth.blocked => 'Blocked',
};
