import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:maestro/app/maestro_form_spacing.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/features/history/data/retention_service.dart';
import 'package:maestro/features/history/presentation/history_controller.dart';
import 'package:maestro/features/history/presentation/storage_limit_mb.dart';

final class HistoryPanel extends StatefulWidget {
  const HistoryPanel({
    required this.createController,
    this.retentionService,
    this.actorId,
    super.key,
  });
  final HistoryController Function() createController;
  final RetentionService? retentionService;
  final String? actorId;
  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

final class _HistoryPanelState extends State<HistoryPanel> {
  late final HistoryController controller = widget.createController()
    ..addListener(_changed);
  final _retentionDays = TextEditingController(
    text: '${RetentionPolicy.defaults.retentionDays}',
  );
  final _storageLimit = TextEditingController(
    text: StorageLimitMb.formatBytes(
      RetentionPolicy.defaults.storageLimitBytes,
    ),
  );
  String? _retentionFeedback;
  bool _applyingRetention = false;

  @override
  void initState() {
    super.initState();
    controller.load();
    unawaited(_hydrateRetentionPolicy());
  }

  /// Shows the policy actually in force, and applies it once per panel.
  ///
  /// Seeding the fields with constants would hide a saved policy and let a
  /// careless re-save revert it, and a policy nothing ever applies is a stored
  /// preference rather than a retention control (UC-13).
  Future<void> _hydrateRetentionPolicy() async {
    final service = widget.retentionService;
    final actorId = widget.actorId;
    if (service == null || actorId == null) return;
    final RetentionPolicy policy;
    try {
      policy = await service.loadPolicy();
    } on Object {
      return;
    }
    if (!mounted) return;
    setState(() {
      _retentionDays.text = '${policy.retentionDays}';
      _storageLimit.text = StorageLimitMb.formatBytes(policy.storageLimitBytes);
    });
    await _applyRetentionPolicy(service, actorId, policy, announce: false);
  }

  /// Applies the policy, reporting only what the user needs to read.
  ///
  /// The pass that runs when the panel opens stays silent unless it actually
  /// removed something: announcing "already within settings" on every open
  /// would be noise the user has to read past to reach the history itself.
  Future<void> _applyRetentionPolicy(
    RetentionService service,
    String actorId,
    RetentionPolicy policy, {
    required bool announce,
  }) async {
    if (_applyingRetention) return;
    _applyingRetention = true;
    try {
      final result = await service.applyPolicy(
        actorId: actorId,
        policy: policy,
      );
      if (!mounted) return;
      final removedSomething =
          result.compaction.compactedSegmentIds.isNotEmpty ||
          result.prune.prunedRunIds.isNotEmpty;
      if (!announce && !removedSomething) return;
      setState(() => _retentionFeedback = result.summary);
    } on Object {
      if (!mounted) return;
      setState(
        () => _retentionFeedback =
            'Retention settings are saved, but applying them did not finish. '
            'Try again.',
      );
    } finally {
      _applyingRetention = false;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    _retentionDays.dispose();
    _storageLimit.dispose();
    super.dispose();
  }

  Future<void> _saveRetentionPolicy() async {
    final service = widget.retentionService;
    final actorId = widget.actorId;
    if (service == null || actorId == null) return;
    final storageLimit = StorageLimitMb.parse(_storageLimit.text);
    if (storageLimit case StorageLimitMbInvalid(:final error)) {
      setState(() => _retentionFeedback = error);
      return;
    }
    final policy = RetentionPolicy(
      retentionDays: int.tryParse(_retentionDays.text) ?? 0,
      storageLimitBytes: storageLimit.bytes!,
    );
    final result = await service.savePolicy(actorId: actorId, policy: policy);
    if (!mounted) return;
    setState(() {
      _retentionFeedback = switch (result) {
        RetentionSucceeded() => 'Retention settings saved.',
        RetentionRejected(:final message) => message,
      };
    });
    // Saving a policy that nothing enforces would leave the user believing
    // history is bounded when it is not, so the new policy is applied now.
    if (result is RetentionSucceeded) {
      await _applyRetentionPolicy(service, actorId, policy, announce: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final theme = Theme.of(context);
    final tokens = theme.extension<MaestroThemeTokens>();
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Material(
          key: const Key('history-section'),
          color: tokens?.workspaceSurface ?? theme.colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: tokens?.toolbarHeight ?? 36,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'History and audit',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: tokens?.subtleBorder),
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.retentionService != null &&
                          widget.actorId != null) ...[
                        Text(
                          'Retention settings',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(
                          height: MaestroFormSpacing.sectionToControl,
                        ),
                        TextField(
                          key: const Key('retention-days'),
                          controller: _retentionDays,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Retention age (days)',
                          ),
                        ),
                        const SizedBox(height: MaestroFormSpacing.fieldToField),
                        TextField(
                          key: const Key('retention-storage-limit'),
                          controller: _storageLimit,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Storage limit (MB)',
                          ),
                        ),
                        const SizedBox(
                          height: MaestroFormSpacing.controlToAction,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _saveRetentionPolicy,
                            child: const Text('Save and apply retention'),
                          ),
                        ),
                        if (_retentionFeedback case final feedback?)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: MaestroFormSpacing.feedback,
                            ),
                            child: Text(feedback),
                          ),
                        const SizedBox(
                          height: MaestroFormSpacing.sectionToControl,
                        ),
                      ],
                      TextField(
                        onChanged: controller.search,
                        decoration: const InputDecoration(
                          labelText: 'Search history',
                        ),
                      ),
                      if (state.loading) const LinearProgressIndicator(),
                      if (state.failure case final failure?) Text(failure),
                      if (!state.loading && state.visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('No history matches your filters.'),
                        ),
                      if (state.diagnostics.isNotEmpty) ...<Widget>[
                        const SizedBox(
                          height: MaestroFormSpacing.sectionToControl,
                        ),
                        Text(
                          'Diagnostics',
                          key: const Key('diagnostics-section'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final entry in state.diagnostics.take(50))
                          SelectableText(
                            '${entry.recordedAt.toIso8601String()}  '
                            '${entry.text}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                      for (final entry in state.visible)
                        Column(
                          children: <Widget>[
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              title: Text(entry.label),
                              subtitle: Text(entry.status.name),
                              trailing: Text(entry.runId),
                              selected: entry.runId == state.selected,
                              onTap: () => controller.select(entry.runId),
                            ),
                            Divider(height: 1, color: tokens?.subtleBorder),
                          ],
                        ),
                      if (state.loadingDetail) const LinearProgressIndicator(),
                      if (state.detail case final detail?) ...[
                        const Divider(),
                        Text(
                          'Immutable run evidence',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SelectableText(detail.snapshotJson),
                        Text('Attempts: ${detail.attempts.length}'),
                        for (final attempt in detail.attempts)
                          Text('${attempt.status} · ${attempt.id}'),
                        Text('Audit events: ${detail.auditEvents.length}'),
                        for (final audit in detail.auditEvents)
                          Text('${audit.action} · ${audit.outcome}'),
                        Text('Log segments: ${detail.logSegments.length}'),
                        for (final log in detail.logSegments)
                          SelectableText(_displayLog(log.bytes)),
                      ],
                    ],
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

/// Renders one stored log segment.
///
/// The repository already expanded any compaction, so this only has to survive
/// bytes that are not valid UTF-8 — an agent may emit anything.
String _displayLog(List<int> bytes) => utf8.decode(bytes, allowMalformed: true);
