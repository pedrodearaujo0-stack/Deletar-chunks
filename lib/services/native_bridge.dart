import 'package:flutter/services.dart';
import '../models/world_info.dart';

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
}
