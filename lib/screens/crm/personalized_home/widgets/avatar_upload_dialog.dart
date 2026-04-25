import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lets the user pick an image from disk, uploads it to
/// `member-photos/<auth_user_id>/avatar.<ext>`, and returns the
/// public URL on success. Updates `members.avatar_url` for the
/// member with the matching `user_id`.
class AvatarUploadDialog extends StatefulWidget {
  final String authUserId;

  const AvatarUploadDialog({super.key, required this.authUserId});

  @override
  State<AvatarUploadDialog> createState() => _AvatarUploadDialogState();
}

class _AvatarUploadDialogState extends State<AvatarUploadDialog> {
  Uint8List? _picked;
  String? _pickedExt;
  bool _uploading = false;
  String? _error;

  static const _maxBytes = 1024 * 1024; // 1 MB

  Future<void> _pick() async {
    setState(() => _error = null);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _error = 'Could not read file');
        return;
      }
      if (bytes.length > _maxBytes) {
        setState(() => _error = 'Image too large (max 1 MB)');
        return;
      }
      setState(() {
        _picked = bytes;
        _pickedExt = (file.extension ?? 'png').toLowerCase();
      });
    } catch (e) {
      setState(() => _error = 'Pick failed: $e');
    }
  }

  Future<void> _upload() async {
    final bytes = _picked;
    final ext = _pickedExt;
    if (bytes == null || ext == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final path = '${widget.authUserId}/avatar.$ext';
      final contentType = _contentTypeForExt(ext);
      await client.storage.from('member-photos').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      // Cache-bust by appending updated_at-like query string
      final publicUrl = client.storage.from('member-photos').getPublicUrl(path);
      final cacheBusted = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await client
          .from('members')
          .update({'avatar_url': cacheBusted})
          .eq('user_id', widget.authUserId);

      if (mounted) Navigator.of(context).pop(cacheBusted);
    } catch (e) {
      if (kDebugMode) debugPrint('[AvatarUploadDialog] upload error: $e');
      setState(() {
        _uploading = false;
        _error = 'Upload failed: $e';
      });
    }
  }

  String _contentTypeForExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return AlertDialog(
      title: const Text('Update profile photo'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (picked != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(picked, height: 160, fit: BoxFit.cover),
              )
            else
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Icon(Icons.image_outlined, size: 48)),
              ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _uploading ? null : _pick,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(picked == null ? 'Choose image' : 'Choose another'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Text(
              'Max 1 MB. PNG, JPG, WEBP, or GIF.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_picked == null || _uploading) ? null : _upload,
          child: _uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Upload'),
        ),
      ],
    );
  }
}
