import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/terminal/application/open_project_terminal.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/domain/terminal_launch_target.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';
import 'package:maestro/features/terminal/presentation/workbench_terminal_manager.dart';

void main() {
  group('WorkbenchTerminalManager', () {
    test('GivenNoSessions_WhenShown_ThenOneContextTerminalIsCreated', () async {
      final fixture = _ManagerFixture();

      await fixture.manager.show(_projectTarget('Maestro'));

      expect(fixture.manager.isVisible, isTrue);
      expect(fixture.manager.entries.single.label, 'Maestro');
      expect(
        fixture.openers.single.requests.single.workingDirectory,
        r'D:\Maestro',
      );
    });

    test(
      'GivenDuplicateTargets_WhenCreated_ThenStableNumericLabelsAreAssigned',
      () async {
        final fixture = _ManagerFixture();

        await fixture.manager.create(_projectTarget('Maestro'));
        await fixture.manager.create(_projectTarget('Maestro'));

        expect(fixture.manager.entries.map((entry) => entry.label), <String>[
          'Maestro',
          'Maestro 2',
        ]);
        expect(
          fixture.manager.entries.map((entry) => entry.id).toSet(),
          hasLength(2),
        );
      },
    );

    test(
      'GivenExistingSessions_WhenHiddenAndShown_ThenNoSessionIsCreated',
      () async {
        final fixture = _ManagerFixture();
        await fixture.manager.show(_homeTarget());
        fixture.manager.hide();

        await fixture.manager.show(_projectTarget('Second'));

        expect(fixture.manager.entries, hasLength(1));
        expect(fixture.manager.activeEntry?.label, 'Home');
      },
    );

    test(
      'GivenThreeSessions_WhenMiddleIsKilled_ThenNearestRightTabBecomesActive',
      () async {
        final fixture = _ManagerFixture();
        await fixture.manager.create(_projectTarget('One'));
        await fixture.manager.create(_projectTarget('Two'));
        await fixture.manager.create(_projectTarget('Three'));
        fixture.manager.select(fixture.manager.entries[1].id);

        await fixture.manager.killActive();

        expect(fixture.manager.entries.map((entry) => entry.label), <String>[
          'One',
          'Three',
        ]);
        expect(fixture.manager.activeEntry?.label, 'Three');
        expect(fixture.openers[1].session.closed, isTrue);
      },
    );

    test('GivenLastSession_WhenKilled_ThenDockCloses', () async {
      final fixture = _ManagerFixture();
      await fixture.manager.show(_homeTarget());

      await fixture.manager.killActive();

      expect(fixture.manager.entries, isEmpty);
      expect(fixture.manager.isVisible, isFalse);
    });

    test(
      'GivenIncompleteTermination_WhenKilled_ThenEntryAndDockRemain',
      () async {
        final fixture = _ManagerFixture(closure: TerminalClosure.incomplete);
        await fixture.manager.show(_homeTarget());

        await fixture.manager.killActive();

        expect(fixture.manager.entries, hasLength(1));
        expect(fixture.manager.isVisible, isTrue);
        expect(fixture.manager.isKilling, isFalse);
      },
    );

    test(
      'GivenStableIds_WhenAnEntryIsSelected_ThenThatExactEntryBecomesActive',
      () async {
        final fixture = _ManagerFixture();
        await fixture.manager.create(_projectTarget('One'));
        await fixture.manager.create(_projectTarget('Two'));
        final firstId = fixture.manager.entries.first.id;

        fixture.manager.select(firstId);

        expect(fixture.manager.activeEntry?.id, firstId);
        expect(fixture.manager.activeEntry?.label, 'One');
      },
    );

    test(
      'GivenProjectSelectionChanges_WhenCreated_ThenTheCurrentTargetIsCaptured',
      () async {
        final fixture = _ManagerFixture();
        await fixture.manager.create(_projectTarget('First'));

        await fixture.manager.create(_projectTarget('Second'));

        expect(
          fixture.manager.entries.map((entry) => entry.target.label),
          <String>['First', 'Second'],
        );
        expect(
          fixture.openers.map(
            (opener) => opener.requests.single.workingDirectory,
          ),
          <String>[r'D:\First', r'D:\Second'],
        );
      },
    );

    test(
      'GivenAFailureTarget_WhenCreated_ThenAReadableFailedEntrySkipsOpening',
      () async {
        final fixture = _ManagerFixture();
        const failure = TerminalFailure(
          code: TerminalFailure.folderUnavailableCode,
          message: 'The home folder could not be resolved.',
          remediation: 'Configure a readable home folder, then try again.',
        );

        await fixture.manager.create(TerminalLaunchTarget.failure(failure));

        final entry = fixture.manager.entries.single;
        expect(entry.label, 'Home');
        expect(entry.controller.state.status, TerminalSessionStatus.failed);
        expect(
          entry.controller.state.failure?.message,
          contains('home folder'),
        );
        expect(fixture.openers.single.requests, isEmpty);
      },
    );

    test(
      'GivenAVisibleDock_WhenToggled_ThenItHidesWithoutCreatingASession',
      () async {
        final fixture = _ManagerFixture();
        await fixture.manager.show(_homeTarget());

        await fixture.manager.toggle(_projectTarget('Ignored'));

        expect(fixture.manager.isVisible, isFalse);
        expect(fixture.manager.entries, hasLength(1));
      },
    );

    test(
      'GivenAnEmptyHiddenDock_WhenToggled_ThenItShowsAndCreatesTheTarget',
      () async {
        final fixture = _ManagerFixture();

        await fixture.manager.toggle(_projectTarget('Maestro'));

        expect(fixture.manager.isVisible, isTrue);
        expect(fixture.manager.entries.single.label, 'Maestro');
      },
    );

    test(
      'GivenLiveSessions_WhenManagerIsDisposed_ThenEveryControllerIsClosed',
      () async {
        final fixture = _ManagerFixture();
        await fixture.manager.create(_projectTarget('One'));
        await fixture.manager.create(_projectTarget('Two'));

        fixture.manager.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(
          fixture.openers.map((opener) => opener.session.closed),
          everyElement(isTrue),
        );
      },
    );

    test(
      'GivenAKillInFlight_WhenSelectionChanges_ThenTheCapturedEntryIsRemoved',
      () async {
        final fixture = _ManagerFixture(delayClose: true);
        await fixture.manager.create(_projectTarget('One'));
        await fixture.manager.create(_projectTarget('Two'));
        final firstId = fixture.manager.entries.first.id;
        final secondId = fixture.manager.entries.last.id;
        fixture.manager.select(firstId);

        final kill = fixture.manager.killActive();
        fixture.manager.select(secondId);
        fixture.openers.first.completeClose();
        await kill;

        expect(fixture.manager.entries.map((entry) => entry.id), <String>[
          secondId,
        ]);
      },
    );

    test(
      'GivenAStartingSession_WhenKilled_ThenItsEntryRemainsUntilStartupSettles',
      () async {
        final fixture = _ManagerFixture(delayOpen: true);
        final creation = fixture.manager.create(_projectTarget('Starting'));

        final kill = fixture.manager.killActive();
        await Future<void>.delayed(Duration.zero);

        expect(fixture.manager.entries, hasLength(1));
        expect(fixture.manager.isVisible, isTrue);
        expect(fixture.manager.isKilling, isTrue);

        fixture.openers.single.completeOpen();
        await creation;
        await kill;
      },
    );

    test(
      'GivenAStartingSession_WhenKilled_ThenItsLateSessionClosesBeforeRemoval',
      () async {
        final fixture = _ManagerFixture(delayOpen: true, delayClose: true);
        final creation = fixture.manager.create(_projectTarget('Starting'));

        final kill = fixture.manager.killActive();
        fixture.openers.single.completeOpen();
        await creation;
        await Future<void>.delayed(Duration.zero);

        expect(fixture.manager.entries, hasLength(1));
        expect(fixture.openers.single.session.closed, isFalse);

        fixture.openers.single.completeClose();
        await kill;

        expect(fixture.openers.single.session.closed, isTrue);
        expect(fixture.manager.entries, isEmpty);
      },
    );

    test(
      'GivenAStartingSession_WhenLateClosureIsIncomplete_ThenEntryRemains',
      () async {
        final fixture = _ManagerFixture(
          closure: TerminalClosure.incomplete,
          delayOpen: true,
        );
        final creation = fixture.manager.create(_projectTarget('Starting'));

        final kill = fixture.manager.killActive();
        fixture.openers.single.completeOpen();
        await creation;
        await kill;

        expect(fixture.manager.entries, hasLength(1));
        expect(fixture.manager.isVisible, isTrue);
        expect(fixture.manager.isKilling, isFalse);
        expect(
          fixture.manager.entries.single.controller.state.failure?.code,
          TerminalFailure.closeIncompleteCode,
        );
      },
    );

    test(
      'GivenAKillWaitingForStartup_WhenDisposed_ThenKillCompletesAndLateSessionCloses',
      () async {
        final fixture = _ManagerFixture(delayOpen: true);
        final creation = fixture.manager.create(_projectTarget('Starting'));
        final controller = fixture.manager.entries.single.controller;
        var controllerNotifications = 0;
        controller.addListener(() => controllerNotifications++);

        final kill = fixture.manager.killActive();
        var killCompleted = false;
        final observedKill = kill.then((_) => killCompleted = true);
        await Future<void>.delayed(Duration.zero);
        expect(killCompleted, isFalse);

        fixture.manager.dispose();
        await Future<void>.delayed(Duration.zero);

        expect(killCompleted, isTrue);
        await observedKill;
        fixture.openers.single.completeOpen();
        await creation;
        await Future<void>.delayed(Duration.zero);

        expect(fixture.openers.single.session.closeCalls, 1);
        expect(fixture.openers.single.session.closed, isTrue);
        expect(controllerNotifications, 0);
      },
    );

    test(
      'GivenAKillInFlight_WhenAnotherTabIsSelected_ThenSelectionIsPreserved',
      () async {
        final fixture = _ManagerFixture(delayClose: true);
        await fixture.manager.create(_projectTarget('One'));
        await fixture.manager.create(_projectTarget('Two'));
        await fixture.manager.create(_projectTarget('Three'));
        final firstId = fixture.manager.entries.first.id;
        final thirdId = fixture.manager.entries.last.id;
        fixture.manager.select(firstId);

        final kill = fixture.manager.killActive();
        fixture.manager.select(thirdId);
        fixture.openers.first.completeClose();
        await kill;

        expect(fixture.manager.activeEntry?.id, thirdId);
        expect(fixture.manager.activeEntry?.label, 'Three');
      },
    );
  });
}

