import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../models/world_info.dart';
import 'chunk_list_screen.dart';

class WorldSelectorScreen extends StatefulWidget {
  const WorldSelectorScreen({super.key});

  @override
  State<WorldSelectorScreen> createState() => _WorldSelectorScreenState();
}

class _WorldSelectorScreenState extends State<WorldSelectorScreen>
    with WidgetsBindingObserver {
  bool _checkingPermission = true;
  bool _hasPermission = false;
  bool _loadingWorlds = false;
  bool _loadingShizuku = false;
  bool _loadingFolder = false;
  List<WorldInfo> _worlds = [];
  String? _error;
  String? _shizukuMessage;
  String? _folderMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Usuário pode ter concedido a permissão nas Configurações e voltado ao app.
    if (state == AppLifecycleState.resumed && !_hasPermission) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    setState(() => _checkingPermission = true);
    final granted = await NativeBridge.hasStoragePermission();
    setState(() {
      _hasPermission = granted;
      _checkingPermission = false;
    });
    if (granted) {
      _loadWorlds();
    }
  }

  Future<void> _loadWorlds() async {
    setState(() {
      _loadingWorlds = true;
      _error = null;
    });
    try {
      final worlds = await NativeBridge.listWorlds();
      setState(() {
        _worlds = worlds;
        _loadingWorlds = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Não foi possível ler os mundos: $e';
        _loadingWorlds = false;
      });
    }
  }

  Future<void> _loadShizukuWorlds() async {
    setState(() {
      _loadingShizuku = true;
      _shizukuMessage = null;
    });

    final hasPermission = await NativeBridge.hasShizuku();
    if (!hasPermission) {
      await NativeBridge.requestShizukuPermission();
      setState(() {
        _loadingShizuku = false;
        _shizukuMessage = 'Abra o app Shizuku, deixe ele ativo, e tenta de '
            'novo. Se pediu uma permissão agora, aceita e toca no botão '
            'de novo.';
      });
      return;
    }

    try {
      final shizukuWorlds = await NativeBridge.listWorldsShizuku();
      setState(() {
        final existingNames = _worlds.map((w) => w.folderName).toSet();
        for (final world in shizukuWorlds) {
          if (!existingNames.contains(world.folderName)) {
            _worlds.add(world);
          }
        }
        _loadingShizuku = false;
        _shizukuMessage = shizukuWorlds.isEmpty
            ? 'Nenhum mundo novo encontrado na pasta protegida.'
            : '${shizukuWorlds.length} mundo(s) encontrado(s) via Shizuku.';
      });
    } catch (e) {
      setState(() {
        _loadingShizuku = false;
        _shizukuMessage = 'Não foi possível buscar via Shizuku: $e';
      });
    }
  }

  Future<void> _pickFolderAndLoad() async {
    setState(() {
      _loadingFolder = true;
      _folderMessage = null;
    });

    final picked = await NativeBridge.pickFolder();
    if (!picked) {
      setState(() {
        _loadingFolder = false;
        _folderMessage = 'Nenhuma pasta selecionada.';
      });
      return;
    }

    try {
      final folderWorlds = await NativeBridge.listWorldsInPickedFolder();
      setState(() {
        final existingNames = _worlds.map((w) => w.folderName).toSet();
        for (final world in folderWorlds) {
          if (!existingNames.contains(world.folderName)) {
            _worlds.add(world);
          }
        }
        _loadingFolder = false;
        _folderMessage = folderWorlds.isEmpty
            ? 'Nenhum mundo encontrado nessa pasta.'
            : '${folderWorlds.length} mundo(s) encontrado(s) na pasta escolhida.';
      });
    } catch (e) {
      setState(() {
        _loadingFolder = false;
        _folderMessage = 'Não foi possível ler a pasta: $e';
      });
    }
  }

  Future<void> _pickMcworldFile() async {
    setState(() {
      _loadingFolder = true;
      _folderMessage = null;
    });

    try {
      final world = await NativeBridge.pickWorldFile();
      setState(() {
        _loadingFolder = false;
        if (world == null) {
          _folderMessage = 'Não foi possível ler esse arquivo como mundo '
              '(.mcworld).';
          return;
        }
        final existingNames = _worlds.map((w) => w.folderName).toSet();
        if (!existingNames.contains(world.folderName)) {
          _worlds.add(world);
        }
        _folderMessage = 'Mundo "${world.folderName}" importado.';
      });
    } catch (e) {
      setState(() {
        _loadingFolder = false;
        _folderMessage = 'Não foi possível importar o arquivo: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seus mundos')),
      body: _buildBody(),
      bottomNavigationBar: _checkingPermission ? null : _buildShizukuBar(),
    );
  }

  Widget _buildShizukuBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_shizukuMessage != null) ...[
              Text(
                _shizukuMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _loadingShizuku ? null : _loadShizukuWorlds,
              icon: _loadingShizuku
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shield_outlined),
              label: const Text('Buscar mundos protegidos (Shizuku)'),
            ),
            const SizedBox(height: 8),
            if (_folderMessage != null) ...[
              Text(
                _folderMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: _loadingFolder ? null : _pickFolderAndLoad,
              icon: _loadingFolder
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open_outlined),
              label: const Text('Escolher pasta manualmente'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadingFolder ? null : _pickMcworldFile,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Escolher arquivo .mcworld'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_checkingPermission) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPermission && _worlds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pra encontrar seus mundos, o app precisa de acesso a '
                'todos os arquivos. Isso é uma exigência do Android pra '
                'ler a pasta do Minecraft.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await NativeBridge.requestStoragePermission();
                },
                child: const Text('Conceder acesso'),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadingWorlds) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!));
    }

    if (_worlds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum mundo encontrado na pasta pública. Se seus mundos '
            'estiverem na pasta protegida do Android, usa o botão '
            '"Buscar mundos protegidos" aqui embaixo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWorlds,
      child: ListView.builder(
        itemCount: _worlds.length,
        itemBuilder: (context, index) {
          final world = _worlds[index];
          return ListTile(
            leading: const Icon(Icons.public),
            title: Text(world.folderName),
            subtitle: Text(
              world.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              if (world.path.startsWith('/')) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChunkListScreen(
                      worldName: world.folderName,
                      worldPath: world.path,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Esse mundo ainda não pode ser aberto direto — '
                      'só funciona por enquanto com mundos da pasta '
                      'pública ou importados por .mcworld.',
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}
