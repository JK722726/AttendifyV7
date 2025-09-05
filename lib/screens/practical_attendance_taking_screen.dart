import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animations/animations.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../services/repository.dart';

class PracticalAttendanceTakingScreen extends StatefulWidget {
  final ClassModel classModel;
  final SubjectModel subject;
  final DateTime dateTime;
  final List<StudentModel> batchStudents;
  final int batchNumber;
  final int totalBatches;

  const PracticalAttendanceTakingScreen({
    super.key,
    required this.classModel,
    required this.subject,
    required this.dateTime,
    required this.batchStudents,
    required this.batchNumber,
    required this.totalBatches,
  });

  @override
  State<PracticalAttendanceTakingScreen> createState() => _PracticalAttendanceTakingScreenState();
}

class _PracticalAttendanceTakingScreenState extends State<PracticalAttendanceTakingScreen>
    with TickerProviderStateMixin {
  final Repository _repository = Repository();
  final Map<String, bool> _attendanceStatus = {};
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentFilter = 0; // 0 = All, 1 = 1-x, 2 = (x+1)-2x, etc.
  List<List<StudentModel>> _studentGroups = [];
  int _batchSize = 25; // Dynamic batch size
  int _filterSize = 10; // Size for filtering groups

  // Enhanced Animation Controllers
  late AnimationController _headerController;
  late AnimationController _filterController;
  late AnimationController _listController;
  late AnimationController _saveButtonController;
  late AnimationController _statsController;

  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _filterScaleAnimation;
  late Animation<double> _saveButtonScaleAnimation;
  late Animation<double> _statsScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadBatchSettings();
  }

  Future<void> _loadBatchSettings() async {
    final batchSize = await _repository.getBatchSize();
    setState(() {
      _batchSize = batchSize;
      // Adjust filter size based on batch size for better UX
      _filterSize = (batchSize / 2.5).ceil(); // Roughly 40% of batch size
      if (_filterSize < 5) _filterSize = 5; // Minimum filter size
      if (_filterSize > 15) _filterSize = 15; // Maximum filter size
    });
    _initializeStudentGroups();
    _loadExistingAttendance();
  }

  void _initializeAnimations() {
    // Header animations
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Filter animations
    _filterController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // List animations
    _listController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Save button animations
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    // Stats animations
    _statsController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // Initialize animations
    _headerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeInOut,
    ));

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.elasticOut,
    ));

    _filterScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _filterController,
      curve: Curves.bounceOut,
    ));

    _saveButtonScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _saveButtonController,
      curve: Curves.elasticOut,
    ));

    _statsScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _statsController,
      curve: Curves.bounceOut,
    ));
  }

  @override
  void dispose() {
    _headerController.dispose();
    _filterController.dispose();
    _listController.dispose();
    _saveButtonController.dispose();
    _statsController.dispose();
    super.dispose();
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

    // Add "All" as first group
    _studentGroups.add(sortedStudents);

    // Group students into groups based on dynamic filter size
    for (int i = 0; i < sortedStudents.length; i += _filterSize) {
      int endIndex = i + _filterSize;
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
      final existingAttendance = await _repository.getAttendanceByDateTime(
        widget.classModel.id,
        widget.subject.id,
        widget.dateTime,
        batchNumber: widget.batchNumber,
      );

      if (existingAttendance != null) {
        // Update attendance status based on existing records
        for (final record in existingAttendance.records) {
          if (_attendanceStatus.containsKey(record.studentId)) {
            _attendanceStatus[record.studentId] = record.present;
          }
        }
      }

      // Sequential animation startup
      await Future.delayed(const Duration(milliseconds: 200));
      _headerController.forward();

      await Future.delayed(const Duration(milliseconds: 300));
      _statsController.forward();

      await Future.delayed(const Duration(milliseconds: 200));
      _filterController.forward();

      await Future.delayed(const Duration(milliseconds: 300));
      _listController.forward();

      await Future.delayed(const Duration(milliseconds: 200));
      _saveButtonController.forward();

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
    if (_isSaving) return;

    // Animate save button with bounce effect
    _saveButtonController.reverse().then((_) {
      _saveButtonController.forward();
    });

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
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        classId: widget.classModel.id,
        subjectId: widget.subject.id,
        dateTime: widget.dateTime,
        records: records,
        batchNumber: widget.batchNumber,
        totalBatches: widget.totalBatches,
      );

      await _repository.saveAttendanceRecord(attendance);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch ${widget.batchNumber} attendance saved successfully'),
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
    return _attendanceStatus.values.where((present) => present).length;
  }

  int get _totalAbsentCount {
    return widget.batchStudents.length - _totalPresentCount;
  }

  Widget _buildEnhancedStatCard(String value, String label, Color color, int index) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _statsController,
          curve: Interval(
            index * 0.2,
            (index * 0.2) + 0.6,
            curve: Curves.elasticOut,
          ),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Text(
                value,
                key: ValueKey(value),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Practical Attendance',
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Batch ${widget.batchNumber} - ${widget.subject.name}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1500),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.rotate(
                  angle: value * 6.28318, // 2 * pi for full rotation
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.green, Colors.green.shade300],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.schedule,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 800),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: const Text(
                    'Loading attendance data...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      )
          : SafeArea(
        child: Column(
          children: [
            // Enhanced Header with Gradient Background
            FadeTransition(
              opacity: _headerFadeAnimation,
              child: SlideTransition(
                position: _headerSlideAnimation,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.green.withOpacity(0.1),
                            Colors.white,
                            Colors.green.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          // Enhanced Batch Badge
                          TweenAnimationBuilder(
                            duration: const Duration(milliseconds: 1000),
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.green.shade400, Colors.green.shade600],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.groups, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Batch ${widget.batchNumber} of ${widget.totalBatches} ($_batchSize students)',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Enhanced Stats Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildEnhancedStatCard(
                                '$_totalPresentCount',
                                'Present',
                                Colors.green,
                                0,
                              ),
                              _buildEnhancedStatCard(
                                '$_totalAbsentCount',
                                'Absent',
                                Colors.red,
                                1,
                              ),
                              _buildEnhancedStatCard(
                                '${widget.batchStudents.length}',
                                'Total',
                                Colors.blue,
                                2,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Enhanced Filter Chips
            if (widget.batchStudents.length > _filterSize) ...[
              ScaleTransition(
                scale: _filterScaleAnimation,
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _studentGroups.length,
                    itemBuilder: (context, index) {
                      final isSelected = _currentFilter == index;
                      final group = _studentGroups[index];
                      final groupPresentCount = group
                          .where((student) => _attendanceStatus[student.id] == true)
                          .length;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6, top: 2, bottom: 2),
                        child: Material(
                          elevation: isSelected ? 4 : 1,
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: isSelected
                                  ? LinearGradient(
                                colors: [Colors.green.shade400, Colors.green.shade600],
                              )
                                  : null,
                              color: isSelected ? null : Colors.grey.shade100,
                              border: Border.all(
                                color: isSelected ? Colors.transparent : Colors.grey.shade300,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                setState(() {
                                  _currentFilter = index;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    if (isSelected) const SizedBox(width: 3),
                                    Text(
                                      '${_getFilterLabel(index)} ($groupPresentCount/${group.length})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Enhanced Mark All Present Section
            ScaleTransition(
              scale: _filterScaleAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.green.withOpacity(0.05),
                          Colors.green.withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.people,
                            color: Colors.green.shade700,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mark All Present (${_currentStudentGroup.length} students)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: 1.0,
                          child: Checkbox(
                            value: _currentStudentGroup.isNotEmpty &&
                                _currentStudentGroup.every((student) =>
                                _attendanceStatus[student.id] == true),
                            onChanged: (value) {
                              _markAllPresent(value ?? false);
                            },
                            activeColor: Colors.green,
                            checkColor: Colors.white,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            side: BorderSide(color: Colors.green.shade400, width: 2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Enhanced Student List
            Expanded(
              child: _currentStudentGroup.isEmpty
                  ? const Center(
                child: Text(
                  'No students in this group',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
                  : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimationLimiter(
                  key: ValueKey(_currentFilter),
                  child: ListView.builder(
                    itemCount: _currentStudentGroup.length,
                    itemBuilder: (context, index) {
                      final student = _currentStudentGroup[index];
                      final isPresent = _attendanceStatus[student.id] ?? false;

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 600),
                        child: SlideAnimation(
                          verticalOffset: 80.0,
                          curve: Curves.easeOutQuart,
                          child: FadeInAnimation(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Colors.white,
                                        isPresent
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.05),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: isPresent
                                          ? Colors.green.withOpacity(0.3)
                                          : Colors.red.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    leading: TweenAnimationBuilder(
                                      duration: const Duration(milliseconds: 500),
                                      tween: ColorTween(
                                        begin: Colors.grey,
                                        end: isPresent ? Colors.green : Colors.red,
                                      ),
                                      builder: (context, color, child) {
                                        return Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                (color as Color),
                                                (color).withOpacity(0.8),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (color).withOpacity(0.4),
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
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    title: Text(
                                      'Roll No: ${student.rollNumber}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        student.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    trailing: Transform.scale(
                                      scale: 1.0,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 300),
                                        transitionBuilder: (child, animation) {
                                          return RotationTransition(
                                            turns: animation,
                                            child: ScaleTransition(scale: animation, child: child),
                                          );
                                        },
                                        child: Switch(
                                          key: ValueKey('${student.id}_$isPresent'),
                                          value: isPresent,
                                          onChanged: (value) {
                                            setState(() {
                                              _attendanceStatus[student.id] = value;
                                            });
                                          },
                                          activeColor: Colors.green.shade600,
                                          inactiveThumbColor: Colors.red.shade400,
                                          activeTrackColor: Colors.green.shade200,
                                          inactiveTrackColor: Colors.red.shade200,
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _attendanceStatus[student.id] = !isPresent;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Enhanced Save Button
            ScaleTransition(
              scale: _saveButtonScaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAttendance,
                    icon: _isSaving
                        ? TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.rotate(
                          angle: value * 6.28318, // 2 * pi
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        );
                      },
                    )
                        : Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.save, size: 16),
                    ),
                    label: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(animation),
                          child: FadeTransition(opacity: animation, child: child),
                        );
                      },
                      child: Text(
                        _isSaving ? 'Saving Attendance...' : 'Save Batch ${widget.batchNumber} Attendance',
                        key: ValueKey(_isSaving),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: _isSaving ? 2 : 4,
                      shadowColor: Colors.green.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}