import 'package:flutter/foundation.dart';
import 'package:maestro/features/history/data/drift_history_repository.dart';
import 'package:maestro/features/history/domain/history_models.dart';

// Public constructor names document injected ports.
// ignore_for_file: prefer_initializing_formals

final class HistoryState {
  const HistoryState({
    this.entries = const <HistorySummary>[],
    this.filter = const HistoryFilter(),
    this.loading = false,
    this.failure,
    this.selected,
    this.detail,
    this.loadingDetail = false,
    this.diagnostics = const <DiagnosticEntry>[],
  });
  final List<HistorySummary> entries;
  final HistoryFilter filter;
  final bool loading;
  final String? failure;
  final String? selected;
  final HistoryDetail? detail;
  final bool loadingDetail;

  /// Recent diagnostic lines, so the remediation advice to review them can be
  /// followed without leaving the application.
  final List<DiagnosticEntry> diagnostics;
  List<HistorySummary> get visible => filterHistory(entries, filter);
}

final class HistoryController extends ChangeNotifier {
  HistoryController({required DriftHistoryRepository repository})
    : _repository = repository;
  final DriftHistoryRepository _repository;
  HistoryState state = const HistoryState();

  Future<void> load() async {
    _publish(loading: true);
    List<HistorySummary>? entries;
    String? failure;
    try {
      entries = await _repository.list();
    } on Object {
      failure =
          'History could not be loaded. Existing evidence remains unchanged.';
    }
    // Diagnostics are read alongside history and never fail the load: they
    // exist to explain a failure, so losing them must not cause one.
    List<DiagnosticEntry> diagnostics = state.diagnostics;
    try {
      diagnostics = await _repository.recentDiagnostics();
    } on Object {
      // Keep whatever was already shown.
    }
    _publish(
      entries: entries ?? state.entries,
      diagnostics: diagnostics,
      failure: failure,
    );
  }

  Future<void> select(String runId) async {
    _publish(selected: runId, loadingDetail: true);
    try {
      final detail = await _repository.detail(runId);
      _publish(selected: runId, detail: detail);
    } on Object {
      _publish(
        selected: runId,
        failure:
            'Run evidence could not be loaded. Existing evidence remains '
            'unchanged.',
      );
    }
  }

  void search(String value) {
    state = HistoryState(
      entries: state.entries,
      diagnostics: state.diagnostics,
      filter: HistoryFilter(query: value, statuses: state.filter.statuses),
    );
    notifyListeners();
  }

  /// Rebuilds the state, carrying forward what this transition does not touch.
  void _publish({
    List<HistorySummary>? entries,
    List<DiagnosticEntry>? diagnostics,
    bool loading = false,
    String? failure,
    String? selected,
    HistoryDetail? detail,
    bool loadingDetail = false,
  }) {
    state = HistoryState(
      entries: entries ?? state.entries,
      diagnostics: diagnostics ?? state.diagnostics,
      filter: state.filter,
      loading: loading,
      failure: failure,
      selected: selected,
      detail: detail,
      loadingDetail: loadingDetail,
    );
    notifyListeners();
  }
}
