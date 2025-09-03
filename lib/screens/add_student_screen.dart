import 'package:flutter/material.dart';
import '../models/student_model.dart';
import '../services/repository.dart';

class AddStudentScreen extends StatefulWidget {
  final String classId;
  final StudentModel? student; // For editing existing student

  const AddStudentScreen({super.key, required this.classId, this.student});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final Repository _repository = Repository();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollNumberController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _nameController.text = widget.student!.name;
      _rollNumberController.text = widget.student!.rollNumber;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollNumberController.dispose();
    super.dispose();
  }

  Future<bool> _isRollNumberTaken(String rollNumber) async {
    if (widget.student != null && widget.student!.rollNumber == rollNumber) {
      // If editing and roll number is the same, it's allowed
      return false;
    }

    final classModel = await _repository.getClassById(widget.classId);
    if (classModel != null) {
      return classModel.students.any((student) => student.rollNumber == rollNumber);
    }
    return false;
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final studentName = _nameController.text.trim();
      final rollNumber = _rollNumberController.text.trim();

      // Check if roll number is already taken
      final isRollNumberTaken = await _isRollNumberTaken(rollNumber);
      if (isRollNumberTaken) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Roll number is already taken')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (widget.student != null) {
        // Update existing student
        final updatedStudent = widget.student!.copyWith(
          name: studentName,
          rollNumber: rollNumber,
        );
        await _repository.updateStudentInClass(widget.classId, updatedStudent);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student updated successfully')),
          );
        }
      } else {
        // Create new student
        final newStudent = StudentModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: studentName,
          rollNumber: rollNumber,
        );

        await _repository.addStudentToClass(widget.classId, newStudent);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student added successfully')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving student: $e')),
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.student != null;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Fix for keyboard overflow
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Student' : 'Add New Student'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView( // Wrap in scrollview to prevent overflow
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Information',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Student Name',
                            hintText: 'Enter student full name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter student name';
                            }
                            if (value.trim().length < 2) {
                              return 'Name must be at least 2 characters long';
                            }
                            return null;
                          },
                          textCapitalization: TextCapitalization.words,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _rollNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Roll Number',
                            hintText: 'Enter roll number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter roll number';
                            }
                            if (value.trim().length < 1) {
                              return 'Roll number must be at least 1 character long';
                            }
                            return null;
                          },
                          enabled: !_isLoading,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveStudent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    isEditing ? 'Update Student' : 'Add Student',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isEditing) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Important Notes',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text('• Each student must have a unique roll number'),
                          const Text('• Student name should be their full name'),
                          const Text('• Roll numbers can be numeric or alphanumeric'),
                          const Text('• You can edit student details later if needed'),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}