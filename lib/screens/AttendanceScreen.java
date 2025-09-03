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

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  final Repository _repository = Repository();
  late DateTime _selectedDateTime;
  int? _selectedBatch;
  int _totalBatches = 0;
  int _batchSize = 25; // Default batch size
  List<AttendanceModel> _existingAttendance = [];
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime.now();
    
    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _loadExistingAttendance();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingAttendance() async {
    try {
      final attendance = await _repository.getAttendanceForSubjectAndDate(
        widget.classModel.id,
        widget.subject.id,
        _selectedDateTime,
      );
      if (mounted) {
        setState(() {
          _existingAttendance = attendance;
        });
      }
    } catch (e) {
      // Handle error silently for now
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
        _loadExistingAttendance();
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

    // Calculate batch range using dynamic batch size
    int startIndex = (_selectedBatch! - 1) * _batchSize;
    int endIndex = startIndex + _batchSize;
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
            batchSize: _batchSize, // Pass the dynamic batch size
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
      _loadExistingAttendance();
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

  Widget _buildPracticalSubjectContent() {
    return FutureBuilder<int>(
      future: _repository.getBatchSizeForClass(widget.classModel.id),
      builder: (context, batchSizeSnapshot) {
        if (!batchSizeSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        _batchSize = batchSizeSnapshot.data!;
        _totalBatches = _repository.calculateTotalBatches(
          widget.classModel.students.length, 
          _batchSize
        );

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.withOpacity(0.05),
                      Colors.white,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.science,
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
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
                              ),
                              Text(
                                'Practical Subject - Batch Size: $_batchSize students',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Stats Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                '$_totalBatches',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Text(
                                'Total Batches',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '$_batchSize',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const Text(
                                'Batch Size',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${widget.classModel.students.length}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const Text(
                                'Total Students',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Batch Selection
                    const Text(
                      'Select Batch to Take Attendance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Batch Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2.5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _totalBatches,
                      itemBuilder: (context, index) {
                        final batchNumber = index + 1;
                        return FutureBuilder<List<StudentModel>>(
                          future: _repository.getStudentsForBatch(
                            widget.classModel.students, 
                            batchNumber, 
                            widget.classModel.id
                          ),
                          builder: (context, studentsSnapshot) {
                            final batchStudents = studentsSnapshot.data ?? [];
                            final hasAttendance = _existingAttendance.any((a) => 
                              a.batchNumber == batchNumber &&
                              a.dateTime.isAtSameMomentAs(_selectedDateTime)
                            );

                            return Card(
                              elevation: hasAttendance ? 4 : 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: batchStudents.isEmpty ? null : () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PracticalAttendanceTakingScreen(
                                        classModel: widget.classModel,
                                        subject: widget.subject,
                                        dateTime: _selectedDateTime,
                                        batchStudents: batchStudents,
                                        batchNumber: batchNumber,
                                        totalBatches: _totalBatches,
                                        batchSize: _batchSize, // Pass the dynamic batch size
                                      ),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadExistingAttendance();
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: hasAttendance
                                        ? LinearGradient(
                                            colors: [Colors.green.shade100, Colors.green.shade50]
                                          )
                                        : null,
                                    border: hasAttendance
                                        ? Border.all(color: Colors.green, width: 2)
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (hasAttendance)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                      Text(
                                        'Batch $batchNumber',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: hasAttendance ? Colors.green.shade700 : Colors.black87,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (batchStudents.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${batchStudents.length} students',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (batchStudents.isNotEmpty) ...[
                                          Text(
                                            'Roll ${batchStudents.first.rollNumber}-${batchStudents.last.rollNumber}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ] else ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'No students',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Students are divided into batches of $_batchSize each. Take attendance for each batch separately. Green batches already have attendance recorded.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date and Time Selection Card
              FadeTransition(
                opacity: _fadeAnimation,
                child: Card(
                  margin: const EdgeInsets.all(16),
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
              ),

              // Subject-specific content
              if (widget.subject.isPractical)
                _buildPracticalSubjectContent()
              else
                _buildTheorySubjectContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTheorySubjectContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
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
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.book,
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
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.subject.typeDisplayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
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

              // Student Count Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Students',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Column(
                            children: [
                              Text(
                                '${widget.classModel.students.length}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const Text(
                                'Total Students',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
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
                  onPressed: widget.classModel.students.isEmpty ? null : _navigateToAttendanceTaking,
                  icon: const Icon(Icons.how_to_reg, size: 24),
                  label: const Text(
                    'Take Attendance',
                    style: TextStyle(
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
                      const Text('• Attendance will be taken for all students'),
                      const Text('• You can filter students in groups of 10'),
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
    );
  }
}