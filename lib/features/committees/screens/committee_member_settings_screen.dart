import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _successGreen = Color(0xFF43A047);
const _backgroundAsset = 'assets/images/Blue-Gradient-Background.png';
const _overlayOpacity = 0.05;

/// Model for field visibility configuration
class FieldVisibility {
  final String fieldName;
  final String displayLabel;
  final String fieldCategory;
  final bool isVisible;
  final bool isEditable;
  final bool isRequired;
  final int sortOrder;
  final String? helpText;

  const FieldVisibility({
    required this.fieldName,
    required this.displayLabel,
    required this.fieldCategory,
    required this.isVisible,
    required this.isEditable,
    required this.isRequired,
    required this.sortOrder,
    this.helpText,
  });

  factory FieldVisibility.fromJson(Map<String, dynamic> json) {
    return FieldVisibility(
      fieldName: json['field_name'] as String,
      displayLabel: json['display_label'] as String,
      fieldCategory: json['field_category'] as String,
      isVisible: json['is_visible'] as bool? ?? false,
      isEditable: json['is_editable'] as bool? ?? false,
      isRequired: json['is_required'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 99,
      helpText: json['help_text'] as String?,
    );
  }
}

/// Settings screen for committee members to edit their profile
class CommitteeMemberSettingsScreen extends StatefulWidget {
  const CommitteeMemberSettingsScreen({super.key});

  @override
  State<CommitteeMemberSettingsScreen> createState() =>
      _CommitteeMemberSettingsScreenState();
}

class _CommitteeMemberSettingsScreenState
    extends State<CommitteeMemberSettingsScreen> {
  final CRMSupabaseService _supabase = CRMSupabaseService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isEditMode = false;
  String? _error;

  List<FieldVisibility> _fieldVisibility = [];
  Map<String, String> _pendingChanges = {};
  Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadFieldVisibility();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFieldVisibility() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = _supabase.client;

      // Load field visibility settings
      final visibilityData = await client
          .from('member_portal_field_visibility')
          .select()
          .eq('is_visible', true)
          .order('field_category')
          .order('sort_order');

      // Also load any pending changes for this member
      final session = context.read<UserSessionProvider>();
      final memberId = session.currentMember?.id;

      Map<String, String> pendingChanges = {};
      if (memberId != null) {
        final changesData = await client
            .from('member_profile_changes')
            .select()
            .eq('member_id', memberId)
            .eq('status', 'pending');

        for (final change in changesData as List) {
          final fieldName = change['field_name'] as String;
          final newValue = change['new_value'] as String?;
          if (newValue != null) {
            pendingChanges[fieldName] = newValue;
          }
        }
      }

      if (!mounted) return;

      final fields = (visibilityData as List)
          .map((item) => FieldVisibility.fromJson(item as Map<String, dynamic>))
          .toList();

      // Initialize controllers with member data + pending changes
      _initializeControllers(fields, pendingChanges);

      setState(() {
        _fieldVisibility = fields;
        _pendingChanges = pendingChanges;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _initializeControllers(
      List<FieldVisibility> fields, Map<String, String> pendingChanges) {
    final session = context.read<UserSessionProvider>();
    final member = session.currentMember;

    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();

    for (final field in fields) {
      // Get current value from member or pending changes
      String? value = pendingChanges[field.fieldName];
      value ??= _getMemberFieldValue(member, field.fieldName);

      _controllers[field.fieldName] = TextEditingController(text: value ?? '');
    }
  }

  String? _getMemberFieldValue(Member? member, String fieldName) {
    if (member == null) return null;

    switch (fieldName) {
      case 'name':
        return member.name;
      case 'email':
        return member.email;
      case 'phone':
        return member.phone;
      case 'address':
        return member.address;
      case 'city':
        return member.city;
      case 'state':
        return member.state;
      case 'zip_code':
        return null; // Not stored in member model
      case 'county':
        return member.county;
      case 'date_of_birth':
        return member.dateOfBirth?.toIso8601String().split('T').first;
      case 'college':
        return member.college;
      case 'high_school':
        return member.highSchool;
      case 'school_name':
        return member.schoolName;
      case 'school_email':
        return member.schoolEmail;
      case 'graduation_year':
        return member.graduationYear;
      case 'employer':
      case 'employed':
        return member.employed;
      case 'occupation':
      case 'industry':
        return member.industry;
      case 'pronouns':
      case 'preferred_pronouns':
        return member.preferredPronouns;
      case 'gender':
      case 'gender_identity':
        return member.genderIdentity;
      case 'race':
        return member.race;
      case 'ethnicity':
        return member.race; // Map ethnicity to race field
      case 'voter_registration_status':
      case 'registered_voter':
        return member.registeredVoter == true ? 'Registered' : (member.registeredVoter == false ? 'Not Registered' : null);
      case 'congressional_district':
        return member.congressionalDistrict;
      case 'state_senate_district':
      case 'state_house_district':
        return null; // Not stored in member model
      default:
        return null;
    }
  }

  Future<void> _uploadPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploadingPhoto = true);

      final session = context.read<UserSessionProvider>();
      final member = session.currentMember;
      if (member == null) throw Exception('No member found');

      // Upload to Supabase storage
      final bytes = await image.readAsBytes();
      final fileName =
          '${member.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'profile-photos/$fileName';

      await _supabase.client.storage
          .from('member-photos')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ));

