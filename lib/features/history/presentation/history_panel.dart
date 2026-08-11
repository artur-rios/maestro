import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:maestro/features/history/data/retention_service.dart';
import 'package:maestro/features/history/presentation/history_controller.dart';

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
  final _retentionDays = TextEditingController(text: '30');
  final _storageLimit = TextEditingController(text: '1073741824');
  String? _retentionFeedback;
  @override
  void initState() {
    super.initState();
    controller.load();
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
    final result = await service.savePolicy(
      actorId: actorId,
      policy: RetentionPolicy(
        retentionDays: int.tryParse(_retentionDays.text) ?? 0,
        storageLimitBytes: int.tryParse(_storageLimit.text) ?? 0,
      ),
    );
    if (!mounted) return;
    setState(() {
      _retentionFeedback = switch (result) {
        RetentionSucceeded() => 'Retention settings saved.',
        RetentionRejected(:final message) => message,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'History and audit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.retentionService != null && widget.actorId != null) ...[
              const SizedBox(height: 12),
              Text(
                'Retention settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextField(
                key: const Key('retention-days'),
                controller: _retentionDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Retention age (days)',
                ),
              ),
              TextField(
                key: const Key('retention-storage-limit'),
                controller: _storageLimit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Storage limit (bytes)',
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _saveRetentionPolicy,
                  child: const Text('Save retention settings'),
                ),
              ),
              if (_retentionFeedback case final feedback?) Text(feedback),
            ],
            TextField(
              onChanged: controller.search,
              decoration: const InputDecoration(labelText: 'Search history'),
            ),
            if (state.loading) const LinearProgressIndicator(),
            if (state.failure case final failure?) Text(failure),
            if (!state.loading && state.visible.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('No history matches your filters.'),
              ),
            for (final entry in state.visible)
              ListTile(
                title: Text(entry.label),
                subtitle: Text(entry.status.name),
                trailing: Text(entry.runId),
                selected: entry.runId == state.selected,
                onTap: () => controller.select(entry.runId),
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
                SelectableText(
                  _displayLog(log.bytes, log.compression) ??
                      'Log segment ${log.id} is corrupt or cannot be expanded.',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _displayLog(List<int> bytes, String compression) {
  try {
    final decoded = compression == 'none' ? bytes : gzip.decode(bytes);
    return utf8.decode(decoded, allowMalformed: true);
  } on Object {
    return null;
  }
}
