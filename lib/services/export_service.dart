import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/class_model.dart';
import '../models/attendance_model.dart';
import 'repository.dart';

class ExportService {
  final Repository _repository = Repository();

  Future<void> exportClassData(ClassModel classModel) async {
    try {
      // Get all attendance records for this class
      List<AttendanceModel> allAttendance = [];
      for (final subject in classModel.subjects) {
        final subjectAttendance = await _repository.getAttendanceByClassAndSubject(
          classModel.id,
          subject.id,
        );
        allAttendance.addAll(subjectAttendance);
      }

      // Sort attendance by date and time
      allAttendance.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Generate CSV content
      final csvContent = _generateCSVContent(classModel, allAttendance);

      // Save and share the file
      await _saveAndShareFile(csvContent, '${classModel.name}_attendance_data.csv');
    } catch (e) {
      throw Exception('Failed to export class data: $e');
    }
  }

  String _generateCSVContent(ClassModel classModel, List<AttendanceModel> attendanceRecords) {
    final buffer = StringBuffer();

    // Add header information
    buffer.writeln('Class Attendance Report');
    buffer.writeln('Class Name,${classModel.name}');
    buffer.writeln('Total Students,${classModel.students.length}');
    buffer.writeln('Total Subjects,${classModel.subjects.length}');
    buffer.writeln('Export Date,${DateTime.now().toIso8601String()}');
    buffer.writeln('');

    // Add student list
    buffer.writeln('Students List');
    buffer.writeln('Roll Number,Student Name');
    final sortedStudents = List<dynamic>.from(classModel.students);
    sortedStudents.sort((a, b) {
      final aRollInt = int.tryParse(a.rollNumber);
      final bRollInt = int.tryParse(b.rollNumber);

      if (aRollInt != null && bRollInt != null) {
        return aRollInt.compareTo(bRollInt);
      }

      return a.rollNumber.compareTo(b.rollNumber);
    });

    for (final student in sortedStudents) {
      buffer.writeln('${student.rollNumber},"${student.name}"');
    }
    buffer.writeln('');

    // Add subjects list
    buffer.writeln('Subjects List');
    buffer.writeln('Subject Name');
    for (final subject in classModel.subjects) {
      buffer.writeln('"${subject.name}"');
    }
    buffer.writeln('');

    // Add overall attendance summary
    buffer.writeln('Overall Attendance Summary');
    buffer.writeln('Student Name,Roll Number,Total Classes,Classes Attended,Attendance Percentage');

    for (final student in sortedStudents) {
      final studentAttendance = _getStudentOverallAttendance(student, attendanceRecords);
      final totalClasses = studentAttendance['totalClasses'] ?? 0;
      final present = studentAttendance['present'] ?? 0;
      final percentage = totalClasses > 0 ? (present / totalClasses * 100) : 0.0;

      buffer.writeln('"${student.name}",${student.rollNumber},$totalClasses,$present,${percentage.toStringAsFixed(2)}%');
    }
    buffer.writeln('');

    // Add subject-wise attendance summary
    for (final subject in classModel.subjects) {
      buffer.writeln('Subject: ${subject.name} - Attendance Summary');
      buffer.writeln('Student Name,Roll Number,Classes Held,Classes Attended,Attendance Percentage');

      final subjectAttendance = attendanceRecords
          .where((attendance) => attendance.subjectId == subject.id)
          .toList();

      for (final student in sortedStudents) {
        final stats = _getStudentSubjectAttendance(student, subjectAttendance);
        final totalClasses = stats['totalClasses'] ?? 0;
        final present = stats['present'] ?? 0;
        final percentage = totalClasses > 0 ? (present / totalClasses * 100) : 0.0;

        buffer.writeln('"${student.name}",${student.rollNumber},$totalClasses,$present,${percentage.toStringAsFixed(2)}%');
      }
      buffer.writeln('');
    }

    // Add detailed attendance records
    buffer.writeln('Detailed Attendance Records');

    // Group by subject for better organization
    for (final subject in classModel.subjects) {
      final subjectAttendance = attendanceRecords
          .where((attendance) => attendance.subjectId == subject.id)
          .toList();

      if (subjectAttendance.isNotEmpty) {
        buffer.writeln('Subject: ${subject.name}');

        // Create header row
        buffer.write('Date,Time');
        for (final student in sortedStudents) {
          buffer.write(',"${student.name} (${student.rollNumber})"');
        }
        buffer.writeln('');

        // Add attendance data rows
        for (final attendance in subjectAttendance) {
          final date = _formatDate(attendance.dateTime);
          final time = _formatTime(attendance.dateTime);
          buffer.write('$date,$time');

          for (final student in sortedStudents) {
            try {
              final record = attendance.records
                  .firstWhere((r) => r.studentId == student.id);
              buffer.write(',${record.present ? "Present" : "Absent"}');
            } catch (e) {
              buffer.write(',N/A');
            }
          }
          buffer.writeln('');
        }
        buffer.writeln('');
      }
    }

    // Add low attendance students list
    buffer.writeln('Students with Low Attendance (Below 75%)');
    buffer.writeln('Student Name,Roll Number,Overall Attendance Percentage,Status');

    for (final student in sortedStudents) {
      final studentAttendance = _getStudentOverallAttendance(student, attendanceRecords);
      final totalClasses = studentAttendance['totalClasses'] ?? 0;
      final present = studentAttendance['present'] ?? 0;
      final percentage = totalClasses > 0 ? (present / totalClasses * 100) : 0.0;

      if (percentage < 75.0) {
        String status = 'Critical';
        if (percentage >= 50) {
          status = 'Warning';
        } else if (percentage < 25) {
          status = 'Very Critical';
        }

        buffer.writeln('"${student.name}",${student.rollNumber},${percentage.toStringAsFixed(2)}%,$status');
      }
    }

    return buffer.toString();
  }

  Map<String, int> _getStudentOverallAttendance(dynamic student, List<AttendanceModel> attendanceRecords) {
    int totalClasses = 0;
    int present = 0;

    for (final attendance in attendanceRecords) {
      try {
        final record = attendance.records
            .firstWhere((r) => r.studentId == student.id);
        totalClasses++;
        if (record.present) {
          present++;
        }
      } catch (e) {
        // Student record not found in this attendance
      }
    }

    return {
      'totalClasses': totalClasses,
      'present': present,
    };
  }

  Map<String, int> _getStudentSubjectAttendance(dynamic student, List<AttendanceModel> subjectAttendance) {
    int totalClasses = 0;
    int present = 0;

    for (final attendance in subjectAttendance) {
      try {
        final record = attendance.records
            .firstWhere((r) => r.studentId == student.id);
        totalClasses++;
        if (record.present) {
          present++;
        }
      } catch (e) {
        // Student record not found in this attendance
      }
    }

    return {
      'totalClasses': totalClasses,
      'present': present,
    };
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  Future<void> _saveAndShareFile(String content, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsString(content);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Class Attendance Data Export',
        text: 'Please find the attached attendance data export file.',
      );
    } catch (e) {
      throw Exception('Failed to save and share file: $e');
    }
  }
}