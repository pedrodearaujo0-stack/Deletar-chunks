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
}
