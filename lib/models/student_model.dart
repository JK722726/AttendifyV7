class StudentModel {
  final String id;
  final String name;
  final String rollNumber;

  StudentModel({
    required this.id,
    required this.name,
    required this.rollNumber,
  });

  // Convert StudentModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rollNumber': rollNumber,
    };
  }

  // Create StudentModel from JSON
  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      name: json['name'],
      rollNumber: json['rollNumber'],
    );
  }

  // Create a copy of StudentModel with updated fields
  StudentModel copyWith({
    String? id,
    String? name,
    String? rollNumber,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNumber: rollNumber ?? this.rollNumber,
    );
  }

  @override
  String toString() {
    return 'StudentModel(id: $id, name: $name, rollNumber: $rollNumber)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudentModel &&
        other.id == id &&
        other.name == name &&
        other.rollNumber == rollNumber;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ rollNumber.hashCode;
}