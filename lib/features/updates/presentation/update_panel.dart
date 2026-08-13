import 'package:flutter/material.dart';
import 'package:maestro/features/updates/presentation/update_controller.dart';

final class UpdatePanel extends StatefulWidget {
  const UpdatePanel({required this.createController, super.key});
  final UpdateController Function() createController;
  @override
  State<UpdatePanel> createState() => _UpdatePanelState();
}

final class _UpdatePanelState extends State<UpdatePanel> {
  late final controller = widget.createController()..addListener(_changed);
  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final candidate = state.candidate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Application updates',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final checkAction = OutlinedButton(
                  onPressed: state.checking ? null : controller.check,
                  child: const Text('Check for updates'),
                );
                if (constraints.maxWidth < 520) {
                  return SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: checkAction,
                  );
                }
                return Align(
                  alignment: Alignment.centerLeft,
                  child: checkAction,
                );
              },
            ),
            if (state.checking) const LinearProgressIndicator(),
            if (candidate != null) ...[
              Text('Version ${candidate.verified.manifest.version}'),
              Text(
                '${candidate.artifact.packageType} · ${candidate.artifact.size} bytes',
              ),
              Text(
                'Published ${candidate.verified.manifest.publishedAt.toIso8601String()}',
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: state.installing
                        ? null
                        : () => controller.install(approved: false),
                    child: const Text('Decline update'),
                  ),
                  FilledButton(
                    onPressed: state.installing
                        ? null
                        : () => controller.install(approved: true),
                    child: const Text('Download and install'),
                  ),
                ],
              ),
            ],
            if (state.installing) const LinearProgressIndicator(),
            if (state.message case final message?)
              Semantics(liveRegion: true, child: Text(message)),
          ],
        ),
      ),
    );
  }
}
