import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'contact_service.dart';

class AvatarService {
  static final AvatarService _instance = AvatarService._internal();
  static AvatarService get instance => _instance;
  AvatarService._internal();

  /// Generate avatar image for CallKit notification
  /// Returns the file path of the generated avatar image
  Future<String?> generateAvatarForCallKit({
    required String phoneNumber,
    required String displayName,
  }) async {
    try {
      debugPrint('AvatarService: Generating avatar for $displayName ($phoneNumber)');

      // First check if we have a contact photo
      final contactInfo = await ContactService.instance.findContactByPhoneNumber(phoneNumber);
      
      if (contactInfo != null && contactInfo.hasPhoto && contactInfo.photo != null) {
        // Use contact photo
        debugPrint('AvatarService: Using contact photo for $displayName');
        return await _saveContactPhotoAsFile(contactInfo.photo!, phoneNumber);
      } else {
        // Generate default avatar with person icon
        debugPrint('AvatarService: Generating default avatar for $displayName');
        return await _generateDefaultAvatar(displayName, phoneNumber);
      }
    } catch (e) {
      debugPrint('AvatarService: Error generating avatar: $e');
      return null;
    }
  }

  /// Save contact photo as a temporary file for CallKit
  Future<String?> _saveContactPhotoAsFile(Uint8List photoData, String phoneNumber) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/callkit_avatar_$phoneNumber.png');
      
      await file.writeAsBytes(photoData);
      debugPrint('AvatarService: Saved contact photo to: ${file.path}');
      
      return file.path;
    } catch (e) {
      debugPrint('AvatarService: Error saving contact photo: $e');
      return null;
    }
  }

  /// Generate a default avatar with person icon (same style as OnCallScreen)
  Future<String?> _generateDefaultAvatar(String displayName, String phoneNumber) async {
    try {
      // Create a widget that matches the OnCallScreen avatar style
      final avatarWidget = _buildAvatarWidget();
      
      // Convert widget to image
      final imageBytes = await _widgetToImage(avatarWidget);
      
      if (imageBytes == null) {
        debugPrint('AvatarService: Failed to convert widget to image');
        return null;
      }

      // Save as temporary file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/callkit_avatar_default_$phoneNumber.png');
      
      await file.writeAsBytes(imageBytes);
      debugPrint('AvatarService: Generated default avatar saved to: ${file.path}');
      
      return file.path;
    } catch (e) {
      debugPrint('AvatarService: Error generating default avatar: $e');
      return null;
    }
  }

  /// Build the avatar widget matching OnCallScreen style
  Widget _buildAvatarWidget() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE6E6FA),
        border: Border.all(
          color: Colors.white,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const CircleAvatar(
        radius: 71,
        backgroundColor: Color(0xFFE6E6FA),
        child: Icon(
          Icons.person,
          size: 60,
          color: Color(0xFF6B46C1),
        ),
      ),
    );
  }

  /// Convert a widget to PNG image bytes
  Future<Uint8List?> _widgetToImage(Widget widget) async {
    try {
      // Create a RepaintBoundary to capture the widget
      // Note: This is a simplified approach for widget to image conversion

      // We need to render this widget - this is a simplified approach
      // In a real app, you might need to use a more sophisticated method
      
      // For now, let's create a simple circular avatar programmatically
      return await _createProgrammaticAvatar();
    } catch (e) {
      debugPrint('AvatarService: Error converting widget to image: $e');
      return null;
    }
  }

  /// Create a programmatic avatar using Canvas (fallback method)
  Future<Uint8List?> _createProgrammaticAvatar() async {
    try {
      const size = 150.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Background circle with lavender color
      final backgroundPaint = Paint()
        ..color = const Color(0xFFE6E6FA)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2 - 2,
        backgroundPaint,
      );

      // White border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(
        const Offset(size / 2, size / 2),
        size / 2 - 1,
        borderPaint,
      );

      // Draw person icon (simplified)
      final iconPaint = Paint()
        ..color = const Color(0xFF6B46C1)
        ..style = PaintingStyle.fill;

      // Draw a simple person icon
      // Head circle
      canvas.drawCircle(
        const Offset(size / 2, size / 2 - 15),
        20,
        iconPaint,
      );

      // Body (simplified as a rounded rectangle)
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: const Offset(size / 2, size / 2 + 20),
          width: 50,
          height: 40,
        ),
        const Radius.circular(25),
      );
      canvas.drawRRect(bodyRect, iconPaint);

      final picture = recorder.endRecording();
      final img = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('AvatarService: Error creating programmatic avatar: $e');
      return null;
    }
  }

  /// Clean up old avatar files to prevent storage bloat
  Future<void> cleanupOldAvatars() async {
    try {
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();
      
      for (final file in files) {
        if (file.path.contains('callkit_avatar_')) {
          final stat = file.statSync();
          final age = DateTime.now().difference(stat.modified);
          
          // Delete files older than 1 hour
          if (age.inHours > 1) {
            file.deleteSync();
            debugPrint('AvatarService: Cleaned up old avatar: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('AvatarService: Error during cleanup: $e');
    }
  }
}