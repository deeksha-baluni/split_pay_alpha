import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../components/header.dart';
import 'manual_add.dart';
import 'bill_review.dart';
import '../services/bill_service.dart';

class AddBillPage extends StatefulWidget {
  final String groupId;
  final List<Map<String, String>> members;

  const AddBillPage({
    super.key,
    required this.groupId,
    required this.members,
  });

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  File? _capturedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing photo: $e')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _capturedImage = File(photo.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_capturedImage == null) return;

    setState(() => _isUploading = true);

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'Parsing bill...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'This may take a few seconds',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );

      final result = await BillService.uploadBill(
        imageFile: _capturedImage!,
        groupId: widget.groupId,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (result['success'] == true && result['expense'] != null) {
        final expense = result['expense'];
        final expenseId = expense['_id'] ?? expense['id'];

        if (expenseId != null) {
          // Navigate to bill review page
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BillReviewPage(
                expenseId: expenseId,
                groupId: widget.groupId,
                members: widget.members,
                billImage: _capturedImage!,
              ),
            ),
          );
        } else {
          throw Exception('No expense ID received');
        }
      } else {
        throw Exception(result['message'] ?? 'Upload failed');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if still open
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Header(
            title: 'Add Bill',
            heightFactor: 0.12,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _capturedImage == null
                  ? _buildInitialView(isDark)
                  : _buildPreviewView(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialView(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          height: 280,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.camera_alt_outlined,
            size: 120,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        const SizedBox(height: 30),

        // Take Photo button
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera_alt, size: 24),
            label: const Text(
              'Take photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8DEE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 2,
            ),
          ),
        ),

        const SizedBox(height: 15),

        // Pick from Gallery button
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library, size: 24),
            label: const Text(
              'Pick from Gallery',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
              foregroundColor: const Color(0xFF5B8DEE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(
                  color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              elevation: 1,
            ),
          ),
        ),

        const SizedBox(height: 15),

        // Manual Add button
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManuallyAddPage(
                    groupId: widget.groupId,
                    members: widget.members,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 24),
            label: const Text(
              'Manual Add',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              foregroundColor: const Color(0xFF5B8DEE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              elevation: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewView(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Display captured image
        Container(
          width: double.infinity,
          height: 280,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
            image: _capturedImage != null
                ? DecorationImage(
                    image: FileImage(_capturedImage!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
        ),

        const SizedBox(height: 30),

        // Upload & Parse button
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : _uploadImage,
            icon: _isUploading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.cloud_upload, size: 24),
            label: Text(
              _isUploading ? 'Processing...' : 'Upload & Parse',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8DEE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 2,
            ),
          ),
        ),

        const SizedBox(height: 15),

        // Retake Photo button
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : _retakePhoto,
            icon: const Icon(Icons.camera_alt, size: 24),
            label: const Text(
              'Retake Photo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              foregroundColor: const Color(0xFF5B8DEE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              elevation: 1,
            ),
          ),
        ),
      ],
    );
  }
}