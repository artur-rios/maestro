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
  });
  final List<HistorySummary> entries;
  final HistoryFilter filter;
  final bool loading;
  final String? failure;
  final String? selected;
  final HistoryDetail? detail;
  final bool loadingDetail;
  List<HistorySummary> get visible => filterHistory(entries, filter);
}

final class HistoryController extends ChangeNotifier {
  HistoryController({required DriftHistoryRepository repository})
    : _repository = repository;
  final DriftHistoryRepository _repository;
  HistoryState state = const HistoryState();
  Future<void> load() async {
    state = HistoryState(
      entries: state.entries,
      filter: state.filter,
      loading: true,
    );
    notifyListeners();
    try {
      state = HistoryState(
        entries: await _repository.list(),
        filter: state.filter,
      );
    } on Object {
      state = HistoryState(
        entries: state.entries,
        filter: state.filter,
        failure:
            'History could not be loaded. Existing evidence remains unchanged.',
      );
    }
    notifyListeners();
  }

  Future<void> select(String runId) async {
    state = HistoryState(
      entries: state.entries,
      filter: state.filter,
      selected: runId,
      loadingDetail: true,
    );
    notifyListeners();
    try {
      final detail = await _repository.detail(runId);
      state = HistoryState(
        entries: state.entries,
        filter: state.filter,
        selected: runId,
        detail: detail,
      );
    } on Object {
      state = HistoryState(
        entries: state.entries,
        filter: state.filter,
        selected: runId,
        failure:
            'Run evidence could not be loaded. Existing evidence remains unchanged.',
      );
    }
    notifyListeners();
  }

  void search(String value) {
    state = HistoryState(
      entries: state.entries,
      filter: HistoryFilter(query: value, statuses: state.filter.statuses),
    );
    notifyListeners();
  }
}
