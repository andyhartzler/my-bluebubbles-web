import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:html' as html;
import '../theme/campaign_builder_theme.dart';

/// Image Asset Manager with Drag & Drop Upload
/// Allows users to upload, manage, and select images for email campaigns
/// Premium dark theme with stunning UI
class ImageAssetManager extends StatefulWidget {
  final Function(String imageUrl) onImageSelected;
  final bool allowMultipleSelection;

  const ImageAssetManager({
    super.key,
    required this.onImageSelected,
    this.allowMultipleSelection = false,
  });

  @override
  State<ImageAssetManager> createState() => _ImageAssetManagerState();
}

class _ImageAssetManagerState extends State<ImageAssetManager> {
  List<Map<String, dynamic>> _images = [];
  bool _loading = true;
  bool _uploading = false;
  double _uploadProgress = 0.0;
  String? _dragOverZone;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _setupDragAndDrop();
  }

  void _setupDragAndDrop() {
    // Set up HTML5 drag and drop for web
    if (html.window.navigator.userAgent.contains('Chrome') ||
        html.window.navigator.userAgent.contains('Firefox') ||
        html.window.navigator.userAgent.contains('Safari')) {
      // Browser supports drag and drop
    }
  }

  Future<void> _loadImages() async {
    setState(() => _loading = true);

    try {
      final supabase = Supabase.instance.client;

      // List all files in campaigns bucket
      final files = await supabase.storage.from('campaigns').list();

      final imageList = files.map((file) {
        final url = supabase.storage.from('campaigns').getPublicUrl(file.name);
        return {
          'name': file.name,
          'url': url,
          'size': file.metadata?['size'] ?? 0,
          'createdAt': file.createdAt,
        };
      }).toList();

      // Sort by creation date (newest first)
      imageList.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

      setState(() {
        _images = imageList;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        _showError('Failed to load images: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: CampaignBuilderTheme.darkTheme,
      child: Container(
        height: 600,
        decoration: BoxDecoration(
          color: CampaignBuilderTheme.slate,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CampaignBuilderTheme.slateLight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: CampaignBuilderTheme.moyDBlue.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Dropzone area for drag & drop upload
            if (!_uploading) _buildDropzone(),

            // Upload progress
            if (_uploading) _buildUploadProgress(),

            // Image grid
            Expanded(
              child: _buildImageGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CampaignBuilderTheme.moyDBlue.withOpacity(0.1),
            CampaignBuilderTheme.brightBlue.withOpacity(0.05),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: const Border(bottom: BorderSide(color: CampaignBuilderTheme.slateLight)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [CampaignBuilderTheme.moyDBlue, CampaignBuilderTheme.brightBlue],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: CampaignBuilderTheme.moyDBlue.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.photo_library_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Campaign Image Library',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: CampaignBuilderTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Upload and manage images for your campaigns',
                style: TextStyle(
                  fontSize: 14,
                  color: CampaignBuilderTheme.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _uploading ? null : _uploadImage,
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_upload_rounded, size: 22),
            label: const Text('Upload Image', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: CampaignBuilderTheme.moyDBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              elevation: 4,
              shadowColor: CampaignBuilderTheme.moyDBlue.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropzone() {
    return MouseRegion(
      onEnter: (_) => setState(() => _dragOverZone = 'active'),
      onExit: (_) => setState(() => _dragOverZone = null),
      child: Container(
        margin: const EdgeInsets.all(24),
        height: 140,
        decoration: BoxDecoration(
          border: Border.all(
            color: _dragOverZone == 'active'
                ? CampaignBuilderTheme.successGreen
                : CampaignBuilderTheme.brightBlue,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(16),
          gradient: _dragOverZone == 'active'
              ? LinearGradient(
                  colors: [
                    CampaignBuilderTheme.successGreen.withOpacity(0.15),
                    CampaignBuilderTheme.successGreen.withOpacity(0.05),
                  ],
                )
              : LinearGradient(
                  colors: [
                    CampaignBuilderTheme.brightBlue.withOpacity(0.1),
                    CampaignBuilderTheme.brightBlue.withOpacity(0.05),
                  ],
                ),
        ),
        child: InkWell(
          onTap: _uploadImage,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _dragOverZone == 'active'
                      ? Icons.file_download_rounded
                      : Icons.cloud_upload_rounded,
                  size: 56,
                  color: _dragOverZone == 'active'
                      ? CampaignBuilderTheme.successGreen
                      : CampaignBuilderTheme.brightBlue,
                ),
                const SizedBox(height: 12),
                Text(
                  _dragOverZone == 'active'
                      ? 'Drop images here'
                      : 'Drag & drop images here',
                  style: TextStyle(
                    color: CampaignBuilderTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'or click to browse',
                  style: TextStyle(
                    color: CampaignBuilderTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'PNG, JPG, GIF, WebP up to 5MB',
                  style: TextStyle(
                    color: CampaignBuilderTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              const Text(
                'Uploading image...',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '${(_uploadProgress * 100).toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    CampaignBuilderTheme.brightBlue.withOpacity(0.2),
                    CampaignBuilderTheme.brightBlue.withOpacity(0.05),
                  ],
                ),
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 80,
                color: CampaignBuilderTheme.brightBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No images yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: CampaignBuilderTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Upload your first image to get started',
              style: TextStyle(
                fontSize: 15,
                color: CampaignBuilderTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _uploadImage,
              icon: const Icon(Icons.cloud_upload_rounded, size: 22),
              label: const Text('Upload Image', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: CampaignBuilderTheme.moyDBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                elevation: 4,
                shadowColor: CampaignBuilderTheme.moyDBlue.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final image = _images[index];
        return _ImageCard(
          imageUrl: image['url'] as String,
          imageName: image['name'] as String,
          imageSize: image['size'] as int,
          onSelect: () {
            widget.onImageSelected(image['url'] as String);
            Navigator.pop(context);
          },
          onDelete: () => _deleteImage(image['name'] as String),
        );
      },
    );
  }

  Future<void> _uploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    // Validate file size (5MB max)
    if (file.size > 5 * 1024 * 1024) {
      _showError('Image must be less than 5MB');
      return;
    }

    // Validate file type
    final allowedExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp'];
    final extension = file.extension?.toLowerCase();
    if (extension == null || !allowedExtensions.contains(extension)) {
      _showError('Only PNG, JPG, GIF, and WebP images are supported');
      return;
    }

    await _uploadFile(file);
  }

  Future<void> _uploadFile(PlatformFile file) async {
    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final supabase = Supabase.instance.client;

      // Upload to Supabase Storage (campaigns bucket)
      await supabase.storage.from('campaigns').uploadBinary(
            fileName,
            file.bytes!,
            fileOptions: FileOptions(
              contentType: 'image/${file.extension}',
              upsert: false,
            ),
          );

      setState(() {
        _uploadProgress = 1.0;
      });

      // Reload images
      await _loadImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Image uploaded successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to upload: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _deleteImage(String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text(
          'Are you sure you want to delete this image? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.storage.from('campaigns').remove([fileName]);

      await _loadImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image deleted'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to delete: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _ImageCard extends StatefulWidget {
  final String imageUrl;
  final String imageName;
  final int imageSize;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _ImageCard({
    required this.imageUrl,
    required this.imageName,
    required this.imageSize,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  State<_ImageCard> createState() => _ImageCardState();
}

class _ImageCardState extends State<_ImageCard> {
  bool _isHovered = false;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        elevation: _isHovered ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _isHovered ? const Color(0xFF1E3A8A) : Colors.grey[300]!,
            width: _isHovered ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            Image.network(
              widget.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  ),
                );
              },
            ),

            // Hover overlay
            if (_isHovered)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.9),
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: widget.onSelect,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Select'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete, color: Colors.white),
                          tooltip: 'Delete',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            // Copy URL to clipboard
                            html.window.navigator.clipboard?.writeText(widget.imageUrl);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Image URL copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.link, color: Colors.white),
                          tooltip: 'Copy URL',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Image info overlay at bottom (when not hovered)
            if (!_isHovered)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.imageName.length > 20
                            ? '${widget.imageName.substring(0, 17)}...'
                            : widget.imageName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatBytes(widget.imageSize),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
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
