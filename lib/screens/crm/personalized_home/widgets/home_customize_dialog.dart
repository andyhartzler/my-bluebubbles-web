import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/user_home_preferences.dart';
import 'package:bluebubbles/services/crm/user_home_preferences_service.dart';

/// Toggle-only customize dialog for v1. Lets the user show/hide each
/// top-level panel on the Personalized Home Screen.
class HomeCustomizeDialog extends StatefulWidget {
  final UserHomePreferences current;

  const HomeCustomizeDialog({super.key, required this.current});

  @override
  State<HomeCustomizeDialog> createState() => _HomeCustomizeDialogState();
}

class _HomeCustomizeDialogState extends State<HomeCustomizeDialog> {
  late bool _showProfile;
  late bool _showAssignments;
  late bool _showMeetings;
  late bool _showOptional;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _showProfile = widget.current.showProfileHeader;
    _showAssignments = widget.current.showAssignments;
    _showMeetings = widget.current.showMeetingHistory;
    _showOptional = widget.current.showOptionalTiles;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.current.copyWith(
      showProfileHeader: _showProfile,
      showAssignments: _showAssignments,
      showMeetingHistory: _showMeetings,
      showOptionalTiles: _showOptional,
    );
    final ok = await UserHomePreferencesService().upsert(updated);
    if (!mounted) return;
    if (!ok) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save preferences')),
      );
      return;
    }
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Customize home screen'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Profile header'),
              subtitle: const Text('Avatar, name, title'),
              value: _showProfile,
              onChanged: (v) => setState(() => _showProfile = v),
            ),
            SwitchListTile(
              title: const Text('Assignments panel'),
              subtitle: const Text('Tasks assigned to you and by you'),
              value: _showAssignments,
              onChanged: (v) => setState(() => _showAssignments = v),
            ),
            SwitchListTile(
              title: const Text('Meeting history'),
              subtitle: const Text('Upcoming, recent, hosted meetings'),
              value: _showMeetings,
              onChanged: (v) => setState(() => _showMeetings = v),
            ),
            SwitchListTile(
              title: const Text('Optional metric tiles'),
              subtitle: const Text('Add dashboard metric tiles to your home'),
              value: _showOptional,
              onChanged: (v) => setState(() => _showOptional = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
