import 'package:flutter/material.dart';
import 'package:maestro/features/appearance/domain/appearance_mode.dart';
import 'package:maestro/features/appearance/presentation/appearance_controller.dart';

final class AppearanceSelector extends StatelessWidget {
  const AppearanceSelector({required this.controller, super.key});

  final AppearanceController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppearanceMode>(
      tooltip: 'Appearance',
      icon: const Icon(Icons.brightness_6_outlined),
      onSelected: (mode) async {
        final saved = await controller.select(mode);
        if (!saved && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appearance preference could not be saved.'),
            ),
          );
        }
      },
      itemBuilder: (_) => [
        for (final mode in AppearanceMode.values)
          CheckedPopupMenuItem<AppearanceMode>(
            value: mode,
            checked: mode == controller.mode,
            child: Text(switch (mode) {
              AppearanceMode.system => 'System',
              AppearanceMode.light => 'Light',
              AppearanceMode.dark => 'Dark',
            }),
          ),
      ],
    );
  }
}
