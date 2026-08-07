# UC-07 verification evidence

This record traces [issue #8](https://github.com/artur-rios/maestro/issues/8)
and [UC-07](../requirements/Use%20Case%20Specification%20Document.md#uc-07-observe-active-runs)
to implementation and local verification evidence prepared for review.

- Toolchain: Flutter 3.44.9 and Dart 3.12.2.
- Local full-suite result: 602 tests passed on Windows.
- Static analysis and architecture/workflow verification: passed.
- New evidence: 45 tests across the observation domain, application service,
  Drift reads, presentation controller, panel widget, production composition,
  and a concurrent-streaming performance integration test.

## Requirement traceability

| Requirement | Implementation | Named evidence and verified outcome |
| --- | --- | --- |
| FR-OB-01 / BR-13 | `DriftRunRepository.listObservable` returns every non-deleted run of the project with its snapshot and attempts; `deriveTopology` projects them onto the ordered snapshot steps. Active runs sort before terminal ones. | `drift_run_repository_test.dart` proves ordering, project scoping, and exclusion of deleted runs; `run_observation_test.dart` proves ordered step derivation; `active_runs_panel_test.dart` renders every step of the selection. |
| FR-OB-02 / BR-13 | Per-step status is derived from the highest-numbered attempt for that snapshot step, never stored. The run's current position is highlighted and announced. | `run_observation_test.dart` covers pending, running, succeeded, failed, interrupted, retried, out-of-order, and foreign-evidence cases; the panel test asserts the current step carries `current step` in its semantics label and neighbours do not. |
| FR-OB-03 / BR-13 | Each coalesced summary triggers one incremental durable read from the last sequence already shown, so streamed output reaches the view without re-reading the window. A run announces itself when it becomes running, so a silent run is visible immediately. | `run_observation_controller_test.dart` proves a single new segment is appended after one read; `run_orchestrator_test.dart` proves the announcement is published for a run that produces no output. |
| FR-OB-04 / NFR-01 / NFR-02 | Summaries are collapsed onto one scheduled refresh, and the display window is capped at 32 KiB with the oldest chunks dropped. Durable ingestion keeps UC-06's bounded queue and 16 KiB / 25 ms coalescing. | Controller tests drive 200 summaries in one burst and assert fewer than ten durable reads; a 200 KiB load is trimmed to the display ceiling. The performance integration test streams two runs while switching selection. |
| FR-OB-05 | The channel travels with the bytes: `RunOutputChunk` pairs `RunLogChannel` with raw bytes, the orchestrator's live tail is channel-tagged, and the panel colours and labels stdout, stderr, and system distinctly. | `run_orchestrator_test.dart` proves the tail preserves an stdout/stderr/stdout sequence; `active_runs_panel_test.dart` asserts three distinct colours and `Error output` / `System output` semantics. |
| FR-OB-06 / NFR-10 | Output remains in `run_log_segments` with its channel, sequence, and raw bytes. The view reads durable storage rather than holding history in memory, and pages backwards on request. | `drift_run_repository_test.dart` covers tail, forward, and backward reads with `hasEarlier`; cross-run attempt reads fail closed. Controller and panel tests cover the load-earlier path and its failure. |
| NFR-03 | In-memory retention is bounded at three levels: the orchestrator's 64 KiB per-run tail released on completion, the 256 KiB unpersisted-output ceiling, and the controller's 32 KiB display window. | `run_orchestrator_test.dart` proves tail overflow drops the oldest chunks while every byte still reaches storage, and that a finished run retains no tail. Controller and integration tests prove the display window stays capped. |
| NFR-12 | Load, output-read, and paging failures cross the UI boundary as bounded typed codes with remediation: `run.observation.load`, `run.observation.output`, and the durable `run.step.log_persist`. | Controller tests assert each typed failure; the panel renders message plus remediation in a live region. |
| NFR-08 / IR-01 | Observation reads through a typed inward `RunObservationRepository` port. The domain projection is pure; Drift and Flutter stay outside it. | `architecture_test.dart` and `tooling/verify_architecture.dart` pass with the new domain, application, data, and presentation files. |
| IR-08 | Every observation test uses hand-written state-based fakes; no test needs a live CLI, network, or GitHub session. | The controller, service, panel, and performance suites run against in-memory fakes; repository tests use a real temporary SQLite database. |

## Use-case flow evidence

| Flow | Evidence and outcome |
| --- | --- |
| Main flow 1: open the active-runs view and select a run | `ActiveRunsPanel` lists every run of the selected project with status and branch, selects the newest actionable run by default, and follows an explicit selection. Panel tests cover the loading, empty, populated, and selection-change states. |
| Main flow 2: show ordered steps and highlight current status | Steps render in snapshot order with derived status; the current step is visually highlighted and announced as `current step`. Step rows are single semantics nodes so status is not read twice. |
| Main flow 3: stream categorized output through bounded buffers | Live summaries drive incremental durable reads; stdout, stderr, and system output stay distinguishable end to end; the display window is capped. |
| Main flow 4: persist output and stay responsive | Persistence precedes the summary, so the view never shows what storage has not accepted. Bursts are coalesced, older output is read on demand, and the performance test navigates between two flooding runs without unbounded growth. |
| AF-01: output exceeds rendering capacity | 200 summaries in one burst collapse to fewer than ten reads and one bounded window; durable segment counts show every byte was retained in order. |
| AF-02: undecodable bytes | `RunOutputChunk.text` decodes with `allowMalformed`, so a truncated multi-byte rune renders as U+FFFD with its neighbours intact, while `bytes` returns the original sequence unmodified and unmodifiable. |
| AF-03: persistence temporarily fails | A failed durable write flips the run to degraded and buffers the batch in order. Recovery replays buffered batches oldest-first with contiguous sequences and no byte loss, and the run completes. A never-recovering outage fails the attempt with `run.step.log_persist` once the 256 KiB ceiling would be crossed, and again if unpersisted output remains when the stream closes. The panel reports degradation in a live region. |

## Behaviour changed in UC-06 code

- A permanent `appendLog` failure previously ended the attempt as
  `run.step.stream_failed`. It now reports degraded durability, buffers a
  bounded amount of output, retries in order, and ends the attempt as
  `run.step.log_persist` only when the buffer would grow unbounded or when
  unpersisted output remains at stream close. The UC-06 expectation was updated
  to the new code.
- The orchestrator's live tail is now channel-tagged and exposed as
  `outputTailFor`. It retains its UC-06 role of bounding and releasing
  in-memory retention; the observation view reads durable storage instead,
  because only durable sequences support exact backward paging.
- `RunSummaryEvents.first` became `firstOutput` and skips run announcements. It
  had no production caller.
- `RunStartPanel` no longer renders output. Observation is one view covering
  runs from this session and earlier ones alike.

## Local verification commands

```text
dart format --output=none --set-exit-if-changed lib test integration_test test_support tooling
# Exit 0; Formatted 201 files (0 changed).

flutter analyze
# Exit 0; No issues found.

dart run tooling/verify_architecture.dart
# Exit 0; architecture-verification: passed.

dart run tooling/verify_workflows.dart
# Exit 0; workflow-verification: passed.

flutter test
# Exit 0; 602 tests passed.
```

Focused counts for the suites added or changed by this use case:

```text
flutter test test/features/runs/domain/run_observation_test.dart                    # 11 passed
flutter test test/features/runs/application/observe_runs_test.dart                   #  6 passed
flutter test test/features/runs/application/run_orchestrator_test.dart               # 34 passed
flutter test test/features/runs/data/drift_run_repository_test.dart                  # 25 passed
flutter test test/features/runs/presentation/run_observation_controller_test.dart    # 15 passed
flutter test test/features/runs/presentation/active_runs_panel_test.dart             # 11 passed
flutter test test/app/production_run_observation_composition_test.dart               #  1 passed
flutter test integration_test/performance/run_observation_integration_test.dart      #  1 passed
```

## Platform and delivery status

- Windows: the full 602-test suite, analysis, and both repository verifiers
  passed locally against the pinned toolchain.
- Linux: not run locally. The Ubuntu `flutter test --coverage` job on the pull
  request is the evidence for that platform.
- GitHub Actions: `analyze-test`, `linux-platform`, and `windows-platform`
  results are recorded on the pull request.
- Pull-request, merge, issue-closure, and cleanup evidence is added by the
  delivery step after explicit publication approval.
