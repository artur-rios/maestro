import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/app/maestro_form_spacing.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/app/maestro_window_chrome.dart';
import 'package:maestro/features/appearance/presentation/appearance_controller.dart';
import 'package:maestro/features/appearance/presentation/appearance_selector.dart';
import 'package:maestro/features/authentication/presentation/authentication_controller.dart';
import 'package:maestro/platform/window/desktop_window_port.dart';

typedef AuthenticatedWorkspaceBuilder =
    Widget Function(
      BuildContext context,
      ValueChanged<String?> onWorkspaceLabelChanged,
    );

final class AuthenticationPage extends ConsumerStatefulWidget {
  const AuthenticationPage({
    required this.appearanceController,
    required this.authenticatedBuilder,
    required this.window,
    this.authenticatedWorkspaceBuilder,
    super.key,
  });

  final AppearanceController appearanceController;
  final WidgetBuilder authenticatedBuilder;
  final AuthenticatedWorkspaceBuilder? authenticatedWorkspaceBuilder;
  final DesktopWindowPort window;

  @override
  ConsumerState<AuthenticationPage> createState() => _AuthenticationPageState();
}

final class _AuthenticationPageState extends ConsumerState<AuthenticationPage> {
  String? _authenticatedUserId;
  String? _workspaceLabel;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authenticationControllerProvider);
    final authenticated = state is AuthenticationAuthenticated;
    final authenticatedUserId = authenticated ? state.session.userId : null;
    if (_authenticatedUserId != authenticatedUserId) {
      _authenticatedUserId = authenticatedUserId;
      _workspaceLabel = null;
    }
    final workspaceLabel = _workspaceLabel;
    return MaestroWindowChrome(
      window: widget.window,
      title: authenticated && workspaceLabel != null
          ? 'Maestro — $workspaceLabel'
          : 'Maestro',
      actions: <Widget>[
        AppearanceSelector(controller: widget.appearanceController),
        if (authenticated)
          TextButton.icon(
            onPressed: () =>
                ref.read(authenticationControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
      ],
      child: authenticated
          ? widget.authenticatedWorkspaceBuilder?.call(
                  context,
                  _changeWorkspaceLabel,
                ) ??
                widget.authenticatedBuilder(context)
          : _AuthenticationForm(state: state),
    );
  }

  void _changeWorkspaceLabel(String? label) {
    if (!mounted || label == _workspaceLabel) return;
    setState(() => _workspaceLabel = label);
  }
}

final class _AuthenticationForm extends ConsumerStatefulWidget {
  const _AuthenticationForm({required this.state});

  final AuthenticationPresentationState state;

  @override
  ConsumerState<_AuthenticationForm> createState() =>
      _AuthenticationFormState();
}

final class _AuthenticationFormState
    extends ConsumerState<_AuthenticationForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _creatingAccount = false;

  @override
  void dispose() {
    _passwordController.clear();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.state is AuthenticationInProgress;
    final error = switch (widget.state) {
      AuthenticationError value => value,
      _ => null,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final formPanel = _AuthenticationFormPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Local authentication',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy ? null : _signInWithOperatingSystem,
                icon: const Icon(Icons.lock_person),
                label: const Text('Sign in with your operating system'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Divider()),
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or use email and password',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              if (error != null) ...<Widget>[
                _AuthenticationErrorMessage(error: error),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                enabled: !busy,
                autofillHints: const <String>[AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: MaestroFormSpacing.fieldToField),
              TextField(
                controller: _passwordController,
                enabled: !busy,
                autofillHints: const <String>[AutofillHints.password],
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: busy ? null : (_) => _submitEmail(),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_creatingAccount &&
                  error?.category !=
                      AuthenticationFailureCategory.passwordPolicy) ...<Widget>[
                const SizedBox(height: MaestroFormSpacing.fieldToField),
                const Text('Password must contain at least 8 characters.'),
                const Text('Choose a strong, unique password.'),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : _submitEmail,
                child: Text(
                  _creatingAccount
                      ? 'Create account'
                      : 'Sign in with email and password',
                ),
              ),
              TextButton(
                onPressed: busy ? null : _toggleAccountMode,
                child: Text(
                  _creatingAccount
                      ? 'Back to sign in'
                      : 'Create a local account',
                ),
              ),
              if (busy) ...<Widget>[
                const SizedBox(height: 8),
                Center(
                  child: Semantics(
                    label: 'Authentication in progress',
                    child: const CircularProgressIndicator(),
                  ),
                ),
              ],
            ],
          ),
        );
        if (constraints.maxWidth < 760) {
          return _AuthenticationFormPane(child: formPanel);
        }
        return Row(
          children: <Widget>[
            const Expanded(child: _AuthenticationIdentityPanel()),
            Expanded(child: _AuthenticationFormPane(child: formPanel)),
          ],
        );
      },
    );
  }

  void _toggleAccountMode() {
    _passwordController.clear();
    ref.read(authenticationControllerProvider.notifier).clearError();
    setState(() => _creatingAccount = !_creatingAccount);
  }

  Future<void> _signInWithOperatingSystem() {
    _passwordController.clear();
    if (_creatingAccount) {
      setState(() => _creatingAccount = false);
    }
    return ref
        .read(authenticationControllerProvider.notifier)
        .signInWithOperatingSystem();
  }

  Future<void> _submitEmail() {
    final email = _emailController.text;
    final password = _passwordController.text;
    _passwordController.clear();
    final controller = ref.read(authenticationControllerProvider.notifier);
    return _creatingAccount
        ? controller.createAccount(email, password)
        : controller.signInWithEmail(email, password);
  }
}

final class _AuthenticationIdentityPanel extends StatelessWidget {
  const _AuthenticationIdentityPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('authentication-identity-panel'),
      color: theme.colorScheme.surfaceContainerLow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.account_tree_outlined,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text('Maestro', style: theme.textTheme.displaySmall),
                  const SizedBox(height: 12),
                  Text(
                    'Your local workspace for projects, workflows, and runs.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _AuthenticationFormPane extends StatelessWidget {
  const _AuthenticationFormPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: child,
        ),
      ),
    );
  }
}

final class _AuthenticationFormPanel extends StatelessWidget {
  const _AuthenticationFormPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('authentication-form-panel'),
      constraints: const BoxConstraints(maxWidth: 420),
      child: child,
    );
  }
}

final class _AuthenticationErrorMessage extends StatelessWidget {
  const _AuthenticationErrorMessage({required this.error});

  final AuthenticationError error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = MaestroThemeTokens.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Authentication error',
      child: DecoratedBox(
        key: const Key('authentication-error-feedback'),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          border: Border(left: BorderSide(color: tokens.destructive, width: 3)),
          borderRadius: BorderRadius.circular(tokens.smallRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(error.message),
              if (error.remediation case final remediation?) Text(remediation),
            ],
          ),
        ),
      ),
    );
  }
}
