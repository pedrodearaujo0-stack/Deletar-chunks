import 'package:flutter/material.dart';
import 'screens/world_selector_screen.dart';

void main() {
  runApp(const ChunkToolApp());
}

class ChunkToolApp extends StatelessWidget {
  const ChunkToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chunk Tool',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const WorldSelectorScreen(),
    );
  }
}
