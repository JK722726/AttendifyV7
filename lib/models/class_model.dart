import 'student_model.dart';
import 'subject_model.dart';

class ClassModel {
  final String id;
  final String name;
  final List<StudentModel> students;
  final List<SubjectModel> subjects;

  ClassModel({
    required this.id,
    required this.name,
    required this.students,
    required this.subjects,
  });

  // Convert ClassModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'students': students.map((student) => student.toJson()).toList(),
      'subjects': subjects.map((subject) => subject.toJson()).toList(),
    };
  }

  // Create ClassModel from JSON
  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'],
      name: json['name'],
      students: (json['students'] as List<dynamic>)
          .map((studentJson) => StudentModel.fromJson(studentJson))
          .toList(),
      subjects: (json['subjects'] as List<dynamic>)
          .map((subjectJson) => SubjectModel.fromJson(subjectJson))
          .toList(),
    );
  }

  // Create a copy of ClassModel with updated fields
  ClassModel copyWith({
    String? id,
    String? name,
    List<StudentModel>? students,
    List<SubjectModel>? subjects,
  }) {
    return ClassModel(
      id: id ?? this.id,
      name: name ?? this.name,
      students: students ?? this.students,
      subjects: subjects ?? this.subjects,
    );
  }

  @override
  String toString() {
    return 'ClassModel(id: $id, name: $name, students: ${students.length}, subjects: ${subjects.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClassModel &&
        other.id == id &&
        other.name == name &&
        other.students.length == students.length &&
        other.subjects.length == subjects.length;
  }

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ students.hashCode ^ subjects.hashCode;
}