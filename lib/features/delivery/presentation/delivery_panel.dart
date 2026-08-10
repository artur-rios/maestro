import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maestro/features/delivery/domain/delivery_record.dart';
import 'package:maestro/features/delivery/presentation/delivery_controller.dart';

final class DeliveryPanel extends StatefulWidget {
  const DeliveryPanel({
    required this.runId,
    required this.createController,
    super.key,
  });
  final String runId;
  final DeliveryController Function() createController;
  @override
  State<DeliveryPanel> createState() => _DeliveryPanelState();
}

final class _DeliveryPanelState extends State<DeliveryPanel> {
  late final DeliveryController _controller;
  @override
  void initState() {
    super.initState();
    _controller = widget.createController()..addListener(_changed);
    _controller.load(widget.runId);
  }

  @override
  void didUpdateWidget(DeliveryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runId != widget.runId) {
      unawaited(_controller.load(widget.runId));
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final record = state.record;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Delivery', style: Theme.of(context).textTheme.titleMedium),
        Semantics(
          liveRegion: true,
          child: Text(
            key: const Key('delivery-status'),
            state.loading ? 'Loading delivery evidence' : _status(record),
          ),
        ),
        if (record?.pullRequestUrl case final url?)
          SelectableText(url, key: const Key('delivery-pr-url')),
        if (record?.reviewOutcome case final review?)
          Text(
            key: const Key('delivery-review'),
            'Review: ${record?.reviewerIdentity ?? 'Unavailable'} · ${review.name}',
          ),
        if (record?.mergeCommit case final commit?)
          Text(
            key: const Key('delivery-merge-commit'),
            'Merge commit: $commit',
          ),
        if (_guidance(record, state.failure) case final guidance?)
          Text(key: const Key('delivery-guidance'), guidance),
      ],
    );
  }
}

String _status(DeliveryRecord? record) {
  if (record == null) {
    return 'No autonomous delivery evidence yet.';
  }
  if (record.completedAt != null) {
    return 'Autonomous delivery completed.';
  }
  if (record.reviewOutcome == DeliveryReviewOutcome.requestedChanges) {
    return 'Review requested changes; returned to execution.';
  }
  return 'Autonomous delivery needs attention.';
}

String? _guidance(DeliveryRecord? record, DeliveryFailure? failure) =>
    failure?.remediation ??
    record?.remediation ??
    (record != null && record.findings.isNotEmpty
        ? record.findings.join('\n')
        : null);
