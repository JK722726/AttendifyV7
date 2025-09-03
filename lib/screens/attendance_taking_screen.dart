import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../services/repository.dart';

class AttendanceTakingScreen extends StatefulWidget {
  final ClassModel classModel;
  final SubjectModel subject;
  final DateTime dateTime;
  final List<StudentModel> batchStudents;
  final int? batchNumber;
  final int totalBatches;

  const AttendanceTakingScreen({
    super.key,
    required this.classModel,
    required this.subject,
    required this.dateTime,
    required this.batchStudents,
    this.batchNumber,
    required this.totalBatches,
  });

  @override
  State<AttendanceTakingScreen> createState() => _AttendanceTakingScreenState();
}

class _AttendanceTakingScreenState extends State<AttendanceTakingScreen> {
  final Repository _repository = Repository();
  final Map<String, bool> _attendanceStatus = {};
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentFilter = 0; // 0 = All, 1 = 1-10, 2 = 11-20, etc.
  List<List<StudentModel>> _studentGroups = [];
  List<StudentModel> _allStudents = []; // Store all students for "All" view

  @override
  void initState() {
    super.initState();
    _initializeStudentGroups();
    _loadExistingAttendance();
  }

  void _initializeStudentGroups() {
    _studentGroups.clear();

    // Sort students by roll number
    final sortedStudents = List<StudentModel>.from(widget.batchStudents);
    sortedStudents.sort((a, b) {
      final aRollInt = int.tryParse(a.rollNumber);
      final bRollInt = int.tryParse(b.rollNumber);
      if (aRollInt != null && bRollInt != null) {
        return aRollInt.compareTo(bRollInt);
      }
      return a.rollNumber.compareTo(b.rollNumber);
    });

    _allStudents = sortedStudents; // Store all students

    // Add "All" as first group
    _studentGroups.add(sortedStudents);

    // Group students into groups of 10
    for (int i = 0; i < sortedStudents.length; i += 10) {
      int endIndex = i + 10;
      if (endIndex > sortedStudents.length) {
        endIndex = sortedStudents.length;
      }
      _studentGroups.add(sortedStudents.sublist(i, endIndex));
    }

    // Initialize attendance status for all students
    for (final student in widget.batchStudents) {
      _attendanceStatus[student.id] = false;
    }
  }

  Future<void> _loadExistingAttendance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load existing attendance for the selected date and time
      final existingAttendance = await _repository.getAttendanceByDateTime(
        widget.classModel.id,
        widget.subject.id,
        widget.dateTime,
        batchNumber: widget.batchNumber,
      );

