import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/app/maestro_theme.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/features/terminal/application/open_project_terminal.dart';
import 'package:maestro/features/terminal/application/terminal_port.dart';
import 'package:maestro/features/terminal/domain/terminal_launch_target.dart';
import 'package:maestro/features/terminal/domain/terminal_models.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_controller.dart';
import 'package:maestro/features/terminal/presentation/project_terminal_drawer_controller.dart';
import 'package:maestro/features/terminal/presentation/workbench_terminal_dock.dart';
import 'package:maestro/features/terminal/presentation/workbench_terminal_manager.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('WorkbenchTerminalDock', () {
    testWidgets(
      'GivenAHiddenDock_WhenShown_ThenItStartsAndShowsOneTerminalView',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());

        fixture.drawer.show();
        await tester.pumpAndSettle();

        final entry = fixture.manager.entries.single;
        expect(find.byKey(const Key('terminal-drawer')), findsOneWidget);
        expect(find.byKey(Key('terminal-view-${entry.id}')), findsOneWidget);
        expect(find.byType(TerminalView), findsOneWidget);
      },
    );

    testWidgets(
      'GivenRunningTerminal_WhenRendered_ThenNerdFontTypographyIsConfigured',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        final terminalView = tester.widget<TerminalView>(
          find.byType(TerminalView),
        );
        expect(terminalView.textStyle.fontFamily, 'MesloLGM Nerd Font');
        expect(terminalView.textStyle.fontFamilyFallback, <String>[
          'monospace',
        ]);
        expect(terminalView.textStyle.fontSize, inInclusiveRange(13, 14));
        expect(terminalView.textStyle.height, greaterThanOrEqualTo(1.2));
      },
    );

    testWidgets(
      'GivenAVisibleDock_WhenRendered_ThenItUsesFullWidthHeightAndSurfaceTokens',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        final drawerSize = tester.getSize(
          find.byKey(const Key('terminal-drawer')),
        );
        expect(drawerSize.width, tester.getSize(find.byType(Scaffold)).width);
        expect(drawerSize.height, 300);
        final dock = tester.widget<DecoratedBox>(
          find.byKey(const Key('terminal-dock')),
        );
        final decoration = dock.decoration as BoxDecoration;
        final tokens = MaestroThemeTokens.of(
          tester.element(find.byKey(const Key('terminal-dock'))),
        );
        expect(decoration.color, tokens.terminalSurface);
        final border = decoration.border! as Border;
        expect(border.top.color, tokens.subtleBorder);
        expect(border.left.style, BorderStyle.none);
        expect(border.right.style, BorderStyle.none);
        expect(border.bottom.style, BorderStyle.none);
        expect(
          tester.getSize(find.byKey(const Key('terminal-toolbar'))).height,
          36,
        );
      },
    );

    testWidgets(
      'GivenNarrowAvailableHeight_WhenTerminalShown_ThenDockHeightIsClamped',
      (tester) async {
        tester.view.physicalSize = const Size(500, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = await _pumpDock(tester, target: _homeTarget());

        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byKey(const Key('terminal-drawer'))).height,
          180,
        );
      },
    );

    testWidgets('GivenVisibleDock_WhenNewPressed_ThenAnotherActiveTabAppears', (
      tester,
    ) async {
      final fixture = await _pumpDock(
        tester,
        target: _projectTarget('Maestro'),
      );
      await fixture.manager.show(fixture.target);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('new-terminal')));
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);
      expect(find.text('Maestro'), findsOneWidget);
      expect(find.text('Maestro 2'), findsOneWidget);
      expect(find.text('2 terminals'), findsOneWidget);
      expect(
        find.byKey(Key('terminal-view-${fixture.manager.activeEntry!.id}')),
        findsOneWidget,
      );
    });

    testWidgets(
      'GivenExistingRunningSession_WhenDockIsShown_ThenTerminalReceivesFocus',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.create(fixture.target);
        fixture.manager.hide();
        await tester.pumpAndSettle();

        fixture.drawer.show();
        await tester.pumpAndSettle();

        final terminal = tester.widget<TerminalView>(find.byType(TerminalView));
        expect(terminal.focusNode, isNotNull);
        expect(terminal.focusNode!.hasFocus, isTrue);
      },
    );

    testWidgets(
      'GivenRunningSession_WhenNewTerminalCreated_ThenNewTerminalReceivesFocus',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('new-terminal')));
        await tester.pumpAndSettle();

        final active = fixture.manager.activeEntry!;
        final terminal = tester.widget<TerminalView>(
          find.byKey(Key('terminal-view-${active.id}')),
        );
        expect(terminal.focusNode, isNotNull);
        expect(terminal.focusNode!.hasFocus, isTrue);
      },
    );

    testWidgets(
      'GivenTwoSessions_WhenInactiveTabSelected_ThenOnlyItsViewIsShown',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.create(fixture.target);
        await fixture.manager.create(fixture.target);
        await tester.pumpAndSettle();
        final first = fixture.manager.entries.first;
        final second = fixture.manager.entries.last;

        await tester.tap(find.byKey(Key('terminal-tab-${first.id}')));
        await tester.pump();

        expect(fixture.manager.activeEntry?.id, first.id);
        expect(find.byKey(Key('terminal-view-${first.id}')), findsOneWidget);
        expect(find.byKey(Key('terminal-view-${second.id}')), findsNothing);
        expect(find.byType(TerminalView), findsOneWidget);
      },
    );

    testWidgets(
      'GivenDifferentRunningTabSelected_WhenViewChanges_ThenSelectedTerminalReceivesItsStableFocusNode',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.create(fixture.target);
        await fixture.manager.create(fixture.target);
        await tester.pumpAndSettle();
        final first = fixture.manager.entries.first;

        await tester.tap(find.byKey(Key('terminal-tab-${first.id}')));
        await tester.pumpAndSettle();
        final firstView = tester.widget<TerminalView>(
          find.byKey(Key('terminal-view-${first.id}')),
        );
        expect(firstView.focusNode, isNotNull);
        expect(firstView.focusNode!.hasFocus, isTrue);
        final firstFocusNode = firstView.focusNode;

        await tester.tap(
          find.byKey(Key('terminal-tab-${fixture.manager.entries.last.id}')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('terminal-tab-${first.id}')));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<TerminalView>(
                find.byKey(Key('terminal-view-${first.id}')),
              )
              .focusNode,
          same(firstFocusNode),
        );
      },
    );

    testWidgets(
      'GivenTwoRunningSessions_WhenActiveIsKilled_ThenNeighborReceivesFocus',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.create(fixture.target);
        await fixture.manager.create(fixture.target);
        await tester.pumpAndSettle();
        final neighbor = fixture.manager.entries.first;

        await tester.tap(find.byKey(const Key('kill-terminal')));
        await tester.pumpAndSettle();

        final terminal = tester.widget<TerminalView>(
          find.byKey(Key('terminal-view-${neighbor.id}')),
        );
        expect(fixture.manager.activeEntry?.id, neighbor.id);
        expect(terminal.focusNode, isNotNull);
        expect(terminal.focusNode!.hasFocus, isTrue);
      },
    );

    testWidgets(
      'GivenWorkbenchFocused_WhenRunningControllerPublishesFailure_ThenTerminalDoesNotStealFocus',
      (tester) async {
        final fixture = await _pumpDock(
          tester,
          target: _homeTarget(),
          closure: TerminalClosure.incomplete,
        );
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();
        fixture.workbenchFocusNode.requestFocus();
        await tester.pump();

        await fixture.manager.activeEntry!.controller.close();
        await tester.pumpAndSettle();

        expect(fixture.workbenchFocusNode.hasPrimaryFocus, isTrue);
        expect(
          tester
              .widget<TerminalView>(find.byType(TerminalView))
              .focusNode!
              .hasFocus,
          isFalse,
        );
      },
    );

    testWidgets(
      'GivenInactiveRunningSession_WhenItWrites_ThenItsControllerStaysAlive',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.create(fixture.target);
        await fixture.manager.create(fixture.target);
        await tester.pumpAndSettle();

        fixture.sessions.first.emit(utf8.encode('background output'));
        await tester.pump();

        expect(fixture.sessions.first.closeCallCount, 0);
        expect(
          fixture.manager.entries.first.controller.terminal.buffer
              .getText()
              .trim(),
          startsWith('background output'),
        );
        expect(find.byType(TerminalView), findsOneWidget);
      },
    );

    testWidgets('GivenLastTerminal_WhenTrashPressed_ThenDockDisappears', (
      tester,
    ) async {
      final fixture = await _pumpDock(tester, target: _homeTarget());
      await fixture.manager.show(fixture.target);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('kill-terminal')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('terminal-drawer')), findsNothing);
      expect(fixture.manager.entries, isEmpty);
      expect(fixture.sessions.single.closeCallCount, 1);
    });

    testWidgets('GivenLastTerminal_WhenKilled_ThenWorkbenchReceivesFocus', (
      tester,
    ) async {
      final fixture = await _pumpDock(tester, target: _homeTarget());
      await fixture.manager.show(fixture.target);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('kill-terminal')));
      await tester.pumpAndSettle();

      expect(fixture.workbenchFocusNode.hasFocus, isTrue);
      expect(fixture.workbenchFocusRequestCount, 1);
    });

    testWidgets('GivenRunningSessions_WhenCollapsed_ThenProcessesRemainOwned', (
      tester,
    ) async {
      final fixture = await _pumpDock(tester, target: _homeTarget());
      await fixture.manager.show(fixture.target);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('collapse-terminal')));
      await tester.pump();

      expect(find.byKey(const Key('terminal-drawer')), findsNothing);
      expect(fixture.sessions.single.closeCallCount, 0);

      fixture.drawer.show();
      await tester.pumpAndSettle();
      expect(fixture.sessions, hasLength(1));
      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets(
      'GivenFocusedTerminal_WhenCollapsed_ThenWorkbenchReceivesFocus',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('collapse-terminal')));
        await tester.pumpAndSettle();

        expect(fixture.workbenchFocusNode.hasFocus, isTrue);
        expect(fixture.workbenchFocusRequestCount, 1);
      },
    );

    testWidgets(
      'GivenActiveAndInactiveTabs_WhenRendered_ThenActiveTabHasBoldNonColorCue',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.create(fixture.target);
        await fixture.manager.create(fixture.target);
        await tester.pumpAndSettle();

        expect(
          tester.widget<Text>(find.text('Home 2')).style?.fontWeight,
          FontWeight.bold,
        );
        expect(
          tester.widget<Text>(find.text('Home')).style?.fontWeight,
          isNot(FontWeight.bold),
        );
      },
    );

    testWidgets(
      'GivenStartingTerminal_WhenRendered_ThenTabShowsStartingStatus',
      (tester) async {
        final fixture = await _pumpDock(
          tester,
          target: _homeTarget(),
          delayOpen: true,
        );

        final creation = fixture.manager.create(fixture.target);
        await tester.pump();
        final entry = fixture.manager.entries.single;

        expect(
          find.byKey(Key('terminal-tab-status-${entry.id}')),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(find.byKey(Key('terminal-tab-${entry.id}')))
              .label,
          contains('Starting'),
        );

        fixture.completeOpen(0);
        await creation;
      },
    );

    testWidgets('GivenRunningTerminal_WhenRendered_ThenTabShowsRunningStatus', (
      tester,
    ) async {
      final fixture = await _pumpDock(tester, target: _homeTarget());
      await fixture.manager.show(fixture.target);
      await tester.pumpAndSettle();
      final entry = fixture.manager.entries.single;

      expect(
        find.byKey(Key('terminal-tab-status-${entry.id}')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byKey(Key('terminal-tab-${entry.id}'))).label,
        contains('Running'),
      );
    });

    testWidgets('GivenExitedTerminal_WhenRendered_ThenTabShowsExitedStatus', (
      tester,
    ) async {
      final fixture = await _pumpDock(tester, target: _homeTarget());
      await fixture.manager.show(fixture.target);
      await tester.pumpAndSettle();
      fixture.sessions.single.exitWith(9);
      await tester.pumpAndSettle();
      final entry = fixture.manager.entries.single;

      expect(
        find.byKey(Key('terminal-tab-status-${entry.id}')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byKey(Key('terminal-tab-${entry.id}'))).label,
        contains('Exited'),
      );
    });

    testWidgets('GivenFailedTerminal_WhenRendered_ThenTabShowsFailedStatus', (
      tester,
    ) async {
      const failure = TerminalFailure(
        code: TerminalFailure.folderUnavailableCode,
        message: 'The home folder is unavailable.',
        remediation: 'Configure a readable home folder, then try again.',
      );
      final fixture = await _pumpDock(
        tester,
        target: TerminalLaunchTarget.failure(failure),
      );
      await fixture.manager.show(fixture.target);
      await tester.pumpAndSettle();
      final entry = fixture.manager.entries.single;

      expect(
        find.byKey(Key('terminal-tab-status-${entry.id}')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byKey(Key('terminal-tab-${entry.id}'))).label,
        contains('Failed'),
      );
    });

    testWidgets(
      'GivenAnExitedSession_WhenDockRenders_ThenTheExitResultIsAnnounced',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        fixture.sessions.single.exitWith(137);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('terminal-exit')), findsOneWidget);
        expect(find.textContaining('exited with code 137'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('terminal-exit'))).label,
          contains('Terminal exited'),
        );
      },
    );

    testWidgets(
      'GivenInactiveRunningSession_WhenItExits_ThenTargetedLiveRegionAnnouncesIt',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.create(fixture.target);
        await fixture.manager.create(fixture.target);
        await tester.pumpAndSettle();

        fixture.sessions.first.exitWith(137);
        await tester.pumpAndSettle();

        final announcement = tester.getSemantics(
          find.byKey(const Key('terminal-inactive-status-announcement')),
        );
        expect(announcement.label, contains('Home terminal exited'));
        expect(announcement.label, contains('code 137'));
      },
    );

    testWidgets(
      'GivenInactiveRunningSession_WhenTerminationFails_ThenTargetedLiveRegionAnnouncesIt',
      (tester) async {
        final fixture = await _pumpDock(
          tester,
          target: _homeTarget(),
          closure: TerminalClosure.incomplete,
        );
        await fixture.manager.create(fixture.target);
        await fixture.manager.create(fixture.target);
        await tester.pumpAndSettle();

        await fixture.manager.entries.first.controller.close();
        await tester.pumpAndSettle();

        final announcement = tester.getSemantics(
          find.byKey(const Key('terminal-inactive-status-announcement')),
        );
        expect(announcement.label, contains('Home terminal failed'));
        expect(
          announcement.label,
          contains('Some terminal processes did not stop'),
        );
      },
    );

    testWidgets(
      'GivenAFailedTarget_WhenDockRenders_ThenFailureAndRemediationAreAnnounced',
      (tester) async {
        const failure = TerminalFailure(
          code: TerminalFailure.folderUnavailableCode,
          message: 'The home folder could not be resolved.',
          remediation: 'Configure a readable home folder, then try again.',
        );
        final fixture = await _pumpDock(
          tester,
          target: TerminalLaunchTarget.failure(failure),
        );

        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(
          find.byKey(const Key('terminal-failure')),
        );
        expect(semantics.label, contains('home folder'));
        expect(semantics.label, contains('Configure a readable home folder'));
        expect(find.byType(TerminalView), findsNothing);
      },
    );

    testWidgets(
      'GivenIncompleteTermination_WhenTrashPressed_ThenFailureAndSessionRemain',
      (tester) async {
        final fixture = await _pumpDock(
          tester,
          target: _homeTarget(),
          closure: TerminalClosure.incomplete,
        );
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('kill-terminal')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('terminal-failure')), findsOneWidget);
        expect(find.byType(TerminalView), findsOneWidget);
        expect(fixture.manager.entries, hasLength(1));
        expect(
          tester.getSemantics(find.byKey(const Key('terminal-failure'))).label,
          contains('Some terminal processes did not stop'),
        );
      },
    );

    testWidgets(
      'GivenAFocusedTerminal_WhenCtrlBackquotePressed_ThenDockHidesWithoutClosing',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();
        final terminalFinder = find.byType(TerminalView);
        await tester.tap(terminalFinder);
        await tester.pump(const Duration(milliseconds: 301));
        expect(tester.binding.focusManager.primaryFocus, isNotNull);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.backquote);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.backquote);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('terminal-drawer')), findsNothing);
        expect(fixture.sessions.single.closeCallCount, 0);
        expect(fixture.workbenchFocusNode.hasFocus, isTrue);
      },
    );

    testWidgets(
      'GivenAFocusedTerminal_WhenRegularKeyPressed_ThenInputHandlingContinues',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();
        final terminalFinder = find.byType(TerminalView);

        final result = tester.widget<TerminalView>(terminalFinder).onKeyEvent!(
          tester.binding.focusManager.primaryFocus!,
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            character: 'a',
            timeStamp: Duration.zero,
          ),
        );

        expect(result, KeyEventResult.ignored);
        expect(find.byKey(const Key('terminal-drawer')), findsOneWidget);
      },
    );

    testWidgets(
      'GivenTabsAndActions_WhenSemanticsInspected_ThenSelectionPathsAndLabelsAreExposed',
      (tester) async {
        final fixture = await _pumpDock(
          tester,
          target: _projectTarget('Maestro'),
        );
        await fixture.manager.create(fixture.target);
        await fixture.manager.create(fixture.target);
        await tester.pumpAndSettle();
        final active = fixture.manager.activeEntry!;
        final inactive = fixture.manager.entries.first;

        final activeSemantics = tester.getSemantics(
          find.byKey(Key('terminal-tab-${active.id}')),
        );
        final inactiveSemantics = tester.getSemantics(
          find.byKey(Key('terminal-tab-${inactive.id}')),
        );
        expect(activeSemantics.flagsCollection.isSelected, Tristate.isTrue);
        expect(inactiveSemantics.flagsCollection.isSelected, Tristate.isFalse);
        for (final control in <Finder>[
          find.byKey(Key('terminal-tab-${active.id}')),
          find.byKey(Key('terminal-tab-${inactive.id}')),
          find.byKey(const Key('new-terminal')),
          find.byKey(const Key('kill-terminal')),
          find.byKey(const Key('collapse-terminal')),
        ]) {
          final semantics = tester.getSemantics(control);
          expect(
            semantics.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
          expect(semantics.flagsCollection.isEnabled, Tristate.isTrue);
        }
        expect(find.byTooltip(r'D:\Maestro'), findsNWidgets(2));
        expect(find.byTooltip('New terminal'), findsOneWidget);
        expect(find.byTooltip('Kill active terminal'), findsOneWidget);
        expect(find.byTooltip('Collapse terminal dock'), findsOneWidget);
        expect(
          find.bySemanticsLabel(r'Maestro. Running. D:\Maestro'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(r'Maestro 2. Running. D:\Maestro'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('New terminal'), findsOneWidget);
        expect(find.bySemanticsLabel('Kill active terminal'), findsOneWidget);
        expect(find.bySemanticsLabel('Collapse terminal dock'), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(const Key('new-terminal'))).label,
          contains('New terminal'),
        );
        expect(
          tester.getSemantics(find.byKey(const Key('kill-terminal'))).label,
          contains('Kill active terminal'),
        );
        expect(
          tester.getSemantics(find.byKey(const Key('collapse-terminal'))).label,
          contains('Collapse terminal dock'),
        );
      },
    );

    testWidgets(
      'GivenKillInFlight_WhenSemanticsInspected_ThenKillCannotBeActivated',
      (tester) async {
        final fixture = await _pumpDock(
          tester,
          target: _homeTarget(),
          delayClose: true,
        );
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        final kill = fixture.manager.killActive();
        await tester.pump();

        final killSemantics = tester.getSemantics(
          find.byKey(const Key('kill-terminal')),
        );
        expect(
          killSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
        );
        expect(killSemantics.flagsCollection.isEnabled, Tristate.isFalse);
        expect(find.bySemanticsLabel('Kill active terminal'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        fixture.sessions.single.completeClose();
        await kill;
      },
    );

    testWidgets(
      'GivenNarrowDockWithManyTabs_WhenRendered_ThenTabsScrollAndControlsStaySquare',
      (tester) async {
        tester.view.physicalSize = const Size(430, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = await _pumpDock(tester, target: _homeTarget());
        for (var index = 0; index < 5; index++) {
          await fixture.manager.create(fixture.target);
        }
        await tester.pumpAndSettle();

        final tabStrip = tester.widget<ListView>(
          find.byKey(const Key('terminal-tab-strip')),
        );
        expect(tabStrip.scrollDirection, Axis.horizontal);
        for (final key in <String>[
          'new-terminal',
          'kill-terminal',
          'collapse-terminal',
        ]) {
          expect(tester.getSize(find.byKey(Key(key))), const Size(36, 36));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'GivenLaunchTargetChanges_WhenDrawerShows_ThenCurrentTargetIsUsedWithoutRecreatingManager',
      (tester) async {
        final fixture = _DockFixture(_projectTarget('First'));
        await _pumpFixture(tester, fixture);
        fixture.target = _projectTarget('Second');

        await _pumpFixture(tester, fixture);
        fixture.drawer.show();
        await tester.pumpAndSettle();

        expect(fixture.createManagerCallCount, 1);
        expect(fixture.manager.entries.single.label, 'Second');
        expect(fixture.openRequests.single.workingDirectory, r'D:\Second');
      },
    );

    testWidgets(
      'GivenRunningSessions_WhenDockDisposed_ThenOwnedSessionsAreClosed',
      (tester) async {
        final fixture = await _pumpDock(tester, target: _homeTarget());
        await fixture.manager.show(fixture.target);
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

        expect(fixture.sessions.single.closeCallCount, 1);
      },
    );
  });
}

Future<_DockFixture> _pumpDock(
  WidgetTester tester, {
  required TerminalLaunchTarget target,
  TerminalClosure closure = TerminalClosure.closed,
  bool delayClose = false,
  bool delayOpen = false,
}) async {
  final fixture = _DockFixture(
    target,
    closure: closure,
    delayClose: delayClose,
    delayOpen: delayOpen,
  );
  await _pumpFixture(tester, fixture);
  return fixture;
}

Future<void> _pumpFixture(WidgetTester tester, _DockFixture fixture) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: maestroTheme(Brightness.light),
      home: Scaffold(
        body: Focus(
          focusNode: fixture.workbenchFocusNode,
          autofocus: true,
          child: WorkbenchTerminalDock(
            key: const Key('workbench-terminal-dock'),
            createManager: fixture.createManager,
            launchTarget: fixture.target,
            drawerController: fixture.drawer,
            onWorkbenchFocusRequested: fixture.requestWorkbenchFocus,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TerminalLaunchTarget _projectTarget(String name) =>
    TerminalLaunchTarget.project(
      projectName: name,
      workingDirectory: 'D:\\$name',
    );

TerminalLaunchTarget _homeTarget() =>
    TerminalLaunchTarget.home(workingDirectory: r'C:\Users\tester');

final class _DockFixture {
  _DockFixture(
    this.target, {
    this.closure = TerminalClosure.closed,
    this.delayClose = false,
    this.delayOpen = false,
  });

  TerminalLaunchTarget target;
  final TerminalClosure closure;
  final bool delayClose;
  final bool delayOpen;
  final drawer = ProjectTerminalDrawerController();
  final workbenchFocusNode = FocusNode(debugLabel: 'test workbench');
  final sessions = <_FakeSession>[];
  final openCompleters = <Completer<TerminalOpenResult>>[];
  final openRequests = <({String workingDirectory, int columns, int rows})>[];
  late final WorkbenchTerminalManager manager;
  var createManagerCallCount = 0;
  var workbenchFocusRequestCount = 0;

  void requestWorkbenchFocus() {
    workbenchFocusRequestCount++;
    workbenchFocusNode.requestFocus();
  }

  WorkbenchTerminalManager createManager() {
    createManagerCallCount++;
    manager = WorkbenchTerminalManager(factory: _createController);
    return manager;
  }

  ProjectTerminalController _createController(TerminalLaunchTarget target) {
    final session = _FakeSession(closure, delayClose: delayClose);
    sessions.add(session);
    final openCompleter = delayOpen ? Completer<TerminalOpenResult>() : null;
    if (openCompleter != null) openCompleters.add(openCompleter);
    return ProjectTerminalController(
      workingDirectory: target.workingDirectory ?? '',
      initialFailure: target.failure,
      terminal: Terminal(maxLines: 200),
      open:
          ({
            required String workingDirectory,
            required int columns,
            required int rows,
          }) async {
            openRequests.add((
              workingDirectory: workingDirectory,
              columns: columns,
              rows: rows,
            ));
            return openCompleter?.future ?? TerminalOpenResult.opened(session);
          },
    );
  }

  void completeOpen(int index) {
    openCompleters[index].complete(TerminalOpenResult.opened(sessions[index]));
  }
}

final class _FakeSession implements TerminalSession {
  _FakeSession(this._closure, {required bool delayClose})
    : _closeCompleter = delayClose ? Completer<TerminalClosure>() : null;

  final TerminalClosure _closure;
  final Completer<TerminalClosure>? _closeCompleter;
  final _output = StreamController<Uint8List>.broadcast();
  final _exit = Completer<TerminalExit>();
  var closeCallCount = 0;

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
    closeCallCount++;
    final result = _closeCompleter == null
        ? _closure
        : await _closeCompleter.future;
    if (result == TerminalClosure.closed) exitWith(0);
    return result;
  }

  void emit(List<int> bytes) => _output.add(Uint8List.fromList(bytes));

  void completeClose() => _closeCompleter?.complete(_closure);

  void exitWith(int code) {
    if (!_exit.isCompleted) _exit.complete(TerminalExit(code));
  }
}
