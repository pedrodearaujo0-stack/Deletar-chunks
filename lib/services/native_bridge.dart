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
}
