class BatchSettingsModel {
  final String classId;
  final int batchSize;
  final DateTime lastModified;

  BatchSettingsModel({
    required this.classId,
    required this.batchSize,
    required this.lastModified,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'batchSize': batchSize,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  // Create from JSON
  factory BatchSettingsModel.fromJson(Map<String, dynamic> json) {
    return BatchSettingsModel(
      classId: json['classId'],
      batchSize: json['batchSize'],
      lastModified: DateTime.parse(json['lastModified']),
    );
  }

  // Create a copy with updated fields
  BatchSettingsModel copyWith({
    String? classId,
    int? batchSize,
    DateTime? lastModified,
  }) {
    return BatchSettingsModel(
      classId: classId ?? this.classId,
      batchSize: batchSize ?? this.batchSize,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  @override
  String toString() {
    return 'BatchSettingsModel(classId: $classId, batchSize: $batchSize, lastModified: $lastModified)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BatchSettingsModel &&
        other.classId == classId &&
        other.batchSize == batchSize;
  }

  @override
  int get hashCode => classId.hashCode ^ batchSize.hashCode;
}