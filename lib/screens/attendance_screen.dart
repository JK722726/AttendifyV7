import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../services/repository.dart';
import 'theory_attendance_taking_screen.dart';
import 'practical_attendance_taking_screen.dart';
import 'attendance_history_screen.dart';

class AttendanceScreen extends StatefulWidget {
  final ClassModel classModel;
  final SubjectModel subject;

  const AttendanceScreen({
    super.key,
    required this.classModel,
    required this.subject,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final Repository _repository = Repository();
  late DateTime _selectedDateTime;
  int? _selectedBatch; // For practical subjects
  int _totalBatches = 0;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime.now();
    _calculateBatches();
  }

  void _calculateBatches() {
    if (widget.subject.isPractical) {
      _totalBatches = (widget.classModel.students.length / 25).ceil();
      _selectedBatch = 1; // Default to first batch
    }
  }

  Future<void> _selectDateTime() async {
    // First select date
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Attendance Date',
    );

    if (pickedDate != null) {
      // Then select time
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
        helpText: 'Select Attendance Time',
      );

      if (pickedTime != null) {
        final newDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          _selectedDateTime = newDateTime;
        });
      }
    }
  }

  List<StudentModel> _getBatchStudents() {
    if (widget.subject.isTheory || _selectedBatch == null) {
      return widget.classModel.students;
    }

    // Sort students by roll number first
    final sortedStudents = List<StudentModel>.from(widget.classModel.students);
    sortedStudents.sort((a, b) {
      final aRollInt = int.tryParse(a.rollNumber);
      final bRollInt = int.tryParse(b.rollNumber);
      if (aRollInt != null && bRollInt != null) {
        return aRollInt.compareTo(bRollInt);
      }
      return a.rollNumber.compareTo(b.rollNumber);
    });

    // Calculate batch range
    int startIndex = (_selectedBatch! - 1) * 25;
    int endIndex = startIndex + 25;
    if (endIndex > sortedStudents.length) {
      endIndex = sortedStudents.length;
    }

    return sortedStudents.sublist(startIndex, endIndex);
  }

  String _getBatchRollRange() {
    if (widget.subject.isTheory || _selectedBatch == null) {
      return 'All Students';
    }

    final batchStudents = _getBatchStudents();
    if (batchStudents.isEmpty) return 'No Students';

    return 'Roll ${batchStudents.first.rollNumber} - ${batchStudents.last.rollNumber}';
  }

  Future<void> _navigateToAttendanceTaking() async {
    final batchStudents = _getBatchStudents();

    if (batchStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students found for selected batch')),
      );
      return;
    }

    dynamic result;

    if (widget.subject.isPractical) {
      // Navigate to Practical Attendance Taking Screen
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PracticalAttendanceTakingScreen(
            classModel: widget.classModel,
            subject: widget.subject,
            dateTime: _selectedDateTime,
            batchStudents: batchStudents,
            batchNumber: _selectedBatch!,
            totalBatches: _totalBatches,
          ),
        ),
      );
    } else {
      // Navigate to Theory Attendance Taking Screen
      result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TheoryAttendanceTakingScreen(
            classModel: widget.classModel,
            subject: widget.subject,
            dateTime: _selectedDateTime,
          ),
        ),
      );
    }

    if (result == true) {
      // Attendance was saved successfully
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} at $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final batchStudents = _getBatchStudents();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance Monitoring App'),
            Text(
              '${widget.subject.name} - ${widget.classModel.name}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AttendanceHistoryScreen(
                    classModel: widget.classModel,
                    subject: widget.subject,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Subject Type Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: widget.subject.isPractical ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            widget.subject.isPractical ? Icons.science : Icons.book,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.subject.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: widget.subject.isPractical ? Colors.green.shade100 : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  widget.subject.typeDisplayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.subject.isPractical ? Colors.green.shade800 : Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
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

                const SizedBox(height: 16),

                // Date and Time Selection Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Date & Time',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDateTime(_selectedDateTime),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _selectDateTime,
                              icon: const Icon(Icons.schedule, size: 18),
                              label: const Text('Change'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Batch Selection Card (for practical subjects only)
                if (widget.subject.isPractical) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Batch',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.group, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Total $_totalBatches batches (25 students each)',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 50,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _totalBatches,
                              itemBuilder: (context, index) {
                                final batchNum = index + 1;
                                final isSelected = _selectedBatch == batchNum;

                                return Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  child: ChoiceChip(
                                    label: Text('Batch $batchNum'),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedBatch = batchNum;
                                        });
                                      }
                                    },
                                    selectedColor: Colors.green.shade100,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.green.shade800 : null,
                                      fontWeight: isSelected ? FontWeight.bold : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_selectedBatch != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.green.shade700, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Batch $_selectedBatch: ${batchStudents.length} students (${_getBatchRollRange()})',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Student Count Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.isPractical ? 'Batch Students' : 'All Students',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  '${batchStudents.length}',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                Text(
                                  widget.subject.isPractical ? 'Students in Batch' : 'Total Students',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            if (widget.subject.isPractical) ...[
                              Column(
                                children: [
                                  Text(
                                    '${widget.classModel.students.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const Text(
                                    'Total in Class',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Take Attendance Button
                SizedBox(
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: batchStudents.isEmpty ? null : _navigateToAttendanceTaking,
                    icon: const Icon(Icons.how_to_reg, size: 24),
                    label: Text(
                      widget.subject.isPractical
                          ? 'Take Batch $_selectedBatch Attendance'
                          : 'Take Attendance',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Info Card
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Instructions',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (widget.subject.isPractical) ...[
                          const Text('• Select the batch for practical attendance'),
                          const Text('• Each batch contains up to 25 students'),
                          const Text('• Students are automatically sorted by roll number'),
                        ] else ...[
                          const Text('• Attendance will be taken for all students'),
                          const Text('• You can filter students in groups of 10'),
                        ],
                        const Text('• Choose the date and time for attendance'),
                        const Text('• Click "Take Attendance" to proceed'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}