      if (existingAttendance != null &&
          existingAttendance.batchNumber == widget.batchNumber) {
        // Update attendance status based on existing records
        for (final record in existingAttendance.records) {
          if (_attendanceStatus.containsKey(record.studentId)) {
            _attendanceStatus[record.studentId] = record.present;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance: $e')),
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

  Future<void> _saveAttendance() async {
    if (_isSaving) return; // Prevent multiple saves

    setState(() {
      _isSaving = true;
    });

    try {
      final records = widget.batchStudents.map((student) {
        return AttendanceRecord(
          studentId: student.id,
          present: _attendanceStatus[student.id] ?? false,
        );
      }).toList();

      final attendance = AttendanceModel(
        id: DateTime
            .now()
            .millisecondsSinceEpoch
            .toString(),
        classId: widget.classModel.id,
        subjectId: widget.subject.id,
        dateTime: widget.dateTime,
        records: records,
        batchNumber: widget.batchNumber,
        totalBatches: widget.subject.isPractical ? widget.totalBatches : null,
      );

      await _repository.saveAttendanceRecord(attendance);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                widget.subject.isPractical
                    ? 'Batch ${widget
                    .batchNumber} attendance saved successfully'
                    : 'Attendance saved successfully'
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _markAllPresent(bool markAll) {
    setState(() {
      for (final student in _currentStudentGroup) {
        _attendanceStatus[student.id] = markAll;
      }
    });
  }

  List<StudentModel> get _currentStudentGroup {
    if (_currentFilter < _studentGroups.length) {
      return _studentGroups[_currentFilter];
    }
    return [];
  }

  String _getFilterLabel(int filterIndex) {
    if (filterIndex == 0) return 'All';
    if (filterIndex > _studentGroups.length) return '';

    final group = _studentGroups[filterIndex];
    if (group.isEmpty) return '';

    final startRoll = group.first.rollNumber;
    final endRoll = group.last.rollNumber;

    return '$startRoll-$endRoll';
  }

  int get _totalPresentCount {
    return _attendanceStatus.values
        .where((present) => present)
        .length;
  }

  int get _totalAbsentCount {
    return widget.batchStudents.length - _totalPresentCount;
  }

  // Compact header with reduced size
  Widget _buildCompactHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.subject.isPractical
                  ? [Colors.green.shade400, Colors.green.shade600]
                  : [Colors.blue.shade400, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Subject Info Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.subject.isPractical ? Icons.science : Icons.book,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.subject.isPractical ? 'PRACTICAL' : 'THEORY',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (widget.subject.isPractical) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Batch ${widget.batchNumber}/${widget.totalBatches}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Compact Stats
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCompactStatColumn('Present', _totalPresentCount.toString(), Colors.white, Icons.check_circle_outline),
                    Container(width: 1, height: 25, color: Colors.white.withOpacity(0.3)),
                    _buildCompactStatColumn('Absent', _totalAbsentCount.toString(), Colors.white, Icons.cancel_outlined),
                    Container(width: 1, height: 25, color: Colors.white.withOpacity(0.3)),
                    _buildCompactStatColumn('Total', widget.batchStudents.length.toString(), Colors.white, Icons.people_outline),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStatColumn(String title, String value, Color color, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            color: color.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Improved student card with bigger, clearer names and roll numbers
  Widget _buildImprovedStudentCard(StudentModel student, int index) {
    final isPresent = _attendanceStatus[student.id] ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            setState(() {
              _attendanceStatus[student.id] = !isPresent;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isPresent ? Colors.green.shade300 : Colors.grey.shade300,
                width: 1.5,
              ),
              color: isPresent ? Colors.green.shade50 : Colors.grey.shade50,
            ),
            child: Row(
              children: [
                // Rounded square for roll number
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isPresent ? Colors.green.shade600 : Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(8), // Rounded square
                    boxShadow: [
                      BoxShadow(
                        color: (isPresent ? Colors.green : Colors.grey).withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      student.rollNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Student Info with bigger, clearer text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Roll Number - Made much more prominent
                      Text(
                        'Roll No: ${student.rollNumber}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Student Name - Made bigger and clearer
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Compact switch
                Transform.scale(
                  scale: 1.2,
                  child: Switch(
                    value: isPresent,
                    onChanged: (value) {
                      setState(() {
                        _attendanceStatus[student.id] = value;
                      });
                    },
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.grey.shade400,
                    activeTrackColor: Colors.green.shade200,
                    inactiveTrackColor: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
        ),
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
              'Mark Attendance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.classModel.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: widget.subject.isPractical ? Colors.green : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading attendance data...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Compact header
          _buildCompactHeader(),

          // Student Filter Chips - Show only if more than 10 students
          if (widget.batchStudents.length > 10) ...[
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _studentGroups.length,
                itemBuilder: (context, index) {
                  final isSelected = _currentFilter == index;
                  final group = _studentGroups[index];
                  final groupPresentCount = group
                      .where((student) => _attendanceStatus[student.id] == true)
                      .length;

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        '${_getFilterLabel(index)}\n($groupPresentCount/${group.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _currentFilter = index;
                          });
                        }
                      },
                      selectedColor: widget.subject.isPractical ? Colors.green.shade100 : Colors.blue.shade100,
                      checkmarkColor: widget.subject.isPractical ? Colors.green.shade800 : Colors.blue.shade800,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Single Mark All Present Checkbox - Compact
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Mark All Present (${_currentStudentGroup.length} students)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 1.3,
                      child: Checkbox(
                        value: _currentStudentGroup.isNotEmpty &&
                            _currentStudentGroup.every((student) =>
                            _attendanceStatus[student.id] == true),
                        onChanged: (value) {
                          _markAllPresent(value ?? false);
                        },
                        activeColor: Colors.green,
                        checkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Student List with improved cards
          Expanded(
            child: _currentStudentGroup.isEmpty
                ? const Center(
              child: Text(
                'No students in this group',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _currentStudentGroup.length,
              itemBuilder: (context, index) {
                final student = _currentStudentGroup[index];
                return _buildImprovedStudentCard(student, index);
              },
            ),
          ),

          // Compact Save Button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAttendance,
                icon: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(Icons.save, size: 20),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Attendance',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.subject.isPractical ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}