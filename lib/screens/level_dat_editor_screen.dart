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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await NativeBridge.readLevelDatFlags(widget.worldPath);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result != null) {
        _flags = result;
      } else {
        _error = 'Não foi possível ler o level.dat desse mundo.';
      }
    });
  }

  Future<void> _toggle(String key, bool value) async {
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
            'Reativa conquistas em mundos onde elas foram desativadas por '
            'causa de addons, trapaças, ou terem sido abertos no criativo. '
            'Pra reativar: desliga os 3 interruptores abaixo e entra no '
            'mundo de novo.',
          ),
        ),
        SwitchListTile(
          title: const Text('Trapaças ativadas'),
          subtitle: const Text('cheatsEnabled'),
          value: _flags['cheatsEnabled'] ?? false,
          onChanged: _saving ? null : (v) => _toggle('cheatsEnabled', v),
        ),
        SwitchListTile(
          title: const Text('Comandos ativados'),
          subtitle: const Text('commandsEnabled'),
          value: _flags['commandsEnabled'] ?? false,
          onChanged: _saving ? null : (v) => _toggle('commandsEnabled', v),
        ),
        SwitchListTile(
          title: const Text('Já foi carregado no criativo'),
          subtitle: const Text('hasBeenLoadedInCreative'),
          value: _flags['hasBeenLoadedInCreative'] ?? false,
          onChanged: _saving ? null : (v) => _toggle('hasBeenLoadedInCreative', v),
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
      ],
    );
  }
}
