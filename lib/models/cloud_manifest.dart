class CloudManifest {
  CloudManifest({
    required this.version,      // 自增版本号
    required this.updatedAtUtc, // ISO8601 UTC 时间
    required this.deviceId,     // 产生这次版本的设备
    required this.dbHash,       // 数据库文件的哈希（避免不必要上传）
    required this.fileName,     // 对应备份文件名
  });

  int version;
  String updatedAtUtc;
  String deviceId;
  String dbHash;
  String fileName;

  factory CloudManifest.fromJson(Map<String, dynamic> j) => CloudManifest(
    version: j['version'] ?? 0,
    updatedAtUtc: j['updatedAtUtc'] ?? '',
    deviceId: j['deviceId'] ?? '',
    dbHash: j['dbHash'] ?? '',
    fileName: j['fileName'] ?? '',
  );
  Map<String, dynamic> toJson() => {
    'version': version,
    'updatedAtUtc': updatedAtUtc,
    'deviceId': deviceId,
    'dbHash': dbHash,
    'fileName': fileName,
  };
}