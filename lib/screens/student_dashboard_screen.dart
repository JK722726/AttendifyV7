import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/subject_model.dart';
import '../models/attendance_model.dart';
import '../services/repository.dart';

class StudentDashboardScreen extends StatefulWidget {
  final StudentModel student;
  final ClassModel classModel;

  const StudentDashboardScreen({
    super.key,
    required this.student,
    required this.classModel,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final Repository _repository = Repository();
  bool _isLoading = true;
  List<AttendanceModel> _allAttendanceRecords = [];
  Map<String, List<AttendanceModel>> _subjectWiseAttendance = {};
  double _overallAttendancePercentage = 0.0;
  double _theoryAttendancePercentage = 0.0;
  double _practicalAttendancePercentage = 0.0;
  int _totalClassesAttended = 0;
  int _totalClasses = 0;
  int _theoryClassesAttended = 0;
  int _totalTheoryClasses = 0;
  int _practicalClassesAttended = 0;
  int _totalPracticalClasses = 0;

  @override
  void initState() {
    super.initState();
    _loadStudentAttendanceData();
  }

  Future<void> _loadStudentAttendanceData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all attendance records for this class
      List<AttendanceModel> allAttendance = [];
      for (final subject in widget.classModel.subjects) {
        final subjectAttendance = await _repository.getAttendanceByClassAndSubject(
          widget.classModel.id,
          subject.id,
        );
        allAttendance.addAll(subjectAttendance);
      }

      // Filter records for this student
      _allAttendanceRecords = allAttendance
          .where((attendance) => attendance.records
          .any((record) => record.studentId == widget.student.id))
          .toList();

      // Group by subject
      _subjectWiseAttendance.clear();
      for (final subject in widget.classModel.subjects) {
        _subjectWiseAttendance[subject.id] = _allAttendanceRecords
            .where((attendance) => attendance.subjectId == subject.id)
            .toList();
      }

      _calculateStatistics();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculateStatistics() {
    int totalPresent = 0;
    int totalClasses = 0;
    int theoryPresent = 0;
    int theoryClasses = 0;
    int practicalPresent = 0;
    int practicalClasses = 0;

    for (final attendance in _allAttendanceRecords) {
      try {
        final studentRecord = attendance.records
            .firstWhere((record) => record.studentId == widget.student.id);

        final subject = widget.classModel.subjects
            .firstWhere((s) => s.id == attendance.subjectId);

        totalClasses++;
        if (studentRecord.present) {
          totalPresent++;
        }

        if (subject.isTheory) {
          theoryClasses++;
          if (studentRecord.present) {
            theoryPresent++;
          }
        } else {
          practicalClasses++;
          if (studentRecord.present) {
            practicalPresent++;
          }
        }
      } catch (e) {
        // Record not found, skip
        continue;
      }
    }

    _totalClassesAttended = totalPresent;
    _totalClasses = totalClasses;
    _overallAttendancePercentage = totalClasses > 0 ? (totalPresent / totalClasses) * 100 : 0.0;

    _theoryClassesAttended = theoryPresent;
    _totalTheoryClasses = theoryClasses;
    _theoryAttendancePercentage = theoryClasses > 0 ? (theoryPresent / theoryClasses) * 100 : 0.0;

    _practicalClassesAttended = practicalPresent;
    _totalPracticalClasses = practicalClasses;
    _practicalAttendancePercentage = practicalClasses > 0 ? (practicalPresent / practicalClasses) * 100 : 0.0;
  }

  double _getSubjectAttendancePercentage(String subjectId) {
    final subjectAttendance = _subjectWiseAttendance[subjectId] ?? [];
    if (subjectAttendance.isEmpty) return 0.0;

    int presentCount = 0;
    for (final attendance in subjectAttendance) {
      try {
        final studentRecord = attendance.records
            .firstWhere((record) => record.studentId == widget.student.id);
        if (studentRecord.present) {
          presentCount++;
        }
      } catch (e) {
        continue;
      }
    }

    return (presentCount / subjectAttendance.length) * 100;
  }

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getAttendanceStatus(double percentage) {
    if (percentage >= 75) return 'Good';
    if (percentage >= 50) return 'Warning';
    return 'Critical';
  }

  Widget _buildEnhancedHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Student Info Row
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.student.name.isNotEmpty ? widget.student.name[0].toUpperCase() : 'S',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.student.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Roll No: ${widget.student.rollNumber}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Class: ${widget.classModel.name}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Overall Attendance
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.analytics,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Overall Attendance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${_overallAttendancePercentage.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getAttendanceColor(_overallAttendancePercentage).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getAttendanceColor(_overallAttendancePercentage).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        _getAttendanceStatus(_overallAttendancePercentage),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Attended $_totalClassesAttended out of $_totalClasses classes',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTheoryPracticalStats() {
    if (_totalTheoryClasses == 0 && _totalPracticalClasses == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.pie_chart, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Attendance Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_totalTheoryClasses > 0)
                    Expanded(
                      child: _buildStatCard(
                        'Theory Classes',
                        '${_theoryAttendancePercentage.toStringAsFixed(1)}%',
                        '$_theoryClassesAttended/$_totalTheoryClasses',
                        _getAttendanceColor(_theoryAttendancePercentage),
                        Icons.book,
                      ),
                    ),
                  if (_totalTheoryClasses > 0 && _totalPracticalClasses > 0)
                    const SizedBox(width: 16),
                  if (_totalPracticalClasses > 0)
                    Expanded(
                      child: _buildStatCard(
                        'Practical Classes',
                        '${_practicalAttendancePercentage.toStringAsFixed(1)}%',
                        '$_practicalClassesAttended/$_totalPracticalClasses',
                        _getAttendanceColor(_practicalAttendancePercentage),
                        Icons.science,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String percentage, String details, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            percentage,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            details,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSubjectWiseAttendance() {
    // Separate theory and practical subjects
    final theorySubjects = widget.classModel.subjects.where((s) => s.isTheory).toList();
    final practicalSubjects = widget.classModel.subjects.where((s) => s.isPractical).toList();

    return Column(
      children: [
        // Theory Subjects
        if (theorySubjects.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.book, color: Colors.blue.shade700, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Theory Subjects (${theorySubjects.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...theorySubjects.map((subject) => _buildEnhancedSubjectCard(subject)),
                  ],
                ),
              ),
            ),
          ),
        ],

        // Practical Subjects
        if (practicalSubjects.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.science, color: Colors.green.shade700, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Practical Subjects (${practicalSubjects.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...practicalSubjects.map((subject) => _buildEnhancedSubjectCard(subject)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEnhancedSubjectCard(SubjectModel subject) {
    final percentage = _getSubjectAttendancePercentage(subject.id);
    final subjectAttendance = _subjectWiseAttendance[subject.id] ?? [];
    final presentCount = subjectAttendance.where((attendance) {
      try {
        final studentRecord = attendance.records
            .firstWhere((record) => record.studentId == widget.student.id);
        return studentRecord.present;
      } catch (e) {
        return false;
      }
    }).length;

    final attendanceColor = _getAttendanceColor(percentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: percentage < 75 ? Colors.red.shade300 : Colors.green.shade300,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: subject.isPractical ? Colors.green.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  subject.isPractical ? Icons.science : Icons.book,
                  color: subject.isPractical ? Colors.green.shade700 : Colors.blue.shade700,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: subject.isPractical ? Colors.green.shade200 : Colors.blue.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        subject.typeDisplayName,
                        style: TextStyle(
                          fontSize: 11,
                          color: subject.isPractical ? Colors.green.shade800 : Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Attendance Percentage
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: attendanceColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: attendanceColor),
                ),
                child: Column(
                  children: [
                    Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: attendanceColor,
                      ),
                    ),
                    Text(
                      '$presentCount/${subjectAttendance.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: attendanceColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attendance Progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: attendanceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getAttendanceStatus(percentage),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(attendanceColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
          // Additional Info for Practical
          if (subject.isPractical) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Batch-wise attendance tracking',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLowAttendanceAlert() {
    final lowAttendanceSubjects = widget.classModel.subjects.where((subject) {
      return _getSubjectAttendancePercentage(subject.id) < 75;
    }).toList();

    if (lowAttendanceSubjects.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.green.shade50,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Excellent Attendance!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your attendance is above 75% in all subjects. Keep up the great work!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.red.shade50,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.warning, color: Colors.red.shade700, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Alert!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your attendance is below 75% in ${lowAttendanceSubjects.length} subject${lowAttendanceSubjects.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...lowAttendanceSubjects.map((subject) {
                final percentage = _getSubjectAttendancePercentage(subject.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        subject.isPractical ? Icons.science : Icons.book,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          subject.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.orange.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Maintain at least 75% attendance to avoid academic issues.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey.shade50,
            Colors.grey.shade100,
          ],
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Created by Jainil Kothari',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            'AI&DS Department | Ajeenkya DY Patil School of Engineering',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Student Dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.student.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _loadStudentAttendanceData,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading attendance data...',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadStudentAttendanceData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildEnhancedHeader(),
                    _buildTheoryPracticalStats(),
                    _buildLowAttendanceAlert(),
                    _buildEnhancedSubjectWiseAttendance(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          _buildEnhancedFooter(),
        ],
      ),
    );
  }
}