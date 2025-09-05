import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/class_model.dart';
import '../models/attendance_model.dart';

class StorageService {
  // File names
  static const String _classesFileName = 'classes.json';
  static const String _attendanceFileName = 'attendance.json';
  static const String _settingsFileName = 'settings.json';

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

  // Get settings file
  Future<File> get _settingsFile async {
    final path = await _localPath;
    return File('${path.path}/$_settingsFileName');
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

  // Load settings from storage
  Future<Map<String, dynamic>> loadSettings() async {
    try {
      final file = await _settingsFile;
      if (!await file.exists()) {
        return {
          'batchSize': 25, // Default batch size
        };
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return {
          'batchSize': 25,
        };
      }

      return Map<String, dynamic>.from(json.decode(contents));
    } catch (e) {
      print('Error loading settings: $e');
      return {
        'batchSize': 25,
      };
    }
  }

  // Save settings to storage
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final file = await _settingsFile;
      await file.writeAsString(json.encode(settings));
    } catch (e) {
      print('Error saving settings: $e');
      throw Exception('Failed to save settings: $e');
    }
  }

  // Get batch size setting
  Future<int> getBatchSize() async {
    try {
      final settings = await loadSettings();
      return settings['batchSize'] ?? 25;
    } catch (e) {
      print('Error getting batch size: $e');
      return 25; // Default fallback
    }
  }

  // Set batch size setting
  Future<void> setBatchSize(int batchSize) async {
    try {
      final settings = await loadSettings();
      settings['batchSize'] = batchSize;
      await saveSettings(settings);
    } catch (e) {
      print('Error setting batch size: $e');
      throw Exception('Failed to save batch size: $e');
    }
  }

  // Clear all data
  Future<void> clearAllData() async {
    try {
      final classesFile = await _classesFile;
      final attendanceFile = await _attendanceFile;
      final settingsFile = await _settingsFile;

      if (await classesFile.exists()) {
        await classesFile.delete();
      }

      if (await attendanceFile.exists()) {
        await attendanceFile.delete();
      }

      if (await settingsFile.exists()) {
        await settingsFile.delete();
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
      final settingsFile = await _settingsFile;

      final classesSize = await classesFile.exists() ? await classesFile.length() : 0;
      final attendanceSize = await attendanceFile.exists() ? await attendanceFile.length() : 0;
      final settingsSize = await settingsFile.exists() ? await settingsFile.length() : 0;

      return {
        'classes': classesSize,
        'attendance': attendanceSize,
        'settings': settingsSize,
      };
    } catch (e) {
      return {
        'classes': 0,
        'attendance': 0,
        'settings': 0,
      };
    }
  }
}