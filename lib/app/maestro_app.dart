import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maestro/features/foundation/application/foundation_probe.dart';
import 'package:maestro/features/foundation/presentation/foundation_controller.dart';
import 'package:maestro/features/foundation/presentation/foundation_page.dart';

class MaestroApp extends StatelessWidget {
  const MaestroApp({
    this.foundationProbes = const <FoundationProbe>[],
    super.key,
  });

  final List<FoundationProbe> foundationProbes;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [foundationProbesProvider.overrideWithValue(foundationProbes)],
      child: MaterialApp(
        title: 'Maestro',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: const FoundationPage(),
      ),
    );
  }
}
