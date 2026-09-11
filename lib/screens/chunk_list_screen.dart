import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../models/chunk_scan_result.dart';

class ChunkListScreen extends StatefulWidget {
  final String worldName;
  final String worldPath;

  const ChunkListScreen({
    super.key,
    required this.worldName,
    required this.worldPath,
  });

  @override
  State<ChunkListScreen> createState() => _ChunkListScreenState();
}

class _ChunkListScreenState extends State<ChunkListScreen> {
  bool _loading = true;
  ChunkScanResult? _result;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _loading = true);
    final result = await NativeBridge.scanChunks(widget.worldPath);
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.worldName)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final result = _result;
    if (result == null || !result.success) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Não foi possível ler o banco de dados do mundo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (result?.error != null)
                Text(
                  result!.error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _scan, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }

    final chunks = result.chunks;
    if (chunks.isEmpty) {
      return const Center(child: Text('Nenhum chunk encontrado.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('${chunks.length} chunk(s) encontrado(s)'),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: chunks.length,
            itemBuilder: (context, index) {
              final chunk = chunks[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.grid_on_outlined),
                title: Text('X: ${chunk.x}, Z: ${chunk.z}'),
                subtitle: Text(chunk.dimensionName),
              );
            },
          ),
        ),
      ],
    );
  }
}
