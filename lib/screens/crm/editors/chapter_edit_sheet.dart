import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/chapter.dart';
import 'package:bluebubbles/services/crm/chapter_repository.dart';

enum _ChapterFieldType { text, multiline, date, bool, socialMedia }

class ChapterEditSheet extends StatefulWidget {
  final Chapter chapter;

  const ChapterEditSheet({super.key, required this.chapter});

  @override
  State<ChapterEditSheet> createState() => _ChapterEditSheetState();
}

class _ChapterEditSheetState extends State<ChapterEditSheet> {
  final ChapterRepository _chapterRepository = ChapterRepository();
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool? _isChartered;
  bool _saving = false;
  late final Map<String, dynamic> _originalData;

  static const _fieldOrder = <String, _ChapterFieldType>{
    'chapter_name': _ChapterFieldType.text,
    'standardized_name': _ChapterFieldType.text,
    'school_name': _ChapterFieldType.text,
    'chapter_type': _ChapterFieldType.text,
    'charter_date': _ChapterFieldType.date,
    'status': _ChapterFieldType.text,
    'website': _ChapterFieldType.text,
    'contact_email': _ChapterFieldType.text,
    'social_media': _ChapterFieldType.socialMedia,
    'is_chartered': _ChapterFieldType.bool,
  };

  static const _socialMediaPlatforms = <String, String>{
    'twitter': 'Twitter/X',
    'bluesky': 'Bluesky',
    'facebook': 'Facebook',
    'instagram': 'Instagram',
    'threads': 'Threads',
    'tiktok': 'TikTok',
  };

