import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../services/repository.dart';
import 'student_dashboard_screen.dart';

class ClassDashboardScreen extends StatefulWidget {
  final ClassModel classModel;

  const ClassDashboardScreen({
    super.key,
    required this.classModel,
  });

  @override
  State<ClassDashboardScreen> createState() => _ClassDashboardScreenState();
}

class _ClassDashboardScreenState extends State<ClassDashboardScreen> {
  final Repository _repository = Repository();
  bool _isLoading = true;
  int _totalSessions = 0;
  List<Map<String, dynamic>> _defaulterStudents = [];
  Map<String, dynamic> _classStatistics = {};

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get class statistics
      _classStatistics = await _repository.getClassStatistics(widget.classModel.id);
      _totalSessions = _classStatistics['totalSessions'] ?? 0;

      // Calculate attendance for each student across all subjects
      final List<Map<String, dynamic>> studentAttendanceData = [];

      for (final student in widget.classModel.students) {
        final studentStats = await _repository.getStudentStatistics(
          widget.classModel.id,
          student.id,
        );

        final totalClasses = studentStats['totalClasses'] ?? 0;
        final classesAttended = studentStats['classesAttended'] ?? 0;
        final percentage = studentStats['attendancePercentage'] ?? 0.0;

        if (totalClasses > 0) {
          studentAttendanceData.add({
            'student': student,
            'attended': classesAttended,
            'totalClasses': totalClasses,
            'percentage': percentage,
            'theoryPercentage': studentStats['theoryPercentage'] ?? 0.0,
            'practicalPercentage': studentStats['practicalPercentage'] ?? 0.0,
          });
        }
      }

      // Filter defaulters (below 75%)
      _defaulterStudents = studentAttendanceData
          .where((data) => data['percentage'] < 75.0)
          .toList();

      // Sort by attendance percentage (lowest first)
      _defaulterStudents.sort((a, b) => a['percentage'].compareTo(b['percentage']));

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard data: $e')),
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

  Widget _buildSummaryCards() {
    final totalStudents = widget.classModel.students.length;
    final defaultersCount = _defaulterStudents.length;
    final goodAttendanceCount = totalStudents - defaultersCount;
    final overallPercentage = _classStatistics['overallAttendancePercentage'] ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Class Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          widget.classModel.name.isNotEmpty
                              ? widget.classModel.name[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.classModel.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Overall Attendance: ${overallPercentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 14,
                                color: overallPercentage >= 75 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // First Row Statistics
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '$_totalSessions',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Total Sessions',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '${widget.classModel.subjects.length}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Total Subjects',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Second Row Statistics
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '$defaultersCount',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Defaulters\n(<75%)',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          '$goodAttendanceCount',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Good\nAttendance',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultersList() {
    if (_defaulterStudents.isEmpty) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.celebration, size: 48, color: Colors.green),
              SizedBox(height: 16),
              Text(
                'No Defaulters!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'All students have good attendance (≥75%)',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _defaulterStudents.length,
      itemBuilder: (context, index) {
        final data = _defaulterStudents[index];
        final student = data['student'] as StudentModel;
        final percentage = data['percentage'] as double;
        final attended = data['attended'] as int;
        final totalClasses = data['totalClasses'] as int;
        final theoryPercentage = data['theoryPercentage'] as double;
        final practicalPercentage = data['practicalPercentage'] as double;

        Color percentageColor = Colors.red;
        if (percentage >= 60) {
          percentageColor = Colors.orange;
        } else if (percentage >= 40) {
          percentageColor = Colors.red;
        } else {
          percentageColor = Colors.red.shade800;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: percentageColor,
              child: Text(
                student.rollNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              student.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '$attended/$totalClasses classes attended',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: percentageColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: percentageColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'DEFAULTER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: percentageColor,
                    ),
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Icon(
                                Icons.book,
                                color: Colors.blue,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Theory',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              Text(
                                '${theoryPercentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theoryPercentage >= 75 ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Icon(
                                Icons.science,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Practical',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                '${practicalPercentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: practicalPercentage >= 75 ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StudentDashboardScreen(
                                student: student,
                                classModel: widget.classModel,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        child: const Text(
                          'View Detailed Dashboard',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
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
        title: Text('${widget.classModel.name} Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Defaulter Students (Below 75%)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildDefaultersList(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}