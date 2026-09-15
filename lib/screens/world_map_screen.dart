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
  final Map<String, ChunkSurface> _surfaceCache = {};
  final Set<String> _selected = {};
  bool _loadingColors = false;
  int _loadedCount = 0;
  bool _deleting = false;
  bool _saving = false;

  final TransformationController _transformController = TransformationController();
  final GlobalKey _viewportKey = GlobalKey();
  bool _didInitialFit = false;

  bool _selectionMode = false;
  bool _showFullMap = false;
  Offset? _dragStart;
  Offset? _dragCurrent;

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
        .where((c) => !_surfaceCache.containsKey(_key(c.x, c.z, c.dimension)))
        .toList();

    for (var i = 0; i < pending.length; i += batchSize) {
      if (!mounted) return;
      final end = (i + batchSize > pending.length) ? pending.length : i + batchSize;
      final batch = pending.sublist(i, end);
      final results = await NativeBridge.getChunkColors(widget.worldPath, batch);
      if (!mounted) return;
      setState(() {
        results.forEach((key, surface) {
          _surfaceCache[key] = surface;
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
      _didInitialFit = false;
    });
    _loadColors();
  }

  void _tryInitialFit(double contentWidth, double contentHeight) {
    if (_didInitialFit) return;
    final renderBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final viewportSize = renderBox.size;
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;

    final scaleX = viewportSize.width / contentWidth;
    final scaleY = viewportSize.height / contentHeight;
    final scale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.02, 1.0);

    final dx = (viewportSize.width - contentWidth * scale) / 2;
    final dy = (viewportSize.height - contentHeight * scale) / 2;

    _transformController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
    _didInitialFit = true;
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

  void _commitDragSelection(int minX, int minZ, double effectiveTileSize) {
    final start = _dragStart;
    final current = _dragCurrent;
    if (start == null || current == null) {
      setState(() {
        _dragStart = null;
        _dragCurrent = null;
      });
      return;
    }

    final left = start.dx < current.dx ? start.dx : current.dx;
    final right = start.dx > current.dx ? start.dx : current.dx;
    final top = start.dy < current.dy ? start.dy : current.dy;
    final bottom = start.dy > current.dy ? start.dy : current.dy;

    final chunkXMin = (left / effectiveTileSize).floor() + minX;
    final chunkXMax = (right / effectiveTileSize).floor() + minX;
    final chunkZMin = (top / effectiveTileSize).floor() + minZ;
    final chunkZMax = (bottom / effectiveTileSize).floor() + minZ;

    setState(() {
      for (final c in _dimChunks) {
        if (c.x >= chunkXMin && c.x <= chunkXMax && c.z >= chunkZMin && c.z <= chunkZMax) {
          _selected.add(_key(c.x, c.z, c.dimension));
        }
      }
      _dragStart = null;
      _dragCurrent = null;
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

  Future<void> _saveWorld() async {
    setState(() => _saving = true);
    final suggestedName = '${widget.worldName}_editado.mcworld';
    final success =
        await NativeBridge.saveWorldAsMcworld(widget.worldPath, suggestedName);
    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Mundo salvo. Toque no arquivo pra reimportar no Minecraft.'
              : 'Não foi possível salvar (ou foi cancelado).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.worldName),
        actions: [
          IconButton(
            icon: Icon(_showFullMap ? Icons.grid_on : Icons.grid_off),
            tooltip: _showFullMap
                ? 'Mostrar só chunks carregados'
                : 'Mostrar mapa completo (com áreas não geradas)',
            onPressed: () => setState(() => _showFullMap = !_showFullMap),
          ),
          IconButton(
            icon: Icon(_selectionMode ? Icons.crop_free : Icons.select_all),
            tooltip: _selectionMode
                ? 'Sair do modo de seleção por área'
                : 'Selecionar área (arrastar)',
            onPressed: () => setState(() {
              _selectionMode = !_selectionMode;
              _dragStart = null;
              _dragCurrent = null;
            }),
          ),
          IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            tooltip: 'Salvar mundo (.mcworld)',
            onPressed: _saving ? null : _saveWorld,
          ),
          if (_selected.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Limpar seleção',
              onPressed: () => setState(() => _selected.clear()),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleting ? null : _confirmAndDelete,
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget? _buildSelectionInfo() {
    if (_selected.isEmpty) return null;
    final selectedChunks =
        _dimChunks.where((c) => _selected.contains(_key(c.x, c.z, c.dimension))).toList();
    if (selectedChunks.isEmpty) return null;

    final xs = selectedChunks.map((c) => c.x);
    final zs = selectedChunks.map((c) => c.z);
    final minSx = xs.reduce((a, b) => a < b ? a : b);
    final maxSx = xs.reduce((a, b) => a > b ? a : b);
    final minSz = zs.reduce((a, b) => a < b ? a : b);
    final maxSz = zs.reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        '${selectedChunks.length} selecionado(s) — X: $minSx..$maxSx, Z: $minSz..$maxSz',
        style: Theme.of(context).textTheme.bodySmall,
      ),
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

    // Area real (min/max bruto). O filtro de chaves invalidas na leitura ja
    // evita o problema de chunk "fantasma" que justificava usar percentil
    // antes, entao aqui usamos a area real sem cortar nada.
    final minX = xs.first;
    final maxX = xs.last;
    final minZ = zs.first;
    final maxZ = zs.last;

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

    final selectionInfo = _buildSelectionInfo();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'chunks: ${chunks.length} | X: $minX..$maxX | Z: $minZ..$maxZ | '
            'quadrado: ${effectiveTileSize.toStringAsFixed(2)}px'
            '${_selectionMode ? " | MODO SELEÇÃO: arraste pra marcar uma área" : ""}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (selectionInfo != null) selectionInfo,
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
        if (_saving) const LinearProgressIndicator(),
        Expanded(
          child: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _tryInitialFit(width, height);
              });
              return InteractiveViewer(
                key: _viewportKey,
                transformationController: _transformController,
                constrained: false,
                maxScale: 20,
                minScale: 0.02,
                panEnabled: !_selectionMode,
                scaleEnabled: !_selectionMode,
                child: GestureDetector(
                  onTapUp: _selectionMode
                      ? null
                      : (details) =>
                          _handleTap(details, minX, minZ, effectiveTileSize),
                  onPanStart: _selectionMode
                      ? (details) => setState(() {
                            _dragStart = details.localPosition;
                            _dragCurrent = details.localPosition;
                          })
                      : null,
                  onPanUpdate: _selectionMode
                      ? (details) =>
                          setState(() => _dragCurrent = details.localPosition)
                      : null,
                  onPanEnd: _selectionMode
                      ? (_) => _commitDragSelection(minX, minZ, effectiveTileSize)
                      : null,
                  child: CustomPaint(
                    size: Size(width, height),
                    painter: _MapPainter(
                      chunks: chunks,
                      surfaceCache: _surfaceCache,
                      selected: _selected,
                      minX: minX,
                      minZ: minZ,
                      tileSize: effectiveTileSize,
                      keyFn: _key,
                      dragStart: _dragStart,
                      dragCurrent: _dragCurrent,
                      showFullMap: _showFullMap,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<ChunkCoord> chunks;
  final Map<String, ChunkSurface> surfaceCache;
  final Set<String> selected;
  final int minX;
  final int minZ;
  final double tileSize;
  final String Function(int, int, int) keyFn;
  final Offset? dragStart;
  final Offset? dragCurrent;
  final bool showFullMap;

  _MapPainter({
    required this.chunks,
    required this.surfaceCache,
    required this.selected,
    required this.minX,
    required this.minZ,
    required this.tileSize,
    required this.keyFn,
    this.dragStart,
    this.dragCurrent,
    this.showFullMap = false,
  });

  // Clareia ou escurece uma cor um pouco, pra simular relevo (igual o mapa
  // vanilla: mais claro se for mais alto que o vizinho, mais escuro se for
  // mais baixo).
  Color _shade(Color color, int delta) {
    if (delta == 0) return color;
    final factor = delta > 0 ? 1.18 : 0.82;
    return Color.fromARGB(
      color.alpha,
      (color.red * factor).clamp(0, 255).round(),
      (color.green * factor).clamp(0, 255).round(),
      (color.blue * factor).clamp(0, 255).round(),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (showFullMap) {
      // Pinta a area inteira com a cor de "nao gerado" primeiro. Os chunks
      // reais desenhados depois ficam por cima, cobrindo essa cor de base.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFBBDEFB),
      );
    }

    final fillPaint = Paint();
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.red;

    for (final chunk in chunks) {
      final key = keyFn(chunk.x, chunk.z, chunk.dimension);
      final surface = surfaceCache[key];
      Color color = const Color(0xFFCCCCCC);

      if (surface != null) {
        color = BlockColors.forBlock(surface.block);
        // Compara com o vizinho "ao norte" (Z menor), igual o mapa vanilla.
        final northKey = keyFn(chunk.x, chunk.z - 1, chunk.dimension);
        final north = surfaceCache[northKey];
        if (north != null) {
          final diff = surface.height - north.height;
          final delta = diff.clamp(-1, 1);
          color = _shade(color, delta);
        }
      }

      final left = (chunk.x - minX) * tileSize;
      final top = (chunk.z - minZ) * tileSize;
      final rect = Rect.fromLTWH(left, top, tileSize, tileSize);

      fillPaint.color = color;
      canvas.drawRect(rect, fillPaint);

      if (selected.contains(key)) {
        canvas.drawRect(rect, strokePaint);
      }
    }

    if (dragStart != null && dragCurrent != null) {
      final dragRect = Rect.fromPoints(dragStart!, dragCurrent!);
      canvas.drawRect(
        dragRect,
        Paint()..color = const Color(0x552196F3),
      );
      canvas.drawRect(
        dragRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF2196F3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => true;
}
