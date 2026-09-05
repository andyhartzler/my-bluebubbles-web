import 'package:flutter/material.dart';

import 'package:bluebubbles/features/canvas_board/models/canvas_node.dart';
import 'package:bluebubbles/features/canvas_board/widgets/node_widgets/base_canvas_node.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/features/committees/widgets/cors_aware_avatar.dart';

/// Available fields that can be displayed on a member node
enum MemberDisplayField {
  name,
  email,
  phone,
  chapter,
  committee,
  school,
  pronouns,
  position,
}

extension MemberDisplayFieldExtension on MemberDisplayField {
  String get label {
    switch (this) {
      case MemberDisplayField.name:
        return 'Name';
      case MemberDisplayField.email:
        return 'Email';
      case MemberDisplayField.phone:
        return 'Phone';
      case MemberDisplayField.chapter:
        return 'Chapter';
      case MemberDisplayField.committee:
        return 'Committee';
      case MemberDisplayField.school:
        return 'School';
      case MemberDisplayField.pronouns:
        return 'Pronouns';
      case MemberDisplayField.position:
        return 'Position';
    }
  }

  IconData get icon {
    switch (this) {
      case MemberDisplayField.name:
        return Icons.person;
      case MemberDisplayField.email:
        return Icons.email;
      case MemberDisplayField.phone:
        return Icons.phone;
      case MemberDisplayField.chapter:
        return Icons.group;
      case MemberDisplayField.committee:
        return Icons.people;
      case MemberDisplayField.school:
        return Icons.school;
      case MemberDisplayField.pronouns:
        return Icons.badge;
      case MemberDisplayField.position:
        return Icons.work;
    }
  }

  String? getValue(Member member) {
    switch (this) {
      case MemberDisplayField.name:
        return member.name;
      case MemberDisplayField.email:
        return member.preferredEmail;
      case MemberDisplayField.phone:
        return member.phone;
      case MemberDisplayField.chapter:
        return member.chapterName;
      case MemberDisplayField.committee:
        final committees = member.committee;
        if (committees == null || committees.isEmpty) return null;
        return committees.join(', ');
      case MemberDisplayField.school:
        return member.schoolName;
      case MemberDisplayField.pronouns:
        return member.preferredPronouns;
      case MemberDisplayField.position:
        return member.chapterPosition;
    }
  }
}

/// Canvas node widget for displaying a Member entity
class MemberCanvasNode extends StatelessWidget {
  final CanvasNode node;
  final Member? member;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onDelete;
  final VoidCallback? onConfigureFields;

  static const accentColor = Color(0xFF2196F3); // Blue

  /// Default fields to display if none configured
  static const defaultDisplayFields = [
    MemberDisplayField.name,
    MemberDisplayField.email,
    MemberDisplayField.chapter,
  ];

  const MemberCanvasNode({
    super.key,
    required this.node,
    this.member,
    this.isSelected = false,
    this.isLoading = false,
    this.onTap,
    this.onDoubleTap,
    this.onDelete,
    this.onConfigureFields,
  });

  /// Get the display fields from node metadata or use defaults
  List<MemberDisplayField> get displayFields {
    final fieldNames = node.metadata?['display_fields'] as List<dynamic>?;
    if (fieldNames == null || fieldNames.isEmpty) {
      return defaultDisplayFields;
    }
    return fieldNames
        .map((name) => MemberDisplayField.values.firstWhere(
              (f) => f.name == name,
              orElse: () => MemberDisplayField.name,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return BaseCanvasNode(
      node: node,
      isSelected: isSelected,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onDelete: onDelete,
      accentColor: accentColor,
      child: Container(
        width: node.width,
        height: node.height,
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NodeTypeHeader(
              label: 'Member',
              icon: Icons.person,
              color: accentColor,
              trailing: isSelected && onConfigureFields != null
                  ? IconButton(
                      icon: const Icon(Icons.settings, size: 16),
                      onPressed: onConfigureFields,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Configure fields',
                    )
                  : null,
            ),
            Expanded(
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : member == null
                      ? _buildErrorState()
                      : _buildMemberContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.grey[400],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Member not found',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberContent() {
    final m = member!;
    final photoUrl = m.effectiveAvatarUrl;
    final fields = displayFields;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // CorsAwareAvatar, not CircleAvatar plus a cached provider: the
          // old form drew initials only when the url was null, so a 404 or a
          // CORS refusal left an empty disc. White on the opaque unityBlue
          // default is 12.51:1.
          CorsAwareAvatar(
            imageUrl: photoUrl,
            radius: 24,
            fallbackText: m.name,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildFieldWidgets(m, fields),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFieldWidgets(Member m, List<MemberDisplayField> fields) {
    final widgets = <Widget>[];

    for (int i = 0; i < fields.length; i++) {
      final field = fields[i];
      final value = field.getValue(m);

      if (value == null || value.isEmpty) continue;

      if (field == MemberDisplayField.name) {
        widgets.add(Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ));
      } else if (field == MemberDisplayField.chapter ||
          field == MemberDisplayField.committee) {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 4));
        widgets.add(Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ));
      } else {
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 2));
        widgets.add(Text(
          value,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ));
      }
    }

    return widgets;
  }
}

/// Dialog for selecting which fields to display on a member node
class MemberFieldSelectionDialog extends StatefulWidget {
  final List<MemberDisplayField> initialFields;

  const MemberFieldSelectionDialog({
    super.key,
    required this.initialFields,
  });

  static Future<List<MemberDisplayField>?> show(
    BuildContext context, {
    List<MemberDisplayField>? initialFields,
  }) async {
    return showDialog<List<MemberDisplayField>>(
      context: context,
      builder: (context) => MemberFieldSelectionDialog(
        initialFields: initialFields ?? MemberCanvasNode.defaultDisplayFields,
      ),
    );
  }

  @override
  State<MemberFieldSelectionDialog> createState() =>
      _MemberFieldSelectionDialogState();
}

class _MemberFieldSelectionDialogState
    extends State<MemberFieldSelectionDialog> {
  late Set<MemberDisplayField> _selectedFields;

  @override
  void initState() {
    super.initState();
    _selectedFields = widget.initialFields.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune, color: MemberCanvasNode.accentColor),
          SizedBox(width: 12),
          Text('Display Fields'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select which fields to display on this member card:',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...MemberDisplayField.values.map((field) => CheckboxListTile(
                  title: Row(
                    children: [
                      Icon(field.icon, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(field.label),
                    ],
                  ),
                  value: _selectedFields.contains(field),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedFields.add(field);
                      } else {
                        // Don't allow deselecting name
                        if (field != MemberDisplayField.name) {
                          _selectedFields.remove(field);
                        }
                      }
                    });
                  },
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            // Ensure name is always first
            final orderedFields = <MemberDisplayField>[MemberDisplayField.name];
            for (final field in MemberDisplayField.values) {
              if (field != MemberDisplayField.name &&
                  _selectedFields.contains(field)) {
                orderedFields.add(field);
              }
            }
            Navigator.pop(context, orderedFields);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
