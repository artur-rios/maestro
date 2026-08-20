// Public constructor names describe injected ports; stored fields stay private.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:maestro/features/terminal/domain/terminal_launch_target.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';

typedef WorkbenchTerminalFactory =
    WorkbenchTerminalController Function(TerminalLaunchTarget target);

final class WorkbenchTerminalEntry {
  const WorkbenchTerminalEntry({
    required this.id,
    required this.label,
    required this.target,
    required this.controller,
  });

  final String id;
  final String label;
  final TerminalLaunchTarget target;
  final WorkbenchTerminalController controller;
}

final class WorkbenchTerminalManager extends ChangeNotifier {
  WorkbenchTerminalManager({required WorkbenchTerminalFactory factory})
    : _factory = factory;

  final WorkbenchTerminalFactory _factory;
  final _entries = <WorkbenchTerminalEntry>[];

  var _nextId = 1;
  String? _activeId;
  var _isVisible = false;
  var _isKilling = false;
  var _disposed = false;

  List<WorkbenchTerminalEntry> get entries => List.unmodifiable(_entries);

  WorkbenchTerminalEntry? get activeEntry {
    final activeId = _activeId;
    if (activeId == null) return null;
    for (final entry in _entries) {
      if (entry.id == activeId) return entry;
    }
    return null;
  }

  bool get isVisible => _isVisible;
  bool get isKilling => _isKilling;

  Future<void> show(TerminalLaunchTarget target) async {
    if (_disposed) return;
    _isVisible = true;
    notifyListeners();
    if (_entries.isEmpty) await create(target);
  }

  void hide() {
    if (_disposed || !_isVisible) return;
    _isVisible = false;
    notifyListeners();
  }

  Future<void> toggle(TerminalLaunchTarget target) async {
    if (_disposed) return;
    if (_isVisible) {
      hide();
      return;
    }
    await show(target);
  }

  Future<void> create(TerminalLaunchTarget target) async {
    if (_disposed) return;
    final controller = _factory(target);
    final entry = WorkbenchTerminalEntry(
      id: 'terminal-${_nextId++}',
      label: _nextLabel(target.label),
      target: target,
      controller: controller,
    );
    _entries.add(entry);
    _activeId = entry.id;
    _isVisible = true;
    controller.addListener(_relayControllerChange);
    notifyListeners();
    if (target.failure == null) await controller.open();
  }

  void select(String id) {
    if (_disposed || id == _activeId) return;
    if (!_entries.any((entry) => entry.id == id)) return;
    _activeId = id;
    notifyListeners();
  }

  Future<void> killActive() async {
    final entry = activeEntry;
    if (_disposed || entry == null || _isKilling) return;
    _isKilling = true;
    notifyListeners();
    final index = _entries.indexWhere((candidate) => candidate.id == entry.id);
    try {
      var closure = TerminalClosure.incomplete;
      try {
        closure = await entry.controller.close();
      } on Object {
        // A controller is expected to normalize close errors. Retaining the
        // captured entry is still the only safe manager-level fallback.
      }
      if (_disposed) return;
      if (closure == TerminalClosure.incomplete) {
        _activeId = entry.id;
        _isVisible = true;
        return;
      }
      final shouldSelectNeighbor = _activeId == entry.id;
      try {
        entry.controller.removeListener(_relayControllerChange);
      } on Object {
        // Confirmed process termination must still allow entry removal.
      }
      try {
        entry.controller.dispose();
      } on Object {
        // Controller cleanup is best-effort after confirmed termination.
      }
      _entries.removeWhere((candidate) => candidate.id == entry.id);
      if (_entries.isEmpty) {
        _activeId = null;
        _isVisible = false;
      } else if (shouldSelectNeighbor) {
        _activeId = _entries[index.clamp(0, _entries.length - 1)].id;
      }
    } finally {
      _isKilling = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  String _nextLabel(String baseLabel) {
    final labels = _entries.map((entry) => entry.label).toSet();
    if (!labels.contains(baseLabel)) return baseLabel;
    var suffix = 2;
    while (labels.contains('$baseLabel $suffix')) {
      suffix++;
    }
    return '$baseLabel $suffix';
  }

  void _relayControllerChange() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final entry in _entries) {
      try {
        entry.controller.removeListener(_relayControllerChange);
      } on Object {
        // Continue disposing the remaining owned entries.
      }
      try {
        entry.controller.dispose();
      } on Object {
        // Continue disposing the remaining owned entries.
      }
    }
    _entries.clear();
    _activeId = null;
    super.dispose();
  }
}
