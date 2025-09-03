import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:lottie/lottie.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/subject_model.dart';
import '../services/repository.dart';
import '../services/export_service.dart';
import 'add_student_screen.dart';
import 'add_subject_screen.dart';
import 'attendance_screen.dart';
import 'attendance_history_screen.dart';
import 'student_dashboard_screen.dart';
import 'subject_dashboard_screen.dart';
import 'class_dashboard_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final ClassModel classModel;

  const ClassDetailScreen({super.key, required this.classModel});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen>
    with TickerProviderStateMixin {
  final Repository _repository = Repository();
  final ExportService _exportService = ExportService();
  late ClassModel _currentClass;
  bool _isLoading = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _fabController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _currentClass = widget.classModel;

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    ));

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    _refreshClassData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _refreshClassData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedClass = await _repository.getClassById(_currentClass.id);
      if (mounted && updatedClass != null) {
        setState(() {
          _currentClass = updatedClass;
        });
        // Restart FAB animation after data refresh
        _fabController.reset();
        _fabController.forward();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing class data: $e')),
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

  Future<void> _deleteStudent(StudentModel student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, -0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: AnimationController(
            duration: const Duration(milliseconds: 300),
            vsync: this,
          )..forward(),
          curve: Curves.easeOut,
        )),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: AnimationController(
                duration: const Duration(milliseconds: 300),
                vsync: this,
              )..forward(),
              curve: Curves.easeIn,
            ),
          ),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Student'),
            content: Text('Are you sure you want to delete "${student.name}"? This will also remove their attendance records.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteStudentFromClass(_currentClass.id, student.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Student "${student.name}" deleted successfully')),
          );
        }
        _refreshClassData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting student: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteSubject(SubjectModel subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, -0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: AnimationController(
            duration: const Duration(milliseconds: 300),
            vsync: this,
          )..forward(),
          curve: Curves.easeOut,
        )),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: AnimationController(
                duration: const Duration(milliseconds: 300),
                vsync: this,
              )..forward(),
              curve: Curves.easeIn,
            ),
          ),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Subject'),
            content: Text('Are you sure you want to delete "${subject.name}"? This will also delete all attendance records for this subject.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteSubjectFromClass(_currentClass.id, subject.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Subject "${subject.name}" deleted successfully')),
          );
        }
        _refreshClassData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting subject: $e')),
          );
        }
      }
    }
  }

  Future<void> _exportClassData() async {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting class data...')),
      );

      await _exportService.exportClassData(_currentClass);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class data exported successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting data: $e')),
        );
      }
    }
  }

  Future<void> _handleSubjectAction(String action, SubjectModel subject) async {
    if (!mounted) return;
    if (action == 'attendance') {
      if (_currentClass.students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add students first before taking attendance')),
        );
        return;
      }
      final result = await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              AttendanceScreen(
                classModel: _currentClass,
                subject: subject,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      );
      if (result == true) {
        _refreshClassData();
      }
    } else if (action == 'history') {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              AttendanceHistoryScreen(
                classModel: _currentClass,
                subject: subject,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      );
    } else if (action == 'dashboard') {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              SubjectDashboardScreen(
                classModel: _currentClass,
                subject: subject,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      );
    } else if (action == 'edit') {
      final result = await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              AddSubjectScreen(
                classId: _currentClass.id,
                subject: subject,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        ),
      );
      if (result == true) {
        _refreshClassData();
      }
    } else if (action == 'delete') {
      _deleteSubject(subject);
    }
  }

  void _showSubjectActions(SubjectModel subject) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.8,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar for dragging
                      TweenAnimationBuilder(
                        duration: const Duration(milliseconds: 500),
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        },
                      ),
                      // Subject header with slide animation
                      TweenAnimationBuilder(
                        duration: const Duration(milliseconds: 600),
                        tween: Tween<Offset>(
                          begin: const Offset(-1.0, 0.0),
                          end: Offset.zero,
                        ),
                        builder: (context, offset, child) {
                          return Transform.translate(
                            offset: Offset(offset.dx * 100, 0),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: [
                                  Hero(
                                    tag: 'subject_${subject.id}',
                                    child: CircleAvatar(
                                      backgroundColor: subject.isPractical ? Colors.green : Colors.blue,
                                      child: Icon(
                                        subject.isPractical ? Icons.science : Icons.book,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subject.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: subject.isPractical ? Colors.green.shade100 : Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            subject.typeDisplayName,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: subject.isPractical ? Colors.green.shade800 : Colors.blue.shade800,
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
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      // Action items with staggered animation
                      AnimationLimiter(
                        child: ListView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: AnimationConfiguration.toStaggeredList(
                            duration: const Duration(milliseconds: 375),
                            childAnimationBuilder: (widget) => SlideAnimation(
                              horizontalOffset: 50.0,
                              child: FadeInAnimation(
                                child: widget,
                              ),
                            ),
                            children: [
                              _buildActionTile(
                                icon: Icons.dashboard,
                                title: 'Subject Dashboard',
                                subtitle: 'View attendance statistics and defaulters',
                                color: Colors.purple,
                                onTap: () {
                                  Navigator.pop(context);
                                  _handleSubjectAction('dashboard', subject);
                                },
                              ),
                              _buildActionTile(
                                icon: Icons.check_circle,
                                title: 'Take Attendance',
                                subtitle: subject.isPractical
                                    ? 'Mark batch-wise attendance for this practical subject'
                                    : 'Mark student attendance for this theory subject',
                                color: Colors.blue,
                                onTap: () {
                                  Navigator.pop(context);
                                  _handleSubjectAction('attendance', subject);
                                },
                              ),
                              _buildActionTile(
                                icon: Icons.history,
                                title: 'Attendance History',
                                subtitle: 'View past attendance records',
                                color: Colors.orange,
                                onTap: () {
                                  Navigator.pop(context);
                                  _handleSubjectAction('history', subject);
                                },
                              ),
                              _buildActionTile(
                                icon: Icons.edit,
                                title: 'Edit Subject',
                                subtitle: 'Change subject name or type',
                                color: Colors.green,
                                onTap: () {
                                  Navigator.pop(context);
                                  _handleSubjectAction('edit', subject);
                                },
                              ),
                              _buildActionTile(
                                icon: Icons.delete,
                                title: 'Delete Subject',
                                subtitle: 'Remove this subject and all its data',
                                color: Colors.red,
                                onTap: () {
                                  Navigator.pop(context);
                                  _handleSubjectAction('delete', subject);
                                },
                              ),
                              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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
  }

  Widget _buildStudentsList() {
    if (_currentClass.students.isEmpty) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 1000),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: const Icon(Icons.people_outline, size: 48, color: Colors.grey),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No students added yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the + button to add students',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final sortedStudents = List<StudentModel>.from(_currentClass.students);
    sortedStudents.sort((a, b) {
      final aRollInt = int.tryParse(a.rollNumber);
      final bRollInt = int.tryParse(b.rollNumber);
      if (aRollInt != null && bRollInt != null) {
        return aRollInt.compareTo(bRollInt);
      }
      return a.rollNumber.compareTo(b.rollNumber);
    });

    return AnimationLimiter(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedStudents.length,
        itemBuilder: (context, index) {
          final student = sortedStudents[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Hero(
                      tag: 'student_${student.id}',
                      child: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          student.rollNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                StudentDashboardScreen(
                                  student: student,
                                  classModel: _currentClass,
                                ),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1.0, 0.0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              );
                            },
                          ),
                        );
                      },
                      child: Text(
                        student.name,
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    subtitle: Text('Roll No: ${student.rollNumber}'),
                    trailing: PopupMenuButton(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.dashboard),
                              SizedBox(width: 8),
                              Text('View Dashboard'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'view') {
                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  StudentDashboardScreen(
                                    student: student,
                                    classModel: _currentClass,
                                  ),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1.0, 0.0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                );
                              },
                            ),
                          );
                        } else if (value == 'edit') {
                          final result = await Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (context, animation, secondaryAnimation) =>
                                  AddStudentScreen(
                                    classId: _currentClass.id,
                                    student: student,
                                  ),
                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(1.0, 0.0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                );
                              },
                            ),
                          );
                          if (result == true) {
                            _refreshClassData();
                          }
                        } else if (value == 'delete') {
                          _deleteStudent(student);
                        }
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              StudentDashboardScreen(
                                student: student,
                                classModel: _currentClass,
                              ),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubjectsList() {
    if (_currentClass.subjects.isEmpty) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 1000),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: const Icon(Icons.book_outlined, size: 48, color: Colors.grey),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No subjects added yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add subjects to start taking attendance',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Separate theory and practical subjects
    final theorySubjects = _currentClass.subjects.where((s) => s.isTheory).toList();
    final practicalSubjects = _currentClass.subjects.where((s) => s.isPractical).toList();

    return Column(
      children: [
        // Theory Subjects Section
        if (theorySubjects.isNotEmpty) ...[
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: const Icon(Icons.book, color: Colors.blue, size: 20),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Theory Subjects (${theorySubjects.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
                children: theorySubjects.map((subject) => _buildSubjectCard(subject)).toList(),
              ),
            ),
          ),
        ],

        // Practical Subjects Section
        if (practicalSubjects.isNotEmpty) ...[
          FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: const Icon(Icons.science, color: Colors.green, size: 20),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Practical Subjects (${practicalSubjects.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimationLimiter(
            child: Column(
              children: AnimationConfiguration.toStaggeredList(
                duration: const Duration(milliseconds: 375),
                childAnimationBuilder: (widget) => SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: widget,
                  ),
                ),
                children: practicalSubjects.map((subject) => _buildSubjectCard(subject)).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubjectCard(SubjectModel subject) {
    final totalBatches = subject.isPractical ? _repository.calculateTotalBatches(_currentClass.students.length) : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSubjectActions(subject),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                (subject.isPractical ? Colors.green : Colors.blue).withOpacity(0.02),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Hero(
                  tag: 'subject_${subject.id}',
                  child: TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: CircleAvatar(
                          backgroundColor: subject.isPractical ? Colors.green : Colors.blue,
                          child: Icon(
                            subject.isPractical ? Icons.science : Icons.book,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          TweenAnimationBuilder(
                            duration: const Duration(milliseconds: 800),
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: subject.isPractical ? Colors.green.shade100 : Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(12),
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
                              );
                            },
                          ),
                          if (subject.isPractical && totalBatches != null) ...[
                            const SizedBox(width: 8),
                            TweenAnimationBuilder(
                              duration: const Duration(milliseconds: 1000),
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$totalBatches batches',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subject.isPractical
                            ? 'Batch-wise attendance (25 students each)'
                            : 'All students attendance',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 1200),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'Actions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isStudentTab) {
    if (isStudentTab) {
      // Students tab summary
      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.withOpacity(0.05),
                    Colors.purple.withOpacity(0.05),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 1000),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Column(
                                children: [
                                  Text(
                                    '${_currentClass.students.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Total Students'),
                                ],
                              ),
                            );
                          },
                        ),
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 1200),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Column(
                                children: [
                                  Text(
                                    '${_currentClass.subjects.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Total Subjects'),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Class Dashboard Button with animation
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1400),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        ClassDashboardScreen(
                                          classModel: _currentClass,
                                        ),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(1.0, 0.0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      );
                                    },
                                  ),
                                );
                              },
                              icon: const Icon(Icons.dashboard, color: Colors.white),
                              label: const Text(
                                'View Class Dashboard',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // Subjects tab summary
      final theoryCount = _currentClass.subjects.where((s) => s.isTheory).length;
      final practicalCount = _currentClass.subjects.where((s) => s.isPractical).length;

      return FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.green.withOpacity(0.05),
                    Colors.blue.withOpacity(0.05),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Column(
                            children: [
                              Text(
                                '$theoryCount',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Theory'),
                            ],
                          ),
                        );
                      },
                    ),
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1000),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Column(
                            children: [
                              Text(
                                '$practicalCount',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Practical'),
                            ],
                          ),
                        );
                      },
                    ),
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 1200),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Column(
                            children: [
                              Text(
                                '${_currentClass.subjects.length}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text('Total'),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 1,
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 600),
            tween: Tween<Offset>(begin: const Offset(0.0, -1.0), end: Offset.zero),
            builder: (context, offset, child) {
              return Transform.translate(
                offset: Offset(0, offset.dy * 120),
                child: AppBar(
                  title: const Text('Attendance Monitoring App'),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  bottom: const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.people), text: 'Students'),
                      Tab(icon: Icon(Icons.book), text: 'Subjects'),
                    ],
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorWeight: 3,
                  ),
                  actions: [
                    TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: PopupMenuButton(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(Icons.download),
                                    SizedBox(width: 8),
                                    Text('Export Data'),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'export') {
                                _exportClassData();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _isLoading
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
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Loading...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              )
                  : TabBarView(
                children: [
                  // Students Tab
                  RefreshIndicator(
                    onRefresh: _refreshClassData,
                    color: Colors.blue,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          _buildSummaryCard(true),
                          _buildStudentsList(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                  // Subjects Tab
                  RefreshIndicator(
                    onRefresh: _refreshClassData,
                    color: Colors.green,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          _buildSummaryCard(false),
                          _buildSubjectsList(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom credits with animation
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1000),
              tween: Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero),
              builder: (context, offset, child) {
                return Transform.translate(
                  offset: Offset(0, offset.dy * 50),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      'Created by Jainil Kothari | SE-A | AIDS Department | Adypsoe Lohegaon',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        floatingActionButton: ScaleTransition(
          scale: _fabAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: "add_subject",
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          AddSubjectScreen(classId: _currentClass.id),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        );
                      },
                    ),
                  );
                  if (result == true) {
                    _refreshClassData();
                  }
                },
                backgroundColor: Colors.green,
                elevation: 6,
                child: const Icon(Icons.book, color: Colors.white),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: "add_student",
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          AddStudentScreen(classId: _currentClass.id),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        );
                      },
                    ),
                  );
                  if (result == true) {
                    _refreshClassData();
                  }
                },
                backgroundColor: Colors.blue,
                elevation: 6,
                child: const Icon(Icons.person_add, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}