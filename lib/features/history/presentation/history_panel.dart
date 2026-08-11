import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:maestro/features/history/presentation/history_controller.dart';

final class HistoryPanel extends StatefulWidget {
  const HistoryPanel({required this.createController, super.key});
  final HistoryController Function() createController;
  @override
  State<HistoryPanel> createState() => _HistoryPanelState();
}

final class _HistoryPanelState extends State<HistoryPanel> {
  late final HistoryController controller = widget.createController()
    ..addListener(_changed);
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
    super.dispose();
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