      // Get public URL
      final publicUrl =
          _supabase.client.storage.from('member-photos').getPublicUrl(path);

      // Update member record with new photo
      final newPhoto = MemberProfilePhoto(
        path: path,
        bucket: 'member-photos',
        filename: fileName,
        uploadedAt: DateTime.now(),
        isPrimary: true,
      );

      // Merge with existing photos
      final updatedPhotos = [
        newPhoto,
        ...member.profilePhotos.where((p) => !p.isPrimary),
      ];

      await _supabase.client.from('members').update({
        'profile_pictures': updatedPhotos.map((p) => p.toJson()).toList(),
      }).eq('id', member.id);

      // Refresh member in session
      final updatedMember = member.copyWith(profilePhotos: updatedPhotos);
      session.refreshMember(updatedMember);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo updated successfully'),
          backgroundColor: _successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    final session = context.read<UserSessionProvider>();
    final member = session.currentMember;
    if (member == null) return;

    // Find fields that have changed
    final changes = <String, Map<String, String?>>{};

    for (final field in _fieldVisibility) {
      if (!field.isEditable) continue;

      final controller = _controllers[field.fieldName];
      if (controller == null) continue;

      final newValue = controller.text.trim();
      final originalValue = _getMemberFieldValue(member, field.fieldName) ?? '';

      // Check if value is different from original (ignore pending changes for comparison)
      if (newValue != originalValue) {
        changes[field.fieldName] = {
          'old_value': originalValue,
          'new_value': newValue,
        };
      }
    }

