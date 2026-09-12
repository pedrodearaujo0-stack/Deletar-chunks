class ChunkCoord {
  final int x;
  final int z;
  final int dimension;

  ChunkCoord({required this.x, required this.z, required this.dimension});

  factory ChunkCoord.fromMap(Map<dynamic, dynamic> map) {
    return ChunkCoord(
      x: map['x'] as int,
      z: map['z'] as int,
      dimension: map['dimension'] as int,
    );
  }

  String get dimensionName {
    switch (dimension) {
      case 0:
        return 'Overworld';
      case 1:
        return 'Nether';
      case 2:
        return 'End';
      default:
        return 'Dimensão $dimension';
    }
  }
}

class ChunkScanResult {
  final bool success;
  final String? error;
  final List<ChunkCoord> chunks;

  ChunkScanResult({required this.success, this.error, required this.chunks});

  factory ChunkScanResult.fromMap(Map<dynamic, dynamic> map) {
    final rawChunks = (map['chunks'] as List<dynamic>?) ?? [];
    return ChunkScanResult(
      success: map['success'] as bool? ?? false,
      error: map['error'] as String?,
      chunks: rawChunks
          .map((item) => ChunkCoord.fromMap(Map<dynamic, dynamic>.from(item)))
          .toList(),
    );
  }
}

class DeleteChunksResult {
  final bool success;
  final String? error;
  final int deletedCount;

  DeleteChunksResult({
    required this.success,
    this.error,
    required this.deletedCount,
  });

  factory DeleteChunksResult.fromMap(Map<dynamic, dynamic> map) {
    return DeleteChunksResult(
      success: map['success'] as bool? ?? false,
      error: map['error'] as String?,
      deletedCount: (map['deletedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