  @override
  void initState() {
    super.initState();
    _originalData = widget.chapter.toJson();
    _isChartered = widget.chapter.isChartered;
    _controllers['chapter_name'] = TextEditingController(text: widget.chapter.chapterName);
    _controllers['standardized_name'] = TextEditingController(text: widget.chapter.standardizedName);
    _controllers['school_name'] = TextEditingController(text: widget.chapter.schoolName);
    _controllers['chapter_type'] = TextEditingController(text: widget.chapter.chapterType);
    _controllers['charter_date'] = TextEditingController(
      text: widget.chapter.charterDate?.toIso8601String().split('T').first ?? '',
    );
    _controllers['status'] = TextEditingController(text: widget.chapter.status ?? '');
    _controllers['website'] = TextEditingController(text: widget.chapter.website ?? '');
    _controllers['contact_email'] = TextEditingController(text: widget.chapter.contactEmail ?? '');

    // Initialize social media controllers from individual fields (preferred) or fallback to socialMedia map
    _controllers['social_twitter'] = TextEditingController(
      text: widget.chapter.twitter ?? widget.chapter.socialMedia?['twitter']?.toString() ?? '',
    );
    _controllers['social_bluesky'] = TextEditingController(
      text: widget.chapter.bluesky ?? widget.chapter.socialMedia?['bluesky']?.toString() ?? '',
    );
    _controllers['social_facebook'] = TextEditingController(
      text: widget.chapter.facebook ?? widget.chapter.socialMedia?['facebook']?.toString() ?? '',
    );
    _controllers['social_instagram'] = TextEditingController(
      text: widget.chapter.instagram ?? widget.chapter.socialMedia?['instagram']?.toString() ?? '',
    );
    _controllers['social_threads'] = TextEditingController(
      text: widget.chapter.threads ?? widget.chapter.socialMedia?['threads']?.toString() ?? '',
    );
    _controllers['social_tiktok'] = TextEditingController(
      text: widget.chapter.tiktok ?? widget.chapter.socialMedia?['tiktok']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.apartment),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Chapter',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  children: _fieldOrder.entries
                      .map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: _buildField(entry.key, entry.value),
                          ))
                      .toList(),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Saving...' : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String key, _ChapterFieldType type) {
    switch (type) {
      case _ChapterFieldType.bool:
        return DropdownButtonFormField<bool?>(
          value: _isChartered,
          decoration: const InputDecoration(
            labelText: 'Chartered',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem<bool?>(value: null, child: Text('Unset')),
            DropdownMenuItem<bool?>(value: true, child: Text('Yes')),
            DropdownMenuItem<bool?>(value: false, child: Text('No')),
          ],
          onChanged: (value) => setState(() => _isChartered = value),
        );
      case _ChapterFieldType.date:
        return TextFormField(
          controller: _controllers[key],
          decoration: const InputDecoration(
            labelText: 'Charter Date',
            helperText: 'YYYY-MM-DD',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return null;
            if (!_isValidDate(text)) {
              return 'Enter a valid date (YYYY-MM-DD)';
            }
            return null;
          },
        );
      case _ChapterFieldType.socialMedia:
        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Social Media Links',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Add handles or URLs for each platform',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ..._socialMediaPlatforms.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextFormField(
                    controller: _controllers['social_${entry.key}'],
                    decoration: InputDecoration(
                      labelText: entry.value,
                      hintText: '@username or URL',
                      prefixIcon: _getSocialIcon(entry.key),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                )).toList(),
              ],
            ),
          ),
        );
      case _ChapterFieldType.multiline:
        return TextFormField(
          controller: _controllers[key],
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: _labelFor(key),
            border: const OutlineInputBorder(),
          ),
        );
      case _ChapterFieldType.text:
      default:
        return TextFormField(
          controller: _controllers[key],
          decoration: InputDecoration(
            labelText: _labelFor(key),
            border: const OutlineInputBorder(),
          ),
        );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updates = <String, dynamic>{};

    void compare(String key, dynamic newValue) {
      final originalValue = _originalData[key];
      if (newValue == originalValue) {
        return;
      }
      if ((newValue == null || (newValue is String && newValue.trim().isEmpty)) &&
          (originalValue == null || (originalValue is String && originalValue.trim().isEmpty))) {
        return;
      }
      if (newValue is String && newValue.trim().isEmpty) {
        updates[key] = null;
      } else {
        updates[key] = newValue;
      }
    }

    for (final entry in _fieldOrder.entries) {
      switch (entry.value) {
        case _ChapterFieldType.bool:
          compare(entry.key, _isChartered);
          break;
        case _ChapterFieldType.date:
          compare(entry.key, _controllers[entry.key]!.text.trim());
          break;
        case _ChapterFieldType.socialMedia:
          // Add individual social media fields to updates
          for (final platform in _socialMediaPlatforms.keys) {
            final value = _controllers['social_$platform']!.text.trim();
            compare(platform, value.isEmpty ? null : value);
          }
          break;
        default:
          compare(entry.key, _controllers[entry.key]!.text.trim());
      }
    }

    if (updates.isEmpty) {
      if (mounted) {
        Navigator.of(context).pop(widget.chapter);
      }
      return;
    }

    setState(() => _saving = true);

    try {
      final updated = await _chapterRepository.updateChapter(widget.chapter.id, updates);
      if (!mounted) return;
      Navigator.of(context).pop(updated ?? widget.chapter);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update chapter: $e')),
      );
    }
  }

  Widget _getSocialIcon(String platform) {
    IconData iconData;
    switch (platform) {
      case 'twitter':
        iconData = Icons.tag; // Twitter/X
        break;
      case 'facebook':
        iconData = Icons.facebook;
        break;
      case 'instagram':
        iconData = Icons.camera_alt;
        break;
      case 'tiktok':
        iconData = Icons.music_note;
        break;
      case 'bluesky':
        iconData = Icons.cloud;
        break;
      case 'threads':
        iconData = Icons.interests;
        break;
      default:
        iconData = Icons.link;
    }
    return Icon(iconData, size: 20);
  }

  String _labelFor(String key) {
    switch (key) {
      case 'chapter_name':
        return 'Chapter Name';
      case 'standardized_name':
        return 'Standardized Name';
      case 'school_name':
        return 'School Name';
      case 'chapter_type':
        return 'Chapter Type';
      case 'status':
        return 'Status';
      case 'website':
        return 'Website';
      case 'contact_email':
        return 'Contact Email';
      default:
        return key.replaceAll('_', ' ').split(' ').map((word) => '${word[0].toUpperCase()}${word.substring(1)}').join(' ');
    }
  }

  bool _isValidDate(String input) {
    if (input.length != 10) return false;
    final date = DateTime.tryParse(input);
    return date != null;
  }
}
