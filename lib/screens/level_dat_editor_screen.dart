import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class LevelDatEditorScreen extends StatefulWidget {
  final String worldPath;

  const LevelDatEditorScreen({super.key, required this.worldPath});

  @override
  State<LevelDatEditorScreen> createState() => _LevelDatEditorScreenState();
}

class _LevelDatEditorScreenState extends State<LevelDatEditorScreen> {
  bool _loading = true;
  String? _error;
  Map<String, bool> _flags = {};
  int _gameType = 0;
  int _seed = 0;
  bool _saving = false;
  final _testXController = TextEditingController(text: '0');
  final _testZController = TextEditingController(text: '0');
  String? _biomeResult;
  bool _testingBiome = false;

  static const _gameModeNames = {
    0: 'Sobrevivência',
    1: 'Criativo',
    2: 'Aventura',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final state = await NativeBridge.readLevelDatFlags(widget.worldPath);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (state != null) {
        _flags = state.flags;
        _gameType = state.gameType;
        _seed = state.seed;
      } else {
        _error = 'Não foi possível ler o level.dat desse mundo.';
      }
    });
  }

  Future<void> _toggleFlag(String key, bool value) async {
    setState(() {
      _flags[key] = value;
      _saving = true;
    });
    final ok = await NativeBridge.writeLevelDatFlags(widget.worldPath, {key: value});
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar essa alteração.')),
      );
    }
  }

  Future<void> _changeGameType(int? value) async {
    if (value == null) return;
    setState(() {
      _gameType = value;
      _saving = true;
    });
    final ok = await NativeBridge.writeLevelDatGameType(widget.worldPath, value);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar o modo de jogo.')),
      );
    }
  }

  Future<void> _reactivateAchievements() async {
    setState(() => _saving = true);
    await NativeBridge.writeLevelDatFlags(widget.worldPath, {
      'cheatsEnabled': false,
      'commandsEnabled': false,
      'hasBeenLoadedInCreative': false,
    });
    await NativeBridge.writeLevelDatGameType(widget.worldPath, 0);
    if (!mounted) return;
    setState(() {
      _flags['cheatsEnabled'] = false;
      _flags['commandsEnabled'] = false;
      _flags['hasBeenLoadedInCreative'] = false;
      _gameType = 0;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pronto. Entra no mundo de novo pra conferir.')),
    );
  }

  Future<void> _testBiome() async {
    final x = int.tryParse(_testXController.text) ?? 0;
    final z = int.tryParse(_testZController.text) ?? 0;
    setState(() {
      _testingBiome = true;
      _biomeResult = null;
    });
    final biome = await NativeBridge.getBiomeAt(_seed, x, z);
    if (!mounted) return;
    setState(() {
      _testingBiome = false;
      _biomeResult = biome ?? 'Erro ao calcular';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar mundo')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Tentar de novo')),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Pra conquistas funcionarem, o mundo precisa estar em modo '
            'Sobrevivência E com os 3 interruptores abaixo desligados. '
            'Faltando qualquer um dos dois, elas continuam desativadas.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _reactivateAchievements,
            icon: const Icon(Icons.emoji_events_outlined),
            label: const Text('Reativar conquistas (ajusta tudo de uma vez)'),
          ),
        ),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<int>(
            value: _gameType,
            decoration: const InputDecoration(labelText: 'Modo de jogo'),
            items: _gameModeNames.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: _saving ? null : _changeGameType,
          ),
        ),
        SwitchListTile(
          title: const Text('Trapaças ativadas'),
          subtitle: const Text('cheatsEnabled'),
          value: _flags['cheatsEnabled'] ?? false,
          onChanged: _saving ? null : (v) => _toggleFlag('cheatsEnabled', v),
        ),
        SwitchListTile(
          title: const Text('Comandos ativados'),
          subtitle: const Text('commandsEnabled'),
          value: _flags['commandsEnabled'] ?? false,
          onChanged: _saving ? null : (v) => _toggleFlag('commandsEnabled', v),
        ),
        SwitchListTile(
          title: const Text('Já foi carregado no criativo'),
          subtitle: const Text('hasBeenLoadedInCreative'),
          value: _flags['hasBeenLoadedInCreative'] ?? false,
          onChanged: _saving ? null : (v) => _toggleFlag('hasBeenLoadedInCreative', v),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Aviso: em alguns casos raros o próprio jogo reativa isso '
            'sozinho de novo (é um bug conhecido do Minecraft, não do app). '
            'Se acontecer, é só repetir o processo.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seed do mundo: $_seed'),
              const SizedBox(height: 8),
              const Text(
                'Teste experimental: previsão de bioma numa coordenada '
                '(bloco). Ainda não confirmamos se bate com o Bedrock de '
                'verdade — é só pra conferir.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _testXController,
                      decoration: const InputDecoration(labelText: 'X'),
                      keyboardType: TextInputType.numberWithOptions(signed: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _testZController,
                      decoration: const InputDecoration(labelText: 'Z'),
                      keyboardType: TextInputType.numberWithOptions(signed: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _testingBiome ? null : _testBiome,
                    child: const Text('Testar'),
                  ),
                ],
              ),
              if (_biomeResult != null) ...[
                const SizedBox(height: 8),
                Text('Bioma previsto: $_biomeResult'),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
