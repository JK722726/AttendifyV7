import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animations/animations.dart';
import 'package:lottie/lottie.dart';
import 'dart:convert';
import 'dart:io';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../services/repository.dart';

class AddClassScreen extends StatefulWidget {
  final ClassModel? classModel;

  const AddClassScreen({super.key, this.classModel});

  @override
  State<AddClassScreen> createState() => _AddClassScreenState();
}

class _AddClassScreenState extends State<AddClassScreen>
    with TickerProviderStateMixin {
  final Repository _repository = Repository();
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _loadingController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  List<StudentModel> _importedStudents = [];
  String? _csvFileName;
  bool _showStudentsList = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    // Start initial animations
    _fadeController.forward();
    _slideController.forward();

    if (widget.classModel != null) {
      _nameController.text = widget.classModel!.name;
      _importedStudents = List.from(widget.classModel!.students);
      if (_importedStudents.isNotEmpty) {
        _showStudentsList = true;
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _loadingController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndImportCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _isLoading = true;
        });
        _loadingController.repeat();

        final file = File(result.files.single.path!);
        String contents;

        try {
          contents = await file.readAsString(encoding: utf8);
        } catch (e1) {
          try {
            contents = await file.readAsString(encoding: latin1);
          } catch (e2) {
            final bytes = await file.readAsBytes();
            contents = String.fromCharCodes(bytes);
          }
        }

        final students = await _parseCSVContents(contents);

        setState(() {
          _importedStudents = students;
          _csvFileName = result.files.single.name;
          _isLoading = false;
          _showStudentsList = students.isNotEmpty;
        });

        _loadingController.stop();
        _loadingController.reset();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Imported ${students.length} students from CSV')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _loadingController.stop();
      _loadingController.reset();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error importing CSV: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<List<StudentModel>> _parseCSVContents(String contents) async {
    final List<StudentModel> students = [];

    String cleanedContents = contents;
    if (cleanedContents.startsWith('\ufeff')) {
      cleanedContents = cleanedContents.substring(1);
    }

    final lines = cleanedContents.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = _parseCSVLine(line);

      if (parts.length >= 2) {
        final rollNumberPart = parts[0].trim();
        String studentName = parts[1].trim();

        if (rollNumberPart.contains(RegExp(r'^[A-Z]-\d+$'))) {
          final rollNumber = rollNumberPart.substring(2);

          studentName = studentName.replaceAll('"', '').trim();

          if (studentName.isEmpty) continue;

          studentName = _toTitleCase(studentName);

          final studentId = 'student_${DateTime.now().millisecondsSinceEpoch}_${rollNumber}_$i';

          students.add(StudentModel(
            id: studentId,
            name: studentName,
            rollNumber: rollNumber,
          ));
        }
      }
    }

    students.sort((a, b) {
      final aRollInt = int.tryParse(a.rollNumber) ?? 0;
      final bRollInt = int.tryParse(b.rollNumber) ?? 0;
      return aRollInt.compareTo(bRollInt);
    });

    return students;
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;

    return text.toLowerCase().split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  List<String> _parseCSVLine(String line) {
    List<String> result = [];
    bool inQuotes = false;
    String current = '';

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current);
        current = '';
      } else {
        current += char;
      }
    }

    result.add(current);
    return result;
  }

  void _removeStudent(int index) {
    setState(() {
      _importedStudents.removeAt(index);
      if (_importedStudents.isEmpty) {
        _showStudentsList = false;
      }
    });
  }

  void _clearImportedStudents() {
    setState(() {
      _importedStudents.clear();
      _csvFileName = null;
      _showStudentsList = false;
    });
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_importedStudents.isEmpty && widget.classModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Please import students from CSV or add them manually')),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    _loadingController.repeat();

    try {
      final className = _nameController.text.trim();

      if (widget.classModel != null) {
        final updatedClass = widget.classModel!.copyWith(
          name: className,
          students: _importedStudents,
        );
        await _repository.updateClass(updatedClass);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Class updated successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final newClass = ClassModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: className,
          students: _importedStudents,
          subjects: [],
        );

        await _repository.addClass(newClass);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Class "$className" created with ${_importedStudents.length} students')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error saving class: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _loadingController.stop();
      _loadingController.reset();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildAnimatedCard({
    required Widget child,
    required int index,
  }) {
    return AnimationLimiter(
      child: AnimationConfiguration.staggeredList(
        position: index,
        duration: const Duration(milliseconds: 600),
        child: SlideAnimation(
          verticalOffset: 50.0,
          child: FadeInAnimation(
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.classModel != null;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Attendance Monitoring App'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: AnimationLimiter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: AnimationConfiguration.toStaggeredList(
                            duration: const Duration(milliseconds: 600),
                            childAnimationBuilder: (widget) => SlideAnimation(
                              horizontalOffset: 50.0,
                              child: FadeInAnimation(child: widget),
                            ),
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      duration: const Duration(milliseconds: 800),
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: Icon(
                                            isEditing ? Icons.edit : Icons.add_circle_outline,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      isEditing ? 'Edit Class' : 'Add New Class',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Class Information Card
                              _buildAnimatedCard(
                                index: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.school,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Class Information',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      TextFormField(
                                        controller: _nameController,
                                        decoration: InputDecoration(
                                          labelText: 'Class Name',
                                          hintText: 'Enter class name (e.g., SE-A)',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                                          ),
                                          prefixIcon: Icon(Icons.class_, color: Colors.blue.shade600),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Please enter a class name';
                                          }
                                          if (value.trim().length < 2) {
                                            return 'Class name must be at least 2 characters long';
                                          }
                                          return null;
                                        },
                                        textCapitalization: TextCapitalization.words,
                                        enabled: !_isLoading,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // CSV Import Card
                              _buildAnimatedCard(
                                index: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.upload_file,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Import Students from CSV',
                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.blue.shade200),
                                        ),
                                        child: const Text(
                                          'Upload a CSV file containing student roll numbers and names. The format should have roll numbers in format "A-1, A-2, B-1, B-2, etc." and student names in adjacent columns.',
                                          style: TextStyle(color: Colors.indigo),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 300),
                                              child: ElevatedButton.icon(
                                                onPressed: _isLoading ? null : _pickAndImportCSV,
                                                icon: _isLoading
                                                    ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                                    : const Icon(Icons.file_upload),
                                                label: Text(_isLoading ? 'Processing...' : 'Select CSV File'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_importedStudents.isNotEmpty) ...[
                                            const SizedBox(width: 12),
                                            AnimatedScale(
                                              scale: 1.0,
                                              duration: const Duration(milliseconds: 200),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  onPressed: _clearImportedStudents,
                                                  icon: Icon(Icons.clear, color: Colors.red.shade700),
                                                  tooltip: 'Clear imported students',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (_csvFileName != null) ...[
                                        const SizedBox(height: 16),
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 500),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green.shade300),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'File imported successfully!',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.green.shade700,
                                                      ),
                                                    ),
                                                    Text(
                                                      'File: $_csvFileName',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.green.shade600,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
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

                              // Imported Students List
                              if (_showStudentsList && _importedStudents.isNotEmpty)
                                _buildAnimatedCard(
                                  index: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.purple.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.people,
                                                color: Colors.purple.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Imported Students (${_importedStudents.length})',
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.purple.shade700,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '${_importedStudents.length}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          constraints: const BoxConstraints(maxHeight: 220),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey.shade300),
                                            borderRadius: BorderRadius.circular(12),
                                            color: Colors.grey.shade50,
                                          ),
                                          child: AnimationLimiter(
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              padding: const EdgeInsets.all(8),
                                              itemCount: _importedStudents.length,
                                              itemBuilder: (context, index) {
                                                final student = _importedStudents[index];
                                                return AnimationConfiguration.staggeredList(
                                                  position: index,
                                                  duration: const Duration(milliseconds: 400),
                                                  child: SlideAnimation(
                                                    verticalOffset: 50.0,
                                                    child: FadeInAnimation(
                                                      child: Container(
                                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(8),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.grey.shade200,
                                                              blurRadius: 4,
                                                              offset: const Offset(0, 2),
                                                            ),
                                                          ],
                                                        ),
                                                        child: ListTile(
                                                          dense: true,
                                                          leading: CircleAvatar(
                                                            radius: 18,
                                                            backgroundColor: Colors.blue.shade100,
                                                            child: Text(
                                                              student.rollNumber,
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.blue.shade700,
                                                              ),
                                                            ),
                                                          ),
                                                          title: Text(
                                                            student.name,
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          trailing: Container(
                                                            decoration: BoxDecoration(
                                                              color: Colors.red.shade100,
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: IconButton(
                                                              icon: Icon(Icons.remove_circle,
                                                                  color: Colors.red.shade700, size: 20),
                                                              onPressed: () => _removeStudent(index),
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
                                      ],
                                    ),
                                  ),
                                ),

                              const SizedBox(height: 24),

                              // Save Button
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _saveClass,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: _isLoading
                                      ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Processing...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                      : Text(
                                    isEditing ? 'Update Class' : 'Create Class',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                              // Next Steps Info (only for new classes)
                              if (!isEditing) ...[
                                const SizedBox(height: 20),
                                _buildAnimatedCard(
                                  index: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.lightbulb_outline,
                                                color: Colors.orange.shade700,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Next Steps',
                                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'After creating the class, you can:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ...[
                                          'Add/edit students manually',
                                          'Add subjects for the class',
                                          'Start marking attendance',
                                          'View attendance history',
                                        ].asMap().entries.map((entry) {
                                          return AnimationConfiguration.staggeredList(
                                            position: entry.key,
                                            duration: const Duration(milliseconds: 300),
                                            child: SlideAnimation(
                                              horizontalOffset: 30.0,
                                              child: FadeInAnimation(
                                                child: Container(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.orange.shade200),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: BoxDecoration(
                                                          color: Colors.orange.shade600,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          entry.value,
                                                          style: TextStyle(
                                                            color: Colors.grey.shade700,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
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
                  ),
                ),
              ),
            ),

            // Bottom credits with animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade100, Colors.grey.shade50],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.code, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Created by Jainil Kothari | SE-A | AIDS Department | Adypsoe Lohegaon',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}