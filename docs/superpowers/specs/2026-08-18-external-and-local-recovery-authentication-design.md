# External and Local Recovery Authentication Design

## Scope

This change extends Maestro's existing local authentication boundary with
Google authentication through Heimdall, Windows credential choices, and the
only supported recovery mechanism for password-backed local accounts.

The feature covers:

- Google browser sign-in using the OAuth 2.0 authorization-code flow with
  PKCE, followed by Heimdall `POST /api/auth/google`.
- Persisted, user-editable Google OAuth client ID and Heimdall scope UUID.
- Existing Windows-only sign-in, plus a Windows-credential alternative beside
  the password action for a local email account.
- A set of ten one-use local recovery codes issued only at local-account
  creation.
- Recovery-code password replacement; email links, password-reset APIs, and
  any other recovery channel are intentionally absent.

The API base URI is supplied through a build-time environment value and
defaults to `http://localhost:8080` for the supplied development API. It is
not an end-user setting. The persisted values are only the OAuth client ID and
the Heimdall scope UUID; neither is a secret.

## Architecture

Authentication remains feature-first and keeps secret handling at explicit
boundaries.

- `domain/` adds value types for validated OAuth client IDs, scope UUIDs,
  recovery codes, and an external session identity. It has no Flutter,
  database, HTTP, or platform imports.
- `application/` extends `AuthenticationService` with external sign-in,
  configuration, Windows-backed local sign-in, recovery-code acknowledgement,
  and password replacement. Ports own remote sign-in, browser authorization,
  configuration persistence, recovery-code persistence, and OS verification.
- `data/` implements Drift repositories, protected token/callback material,
  the Google/Heimdall HTTP adapter, and OAuth PKCE support. The browser adapter
  uses a random loopback port and accepts only the exact generated `state`.
- `platform/auth/` retains the existing native Windows/Linux verifier. The
  email-account Windows action delegates to this verifier; Windows-only
  accounts continue to call the same verifier and retain their current
  separate identity semantics.
- `presentation/` adds sign-in controls, a compact authentication
  configuration panel, a modal recovery-code acknowledgement screen, and a
  recovery-password form. The protected workspace remains gated on an
  authenticated session.

## Google and Heimdall flow

The user configures a Google desktop OAuth client ID and a Heimdall scope UUID
before Google sign-in is enabled. Empty, malformed, or missing configuration
is reported locally and does not open a browser.

On **Continue with Google**, Maestro creates a fresh PKCE verifier/challenge,
`state`, and loopback callback listener. It opens the system browser at
Google's authorization endpoint with the configured client ID, OpenID scopes,
the loopback redirect URI, and the PKCE challenge. The callback must contain
the original state and a code; mismatches, errors, duplicate callbacks,
timeouts, and listener failures leave the user signed out. Maestro exchanges
the code directly with Google for an ID token, then posts this payload to
Heimdall:

```json
{ "scopeId": "<configured UUID>", "idToken": "<Google ID token>" }
```

Maestro reads the standard Heimdall `DataOutput` envelope. A successful
response contains `token`, `expiresAt`, and `emailVerified`; the token stays
only in memory with the authenticated session and is cleared on sign-out or
expiry. Maestro does not persist a Google refresh token, does not send a
Google client secret, and does not call the API's password-recovery endpoints.

The local session actor is the JWT `sub` claim after safe, non-authoritative
payload decoding. The token itself remains the authority for remote calls; the
decoded subject is used only as Maestro's audit/workspace actor identifier. A
missing subject is a failed sign-in. Remote, transport, malformed-envelope,
and rejected-token errors are mapped to redacted user-facing authentication
failures and audit events without recording ID tokens, authorization codes,
access tokens, or response bodies containing them.

## Local Windows choices

The sign-in page keeps **Sign in with Windows**. It verifies the current OS
identity and signs into (or initially creates) the single Windows-only local
account, exactly as it does today.

For a local email/password account, the password field's submit action is
accompanied by **Use Windows credentials**. It requires the entered email to
resolve to a password-backed local account, invokes the existing native
credential verifier, and signs into that same local account only after the
verifier succeeds. It does not create a second Windows-only account, change
the password, or expose the entered email to the native channel. Failure is
indistinguishable from other authentication failures to preserve the current
non-enumeration behavior.

This action deliberately trusts the operating system's credential prompt as
the local device-credential proof. It is available only on platforms where
the existing verifier reports capability; otherwise its visible remediation is
the local password or recovery code flow.

## Recovery-code data and flow