TerminalLaunchTarget _projectTarget(String name) =>
    TerminalLaunchTarget.project(
      projectName: name,
      workingDirectory: 'D:\\$name',
    );

TerminalLaunchTarget _homeTarget() =>
    TerminalLaunchTarget.home(workingDirectory: r'C:\Users\tester');

final class _ManagerFixture {
  _ManagerFixture({
    this.closure = TerminalClosure.closed,
    this.delayOpen = false,
    this.delayClose = false,
  }) {
    manager = WorkbenchTerminalManager(factory: _createController);
  }

  final TerminalClosure closure;
  final bool delayOpen;
  final bool delayClose;
  final openers = <_FakeOpener>[];
  late final WorkbenchTerminalManager manager;

  ProjectTerminalController _createController(TerminalLaunchTarget target) {
    final opener = _FakeOpener(
      closure: closure,
      delayOpen: delayOpen,
      delayClose: delayClose,
    );
    openers.add(opener);
    return ProjectTerminalController(
      workingDirectory: target.workingDirectory ?? '',
      open: opener.call,
      initialFailure: target.failure,
    );
  }
}

final class _FakeOpener {
  _FakeOpener({
    required this.closure,
    required bool delayOpen,
    required bool delayClose,
  }) : session = _FakeSession(closure: closure, delayClose: delayClose),
       _openCompleter = delayOpen ? Completer<TerminalOpenResult>() : null;

