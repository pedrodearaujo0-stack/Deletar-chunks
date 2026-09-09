import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../models/world_info.dart';

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
  List<WorldInfo> _worlds = [];
  String? _error;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seus mundos')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_checkingPermission) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasPermission) {
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
      return const Center(child: Text('Nenhum mundo encontrado.'));
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
              // Próximo passo: navegar pro mapa do mundo selecionado.
            },
          );
        },
      ),
    );
  }
}
