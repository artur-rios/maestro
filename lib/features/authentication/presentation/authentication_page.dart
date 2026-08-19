import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/app/maestro_form_spacing.dart';
import 'package:maestro/app/maestro_theme_tokens.dart';
import 'package:maestro/app/maestro_window_chrome.dart';
import 'package:maestro/features/appearance/presentation/appearance_controller.dart';
import 'package:maestro/features/appearance/presentation/appearance_selector.dart';
import 'package:maestro/features/authentication/presentation/authentication_controller.dart';
import 'package:maestro/features/authentication/presentation/authentication_settings_controller.dart';
import 'package:maestro/features/authentication/presentation/recovery_code_dialog.dart';
import 'package:maestro/platform/common/capability.dart';
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
  late final AuthenticationController _authenticationController;
  String? _authenticatedUserId;
  String? _workspaceLabel;

  @override
  void initState() {
    super.initState();
    _authenticationController = ref.read(
      authenticationControllerProvider.notifier,
    );
  }

  @override
  void dispose() {
    _authenticationController.abandonRecoveryCodePresentation();
    super.dispose();
  }

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
    final pageContent = authenticated
        ? widget.authenticatedWorkspaceBuilder?.call(
                context,
                _changeWorkspaceLabel,
              ) ??
              widget.authenticatedBuilder(context)
        : _AuthenticationForm(state: state);
    final recoveryCodes = switch (state) {
      AuthenticationRecoveryCodesPending(:final recoveryCodes) => recoveryCodes,
      _ => null,
    };
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
      child: recoveryCodes == null
          ? pageContent
          : Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ExcludeFocus(excluding: true, child: pageContent),
                const ModalBarrier(dismissible: false, color: Colors.black54),
                Center(
                  child: RecoveryCodeDialog(
                    recoveryCodes: recoveryCodes,
                    onAcknowledge: ref
                        .read(authenticationControllerProvider.notifier)
                        .acknowledgeRecoveryCodes,
                  ),
                ),
              ],
            ),
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
  final TextEditingController _recoveryEmailController =
      TextEditingController();
  final TextEditingController _recoveryCodeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _googleClientIdController =
      TextEditingController();
  final TextEditingController _heimdallScopeController =
      TextEditingController();
  bool _creatingAccount = false;
  bool _recoveringAccount = false;
  bool _settingsExpanded = false;
  bool _settingsInitialized = false;
  bool _recoveryPasswordsMismatch = false;

  @override
  void dispose() {
    _clearSecretText();
    _passwordController.dispose();
    _emailController.dispose();
    _recoveryEmailController.dispose();
    _recoveryCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _googleClientIdController.dispose();
    _heimdallScopeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authenticationInProgress = widget.state is AuthenticationInProgress;
    final busy =
        authenticationInProgress ||
        widget.state is AuthenticationRecoveryCodesPending;
    final error = switch (widget.state) {
      AuthenticationError value => value,
      _ => null,
    };
    final settingsState = ref.watch(authenticationSettingsControllerProvider);
    final operatingSystemCapability = ref.watch(
      operatingSystemAuthenticationCapabilityProvider,
    );
    final localWindowsAvailable = switch (operatingSystemCapability) {
      AsyncData(:final value) => value.state == CapabilityState.available,
      _ => false,
    };
    final localWindowsUnavailable = switch (operatingSystemCapability) {
      AsyncData(:final value) => value.state != CapabilityState.available,
      AsyncError() => true,
      _ => false,
    };
    if (!_settingsInitialized &&
        settingsState is! AuthenticationConfigurationLoading) {
      _settingsInitialized = true;
      _googleClientIdController.text = settingsState.clientId;
      _heimdallScopeController.text = settingsState.scopeId;
    }
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
              const SizedBox(height: MaestroFormSpacing.sectionToControl),
              FilledButton.icon(
                onPressed: busy ? null : _signInWithOperatingSystem,
                icon: const Icon(Icons.lock_person),
                label: const Text('Sign in with Windows'),
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
                          'or use a local account',
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
                const SizedBox(height: MaestroFormSpacing.feedback),
              ],
              if (_recoveringAccount)
                _buildRecoveryForm(busy)
              else
                _buildLocalAccountForm(
                  busy,
                  error,
                  localWindowsAvailable: localWindowsAvailable,
                  localWindowsUnavailable: localWindowsUnavailable,
                ),
              const SizedBox(height: MaestroFormSpacing.sectionToControl),
              const Divider(),
              const SizedBox(height: MaestroFormSpacing.sectionToControl),
              Text(
                'External authentication',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: MaestroFormSpacing.sectionToControl),
              FilledButton.icon(
                onPressed: busy || !settingsState.googleSignInEnabled
                    ? null
                    : _signInWithGoogle,
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Continue with Google'),
              ),
              TextButton.icon(
                onPressed: busy ? null : _toggleSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Authentication settings'),
              ),
              if (_settingsExpanded)
                _buildAuthenticationSettings(busy, settingsState),
              if (authenticationInProgress) ...<Widget>[
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

  Widget _buildLocalAccountForm(
    bool busy,
    AuthenticationError? error, {
    required bool localWindowsAvailable,
    required bool localWindowsUnavailable,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
        const SizedBox(height: MaestroFormSpacing.controlToAction),
        if (_creatingAccount)
          FilledButton(
            onPressed: busy ? null : _submitEmail,
            child: const Text('Create local account'),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : _submitEmail,
                  child: const Text('Sign in'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy || !localWindowsAvailable
                      ? null
                      : _signInWithLocalWindowsCredentials,
                  child: const Text('Use Windows credentials'),
                ),
              ),
            ],
          ),
        if (!_creatingAccount && localWindowsUnavailable) ...<Widget>[
          const SizedBox(height: 8),
          const Text(
            'Windows credentials are unavailable. '
            'Use your local password or a recovery code.',
          ),
        ],
        TextButton(
          onPressed: busy ? null : _toggleAccountMode,
          child: Text(
            _creatingAccount ? 'Back to sign in' : 'Create local account',
          ),
        ),
        if (!_creatingAccount)
          TextButton(
            onPressed: busy ? null : _showRecoveryForm,
            child: const Text('Recover local account'),
          ),
      ],
    );
  }

  Widget _buildRecoveryForm(bool busy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Local account recovery',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: MaestroFormSpacing.sectionToControl),
        TextField(
          controller: _recoveryEmailController,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Recovery email address',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: MaestroFormSpacing.fieldToField),
        TextField(
          controller: _recoveryCodeController,
          enabled: !busy,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Recovery code',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: MaestroFormSpacing.fieldToField),
        TextField(
          controller: _newPasswordController,
          enabled: !busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'New password',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: MaestroFormSpacing.fieldToField),
        TextField(
          controller: _confirmPasswordController,
          enabled: !busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: busy ? null : (_) => _recoverLocalAccount(),
          decoration: const InputDecoration(
            labelText: 'Confirm new password',
            border: OutlineInputBorder(),
          ),
        ),
        if (_recoveryPasswordsMismatch) ...<Widget>[
          const SizedBox(height: MaestroFormSpacing.feedback),
          Text(
            'New passwords do not match.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: MaestroFormSpacing.controlToAction),
        FilledButton(
          onPressed: busy ? null : _recoverLocalAccount,
          child: const Text('Recover local account'),
        ),
        TextButton(
          onPressed: busy ? null : _hideRecoveryForm,
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }

  Widget _buildAuthenticationSettings(
    bool busy,
    AuthenticationConfigurationState settingsState,
  ) {
    final settingsBusy = busy || settingsState.settingsBusy;
    return Padding(
      padding: const EdgeInsets.only(top: MaestroFormSpacing.fieldToField),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _googleClientIdController,
            enabled: !settingsBusy,
            onChanged: (_) => _updateSettingsInput(),
            decoration: const InputDecoration(
              labelText: 'Google OAuth client ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: MaestroFormSpacing.fieldToField),
          TextField(
            controller: _heimdallScopeController,
            enabled: !settingsBusy,
            onChanged: (_) => _updateSettingsInput(),
            decoration: const InputDecoration(
              labelText: 'Heimdall scope UUID',
              border: OutlineInputBorder(),
            ),
          ),
          if (settingsState is AuthenticationConfigurationError) ...<Widget>[
            const SizedBox(height: MaestroFormSpacing.feedback),
            Text(
              settingsState.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: MaestroFormSpacing.controlToAction),
          FilledButton.tonal(
            onPressed: settingsBusy ? null : _saveSettings,
            child: const Text('Save authentication settings'),
          ),
        ],
      ),
    );
  }

  void _toggleAccountMode() {
    _passwordController.clear();
    ref.read(authenticationControllerProvider.notifier).clearError();
    setState(() => _creatingAccount = !_creatingAccount);
  }

  void _showRecoveryForm() {
    _passwordController.clear();
    _recoveryEmailController.text = _emailController.text;
    ref.read(authenticationControllerProvider.notifier).clearError();
    setState(() {
      _creatingAccount = false;
      _recoveringAccount = true;
      _recoveryPasswordsMismatch = false;
    });
  }

  void _hideRecoveryForm() {
    _clearRecoverySecretText();
    ref.read(authenticationControllerProvider.notifier).clearError();
    setState(() {
      _recoveringAccount = false;
      _recoveryPasswordsMismatch = false;
    });
  }

  void _toggleSettings() {
    setState(() => _settingsExpanded = !_settingsExpanded);
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

  Future<void> _signInWithLocalWindowsCredentials() {
    _passwordController.clear();
    return ref
        .read(authenticationControllerProvider.notifier)
        .signInWithLocalWindowsCredentials(_emailController.text);
  }

  Future<void> _signInWithGoogle() {
    _passwordController.clear();
    _clearRecoverySecretText();
    return ref
        .read(authenticationControllerProvider.notifier)
        .signInWithGoogle();
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

  Future<void> _recoverLocalAccount() {
    final email = _recoveryEmailController.text;
    final recoveryCode = _recoveryCodeController.text;
    final newPassword = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;
    _clearRecoverySecretText();
    if (newPassword != confirmation) {
      setState(() => _recoveryPasswordsMismatch = true);
      return Future<void>.value();
    }
    setState(() => _recoveryPasswordsMismatch = false);
    return ref
        .read(authenticationControllerProvider.notifier)
        .recoverLocalAccount(email, recoveryCode, newPassword);
  }

  void _updateSettingsInput() {
    ref
        .read(authenticationSettingsControllerProvider.notifier)
        .updateInput(
          clientId: _googleClientIdController.text,
          scopeId: _heimdallScopeController.text,
        );
  }

  Future<void> _saveSettings() {
    return ref
        .read(authenticationSettingsControllerProvider.notifier)
        .save(_googleClientIdController.text, _heimdallScopeController.text);
  }

  void _clearSecretText() {
    _passwordController.clear();
    _clearRecoverySecretText();
  }

  void _clearRecoverySecretText() {
    _recoveryCodeController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
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
