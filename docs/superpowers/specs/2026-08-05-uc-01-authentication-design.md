# UC-01 Local Authentication Design

## Scope and traceability

This design implements UC-01 and FR-AU-01 through FR-AU-07. It establishes a
local full-control session through either operating-system verification or a
local email/password account. It also implements BR-21 and keeps protected
features unavailable until authentication succeeds.

The alternative flows map as follows:

- AF-01: an unavailable, denied, or failed operating-system verifier leaves the
  session unauthenticated and returns an email/password fallback action.
- AF-02: account creation rejects passwords shorter than eight characters and
  returns the exact minimum plus strength guidance.
- AF-03: normalized duplicate email addresses are rejected before verifier
  creation or protected-storage mutation.
- AF-04: invalid credentials leave the session unauthenticated and append a
  redacted failure audit event.

## Architecture

Authentication follows the existing feature-first MVVM boundaries.

- `domain/` owns normalized email, password validation, local-user metadata,
  authentication method, session permissions, and typed authentication
  failures. It has no Flutter, Drift, Sodium, or platform imports.
- `application/` owns `AuthenticationService` and repository/crypto/audit
  interfaces. The service is the only place that transitions session state.
- `data/` implements user and audit repositories with Drift and stores password
  verifier bytes through the existing `ProtectedStorage` boundary.
- `platform/auth/` retains `AuthenticationPort` for operating-system
  verification and adds a platform-channel implementation. Native Windows and
  Linux hosts are responsible for their supported credential prompts.
- `presentation/` provides a Riverpod controller and an authentication page.
  The protected application shell is rendered only for an authenticated
  session.

## Data and security

Schema version 2 adds `local_users` and `audit_events`. A local user stores a
UUIDv7 identifier, optional normalized email, authentication method, protected
verifier key, creation time, and last-authenticated time. Password text never
enters SQLite. `ProtectedStorage` stores only UTF-8 bytes of Sodium's salted
Argon2 verifier string under `maestro.auth.verifier.<user-id>`.

`SodiumPasswordHasher` initializes `SodiumSumo`, performs `pwhash.str` and
`strVerify` in Sodium-supported isolates, and uses interactive limits. Plaintext
password values are scoped to the command and are never included in failures,
logs, state descriptions, or audit details.

Audit events contain stable IDs, an actor UUID, action, target, outcome,
timestamp, and JSON details. Unknown-principal failures use a fresh UUIDv7 actor
identifier and the details value `{\"principal\":\"unknown\"}`; attempted email
text and password material are never retained.

## Application flows

Account creation normalizes the email, validates password length, checks
uniqueness, creates a Sodium verifier, writes it to protected storage, persists
the local-user record, writes a success audit event, and opens a full-control
session. A persistence failure deletes a newly written verifier before returning
failure.

Email sign-in resolves the normalized email, reads and verifies the protected
verifier, writes a redacted success or failure audit event, updates
`lastAuthenticatedAt`, and opens a full-control session only on success.

Operating-system sign-in invokes `AuthenticationPort`. Success resolves or
creates the single OS-auth local-user record, writes audit evidence, and opens a
full-control session. Failure preserves the signed-out state and exposes the
email/password fallback.

Sign-out clears only in-memory session state; it does not delete local-user or
audit records.

## Presentation

`AuthenticationPage` offers operating-system sign-in, email/password sign-in,
and local-account creation. Password fields obscure input. Validation and
dependency failures remain visible without exposing secrets. Strength guidance
is always present during account creation. Once authenticated, the current
foundation shell is shown as protected content with a sign-out action.

## Testing

Given-When-Then tests cover normalization, minimum length, duplicate rejection,
OS fallback, successful account creation and sign-in, invalid credentials,
redacted audits, full-control authorization, protected-storage rollback, widget
guidance, protected-shell gating, and sign-out. Drift tests use an in-memory
database; crypto and OS boundaries use hand-written fakes. A Sodium contract test
proves a generated verifier accepts only the original password without asserting
its encoded contents. The final gate runs the unfiltered `flutter test` suite.

## Gate 1 self-review

- Every UC-01 alternative flow has a concrete failure path above.
- FR-AU-01 through FR-AU-07 all exist in the System Requirements Document.
- Every implementation task below begins with a failing focused test.
- The flow semantics are single-valued: failure never authenticates, duplicate
  normalized email never mutates storage, and authenticated sessions always have
  full local permissions.

