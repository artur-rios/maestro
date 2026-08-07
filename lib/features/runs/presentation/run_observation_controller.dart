import 'dart:async';

// Public constructor names describe injected ports; stored fields stay private.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:maestro/features/runs/application/observe_runs.dart';
import 'package:maestro/features/runs/application/run_orchestrator.dart';
import 'package:maestro/features/runs/domain/run_observation.dart';

final class RunObservationFailure {
  const RunObservationFailure({
    required this.code,
    required this.message,
    required this.remediation,
  });

  final String code;
  final String message;
  final String remediation;
}

final class RunObservationState {
  const RunObservationState({
    this.runs = const <RunTopology>[],
    this.selectedRunId,
    this.output = const <RunOutputChunk>[],
    this.loading = false,
    this.loadingEarlier = false,
    this.hasEarlier = false,
    this.durability = OutputDurability.durable,
    this.failure,
  });

  final List<RunTopology> runs;
  final String? selectedRunId;
  final List<RunOutputChunk> output;
  final bool loading;
  final bool loadingEarlier;
  final bool hasEarlier;
  final OutputDurability durability;
  final RunObservationFailure? failure;

  RunTopology? get selectedRun {
    for (final run in runs) {
      if (run.runId == selectedRunId) return run;
    }
    return null;
  }

  bool get isEmpty => !loading && runs.isEmpty;

