import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/subject_model.dart';
import '../models/attendance_model.dart';
import 'storage_service.dart';

class Repository {
  final StorageService _storageService = StorageService();

  // Classes CRUD Operations
  Future<List<ClassModel>> getAllClasses() async {
    final classes = await _storageService.loadClasses();
    return classes;
  }

  Future<void> addClass(ClassModel classModel) async {
    final classes = await getAllClasses();
    classes.add(classModel);
    await _storageService.saveClasses(classes);
  }

  Future<void> updateClass(ClassModel updatedClass) async {
    final classes = await getAllClasses();
    final index = classes.indexWhere((c) => c.id == updatedClass.id);
    if (index != -1) {
      classes[index] = updatedClass;
      await _storageService.saveClasses(classes);
    }
  }

  Future<void> deleteClass(String classId) async {
    final classes = await getAllClasses();
    classes.removeWhere((c) => c.id == classId);
    await _storageService.saveClasses(classes);

    // Also delete all attendance records for this class
    final attendance = await getAllAttendance();
    attendance.removeWhere((a) => a.classId == classId);
    await _storageService.saveAttendance(attendance);
  }

  Future<ClassModel?> getClassById(String classId) async {
    final classes = await getAllClasses();
    try {
      return classes.firstWhere((c) => c.id == classId);
    } catch (e) {
      return null;
    }
  }

  // Students CRUD Operations
  Future<void> addStudentToClass(String classId, StudentModel student) async {
    final classes = await getAllClasses();
    final classIndex = classes.indexWhere((c) => c.id == classId);
    if (classIndex != -1) {
      final updatedStudents = List<StudentModel>.from(classes[classIndex].students);
      updatedStudents.add(student);
      classes[classIndex] = classes[classIndex].copyWith(students: updatedStudents);
      await _storageService.saveClasses(classes);
    }
  }

  Future<void> updateStudentInClass(String classId, StudentModel updatedStudent) async {
    final classes = await getAllClasses();
    final classIndex = classes.indexWhere((c) => c.id == classId);
    if (classIndex != -1) {
      final students = List<StudentModel>.from(classes[classIndex].students);
      final studentIndex = students.indexWhere((s) => s.id == updatedStudent.id);
      if (studentIndex != -1) {
        students[studentIndex] = updatedStudent;
        classes[classIndex] = classes[classIndex].copyWith(students: students);
        await _storageService.saveClasses(classes);
      }
    }
  }

  Future<void> deleteStudentFromClass(String classId, String studentId) async {
    final classes = await getAllClasses();
    final classIndex = classes.indexWhere((c) => c.id == classId);
    if (classIndex != -1) {
      final students = List<StudentModel>.from(classes[classIndex].students);
      students.removeWhere((s) => s.id == studentId);
      classes[classIndex] = classes[classIndex].copyWith(students: students);
      await _storageService.saveClasses(classes);

      // Also remove student from all attendance records
      final attendance = await getAllAttendance();
      for (var i = 0; i < attendance.length; i++) {
        if (attendance[i].classId == classId) {
          final records = attendance[i].records.where((r) => r.studentId != studentId).toList();
          attendance[i] = attendance[i].copyWith(records: records);
        }
      }
      await _storageService.saveAttendance(attendance);
    }
  }

  // Subjects CRUD Operations
  Future<void> addSubjectToClass(String classId, SubjectModel subject) async {
    final classes = await getAllClasses();
    final classIndex = classes.indexWhere((c) => c.id == classId);
    if (classIndex != -1) {
      final updatedSubjects = List<SubjectModel>.from(classes[classIndex].subjects);
      updatedSubjects.add(subject);
      classes[classIndex] = classes[classIndex].copyWith(subjects: updatedSubjects);
      await _storageService.saveClasses(classes);
    }
  }

  Future<void> updateSubjectInClass(String classId, SubjectModel updatedSubject) async {
    final classes = await getAllClasses();
    final classIndex = classes.indexWhere((c) => c.id == classId);
    if (classIndex != -1) {
      final subjects = List<SubjectModel>.from(classes[classIndex].subjects);
      final subjectIndex = subjects.indexWhere((s) => s.id == updatedSubject.id);
      if (subjectIndex != -1) {
        subjects[subjectIndex] = updatedSubject;
        classes[classIndex] = classes[classIndex].copyWith(subjects: subjects);
        await _storageService.saveClasses(classes);
      }
    }
  }

