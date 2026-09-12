import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../models/chunk_scan_result.dart';
import '../models/block_colors.dart';

class WorldMapScreen extends StatefulWidget {
  final String worldName;
  final String worldPath;

  const WorldMapScreen({
    super.key,
    required this.worldName,
    required this.worldPath,
  });

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  static const double tileSize = 6.0;
  static const int batchSize = 300;

  bool _loadingChunks = true;
  String? _scanError;
  List<ChunkCoord> _allChunks = [];

  int _dimension = 0;
  final Map<String, Color> _colorCache = {};
  final Set<String> _selected = {};
  bool _loadingColors = false;
  int _loadedCount = 0;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _scanWorld();
  }

  String _key(int x, int z, int dim) => '${x}_${z}_$dim';

  List<ChunkCoord> get _dimChunks =>
      _allChunks.where((c) => c.dimension == _dimension).toList();

  Future<void> _scanWorld() async {
    setState(() => _loadingChunks = true);
    final result = await NativeBridge.scanChunks(widget.worldPath);
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _loadingChunks = false;
        _scanError = result.error ?? 'Erro desconhecido';
      });
      return;
    }

    final dims = result.chunks.map((c) => c.dimension).toSet();
    setState(() {
      _allChunks = result.chunks;
      _dimension = dims.contains(0) ? 0 : (dims.isNotEmpty ? dims.first : 0);
      _loadingChunks = false;
    });
    _loadColors();
  }

  Future<void> _loadColors() async {
    setState(() => _loadingColors = true);
    final pending = _dimChunks
        .where((c) => !_colorCache.containsKey(_key(c.x, c.z, c.dimension)))
        .toList();

    for (var i = 0; i < pending.length; i += batchSize) {
      if (!mounted) return;
      final end = (i + batchSize > pending.length) ? pending.length : i + batchSize;
      final batch = pending.sublist(i, end);
      final results = await NativeBridge.getChunkColors(widget.worldPath, batch);
      if (!mounted) return;
      setState(() {
        results.forEach((key, block) {
          _colorCache[key] = BlockColors.forBlock(block);
        });
        _loadedCount += batch.length;
      });
    }

    if (mounted) setState(() => _loadingColors = false);
  }

  void _switchDimension(int dim) {
    setState(() {
      _dimension = dim;
      _selected.clear();
      _loadedCount = 0;
    });
    _loadColors();
  }

  void _handleTap(TapUpDetails details, int minX, int minZ, double effectiveTileSize) {
    final local = details.localPosition;
    final chunkX = (local.dx / effectiveTileSize).floor() + minX;
    final chunkZ = (local.dy / effectiveTileSize).floor() + minZ;

    ChunkCoord? match;
    for (final c in _dimChunks) {
      if (c.x == chunkX && c.z == chunkZ) {
        match = c;
        break;
      }
    }
    if (match == null) return;

    setState(() {
      final key = _key(match!.x, match.z, match.dimension);
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  Future<void> _confirmAndDelete() async {
    final toDelete = _dimChunks
        .where((c) => _selected.contains(_key(c.x, c.z, c.dimension)))
        .toList();
    final count = toDelete.length;

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

    setState(() => _deleting = true);
    final result = await NativeBridge.deleteChunks(widget.worldPath, toDelete);
    if (!mounted) return;
    setState(() => _deleting = false);

    if (result.success) {
      setState(() {
        final deletedKeys = _selected;
        _allChunks = _allChunks
            .where((c) => !deletedKeys.contains(_key(c.x, c.z, c.dimension)))
            .toList();
        _selected.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count chunk(s) apagado(s).')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar: ${result.error}')),
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
    if (_loadingChunks) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_scanError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Não foi possível ler o mundo.'),
              const SizedBox(height: 8),
              Text(_scanError!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _scanWorld, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }

    final chunks = _dimChunks;
    final dims = _allChunks.map((c) => c.dimension).toSet().toList()..sort();

    if (chunks.isEmpty) {
      return const Center(child: Text('Nenhum chunk nessa dimensão.'));
    }

    final xs = chunks.map((c) => c.x).toList()..sort();
    final zs = chunks.map((c) => c.z).toList()..sort();

    // Usa percentil 1%-99% em vez de minimo/maximo bruto, pra nao deixar um
    // unico chunk fora da curva (dado corrompido/distante) estourar a area
    // calculada e encolher tudo ate sumir.
    int percentile(List<int> sorted, double p) {
      final idx = (sorted.length * p).floor().clamp(0, sorted.length - 1);
      return sorted[idx];
    }

    final minX = percentile(xs, 0.01);
    final maxX = percentile(xs, 0.99);
    final minZ = percentile(zs, 0.01);
    final maxZ = percentile(zs, 0.99);

    // Protecao: se a area for grande demais, o Android nao consegue desenhar
    // um canvas gigante de uma vez so. Encolhe o tamanho de cada quadrado
    // pra caber num limite seguro.
    const maxCanvasDimension = 6000.0;
    final rawWidth = (maxX - minX + 1) * tileSize;
    final rawHeight = (maxZ - minZ + 1) * tileSize;
    final biggestSide = rawWidth > rawHeight ? rawWidth : rawHeight;
    final effectiveTileSize = biggestSide > maxCanvasDimension
        ? tileSize * (maxCanvasDimension / biggestSide)
        : tileSize;

    final width = (maxX - minX + 1) * effectiveTileSize;
    final height = (maxZ - minZ + 1) * effectiveTileSize;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'chunks: ${chunks.length} | X: $minX..$maxX | Z: $minZ..$maxZ | '
            'quadrado: ${effectiveTileSize.toStringAsFixed(2)}px',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (dims.length > 1)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: dims.map((d) {
                final label = ChunkCoord(x: 0, z: 0, dimension: d).dimensionName;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: d == _dimension,
                    onSelected: (_) => _switchDimension(d),
                  ),
                );
              }).toList(),
            ),
          ),
        if (_loadingColors)
          LinearProgressIndicator(
            value: chunks.isEmpty ? null : _loadedCount / chunks.length,
          ),
        if (_deleting) const LinearProgressIndicator(),
        Expanded(
          child: InteractiveViewer(
            maxScale: 20,
            minScale: 0.05,
            child: GestureDetector(
              onTapUp: (details) =>
                  _handleTap(details, minX, minZ, effectiveTileSize),
              child: CustomPaint(
                size: Size(width, height),
                painter: _MapPainter(
                  chunks: chunks,
                  colorCache: _colorCache,
                  selected: _selected,
                  minX: minX,
                  minZ: minZ,
                  tileSize: effectiveTileSize,
                  keyFn: _key,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<ChunkCoord> chunks;
  final Map<String, Color> colorCache;
  final Set<String> selected;
  final int minX;
  final int minZ;
  final double tileSize;
  final String Function(int, int, int) keyFn;

  _MapPainter({
    required this.chunks,
    required this.colorCache,
    required this.selected,
    required this.minX,
    required this.minZ,
    required this.tileSize,
    required this.keyFn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint();
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.red;

    for (final chunk in chunks) {
      final key = keyFn(chunk.x, chunk.z, chunk.dimension);
      final color = colorCache[key] ?? const Color(0xFFCCCCCC);
      final left = (chunk.x - minX) * tileSize;
      final top = (chunk.z - minZ) * tileSize;
      final rect = Rect.fromLTWH(left, top, tileSize, tileSize);

      fillPaint.color = color;
      canvas.drawRect(rect, fillPaint);

      if (selected.contains(key)) {
        canvas.drawRect(rect, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => true;
}
