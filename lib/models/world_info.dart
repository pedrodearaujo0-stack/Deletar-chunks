class WorldInfo {
  final String folderName;
  final String path;

  WorldInfo({required this.folderName, required this.path});

  factory WorldInfo.fromMap(Map<dynamic, dynamic> map) {
    return WorldInfo(
      folderName: map['folderName'] as String,
      path: map['path'] as String,
    );
  }
}
