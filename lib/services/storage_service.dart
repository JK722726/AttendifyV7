import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/class_model.dart';
import '../models/attendance_model.dart';

class StorageService {
  // File names
  static const String _classesFileName = 'classes.json';
  static const String _attendanceFileName = 'attendance.json';

  // Get the application documents directory
  Future<Directory> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory;
  }

  // Get classes file
  Future<File> get _classesFile async {
    final path = await _localPath;
    return File('${path.path}/$_classesFileName');
  }

  // Get attendance file
  Future<File> get _attendanceFile async {
    final path = await _localPath;
    return File('${path.path}/$_attendanceFileName');
  }

  // Load classes from storage
  Future<List<ClassModel>> loadClasses() async {
    try {
      final file = await _classesFile;
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }

      final List<dynamic> jsonData = json.decode(contents);
      return jsonData.map((json) => ClassModel.fromJson(json)).toList();
    } catch (e) {
      print('Error loading classes: $e');
      return [];
    }
  }

  // Save classes to storage
  Future<void> saveClasses(List<ClassModel> classes) async {
    try {
      final file = await _classesFile;
      final jsonData = classes.map((classModel) => classModel.toJson()).toList();
      await file.writeAsString(json.encode(jsonData));
    } catch (e) {
      print('Error saving classes: $e');
      throw Exception('Failed to save classes: $e');
    }
  }

  // Load attendance from storage
  Future<List<AttendanceModel>> loadAttendance() async {
    try {
      final file = await _attendanceFile;
      if (!await file.exists()) {
        return [];
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }

      final List<dynamic> jsonData = json.decode(contents);
      return jsonData.map((json) => AttendanceModel.fromJson(json)).toList();
    } catch (e) {
      print('Error loading attendance: $e');
      return [];
    }
  }

  // Save attendance to storage
  Future<void> saveAttendance(List<AttendanceModel> attendance) async {
    try {
      final file = await _attendanceFile;
      final jsonData = attendance.map((attendanceModel) => attendanceModel.toJson()).toList();
      await file.writeAsString(json.encode(jsonData));
    } catch (e) {
      print('Error saving attendance: $e');
      throw Exception('Failed to save attendance: $e');
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    try {
      final classesFile = await _classesFile;
      final attendanceFile = await _attendanceFile;

      if (await classesFile.exists()) {
        await classesFile.delete();
      }

      if (await attendanceFile.exists()) {
        await attendanceFile.delete();
      }
    } catch (e) {
      print('Error clearing data: $e');
      throw Exception('Failed to clear data: $e');
    }
  }

  // Check if files exist
  Future<bool> get hasData async {
    try {
      final classesFile = await _classesFile;
      final attendanceFile = await _attendanceFile;
      return await classesFile.exists() || await attendanceFile.exists();
    } catch (e) {
      return false;
    }
  }

  // Get file sizes for debugging
  Future<Map<String, int>> getFileSizes() async {
    try {
      final classesFile = await _classesFile;
      final attendanceFile = await _attendanceFile;

      final classesSize = await classesFile.exists() ? await classesFile.length() : 0;
      final attendanceSize = await attendanceFile.exists() ? await attendanceFile.length() : 0;

      return {
        'classes': classesSize,
        'attendance': attendanceSize,
      };
    } catch (e) {
      return {
        'classes': 0,
        'attendance': 0,
      };
    }
  }
}