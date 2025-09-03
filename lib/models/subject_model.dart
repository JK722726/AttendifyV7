enum SubjectType { theory, practical }

class SubjectModel {
  final String id;
  final String name;
  final SubjectType type;

  SubjectModel({
    required this.id,
    required this.name,
    required this.type,
  });

  // Convert SubjectModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last, // Store as string
    };
  }

  // Create SubjectModel from JSON
  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    return SubjectModel(
      id: json['id'],
      name: json['name'],
      type: _parseSubjectType(json['type']),
    );
  }

  static SubjectType _parseSubjectType(dynamic typeValue) {
    if (typeValue == null) return SubjectType.theory; // Default for existing data

    if (typeValue is String) {
      switch (typeValue.toLowerCase()) {
        case 'practical':
          return SubjectType.practical;
        case 'theory':
        default:
          return SubjectType.theory;
      }
    }
    return SubjectType.theory;
  }

  // Create a copy of SubjectModel with updated fields
  SubjectModel copyWith({
    String? id,
    String? name,
    SubjectType? type,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
    );
  }

  // Helper methods
  bool get isTheory => type == SubjectType.theory;
  bool get isPractical => type == SubjectType.practical;

  String get typeDisplayName => type == SubjectType.theory ? 'Theory' : 'Practical';

  @override
  String toString() {
    return 'SubjectModel(id: $id, name: $name, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubjectModel &&
        other.id == id &&
        other.name == name &&
        other.type == type;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ type.hashCode;
}