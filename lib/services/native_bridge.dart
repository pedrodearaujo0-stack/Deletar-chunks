import 'package:flutter/services.dart';
import '../models/world_info.dart';
import '../models/chunk_scan_result.dart';

class NativeBridge {
  static const _channel = MethodChannel('chunk_tool/native');

  static Future<bool> hasStoragePermission() async {
    final result = await _channel.invokeMethod<bool>('hasStoragePermission');
    return result ?? false;
  }

  static Future<void> requestStoragePermission() async {
    await _channel.invokeMethod('requestStoragePermission');
  }

  static Future<List<WorldInfo>> listWorlds() async {
    final result = await _channel.invokeMethod<List<dynamic>>('listWorlds');
    if (result == null) return [];
    return result
        .map((item) => WorldInfo.fromMap(Map<dynamic, dynamic>.from(item)))
        .toList();
  }

  static Future<bool> hasShizuku() async {
    final result = await _channel.invokeMethod<bool>('hasShizuku');
    return result ?? false;
  }

  static Future<void> requestShizukuPermission() async {
    await _channel.invokeMethod('requestShizukuPermission');
  }

  /// Lista mundos na pasta protegida (Android/data) usando o Shizuku.
  /// Retorna null se o Shizuku não estiver disponível/autorizado.
  static Future<List<WorldInfo>> listWorldsShizuku() async {
    final result = await _channel.invokeMethod<String>('listWorldsShizuku');
    if (result == null || result.isEmpty) return [];
    return result
        .split('\n')
        .where((name) => name.trim().isNotEmpty)
        .map((name) => WorldInfo(
              folderName: name,
              path: 'Android/data (via Shizuku)',
            ))
        .toList();
  }

  /// Abre o seletor nativo de pasta do Android. Retorna true se o usuário
  /// escolheu uma pasta com sucesso.
  static Future<bool> pickFolder() async {
    final result = await _channel.invokeMethod<bool>('pickFolder');
    return result ?? false;
  }

  static Future<bool> hasPickedFolder() async {
    final result = await _channel.invokeMethod<bool>('hasPickedFolder');
    return result ?? false;
  }

  static Future<List<WorldInfo>> listWorldsInPickedFolder() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>('listWorldsInPickedFolder');
    if (result == null) return [];
    return result
        .map((item) => WorldInfo.fromMap(Map<dynamic, dynamic>.from(item)))
        .toList();
  }

  /// Abre o seletor de arquivo único, esperando um .mcworld. Extrai
  /// automaticamente e retorna o mundo pronto, ou null se cancelado/falhou.
  static Future<WorldInfo?> pickWorldFile() async {
    final result =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('pickWorldFile');
    if (result == null) return null;
    return WorldInfo.fromMap(result);
  }

  /// Abre o mundo (pasta ja extraida/copiada) e lista os chunks existentes,
  /// lendo o LevelDB de verdade via codigo nativo C++.
  static Future<ChunkScanResult> scanChunks(String worldPath) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'scanChunks',
      {'worldPath': worldPath},
    );
    if (result == null) {
      return ChunkScanResult(success: false, error: 'Sem resposta', chunks: []);
    }
    return ChunkScanResult.fromMap(result);
  }

  /// Apaga os chunks selecionados (todas as entradas do banco daquele
  /// chunk, não só uma). Ação irreversível.
  static Future<DeleteChunksResult> deleteChunks(
    String worldPath,
    List<ChunkCoord> chunks,
  ) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'deleteChunks',
      {
        'worldPath': worldPath,
        'chunks': chunks
            .map((c) => {'x': c.x, 'z': c.z, 'dimension': c.dimension})
            .toList(),
      },
    );
    if (result == null) {
      return DeleteChunksResult(success: false, error: 'Sem resposta', deletedCount: 0);
    }
    return DeleteChunksResult.fromMap(result);
  }

  /// Teste de texto: le os blocos do topo do chunk (256 colunas), pra
  /// conferir se a decodificacao do formato binario ta correta antes de
  /// montar o mapa visual.
  static Future<List<String>> getTopBlocks(
    String worldPath,
    ChunkCoord chunk,
  ) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getTopBlocks',
      {
        'worldPath': worldPath,
        'x': chunk.x,
        'z': chunk.z,
        'dimension': chunk.dimension,
      },
    );
    if (result == null) return [];
    final blocks = (result['blocks'] as List<dynamic>?) ?? [];
    return blocks.map((b) => b as String).toList();
  }

  /// Le o bloco do topo (1 coluna central) de varios chunks de uma vez.
  /// Usado pra colorir o mapa sem travar em mundos grandes.
  static Future<Map<String, ChunkSurface>> getChunkColors(
    String worldPath,
    List<ChunkCoord> chunks,
    int startSubY,
  ) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getChunkColors',
      {
        'worldPath': worldPath,
        'chunks': chunks
            .map((c) => {'x': c.x, 'z': c.z, 'dimension': c.dimension})
            .toList(),
        'startSubY': startSubY,
      },
    );
    if (result == null) return {};
    final rawResults = (result['results'] as List<dynamic>?) ?? [];
    final map = <String, ChunkSurface>{};
    for (final item in rawResults) {
      final m = Map<dynamic, dynamic>.from(item);
      final key = '${m['x']}_${m['z']}_${m['dimension']}';
      map[key] = ChunkSurface(
        block: m['block'] as String? ?? '',
        height: (m['height'] as num?)?.toInt() ?? 0,
      );
    }
    return map;
  }

  /// Compacta a pasta do mundo (ja editada) de volta num .mcworld e abre o
  /// seletor "salvar como" do Android pro usuario escolher onde guardar.
  static Future<bool> saveWorldAsMcworld(
    String worldPath,
    String suggestedName,
  ) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'saveWorldAsMcworld',
      {'worldPath': worldPath, 'suggestedName': suggestedName},
    );
    return result?['success'] as bool? ?? false;
  }

  /// Le as flags de conquista/trapaca do level.dat (cheatsEnabled,
  /// commandsEnabled, hasBeenLoadedInCreative). Retorna null se falhar.
  static Future<Map<String, bool>?> readLevelDatFlags(String worldPath) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'readLevelDatFlags',
      {'worldPath': worldPath},
    );
    if (result == null || result['success'] != true) return null;
    final flagsRaw = Map<dynamic, dynamic>.from(result['flags'] as Map);
    return flagsRaw.map((k, v) => MapEntry(k as String, v as bool));
  }

  /// Escreve de volta uma ou mais flags do level.dat.
  static Future<bool> writeLevelDatFlags(
    String worldPath,
    Map<String, bool> flags,
  ) async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'writeLevelDatFlags',
      {'worldPath': worldPath, 'flags': flags},
    );
    return result?['success'] as bool? ?? false;
  }
}
