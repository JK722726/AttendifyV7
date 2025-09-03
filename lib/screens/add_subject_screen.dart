import 'package:flutter/material.dart';
import '../models/subject_model.dart';
import '../services/repository.dart';

class AddSubjectScreen extends StatefulWidget {
  final String classId;
  final SubjectModel? subject; // For editing existing subject

  const AddSubjectScreen({super.key, required this.classId, this.subject});

  @override
  State<AddSubjectScreen> createState() => _AddSubjectScreenState();
}

class _AddSubjectScreenState extends State<AddSubjectScreen> {
  final Repository _repository = Repository();
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  SubjectType _selectedType = SubjectType.theory;

  @override
  void initState() {
    super.initState();
    if (widget.subject != null) {
      _nameController.text = widget.subject!.name;
      _selectedType = widget.subject!.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<bool> _isSubjectNameTaken(String subjectName) async {
    if (widget.subject != null && widget.subject!.name.toLowerCase() == subjectName.toLowerCase()) {
      // If editing and subject name is the same, it's allowed
      return false;
    }

    final classModel = await _repository.getClassById(widget.classId);
    if (classModel != null) {
      return classModel.subjects.any(
            (subject) => subject.name.toLowerCase() == subjectName.toLowerCase(),
      );
    }
    return false;
  }

  Future<void> _saveSubject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final subjectName = _nameController.text.trim();

      // Check if subject name is already taken
      final isSubjectNameTaken = await _isSubjectNameTaken(subjectName);
      if (isSubjectNameTaken) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject name already exists in this class')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (widget.subject != null) {
        // Update existing subject
        final updatedSubject = widget.subject!.copyWith(
          name: subjectName,
          type: _selectedType,
        );
        await _repository.updateSubjectInClass(widget.classId, updatedSubject);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subject updated successfully')),
          );
        }
      } else {
        // Create new subject
        final newSubject = SubjectModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: subjectName,
          type: _selectedType,
        );

        await _repository.addSubjectToClass(widget.classId, newSubject);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subject added successfully')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving subject: $e')),
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
    final isEditing = widget.subject != null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Attendance Monitoring App'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isEditing ? 'Edit Subject' : 'Add New Subject',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subject Information',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Subject Name',
                                  hintText: 'Enter subject name (e.g., Mathematics)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.book),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter subject name';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Subject name must be at least 2 characters long';
                                  }
                                  return null;
                                },
                                textCapitalization: TextCapitalization.words,
                                enabled: !_isLoading,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Subject Type',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<SubjectType>(
                                      title: const Text('Theory'),
                                      subtitle: const Text('Regular classes'),
                                      value: SubjectType.theory,
                                      groupValue: _selectedType,
                                      onChanged: _isLoading ? null : (SubjectType? value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedType = value;
                                          });
                                        }
                                      },
                                      contentPadding: const EdgeInsets.all(0),
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<SubjectType>(
                                      title: const Text('Practical'),
                                      subtitle: const Text('Batch-wise classes'),
                                      value: SubjectType.practical,
                                      groupValue: _selectedType,
                                      onChanged: _isLoading ? null : (SubjectType? value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedType = value;
                                          });
                                        }
                                      },
                                      contentPadding: const EdgeInsets.all(0),
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedType == SubjectType.practical) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.info_outline,
                                              color: Colors.blue.shade700, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Practical Subject Info',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text('• Attendance will be taken batch-wise'),
                                      const Text('• Each batch contains up to 25 students'),
                                      const Text('• Students are automatically divided into batches'),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveSubject,
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
                          isEditing ? 'Update Subject' : 'Add Subject',
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
                                    const Icon(Icons.lightbulb_outline, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Subject Examples',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Theory Subjects:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Chip(label: Text('Mathematics'), backgroundColor: Color(0xFFE3F2FD)),
                                    Chip(label: Text('English'), backgroundColor: Color(0xFFE3F2FD)),
                                    Chip(label: Text('Science'), backgroundColor: Color(0xFFE3F2FD)),
                                    Chip(label: Text('Social Studies'), backgroundColor: Color(0xFFE3F2FD)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Practical Subjects:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Chip(label: Text('Computer Lab'), backgroundColor: Color(0xFFE8F5E8)),
                                    Chip(label: Text('Chemistry Lab'), backgroundColor: Color(0xFFE8F5E8)),
                                    Chip(label: Text('Physics Lab'), backgroundColor: Color(0xFFE8F5E8)),
                                    Chip(label: Text('Biology Lab'), backgroundColor: Color(0xFFE8F5E8)),
                                  ],
                                ),
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
      ),
    );
  }
}