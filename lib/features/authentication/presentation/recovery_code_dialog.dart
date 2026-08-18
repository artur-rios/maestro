import 'package:flutter/material.dart';

/// Non-dismissible, one-time presentation of newly created recovery codes.
final class RecoveryCodeDialog extends StatefulWidget {
  const RecoveryCodeDialog({
    required this.recoveryCodes,
    required this.onAcknowledge,
    super.key,
  });

  final List<String> recoveryCodes;
  final VoidCallback onAcknowledge;

  @override
  State<RecoveryCodeDialog> createState() => _RecoveryCodeDialogState();
}

final class _RecoveryCodeDialogState extends State<RecoveryCodeDialog> {
  late final List<String> _plaintext = List<String>.of(widget.recoveryCodes);

  @override
  void dispose() {
    _plaintext.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Semantics(
        container: true,
        label: 'Recovery codes',
        child: AlertDialog(
          title: const Text('Record your recovery codes'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'These one-use codes are the only way to recover this '
                    'local account. Store every code somewhere safe before '
                    'continuing.',
                  ),
                  const SizedBox(height: 16),
                  for (final code in _plaintext)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: SelectableText(
                        code,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: widget.onAcknowledge,
              child: const Text('Acknowledge recovery codes'),
            ),
          ],
        ),
      ),
    );
  }
}