  final TerminalClosure closure;
  final _FakeSession session;
  final Completer<TerminalOpenResult>? _openCompleter;
  final requests = <({String workingDirectory, int columns, int rows})>[];

  Future<TerminalOpenResult> call({
    required String workingDirectory,
    required int columns,
    required int rows,
  }) async {
    requests.add((
      workingDirectory: workingDirectory,
      columns: columns,
      rows: rows,
    ));
    return _openCompleter?.future ?? TerminalOpenResult.opened(session);
  }

  void completeOpen() =>
      _openCompleter?.complete(TerminalOpenResult.opened(session));

  void completeClose() => session.completeClose();
}

final class _FakeSession implements TerminalSession {
  _FakeSession({required this.closure, required bool delayClose})
    : _closeCompleter = delayClose ? Completer<TerminalClosure>() : null;

  final TerminalClosure closure;
  final Completer<TerminalClosure>? _closeCompleter;
  final _output = StreamController<Uint8List>.broadcast();
  final _exit = Completer<TerminalExit>();
  var closed = false;
  var closeCalls = 0;

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<TerminalExit> get exit => _exit.future;

  @override
  Future<void> write(Uint8List bytes) async {}

  @override
  Future<void> resize({required int columns, required int rows}) async {}

  @override
  Future<TerminalClosure> close() async {
    closeCalls++;
    final result = _closeCompleter == null
        ? closure
        : await _closeCompleter.future;
    if (result == TerminalClosure.closed) {
      closed = true;
      if (!_exit.isCompleted) _exit.complete(const TerminalExit(0));
    }
    return result;
  }

  void completeClose() => _closeCompleter?.complete(closure);
}
