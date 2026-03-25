import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Result from uploading an image
class ImageUploadResult {
  final String imageUrl;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int fileSize;
  final String fileName;

  const ImageUploadResult({
    required this.imageUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    required this.fileSize,
    required this.fileName,
  });
}

/// Result from uploading a file
class FileUploadResult {
  final String fileUrl;
  final String fileName;
  final String mimeType;
  final int fileSize;

  const FileUploadResult({
    required this.fileUrl,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
  });
}

/// Service for handling file and image uploads for the canvas board
class CanvasFileService {
  static final CanvasFileService _instance = CanvasFileService._internal();
  factory CanvasFileService() => _instance;
  CanvasFileService._internal();

  final _supabase = CRMSupabaseService();
  final _uuid = const Uuid();
  final _imagePicker = ImagePicker();

  // Storage bucket name
  static const _bucketName = 'canvas-files';

  // Supported file types
  static const supportedImageTypes = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'];
  static const supportedFileTypes = [
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'md',
    'csv',
  ];

  // File size limits
  static const maxImageSize = 10 * 1024 * 1024; // 10MB
  static const maxFileSize = 50 * 1024 * 1024; // 50MB

  // ============ Image Operations ============

  /// Upload an image file to storage
  Future<ImageUploadResult> uploadImage(String boardId, File imageFile) async {
    final fileSize = await imageFile.length();
    if (fileSize > maxImageSize) {
      throw Exception('Image size exceeds 10MB limit');
    }

    final extension = path.extension(imageFile.path).toLowerCase().replaceAll('.', '');
    if (!supportedImageTypes.contains(extension)) {
      throw Exception('Unsupported image format: $extension');
    }

    final fileName = '${_uuid.v4()}.$extension';
    final storagePath = '$boardId/images/$fileName';
    final originalFileName = path.basename(imageFile.path);

    try {
      final bytes = await imageFile.readAsBytes();
      await _supabase.client.storage
          .from(_bucketName)
          .uploadBinary(storagePath, bytes);

      final imageUrl = _supabase.client.storage
          .from(_bucketName)
          .getPublicUrl(storagePath);

      return ImageUploadResult(
        imageUrl: imageUrl,
        fileSize: fileSize,
        fileName: originalFileName,
      );
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  /// Upload image from bytes (for clipboard paste)
  Future<ImageUploadResult> uploadImageFromBytes(
    String boardId,
    Uint8List bytes, {
    String extension = 'png',
    String? originalFileName,
  }) async {
    if (bytes.length > maxImageSize) {
      throw Exception('Image size exceeds 10MB limit');
    }

    final fileName = '${_uuid.v4()}.$extension';
    final storagePath = '$boardId/images/$fileName';

    // Decode image to get dimensions
    int? width;
    int? height;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      width = frame.image.width;
      height = frame.image.height;
      frame.image.dispose();
    } catch (e) {
      // Failed to decode - continue without dimensions
      debugPrint('Failed to decode image dimensions: $e');
    }

    try {
      await _supabase.client.storage
          .from(_bucketName)
          .uploadBinary(storagePath, bytes);

      final imageUrl = _supabase.client.storage
          .from(_bucketName)
          .getPublicUrl(storagePath);

      return ImageUploadResult(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fileSize: bytes.length,
        fileName: originalFileName ?? fileName,
      );
    } catch (e) {
      debugPrint('Error uploading image from bytes: $e');
      rethrow;
    }
  }

  /// Pick and upload image from gallery
  Future<ImageUploadResult?> uploadImageFromGallery(String boardId) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 4000,
        maxHeight: 4000,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      // Read bytes for web compatibility
      final bytes = await pickedFile.readAsBytes();
      final extension = pickedFile.path.split('.').last.toLowerCase();

      return uploadImageFromBytes(
        boardId,
        bytes,
        extension: extension.isNotEmpty ? extension : 'png',
        originalFileName: pickedFile.name,
      );
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      rethrow;
    }
  }

  /// Pick and upload image from camera
  Future<ImageUploadResult?> uploadImageFromCamera(String boardId) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 4000,
        maxHeight: 4000,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      // Read bytes for web compatibility
      final bytes = await pickedFile.readAsBytes();
      final extension = pickedFile.path.split('.').last.toLowerCase();

      return uploadImageFromBytes(
        boardId,
        bytes,
        extension: extension.isNotEmpty ? extension : 'png',
        originalFileName: pickedFile.name,
      );
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      rethrow;
    }
  }

  /// Delete an image from storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      final path = _extractPathFromUrl(imageUrl);
      if (path != null) {
        await _supabase.client.storage.from(_bucketName).remove([path]);
      }
    } catch (e) {
      debugPrint('Error deleting image: $e');
      // Don't rethrow - deletion failures shouldn't block other operations
    }
  }

  // ============ File Operations ============

  /// Upload a file to storage
  Future<FileUploadResult> uploadFile(String boardId, File file) async {
    final fileSize = await file.length();
    if (fileSize > maxFileSize) {
      throw Exception('File size exceeds 50MB limit');
    }

    final extension = path.extension(file.path).toLowerCase().replaceAll('.', '');
    final fileName = '${_uuid.v4()}.$extension';
    final storagePath = '$boardId/files/$fileName';
    final originalFileName = path.basename(file.path);
    final mimeType = _getMimeType(extension);

    try {
      final bytes = await file.readAsBytes();
      await _supabase.client.storage
          .from(_bucketName)
          .uploadBinary(storagePath, bytes);

      final fileUrl = _supabase.client.storage
          .from(_bucketName)
          .getPublicUrl(storagePath);

      return FileUploadResult(
        fileUrl: fileUrl,
        fileName: originalFileName,
        mimeType: mimeType,
        fileSize: fileSize,
      );
    } catch (e) {
      debugPrint('Error uploading file: $e');
      rethrow;
    }
  }

  /// Pick and upload a file
  Future<FileUploadResult?> pickAndUploadFile(String boardId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [...supportedImageTypes, ...supportedFileTypes],
        withData: true, // Use bytes for web compatibility
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final pickedFile = result.files.first;
      final bytes = pickedFile.bytes;

      if (bytes == null) {
        throw Exception('Could not read file data');
      }

      final extension = pickedFile.extension?.toLowerCase() ?? '';
      final originalFileName = pickedFile.name;

      // Check if it's an image or a file
      if (supportedImageTypes.contains(extension)) {
        final imageResult = await uploadImageFromBytes(
          boardId,
          bytes,
          extension: extension,
          originalFileName: originalFileName,
        );
        return FileUploadResult(
          fileUrl: imageResult.imageUrl,
          fileName: imageResult.fileName,
          mimeType: _getMimeType(extension),
          fileSize: imageResult.fileSize,
        );
      } else {
        return uploadFileFromBytes(boardId, bytes, extension, originalFileName);
      }
    } catch (e) {
      debugPrint('Error picking and uploading file: $e');
      rethrow;
    }
  }

  /// Upload a file from bytes (for web compatibility)
  Future<FileUploadResult> uploadFileFromBytes(
    String boardId,
    Uint8List bytes,
    String extension,
    String originalFileName,
  ) async {
    if (bytes.length > maxFileSize) {
      throw Exception('File size exceeds 50MB limit');
    }

    final fileName = '${_uuid.v4()}.$extension';
    final storagePath = '$boardId/files/$fileName';
    final mimeType = _getMimeType(extension);

    try {
      await _supabase.client.storage
          .from(_bucketName)
          .uploadBinary(storagePath, bytes);

      final fileUrl = _supabase.client.storage
          .from(_bucketName)
          .getPublicUrl(storagePath);

      return FileUploadResult(
        fileUrl: fileUrl,
        fileName: originalFileName,
        mimeType: mimeType,
        fileSize: bytes.length,
      );
    } catch (e) {
      debugPrint('Error uploading file from bytes: $e');
      rethrow;
    }
  }

  /// Delete a file from storage
  Future<void> deleteFile(String fileUrl) async {
    try {
      final path = _extractPathFromUrl(fileUrl);
      if (path != null) {
        await _supabase.client.storage.from(_bucketName).remove([path]);
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  // ============ Utility Methods ============

  /// Get MIME type from file extension
  String _getMimeType(String extension) {
    final ext = extension.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'csv':
        return 'text/csv';
      default:
        return 'application/octet-stream';
    }
  }

  /// Extract storage path from public URL
  String? _extractPathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // Find index after 'canvas-files' in the path
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        return null;
      }

      return pathSegments.sublist(bucketIndex + 1).join('/');
    } catch (e) {
      return null;
    }
  }

  /// Get icon name for file type
  static String getFileTypeIcon(String mimeType) {
    if (mimeType.startsWith('image/')) {
      return 'image';
    }
    switch (mimeType) {
      case 'application/pdf':
        return 'pdf';
      case 'application/msword':
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'word';
      case 'application/vnd.ms-excel':
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return 'excel';
      case 'application/vnd.ms-powerpoint':
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return 'powerpoint';
      case 'text/plain':
      case 'text/markdown':
        return 'text';
      case 'text/csv':
        return 'csv';
      default:
        return 'file';
    }
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
