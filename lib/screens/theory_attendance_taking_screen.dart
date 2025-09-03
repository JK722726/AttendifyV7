import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';
import '../models/student_model.dart';
import '../models/attendance_model.dart';
import '../services/repository.dart';

class TheoryAttendanceTakingScreen extends StatefulWidget {
  final ClassModel classModel;
  final SubjectModel subject;
  final DateTime dateTime;

  const TheoryAttendanceTakingScreen({
    super.key,
    required this.classModel,
    required this.subject,
    required this.dateTime,
  });

  @override
  State<TheoryAttendanceTakingScreen> createState() => _TheoryAttendanceTakingScreenState();
}

class _TheoryAttendanceTakingScreenState extends State<TheoryAttendanceTakingScreen>
    with TickerProviderStateMixin {
  final Repository _repository = Repository();
  final Map<String, bool> _attendanceStatus = {};
  bool _isLoading = true;
  bool _isSaving = false;
  int _currentFilter = 0; // 0 = All, 1 = 1-10, 2 = 11-20, etc.
  List<List<StudentModel>> _studentGroups = [];
  List<StudentModel> _allStudents = [];

  // Animation controllers
  late AnimationController _headerController;
  late AnimationController _filterController;
  late AnimationController _listController;
  late AnimationController _saveButtonController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _filterScaleAnimation;
  late Animation<double> _saveButtonScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _filterController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _listController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 500),
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
      begin: const Offset(0.0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));

    _filterScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _filterController,
      curve: Curves.elasticOut,
    ));

    _saveButtonScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _saveButtonController,
      curve: Curves.elasticOut,
    ));

    _initializeStudentGroups();
    _loadExistingAttendance();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _filterController.dispose();
    _listController.dispose();
    _saveButtonController.dispose();
    super.dispose();
  }

  void _initializeStudentGroups() {
    _studentGroups.clear();

    // Sort students by roll number
    final List<StudentModel> sortedStudents = List<StudentModel>.from(widget.classModel.students);
    sortedStudents.sort((a, b) {
      final int? aRollInt = int.tryParse(a.rollNumber);
      final int? bRollInt = int.tryParse(b.rollNumber);
      if (aRollInt != null && bRollInt != null) {
        return aRollInt.compareTo(bRollInt);
      }
      return a.rollNumber.compareTo(b.rollNumber);
    });

    _allStudents = sortedStudents;

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
    for (final StudentModel student in widget.classModel.students) {
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
      );

      if (existingAttendance != null) {
        // Update attendance status based on existing records
        for (final record in existingAttendance.records) {
          if (_attendanceStatus.containsKey(record.studentId)) {
            _attendanceStatus[record.studentId] = record.present;
          }
        }
      }

      // Start animations after loading
      _headerController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _filterController.forward();
      await Future.delayed(const Duration(milliseconds: 100));
      _listController.forward();
      await Future.delayed(const Duration(milliseconds: 100));
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

    // Animate save button with bounce effect (same as practical screen)
    _saveButtonController.reverse().then((_) {
      _saveButtonController.forward();
    });

    setState(() {
      _isSaving = true;
    });

    try {
      final List<AttendanceRecord> records = widget.classModel.students.map((student) {
        return AttendanceRecord(
          studentId: student.id,
          present: _attendanceStatus[student.id] ?? false,
        );
      }).toList();

      final AttendanceModel attendance = AttendanceModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        classId: widget.classModel.id,
        subjectId: widget.subject.id,
        dateTime: widget.dateTime,
        records: records,
        batchNumber: null, // Theory doesn't have batches
        totalBatches: null,
      );

      await _repository.saveAttendanceRecord(attendance);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Theory attendance saved successfully'),
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
      for (final StudentModel student in _currentStudentGroup) {
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

    final List<StudentModel> group = _studentGroups[filterIndex];
    if (group.isEmpty) return '';

    final String startRoll = group.first.rollNumber;
    final String endRoll = group.last.rollNumber;

    return '$startRoll-$endRoll';
  }

  int get _totalPresentCount {
    return _attendanceStatus.values.where((present) => present).length;
  }

  int get _totalAbsentCount {
    return widget.classModel.students.length - _totalPresentCount;
  }

  Widget _buildAnimatedStatCard(String value, String label, Color color, int index) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 600 + (index * 100)),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, animationValue, child) {
        return Transform.scale(
          scale: animationValue,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Theory Attendance',
              style: TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.subject.name} - ${widget.classModel.name}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1000),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.rotate(
                  angle: value * 2 * 3.14159,
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _headerFadeAnimation,
              child: const Text(
                'Loading attendance data...',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      )
          : SafeArea(
        child: Column(
          children: [
            // Animated Header Info Card
            FadeTransition(
              opacity: _headerFadeAnimation,
              child: SlideTransition(
                position: _headerSlideAnimation,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.withOpacity(0.05),
                            Colors.white,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Theory Label with animation
                          TweenAnimationBuilder(
                            duration: const Duration(milliseconds: 800),
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Theory Subject - All Students',
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          // Animated Stats Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildAnimatedStatCard(
                                '$_totalPresentCount',
                                'Present',
                                Colors.green,
                                0,
                              ),
                              Container(width: 1, height: 20, color: Colors.grey.shade300),
                              _buildAnimatedStatCard(
                                '$_totalAbsentCount',
                                'Absent',
                                Colors.red,
                                1,
                              ),
                              Container(width: 1, height: 20, color: Colors.grey.shade300),
                              _buildAnimatedStatCard(
                                '${widget.classModel.students.length}',
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

            // Animated Student Filter Chips
            if (widget.classModel.students.length > 10) ...[
              ScaleTransition(
                scale: _filterScaleAnimation,
                child: Container(
                  height: 35,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _studentGroups.length,
                    itemBuilder: (context, index) {
                      final bool isSelected = _currentFilter == index;
                      final List<StudentModel> group = _studentGroups[index];
                      final int groupPresentCount = group
                          .where((student) => _attendanceStatus[student.id] == true)
                          .length;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(
                            '${_getFilterLabel(index)} ($groupPresentCount/${group.length})',
                            style: const TextStyle(fontSize: 9),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _currentFilter = index;
                              });
                            }
                          },
                          selectedColor: Colors.blue.shade100,
                          checkmarkColor: Colors.blue.shade800,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Animated Mark All Present Checkbox
            ScaleTransition(
              scale: _filterScaleAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 600),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Icon(Icons.people, color: Colors.green.shade700, size: 16),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mark All Present (${_currentStudentGroup.length} students)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.9,
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
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 4),

            // Animated Student List
            Expanded(
              child: _currentStudentGroup.isEmpty
                  ? const Center(child: Text('No students in this group'))
                  : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: AnimationLimiter(
                  child: ListView.builder(
                    itemCount: _currentStudentGroup.length,
                    itemBuilder: (context, index) {
                      final StudentModel student = _currentStudentGroup[index];
                      final bool isPresent = _attendanceStatus[student.id] ?? false;

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 3),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.white,
                                      isPresent
                                          ? Colors.green.withOpacity(0.05)
                                          : Colors.red.withOpacity(0.05),
                                    ],
                                  ),
                                ),
                                child: ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  // Animated leading container
                                  leading: TweenAnimationBuilder(
                                    duration: const Duration(milliseconds: 300),
                                    tween: ColorTween(
                                      begin: isPresent ? Colors.red : Colors.green,
                                      end: isPresent ? Colors.green : Colors.red,
                                    ),
                                    builder: (context, color, child) {
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isPresent ? Colors.green : Colors.red,
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isPresent ? Colors.green : Colors.red).withOpacity(0.3),
                                              spreadRadius: 1,
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            student.rollNumber,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
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
                                      fontSize: 16,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  subtitle: Text(
                                    student.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Transform.scale(
                                    scale: 1.1,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      child: Switch(
                                        key: ValueKey(isPresent),
                                        value: isPresent,
                                        onChanged: (value) {
                                          setState(() {
                                            _attendanceStatus[student.id] = value;
                                          });
                                        },
                                        activeColor: Colors.green,
                                        inactiveThumbColor: Colors.red.shade300,
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
                      );
                    },
                  ),
                ),
              ),
            ),

            // Animated Save Button with Rotating Effect (Updated)
            ScaleTransition(
              scale: _saveButtonScaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveAttendance,
                    icon: _isSaving
                        ? TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.rotate(
                          angle: value * 6.28318, // 2 * pi for full rotation
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
                        : const Icon(Icons.save, size: 18),
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
                        _isSaving ? 'Saving Theory Attendance...' : 'Save Theory Attendance',
                        key: ValueKey(_isSaving),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: _isSaving ? 2 : 4,
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