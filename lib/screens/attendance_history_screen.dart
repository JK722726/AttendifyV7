import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';
import '../services/repository.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final ClassModel classModel;
  final SubjectModel subject;

  const AttendanceHistoryScreen({
    super.key,
    required this.classModel,
    required this.subject,
  });

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final Repository _repository = Repository();
  List<AttendanceModel> _attendanceHistory = [];
  bool _isLoading = true;
  Map<String, List<AttendanceModel>> _dateGroupedAttendance = {};

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final history = await _repository.getAttendanceByClassAndSubject(
        widget.classModel.id,
        widget.subject.id,
      );

      // Sort by date and time (most recent first)
      history.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      // Group by date
      _dateGroupedAttendance.clear();
      for (final attendance in history) {
        final dateKey = _getDateKey(attendance.dateTime);
        if (_dateGroupedAttendance[dateKey] == null) {
          _dateGroupedAttendance[dateKey] = [];
        }
        _dateGroupedAttendance[dateKey]!.add(attendance);
      }

      // Sort times within each date
      _dateGroupedAttendance.forEach((date, attendanceList) {
        attendanceList.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      });

      setState(() {
        _attendanceHistory = history;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendance history: $e')),
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

  String _getDateKey(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0 ? 12 : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  // NEW: Copy absent students function
  Future<void> _copyAbsentStudents(AttendanceModel attendance) async {
    final absentStudents = _getAbsentStudents(attendance);

    if (absentStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No absent students to copy'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Sort absent students by roll number in ascending order
    absentStudents.sort((a, b) {
      final aRollInt = int.tryParse(a.rollNumber);
      final bRollInt = int.tryParse(b.rollNumber);
      if (aRollInt != null && bRollInt != null) {
        return aRollInt.compareTo(bRollInt);
      }
      return a.rollNumber.compareTo(b.rollNumber);
    });

    // Format the text
    final dateStr = _formatDate(attendance.dateTime);
    final timeStr = _formatTime(attendance.dateTime);
    final rollNumbers = absentStudents.map((student) => student.rollNumber).join(', ');

    final formattedText = '''Date - $dateStr ($timeStr)
Subject - ${widget.subject.name}
The roll numbers of students absent during this session are - $rollNumbers''';

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: formattedText));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${absentStudents.length} absent student roll numbers to clipboard'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              _showCopiedText(formattedText);
            },
          ),
        ),
      );
    }
  }

  void _showCopiedText(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copied Text'),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTimeSelection(String dateKey, List<AttendanceModel> attendanceList) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Time for ${_formatDate(attendanceList.first.dateTime)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...attendanceList.map((attendance) {
                final presentCount = _getPresentCount(attendance);
                final totalCount = attendance.records.length;
                final percentage = _getAttendancePercentage(attendance);

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getPercentageColor(percentage),
                      child: Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(_formatTime(attendance.dateTime)),
                    subtitle: Text('$presentCount/$totalCount students present'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pop(context);
                      _showAttendanceDetails(attendance);
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showAttendanceDetails(AttendanceModel attendance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            // Get sorted absent students
            final absentStudents = _getAbsentStudents(attendance);

            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Attendance Details',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    '${_formatDate(attendance.dateTime)} at ${_formatTime(attendance.dateTime)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard('Present', _getPresentCount(attendance), Colors.green),
                      _buildStatCard('Absent', _getAbsentCount(attendance), Colors.red),
                      _buildStatCard('Total', attendance.records.length, Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Enhanced absent students section with copy button
                  if (absentStudents.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAbsentStudents(absentStudents),
                              icon: const Icon(Icons.person_off),
                              label: Text('Show Absent Students (${absentStudents.length})'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // NEW: Copy button
                          ElevatedButton.icon(
                            onPressed: () => _copyAbsentStudents(attendance),
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'All Students',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: attendance.records.length,
                      itemBuilder: (context, index) {
                        final record = attendance.records[index];
                        StudentModel? student;
                        try {
                          student = widget.classModel.students.firstWhere(
                                (s) => s.id == record.studentId,
                          );
                        } catch (e) {
                          student = null;
                        }

                        if (student == null) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: record.present ? Colors.green : Colors.red,
                              child: Icon(
                                record.present ? Icons.check : Icons.close,
                                color: Colors.white,
                              ),
                            ),
                            title: const Text('Unknown Student'),
                            subtitle: Text('ID: ${record.studentId}'),
                            trailing: Text(
                              record.present ? 'Present' : 'Absent',
                              style: TextStyle(
                                color: record.present ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: record.present ? Colors.green : Colors.red,
                            child: Icon(
                              record.present ? Icons.check : Icons.close,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(student.name),
                          subtitle: Text('Roll No: ${student.rollNumber}'),
                          trailing: Text(
                            record.present ? 'Present' : 'Absent',
                            style: TextStyle(
                              color: record.present ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAbsentStudents(List<StudentModel> absentStudents) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Absent Students (${absentStudents.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: absentStudents.length,
            itemBuilder: (context, index) {
              final student = absentStudents[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Text(
                    student.rollNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text('Roll No: ${student.rollNumber}'),
                // Only show roll number as title, not the name
                contentPadding: EdgeInsets.zero,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<StudentModel> _getAbsentStudents(AttendanceModel attendance) {
    final absentStudentIds = attendance.records
        .where((record) => !record.present)
        .map((record) => record.studentId)
        .toList();

    final absentStudents = widget.classModel.students
        .where((student) => absentStudentIds.contains(student.id))
        .toList();

    // Sort by roll number
    absentStudents.sort((a, b) {
      final aRollInt = int.tryParse(a.rollNumber);
      final bRollInt = int.tryParse(b.rollNumber);

      if (aRollInt != null && bRollInt != null) {
        return aRollInt.compareTo(bRollInt);
      }

      return a.rollNumber.compareTo(b.rollNumber);
    });

    return absentStudents;
  }

  Future<void> _deleteAttendanceRecord(AttendanceModel attendance) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Attendance'),
          content: Text(
            'Are you sure you want to delete attendance record for ${_formatDate(attendance.dateTime)} at ${_formatTime(attendance.dateTime)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _repository.deleteAttendanceRecord(attendance.id);
        _loadAttendanceHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance record deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting record: $e')),
          );
        }
      }
    }
  }

  int _getPresentCount(AttendanceModel attendance) {
    return attendance.records.where((record) => record.present).length;
  }

  int _getAbsentCount(AttendanceModel attendance) {
    return attendance.records.where((record) => !record.present).length;
  }

  double _getAttendancePercentage(AttendanceModel attendance) {
    if (attendance.records.isEmpty) return 0.0;
    final presentCount = _getPresentCount(attendance);
    return (presentCount / attendance.records.length) * 100;
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(color: color),
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
          children: [
            const Text('Attendance Monitoring App'),
            Text(
              '${widget.subject.name} - ${widget.classModel.name}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dateGroupedAttendance.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No attendance records found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start taking attendance to see history here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadAttendanceHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _dateGroupedAttendance.keys.length,
                itemBuilder: (context, index) {
                  final dateKey = _dateGroupedAttendance.keys.toList()[index];
                  final attendanceList = _dateGroupedAttendance[dateKey]!;
                  final latestAttendance = attendanceList.first;

                  // Calculate aggregate stats for the day
                  int totalPresent = 0;
                  int totalRecords = 0;
                  for (final attendance in attendanceList) {
                    totalPresent += _getPresentCount(attendance);
                    totalRecords += attendance.records.length;
                  }
                  final dayPercentage = totalRecords > 0 ? (totalPresent / totalRecords) * 100 : 0.0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: _getPercentageColor(dayPercentage),
                        child: Text(
                          '${attendanceList.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        _formatDate(latestAttendance.dateTime),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text('${attendanceList.length} session(s)'),
                          Text('Overall: ${dayPercentage.toStringAsFixed(0)}% attendance'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete_all') {
                            _deleteAllSessionsForDate(attendanceList);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'delete_all',
                            child: ListTile(
                              leading: Icon(Icons.delete, color: Colors.red),
                              title: Text('Delete All Sessions', style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showTimeSelection(dateKey, attendanceList),
                    ),
                  );
                },
              ),
            ),
          ),
          // Bottom credits
          Container(
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
        ],
      ),
    );
  }

  Future<void> _deleteAllSessionsForDate(List<AttendanceModel> attendanceList) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete All Sessions'),
          content: Text(
            'Are you sure you want to delete all ${attendanceList.length} attendance sessions for ${_formatDate(attendanceList.first.dateTime)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        for (final attendance in attendanceList) {
          await _repository.deleteAttendanceRecord(attendance.id);
        }
        _loadAttendanceHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted ${attendanceList.length} attendance sessions')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting sessions: $e')),
          );
        }
      }
    }
  }
}