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
  bool _deleting = false;
  ChunkScanResult? _result;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _scan();
  }

  String _keyFor(ChunkCoord c) => '${c.x}_${c.z}_${c.dimension}';

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _selected.clear();
    });
    final result = await NativeBridge.scanChunks(widget.worldPath);
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  void _toggle(ChunkCoord chunk) {
    setState(() {
      final key = _keyFor(chunk);
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  Future<void> _confirmAndDelete() async {
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar chunks?'),
        content: Text(
          'Isso vai apagar $count chunk(s) permanentemente. '
          'Não tem como desfazer. Tem certeza?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final chunksToDelete = _result!.chunks
        .where((c) => _selected.contains(_keyFor(c)))
        .toList();

    setState(() => _deleting = true);
    final deleteResult = await NativeBridge.deleteChunks(
      widget.worldPath,
      chunksToDelete,
    );
    setState(() => _deleting = false);

    if (!mounted) return;

    if (deleteResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${chunksToDelete.length} chunk(s) apagado(s) '
            '(${deleteResult.deletedCount} registro(s) removido(s)).',
          ),
        ),
      );
      await _scan();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar: ${deleteResult.error}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.worldName),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleting ? null : _confirmAndDelete,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading || _deleting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_deleting) ...[
              const SizedBox(height: 12),
              const Text('Apagando...'),
            ],
          ],
        ),
      );
    }

    final result = _result;
    if (result == null || !result.success) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
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
          child: Text(
            _selected.isEmpty
                ? '${chunks.length} chunk(s) encontrado(s). Toque pra selecionar.'
                : '${_selected.length} selecionado(s)',
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: chunks.length,
            itemBuilder: (context, index) {
              final chunk = chunks[index];
              final selected = _selected.contains(_keyFor(chunk));
              return CheckboxListTile(
                dense: true,
                value: selected,
                onChanged: (_) => _toggle(chunk),
                secondary: const Icon(Icons.grid_on_outlined),
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
