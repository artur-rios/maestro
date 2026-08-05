import 'package:flutter/material.dart';

class MaestroApp extends StatelessWidget {
  const MaestroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maestro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Maestro')),
        body: Semantics(
          label: 'Foundation status',
          child: const Center(child: Text('Initializing foundation')),
        ),
      ),
    );
  }
}