Creating a local email/password account produces ten random, one-use recovery
codes. Each code contains 128 bits from a cryptographically secure RNG and is
formatted for transcription (for example, `ABCD-EFGH-JKLM-NPQR-TUVW`). Plain
codes exist only long enough to render the acknowledgement screen; they are
never logged, placed in audit details, persisted in settings, or returned by a
repository after account creation.

SQLite adds `local_recovery_codes` with a unique digest, owning local-user ID,
issuance time, and nullable consumed time. The digest is SHA-256 over the
canonical 128-bit code; the code's entropy makes offline guessing infeasible.
The table is not a password-verifier store. A foreign key cascades deletion
with the local user. Schema version 7 creates this table and its lookup index.

Account creation persists the local user, protected password verifier, audit
record, and code rows before opening a session. If any durable write fails,
the existing compensation path removes all newly created credentials and rows.
The UI then presents the codes once and requires an explicit acknowledgement
before workspace entry. Closing the page before acknowledgement retains the
already-created account and code set, but does not display the codes again;
the user must record them during creation.

**Recover local account** accepts a local email, one recovery code, and a new
valid password. It resolves only a password-backed local user, normalizes and
hashes the submitted code, and conditionally consumes the matching unused row
in one SQL statement. Exactly one concurrent recovery request can consume a
code. Only after successful consumption does it replace the protected Argon2
password verifier, update `lastAuthenticatedAt`, write a redacted recovery
audit event, and open the session. A verifier-write failure returns a storage
failure after the code is spent; this conservative behavior prevents code
reuse and tells the user to use another recorded code.

No recovery-code regeneration endpoint, UI, automatic reissue, email reset,
or password-reset token exists. Consequently the original creation set is the
only recovery route for the local account. Accounts without a usable recorded
code cannot be recovered by Maestro.

## Persistence and configuration

`Settings` holds these namespaced plaintext values:

- `authentication.google.oauth_client_id`
- `authentication.heimdall.scope_id`

The Google ID token, Heimdall bearer token, OAuth authorization code, PKCE
verifier, callback URI, local password, and recovery code plaintext are
ephemeral. Existing Sodium-backed password verifiers remain in protected
storage. The recovery-code database digests and account metadata contain no
recoverable authentication secret.

The session model gains an authentication source and optional remote token
expiry, while preserving `userId` for the existing application services.
Sign-out clears every in-memory session field and cancels any active OAuth
callback listener.

## Error handling and audit

All authentication operations participate in the existing generation guard:
sign-out, disposal, or a newer sign-in supersedes pending browser, remote,
Windows, recovery, and password operations. Superseded callbacks close their
listener and cannot open a session.

Failures use stable codes for configuration, browser cancellation/timeout,
callback state mismatch, Google exchange, Heimdall rejection/envelope,
recovery-code invalid/used, and recovery persistence. User-facing errors are
specific enough to remediate configuration or retry safely but never reveal
whether an email exists or whether a particular recovery code matched. Audits
record source and outcome with known/unknown principal markers only; no
passwords, codes, OAuth artifacts, or remote bearer tokens are retained.

## Presentation

The signed-out page presents a local section with email and password fields,
**Sign in**, **Use Windows credentials**, **Create local account**, **Recover
local account**, and the existing **Sign in with Windows** action. Google is a
separate external section with **Continue with Google** and a small
configuration affordance for the client ID and scope UUID. Controls disable
while their operation is active and preserve no secret text after completion
or navigation.

After a successful local-account creation, a recovery-code dialog explains
that these are the only recovery method, renders all ten codes in selectable
monospace text, and requires an acknowledgement before entering the workspace.
The recovery form asks for email, one recovery code, new password, and
confirmation; it gives no account-reset or email-link alternative.

## Testing and verification

Focused Given-When-Then tests cover:

- configuration validation and Drift persistence;
- OAuth request construction, PKCE/state validation, cancellation/timeout,
  successful ID-token exchange, Heimdall request/envelope parsing, token
  non-persistence, expiry, and redacted failure audits;
- retained Windows-only account sign-in and email-account Windows sign-in
  success, denial, unknown email, unavailable platform, and stale operations;
- ten CSPRNG recovery codes issued at creation, plaintext one-time display,
  digest-only persistence, acknowledgement gating, and creation rollback;
- successful password replacement, incorrect/used code rejection,
  concurrent redemption, verifier-write failure after consumption, and the
  absence of regeneration and email-reset paths;
- widget semantics, disabled busy controls, recovery guidance, configuration
  validation, and protected-shell gating for each authenticated source;
- schema migration from version 6 to 7 plus `dart run build_runner build` to
  regenerate Drift output.

The final verification runs `dart format --set-exit-if-changed .`, `flutter
analyze`, focused authentication tests, migration tests, and the complete
`flutter test` suite.
