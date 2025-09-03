class AttendanceRecord {
  final String studentId;
  final bool present;

  AttendanceRecord({
    required this.studentId,
    required this.present,
  });

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'present': present,
    };
  }

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      studentId: json['studentId'],
      present: json['present'],
    );
  }

  @override
  String toString() {
    return 'AttendanceRecord(studentId: $studentId, present: $present)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceRecord &&
        other.studentId == studentId &&
        other.present == present;
  }

  @override
  int get hashCode => studentId.hashCode ^ present.hashCode;
}

class AttendanceModel {
  final String id;
  final String classId;
  final String subjectId;
  final DateTime dateTime;
  final List<AttendanceRecord> records;
  final int? batchNumber; // For practical subjects
  final int? totalBatches; // Total number of batches for this practical

  AttendanceModel({
    required this.id,
    required this.classId,
    required this.subjectId,
    required this.dateTime,
    required this.records,
    this.batchNumber,
    this.totalBatches,
  });

  // Convert AttendanceModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'classId': classId,
      'subjectId': subjectId,
      'dateTime': dateTime.toIso8601String(),
      'records': records.map((record) => record.toJson()).toList(),
      'batchNumber': batchNumber,
      'totalBatches': totalBatches,
    };
  }

  // Create AttendanceModel from JSON
  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'],
      classId: json['classId'],
      subjectId: json['subjectId'],
      dateTime: DateTime.parse(json['dateTime'] ?? json['date']), // Backward compatibility
      records: (json['records'] as List<dynamic>)
          .map((recordJson) => AttendanceRecord.fromJson(recordJson))
          .toList(),
      batchNumber: json['batchNumber'],
      totalBatches: json['totalBatches'],
    );
  }

  // Create a copy of AttendanceModel with updated fields
  AttendanceModel copyWith({
    String? id,
    String? classId,
    String? subjectId,
    DateTime? dateTime,
    List<AttendanceRecord>? records,
    int? batchNumber,
    int? totalBatches,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      subjectId: subjectId ?? this.subjectId,
      dateTime: dateTime ?? this.dateTime,
      records: records ?? this.records,
      batchNumber: batchNumber ?? this.batchNumber,
      totalBatches: totalBatches ?? this.totalBatches,
    );
  }

  // Helper getter for backward compatibility
  DateTime get date => DateTime(dateTime.year, dateTime.month, dateTime.day);

  // Helper methods for batch information
  bool get hasBatchInfo => batchNumber != null && totalBatches != null;
  bool get isTheoryAttendance => batchNumber == null;
  bool get isPracticalAttendance => batchNumber != null;

  String get batchDisplayName {
    if (batchNumber == null) return 'Theory';
    return 'Batch $batchNumber';
  }

  @override
  String toString() {
    return 'AttendanceModel(id: $id, classId: $classId, subjectId: $subjectId, dateTime: $dateTime, records: ${records.length}, batch: $batchNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceModel &&
        other.id == id &&
        other.classId == classId &&
        other.subjectId == subjectId &&
        other.dateTime == dateTime &&
        other.batchNumber == batchNumber &&
        other.records.length == records.length;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      classId.hashCode ^
      subjectId.hashCode ^
      dateTime.hashCode ^
      (batchNumber?.hashCode ?? 0) ^
      records.hashCode;
}