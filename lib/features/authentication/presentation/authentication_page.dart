import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/features/appearance/presentation/appearance_controller.dart';
import 'package:maestro/features/appearance/presentation/appearance_selector.dart';
import 'package:maestro/features/authentication/presentation/authentication_controller.dart';

final class AuthenticationPage extends ConsumerWidget {
  const AuthenticationPage({
    required this.appearanceController,
    required this.authenticatedBuilder,
    super.key,
  });

  final AppearanceController appearanceController;
  final WidgetBuilder authenticatedBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authenticationControllerProvider);
    if (state is AuthenticationAuthenticated) {
      return _AuthenticatedShell(
        appearanceController: appearanceController,
        authenticatedBuilder: authenticatedBuilder,
      );
    }
    return _AuthenticationForm(
      appearanceController: appearanceController,
      state: state,
    );
  }
}

final class _AuthenticatedShell extends ConsumerWidget {
  const _AuthenticatedShell({
    required this.appearanceController,
    required this.authenticatedBuilder,
  });

  final AppearanceController appearanceController;
  final WidgetBuilder authenticatedBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      child: Column(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppearanceSelector(controller: appearanceController),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(authenticationControllerProvider.notifier)
                          .signOut(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: authenticatedBuilder(context)),
        ],
      ),
    );
  }
}

final class _AuthenticationForm extends ConsumerStatefulWidget {
  const _AuthenticationForm({
    required this.appearanceController,
    required this.state,
  });

  final AppearanceController appearanceController;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maestro'),
        actions: [AppearanceSelector(controller: widget.appearanceController)],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or use email and password'),
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
                    const SizedBox(height: 12),
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
                            AuthenticationFailureCategory
                                .passwordPolicy) ...<Widget>[
                      const SizedBox(height: 12),
                      const Text(
                        'Password must contain at least 8 characters.',
                      ),
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
              ),
            ),
          ),
        ),
      ),
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

final class _AuthenticationErrorMessage extends StatelessWidget {
  const _AuthenticationErrorMessage({required this.error});

  final AuthenticationError error;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Authentication error',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
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
