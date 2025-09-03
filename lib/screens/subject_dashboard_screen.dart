import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/subject_model.dart';
import '../services/repository.dart';
import 'student_dashboard_screen.dart';

class SubjectDashboardScreen extends StatefulWidget {
  final ClassModel classModel;
  final SubjectModel subject;

  const SubjectDashboardScreen({
    super.key,
    required this.classModel,
    required this.subject,
  });

  @override
  State<SubjectDashboardScreen> createState() => _SubjectDashboardScreenState();
}

class _SubjectDashboardScreenState extends State<SubjectDashboardScreen> {
  final Repository _repository = Repository();
  bool _isLoading = true;
  int _totalSessions = 0;
  List<Map<String, dynamic>> _defaulterStudents = [];

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
      // Get all attendance records for this subject
      final attendanceRecords = await _repository.getAttendanceByClassAndSubject(
        widget.classModel.id,
        widget.subject.id,
      );

      _totalSessions = attendanceRecords.length;

      // Calculate attendance for each student
      final List<Map<String, dynamic>> studentAttendanceData = [];

      for (final student in widget.classModel.students) {
        int attended = 0;
        int totalClasses = 0;

        for (final attendance in attendanceRecords) {
          try {
            final record = attendance.records.firstWhere((r) => r.studentId == student.id);
            totalClasses++;
            if (record.present) {
              attended++;
            }
          } catch (e) {
            // Student record not found in this attendance
          }
        }

        if (totalClasses > 0) {
          final percentage = (attended / totalClasses) * 100;
          studentAttendanceData.add({
            'student': student,
            'attended': attended,
            'totalClasses': totalClasses,
            'percentage': percentage,
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

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Subject Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: widget.subject.isPractical ? Colors.green : Colors.blue,
                        child: Icon(
                          widget.subject.isPractical ? Icons.science : Icons.book,
                          color: Colors.white,
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
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.subject.isPractical
                                    ? Colors.green.shade100
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.subject.typeDisplayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.subject.isPractical
                                      ? Colors.green.shade800
                                      : Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
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
          // Statistics Cards
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
          child: ListTile(
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
            onTap: () {
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subject.name} Dashboard'),
        backgroundColor: widget.subject.isPractical ? Colors.green : Colors.blue,
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