  Future<void> deleteSubjectFromClass(String classId, String subjectId) async {
    final classes = await getAllClasses();
    final classIndex = classes.indexWhere((c) => c.id == classId);
    if (classIndex != -1) {
      final subjects = List<SubjectModel>.from(classes[classIndex].subjects);
      subjects.removeWhere((s) => s.id == subjectId);
      classes[classIndex] = classes[classIndex].copyWith(subjects: subjects);
      await _storageService.saveClasses(classes);

      // Also delete all attendance records for this subject
      final attendance = await getAllAttendance();
      attendance.removeWhere((a) => a.classId == classId && a.subjectId == subjectId);
      await _storageService.saveAttendance(attendance);
    }
  }

  // Attendance CRUD Operations
  Future<List<AttendanceModel>> getAllAttendance() async {
    return await _storageService.loadAttendance();
  }

  Future<void> saveAttendanceRecord(AttendanceModel attendance) async {
    final attendanceList = await getAllAttendance();

    // For practical subjects, check if attendance for same class, subject, datetime AND batch already exists
    // For theory subjects, check if attendance for same class, subject, and exact datetime already exists
    final existingIndex = attendanceList.indexWhere((a) =>
    a.classId == attendance.classId &&
        a.subjectId == attendance.subjectId &&
        a.dateTime.isAtSameMomentAs(attendance.dateTime) &&
        a.batchNumber == attendance.batchNumber);

    if (existingIndex != -1) {
      // Update existing record
      attendanceList[existingIndex] = attendance;
    } else {
      // Add new record
      attendanceList.add(attendance);
    }

    await _storageService.saveAttendance(attendanceList);
  }

  Future<List<AttendanceModel>> getAttendanceByClassAndSubject(String classId, String subjectId) async {
    final attendance = await getAllAttendance();
    return attendance.where((a) => a.classId == classId && a.subjectId == subjectId).toList();
  }

  Future<AttendanceModel?> getAttendanceByDate(String classId, String subjectId, DateTime date) async {
    final attendance = await getAllAttendance();
    try {
      return attendance.firstWhere((a) =>
      a.classId == classId &&
          a.subjectId == subjectId &&
          a.dateTime.year == date.year &&
          a.dateTime.month == date.month &&
          a.dateTime.day == date.day);
    } catch (e) {
      return null;
    }
  }

  // Updated method for exact datetime matching with batch support
  Future<AttendanceModel?> getAttendanceByDateTime(String classId, String subjectId, DateTime dateTime, {int? batchNumber}) async {
    final attendance = await getAllAttendance();
    try {
      return attendance.firstWhere((a) =>
      a.classId == classId &&
          a.subjectId == subjectId &&
          a.dateTime.isAtSameMomentAs(dateTime) &&
          a.batchNumber == batchNumber);
    } catch (e) {
      return null;
    }
  }

  // Get attendance records for a specific date (all times and batches)
  Future<List<AttendanceModel>> getAttendanceByDateOnly(String classId, String subjectId, DateTime date) async {
    final attendance = await getAllAttendance();
    return attendance.where((a) =>
    a.classId == classId &&
        a.subjectId == subjectId &&
        a.dateTime.year == date.year &&
        a.dateTime.month == date.month &&
        a.dateTime.day == date.day).toList();
  }

  // Get attendance records for a specific batch
  Future<List<AttendanceModel>> getAttendanceByBatch(String classId, String subjectId, int batchNumber) async {
    final attendance = await getAllAttendance();
    return attendance.where((a) =>
    a.classId == classId &&
        a.subjectId == subjectId &&
        a.batchNumber == batchNumber).toList();
  }

  // Get all batches for a practical subject
  Future<List<int>> getBatchesForSubject(String classId, String subjectId) async {
    final attendance = await getAllAttendance();
    final batchNumbers = attendance
        .where((a) => a.classId == classId && a.subjectId == subjectId && a.batchNumber != null)
        .map((a) => a.batchNumber!)
        .toSet()
        .toList();
    batchNumbers.sort();
    return batchNumbers;
  }

  Future<void> deleteAttendanceRecord(String attendanceId) async {
    final attendance = await getAllAttendance();
    attendance.removeWhere((a) => a.id == attendanceId);
    await _storageService.saveAttendance(attendance);
  }

  // Utility methods
  Future<void> clearAllData() async {
    await _storageService.clearAllData();
  }

  Future<bool> hasData() async {
    return await _storageService.hasData;
  }

