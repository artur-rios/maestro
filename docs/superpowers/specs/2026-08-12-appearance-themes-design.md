# Appearance Themes Design

## Goal

Maestro supports an app-wide appearance preference with three modes: System,
Light, and Dark. System is the first-launch default and follows operating-system
brightness changes. The selected mode applies before authentication and after
authentication, persists across restarts, and can be changed from the global
top-right area on both screens.

## Scope

This change adds theme selection and persistence only. It does not add custom
color palettes, per-user preferences, scheduled theme changes, or broader
settings UI. The existing indigo brand seed remains unchanged.

## Architecture

Appearance is an app-level feature because it affects `MaterialApp` itself and
must be available before sign-in. It consists of three isolated units:

1. `AppearanceMode` is the application-owned representation of `system`,
   `light`, and `dark`. It maps explicitly to Flutter's `ThemeMode` at the
   presentation boundary.
2. `AppearancePreferenceRepository` reads and writes the app-wide preference.
   The production implementation uses the existing Drift `settings` table and
   the stable key `appearance.themeMode`.
3. `AppearanceController` owns the active mode and coordinates changes with the
   repository. `MaestroApp` observes this controller and configures
   `MaterialApp`.

The repository interface keeps Drift out of widgets and permits deterministic
unit and widget tests. No schema migration is required because every supported
database version already contains the `settings` table.

## Startup and Data Flow

Production composition reads the stored preference before constructing the
root app widget. A missing value selects System. An unknown value also safely
selects System so an older binary or manually edited database cannot prevent
startup.

The loaded mode initializes `AppearanceController`. `MaestroApp` supplies:

- a Material 3 light theme generated from the existing indigo seed;
- a Material 3 dark theme generated from the same seed; and
- the controller's mapped `ThemeMode`.

When System is active, Flutter resolves platform brightness and reacts to later
operating-system brightness changes without another database read.

When the user chooses a different mode, the controller retains the previous
mode, applies the new mode immediately, and writes its canonical lowercase
value to `appearance.themeMode`. A successful write makes the choice durable.
Repeated selection of the active mode is a no-op.

## User Interface

A reusable appearance selector is placed in the global top-right area:

- in the sign-in screen's app bar; and
- in the authenticated header immediately before the Sign out action.

The selector uses a familiar appearance icon and opens a menu containing
System, Light, and Dark. The active item is visibly selected. Tooltips and
semantics identify the control as `Appearance` and identify each option by
name, so keyboard and assistive-technology users receive the same information.
Changing appearance does not reset authentication, navigation, project
selection, editor state, or other presentation state.

## Persistence and Failure Handling

The preference is app-wide rather than associated with a local account, which
allows it to apply on the sign-in screen. Drift writes use an upsert so the same
operation handles first selection and later updates. `updated_at` is refreshed
on every successful change.

If the initial read fails, production composition fails through the existing
startup error path rather than silently masking database failure. If a runtime
write fails, the controller restores the previous mode and reports a bounded
failure to the selector. The selector shows a `SnackBar` explaining that the
appearance preference could not be saved. Only the most recent selection is
allowed to publish success or rollback state, preventing an older asynchronous
write from overwriting a newer user choice.

## Testing

Tests cover the behavior at each boundary:

- repository tests verify missing-value defaults, canonical parsing, unknown
  value fallback, upsert persistence, and timestamp refresh;
- controller tests verify immediate publication, successful persistence,
  same-mode no-op behavior, rollback on failure, and stale-completion safety;
- app widget tests verify System is the default, all three modes map to the
  correct `ThemeMode`, and light and dark themes have the expected brightness;
- authentication and workspace widget tests verify the selector appears in the
  top-right location before and after sign-in, exposes accessible option names,
  preserves application state, and reports persistence failure; and
- production composition tests verify a stored preference is loaded into the
  root app and a changed preference survives database reopen.

Existing feature widgets already use `Theme.of(context)` and semantic
`ColorScheme` values. The implementation will retain that pattern and will add
targeted regression coverage for any surface found to use a fixed color that
does not remain legible in both brightness modes.