    if (changes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final client = _supabase.client;

      // Insert each change into member_profile_changes table
      for (final entry in changes.entries) {
        await client.from('member_profile_changes').insert({
          'member_id': member.id,
          'field_name': entry.key,
          'old_value': entry.value['old_value'],
          'new_value': entry.value['new_value'],
          'change_type': 'update',
          'status': 'pending',
        });

        // Track as pending change locally
        _pendingChanges[entry.key] = entry.value['new_value']!;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Changes submitted for review'),
          backgroundColor: _successGreen,
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Positioned.fill(
            child: Image.asset(
              _backgroundAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_unityBlue, _momentumBlue],
                  ),
                ),
              ),
            ),
          ),
          // White overlay
          Positioned.fill(
            child: Container(color: Colors.white.withOpacity(_overlayOpacity)),
          ),
          // Content
          Positioned.fill(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final session = context.watch<UserSessionProvider>();
    final member = session.currentMember;

    return CustomScrollView(
      slivers: [
        // App bar
        SliverAppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          pinned: true,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _unityBlue.withOpacity(0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back, color: _unityBlue, size: 20),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _unityBlue.withOpacity(0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Text(
              'Profile Settings',
              style: TextStyle(
                color: _unityBlue,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isEditMode ? _momentumBlue : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _unityBlue.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isEditMode ? Icons.visibility : Icons.edit,
                    color: _isEditMode ? Colors.white : _unityBlue,
                    size: 20,
                  ),
                ),
                onPressed: () {
                  setState(() => _isEditMode = !_isEditMode);
                },
                tooltip: _isEditMode ? 'View mode' : 'Edit mode',
              ),
            ),
          ],
        ),

        // Content
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_momentumBlue),
              ),
            ),
          )
        else if (_error != null)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: _unityBlue),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: _unityBlue)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadFieldVisibility,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Profile photo section
                _buildPhotoSection(member),
                const SizedBox(height: 24),

                // Edit mode indicator
                if (_isEditMode)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _momentumBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _momentumBlue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note, color: _momentumBlue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Edit mode - Fill in your profile information',
                            style: TextStyle(
                              color: _momentumBlue.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Profile fields grouped by category
                ..._buildFieldSections(),

                const SizedBox(height: 24),

                // Save button - only show in edit mode
                if (_isEditMode) _buildSaveButton(),

                const SizedBox(height: 32),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoSection(Member? member) {
    final photoUrl = member?.effectiveAvatarUrl;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_unityBlue, _momentumBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: CorsAwareAvatar(
                  imageUrl: photoUrl,
                  radius: 50,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  fallbackText: member?.name ?? '',
                  fallbackIconColor: Colors.white,
                  fallbackTextColor: Colors.white,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingPhoto ? null : _uploadPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _unityBlue.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: _isUploadingPhoto
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(_momentumBlue),
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: _momentumBlue,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            member?.name ?? 'Member',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (member?.email != null) ...[
            const SizedBox(height: 4),
            Text(
              member!.email!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Tap the camera icon to update your photo',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFieldSections() {
    // Group fields by category
    final categoryFields = <String, List<FieldVisibility>>{};
    for (final field in _fieldVisibility) {
      // In view mode, only include fields with values
      if (!_isEditMode) {
        final controller = _controllers[field.fieldName];
        final hasValue = controller != null && controller.text.trim().isNotEmpty;
        if (!hasValue) continue;
      }
      categoryFields.putIfAbsent(field.fieldCategory, () => []).add(field);
    }

    final widgets = <Widget>[];

    for (final category in categoryFields.keys) {
      final fields = categoryFields[category]!;
      if (fields.isEmpty) continue;

      fields.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      widgets.add(_buildCategorySection(category, fields));
      widgets.add(const SizedBox(height: 16));
    }

    // Show message if no fields have values
    if (!_isEditMode && widgets.isEmpty) {
      widgets.add(
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _unityBlue.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: _momentumBlue.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No profile information yet',
                style: TextStyle(
                  color: _unityBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the edit icon to add your information',
                style: TextStyle(
                  color: _unityBlue.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildCategorySection(String category, List<FieldVisibility> fields) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _unityBlue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _momentumBlue.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(category),
                  color: _momentumBlue,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  category,
                  style: const TextStyle(
                    color: _unityBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          // Fields
          ...fields.map((field) => _buildFieldRow(field)),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'personal information':
        return Icons.person_outline;
      case 'contact information':
        return Icons.contact_mail_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'employment':
        return Icons.work_outline;
      case 'voter information':
        return Icons.how_to_vote_outlined;
      case 'demographics':
        return Icons.groups_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildFieldRow(FieldVisibility field) {
    final controller = _controllers[field.fieldName];
    final hasPendingChange = _pendingChanges.containsKey(field.fieldName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                field.displayLabel,
                style: TextStyle(
                  color: _unityBlue.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (field.isRequired) ...[
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                ),
              ],
              if (hasPendingChange) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (field.isEditable)
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                filled: true,
                fillColor: _momentumBlue.withOpacity(0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _momentumBlue.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _momentumBlue.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _momentumBlue, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                hintText: field.helpText,
                hintStyle: TextStyle(
                  color: _unityBlue.withOpacity(0.3),
                  fontSize: 14,
                ),
              ),
              style: const TextStyle(
                color: _unityBlue,
                fontSize: 14,
              ),
              keyboardType: _getKeyboardType(field.fieldName),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                controller?.text ?? '',
                style: TextStyle(
                  color: _unityBlue.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
          const Divider(height: 24),
        ],
      ),
    );
  }

  TextInputType _getKeyboardType(String fieldName) {
    if (fieldName.contains('email')) return TextInputType.emailAddress;
    if (fieldName.contains('phone')) return TextInputType.phone;
    if (fieldName.contains('zip')) return TextInputType.number;
    if (fieldName.contains('date')) return TextInputType.datetime;
    return TextInputType.text;
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveChanges,
      style: ElevatedButton.styleFrom(
        backgroundColor: _momentumBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSaving) ...[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Saving...',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ] else ...[
            const Icon(Icons.save_outlined, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Save Changes',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