  Future<Map<String, int>> getDataSizes() async {
    return await _storageService.getFileSizes();
  }

  // Analytics methods - updated to handle batches
  Future<Map<String, dynamic>> getClassStatistics(String classId) async {
    final classModel = await getClassById(classId);
    if (classModel == null) return {};

    final allAttendance = await getAllAttendance();
    final classAttendance = allAttendance.where((a) => a.classId == classId).toList();

    int totalSessions = classAttendance.length;
    int totalStudents = classModel.students.length;

    // Calculate total possible attendance considering batches
    int totalPossibleAttendance = 0;
    int totalPresent = 0;

    for (final attendance in classAttendance) {
      totalPossibleAttendance += attendance.records.length;
      totalPresent += attendance.records.where((r) => r.present).length;
    }

    double overallAttendancePercentage = totalPossibleAttendance > 0
        ? (totalPresent / totalPossibleAttendance) * 100
        : 0.0;

    // Separate theory and practical sessions
    final theorySubjects = classModel.subjects.where((s) => s.isTheory).length;
    final practicalSubjects = classModel.subjects.where((s) => s.isPractical).length;

    return {
      'totalStudents': totalStudents,
      'totalSessions': totalSessions,
      'totalPresent': totalPresent,
      'overallAttendancePercentage': overallAttendancePercentage,
      'totalSubjects': classModel.subjects.length,
      'theorySubjects': theorySubjects,
      'practicalSubjects': practicalSubjects,
    };
  }

  Future<Map<String, dynamic>> getStudentStatistics(String classId, String studentId) async {
    final allAttendance = await getAllAttendance();
    final studentAttendance = allAttendance
        .where((a) => a.classId == classId)
        .where((a) => a.records.any((r) => r.studentId == studentId))
        .toList();

    int totalClasses = studentAttendance.length;
    int classesAttended = 0;
    int theoryClasses = 0;
    int theoryAttended = 0;
    int practicalClasses = 0;
    int practicalAttended = 0;

    final classModel = await getClassById(classId);
    if (classModel == null) return {};

    for (final attendance in studentAttendance) {
      try {
        final record = attendance.records.firstWhere((r) => r.studentId == studentId);
        final subject = classModel.subjects.firstWhere((s) => s.id == attendance.subjectId);

        if (record.present) {
          classesAttended++;
          if (subject.isTheory) {
            theoryAttended++;
          } else {
            practicalAttended++;
          }
        }

        if (subject.isTheory) {
          theoryClasses++;
        } else {
          practicalClasses++;
        }
      } catch (e) {
        // Record not found
      }
    }

    double attendancePercentage = totalClasses > 0
        ? (classesAttended / totalClasses) * 100
        : 0.0;

    double theoryPercentage = theoryClasses > 0
        ? (theoryAttended / theoryClasses) * 100
        : 0.0;

    double practicalPercentage = practicalClasses > 0
        ? (practicalAttended / practicalClasses) * 100
        : 0.0;

    return {
      'totalClasses': totalClasses,
      'classesAttended': classesAttended,
      'attendancePercentage': attendancePercentage,
      'theoryClasses': theoryClasses,
      'theoryAttended': theoryAttended,
      'theoryPercentage': theoryPercentage,
      'practicalClasses': practicalClasses,
      'practicalAttended': practicalAttended,
      'practicalPercentage': practicalPercentage,
    };
  }

  // Helper method to calculate total batches for a class
  int calculateTotalBatches(int totalStudents) {
    return (totalStudents / 25).ceil();
  }

  // Get students for a specific batch
  List<StudentModel> getStudentsForBatch(List<StudentModel> allStudents, int batchNumber) {
    // Sort students by roll number first
    final sortedStudents = List<StudentModel>.from(allStudents);
    sortedStudents.sort((a, b) {
      final aRollInt = int.tryParse(a.rollNumber);
      final bRollInt = int.tryParse(b.rollNumber);
      if (aRollInt != null && bRollInt != null) {
        return aRollInt.compareTo(bRollInt);
      }
      return a.rollNumber.compareTo(b.rollNumber);
    });

    int startIndex = (batchNumber - 1) * 25;
    int endIndex = startIndex + 25;
    if (endIndex > sortedStudents.length) {
      endIndex = sortedStudents.length;
    }

    if (startIndex >= sortedStudents.length) {
      return [];
    }

    return sortedStudents.sublist(startIndex, endIndex);
  }
}