  RunObservationState copyWith({
    List<RunTopology>? runs,
    String? selectedRunId,
    bool clearSelection = false,
    List<RunOutputChunk>? output,
    bool? loading,
    bool? loadingEarlier,
    bool? hasEarlier,
    OutputDurability? durability,
    RunObservationFailure? failure,
    bool clearFailure = false,
  }) => RunObservationState(
    runs: runs ?? this.runs,
    selectedRunId: clearSelection ? null : selectedRunId ?? this.selectedRunId,
    output: output ?? this.output,
    loading: loading ?? this.loading,
    loadingEarlier: loadingEarlier ?? this.loadingEarlier,
    hasEarlier: hasEarlier ?? this.hasEarlier,
    durability: durability ?? this.durability,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

/// Presents concurrent run structure, status, and streamed output.
///
/// Summaries arrive faster than a view can usefully repaint, so this controller
/// coalesces them onto a single scheduled refresh and keeps a bounded display
/// window. Durable storage stays the authority for what the run actually
/// produced (FR-OB-03, FR-OB-04, NFR-01..03).
final class RunObservationController extends ChangeNotifier {
  RunObservationController({
    required this.projectId,
    required ObserveRuns observe,
    required RunSummaryEvents events,
    Duration refreshInterval = const Duration(milliseconds: 16),
  }) : _observe = observe,
       _events = events,
       _refreshInterval = refreshInterval {
    _subscription = events.listen(_onSummary);
  }

  /// The ceiling on output held for display. Older output is read back from
  /// storage on request rather than kept resident.
  static const int maximumDisplayBytes = 32 * 1024;

  final String projectId;
  final ObserveRuns _observe;
  // Retaining the event owner makes the subscription lifetime explicit.
  final RunSummaryEvents _events;
  final Duration _refreshInterval;
  late final RunSummarySubscription _subscription;

  RunObservationState state = const RunObservationState();

  Timer? _refreshTimer;
  var _reloadRunsPending = false;
  var _refreshOutputPending = false;
  var _refreshing = false;
  var _generation = 0;
  var _disposed = false;
  int? _lastSequence;
  String? _outputAttemptId;

  /// The sequence of the oldest chunk on display.
  ///
  /// Log sequences are contiguous within an attempt, so the window's start is
  /// derived rather than tracked separately — trimming the oldest chunks then
  /// cannot desynchronize it.
  int? get _firstDisplayedSequence =>
      _lastSequence == null ? null : _lastSequence! - state.output.length + 1;

  Future<void> load() async {
    final generation = ++_generation;
    _publish(state.copyWith(loading: true, clearFailure: true));
    late final List<RunTopology> runs;
    try {
      runs = await _observe.forProject(projectId);
    } on Object {
      if (!_owns(generation)) return;
      _publish(
        state.copyWith(
          loading: false,
          failure: const RunObservationFailure(
            code: 'run.observation.load',
            message: 'Could not load runs for this project.',
            remediation: 'The runs remain durable. Refresh to try again.',
          ),
        ),
      );
      return;
    }
    if (!_owns(generation)) return;
    final selected = runs.any((run) => run.runId == state.selectedRunId)
        ? state.selectedRunId
        : runs.firstOrNull?.runId;
    final selectionChanged = selected != state.selectedRunId;
    _publish(
      state.copyWith(
        runs: List<RunTopology>.unmodifiable(runs),
        loading: false,
        selectedRunId: selected,
        clearSelection: selected == null,
      ),
    );
    if (selected != null && (selectionChanged || state.output.isEmpty)) {
      await _loadWindow(selected);
    }
  }

  Future<void> select(String runId) async {
    if (_disposed || runId == state.selectedRunId) return;
    _resetWindow();
    _publish(
      state.copyWith(
        selectedRunId: runId,
        output: const <RunOutputChunk>[],
        hasEarlier: false,
        clearFailure: true,
      ),
    );
    await _loadWindow(runId);
  }

  /// Reads the output preceding the oldest chunk currently displayed.
  Future<void> loadEarlier() async {
    final runId = state.selectedRunId;
    final attemptId = _outputAttemptId;
    final first = _firstDisplayedSequence;
    if (_disposed ||
        state.loadingEarlier ||
        runId == null ||
        attemptId == null ||
        first == null ||
        !state.hasEarlier) {
      return;
    }
    final generation = _generation;
    _publish(state.copyWith(loadingEarlier: true, clearFailure: true));
    try {
      final earlier = await _observe.earlierOutput(
        runId: runId,
        attemptId: attemptId,
        beforeSequenceExclusive: first,
      );
      if (!_owns(generation) || runId != state.selectedRunId) return;
      if (earlier.chunks.isEmpty) {
        _publish(state.copyWith(loadingEarlier: false, hasEarlier: false));
        return;
      }
      // Earlier output is prepended without trimming: the user asked for it,
      // so the newest end is not what should give way.
      _publish(
        state.copyWith(
          loadingEarlier: false,
          hasEarlier: earlier.hasEarlier,
          output: List<RunOutputChunk>.unmodifiable(<RunOutputChunk>[
            ...earlier.chunks,
            ...state.output,
          ]),
        ),
      );
    } on Object {
      if (!_owns(generation)) return;
      _publish(
        state.copyWith(
          loadingEarlier: false,
          failure: const RunObservationFailure(
            code: 'run.observation.output',
            message: 'Could not read earlier output.',
            remediation: 'The output remains stored. Try again.',
          ),
        ),
      );
    }
  }

  Future<void> _loadWindow(String runId) async {
    final generation = _generation;
    final attemptId = state.selectedRun?.latestAttemptId;
    _outputAttemptId = attemptId;
    if (attemptId == null) {
      _publish(
        state.copyWith(output: const <RunOutputChunk>[], hasEarlier: false),
      );
      return;
    }
    try {
      final window = await _observe.latestOutput(
        runId: runId,
        attemptId: attemptId,
      );
      if (!_owns(generation) || runId != state.selectedRunId) return;
      _lastSequence = window.lastSequence;
      final bounded = _bounded(window.chunks);
      _publish(
        state.copyWith(
          output: bounded,
          hasEarlier: _startsAfterOrigin(bounded),
        ),
      );
    } on Object {
      if (!_owns(generation)) return;
      _publish(
        state.copyWith(
          failure: const RunObservationFailure(
            code: 'run.observation.output',
            message: 'Could not read run output.',
            remediation: 'The output remains stored. Refresh to try again.',
          ),
        ),
      );
    }
  }

  void _onSummary(RunLogSummary event) {
    if (_disposed) return;
    final known = state.runs.any((run) => run.runId == event.runId);
    if (!known) {
      _reloadRunsPending = true;
      _scheduleRefresh();
      return;
    }
    if (event.isAnnouncement) return;
    if (event.durability != state.durability &&
        event.runId == state.selectedRunId) {
      _publish(state.copyWith(durability: event.durability));
    }
    _refreshOutputPending = true;
    _scheduleRefresh();
  }

  /// Collapses a burst of summaries into one refresh, so a flooding run costs
  /// a bounded number of repaints and durable reads (AF-01).
  void _scheduleRefresh() {
    if (_disposed || _refreshTimer != null) return;
    _refreshTimer = Timer(_refreshInterval, () {
      _refreshTimer = null;
      unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (_disposed || _refreshing) return;
    _refreshing = true;
    try {
      if (_reloadRunsPending) {
        _reloadRunsPending = false;
        await load();
        if (_disposed) return;
      }
      if (!_refreshOutputPending) return;
      _refreshOutputPending = false;
      final runId = state.selectedRunId;
      if (runId == null) return;
      final generation = _generation;
      final topology = await _observe.run(runId);
      if (!_owns(generation) || runId != state.selectedRunId) return;
      if (topology != null) {
        _publish(
          state.copyWith(
            runs: List<RunTopology>.unmodifiable(
              state.runs.map((run) => run.runId == runId ? topology : run),
            ),
          ),
        );
      }
      final attemptId = state.selectedRun?.latestAttemptId;
      if (attemptId == null) return;
      if (attemptId != _outputAttemptId) {
        // A new attempt owns the output from here on.
        _resetWindow();
        _outputAttemptId = attemptId;
        _publish(state.copyWith(output: const <RunOutputChunk>[]));
      }
      final since = _lastSequence;
      final appended = since == null
          ? await _observe.latestOutput(runId: runId, attemptId: attemptId)
          : await _observe.outputSince(
              runId: runId,
              attemptId: attemptId,
              afterSequenceExclusive: since,
            );
      if (!_owns(generation) ||
          runId != state.selectedRunId ||
          appended.chunks.isEmpty) {
        return;
      }
      _lastSequence = appended.lastSequence;
      final bounded = _bounded(<RunOutputChunk>[
        ...state.output,
        ...appended.chunks,
      ]);
      _publish(
        state.copyWith(
          output: bounded,
          hasEarlier: state.hasEarlier || _startsAfterOrigin(bounded),
        ),
      );
    } on Object {
      if (_disposed) return;
      _publish(
        state.copyWith(
          failure: const RunObservationFailure(
            code: 'run.observation.output',
            message: 'Could not read streamed run output.',
            remediation: 'The output remains stored. Refresh to try again.',
          ),
        ),
      );
    } finally {
      _refreshing = false;
      if (!_disposed && (_reloadRunsPending || _refreshOutputPending)) {
        _scheduleRefresh();
      }
    }
  }

  void _resetWindow() {
    _lastSequence = null;
    _outputAttemptId = null;
  }

  /// Whether durable output precedes the window that would be displayed.
  bool _startsAfterOrigin(List<RunOutputChunk> window) {
    final last = _lastSequence;
    return last != null && last - window.length + 1 > 0;
  }

  /// Drops the oldest chunks once the display window exceeds its ceiling, so a
  /// long-running flood cannot grow the view without bound (NFR-03).
  List<RunOutputChunk> _bounded(Iterable<RunOutputChunk> chunks) {
    final ordered = chunks.toList(growable: false);
    var total = ordered.fold<int>(0, (sum, chunk) => sum + chunk.byteLength);
    var start = 0;
    while (start < ordered.length && total > maximumDisplayBytes) {
      total -= ordered[start].byteLength;
      start++;
    }
    return List<RunOutputChunk>.unmodifiable(ordered.sublist(start));
  }

  bool _owns(int generation) => !_disposed && generation == _generation;

  void _publish(RunObservationState next) {
    if (_disposed) return;
    state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _subscription.cancel();
    // Access keeps the retained owner intentional under strict analysis.
    _events.hashCode;
    super.dispose();
  }
}
