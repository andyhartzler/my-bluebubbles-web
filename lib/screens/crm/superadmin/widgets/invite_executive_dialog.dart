import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Dialog for Andrew / other superadmins to invite a new executive-committee
/// member. Calls the `invite-executive` Edge Function, handles the 409
/// "already a member" case with a one-tap upgrade to `executive_committee=true`.
///
/// Resolves with `true` on successful invite (so the caller can refresh its
/// list) or `null` if the dialog was cancelled.
class InviteExecutiveDialog extends StatefulWidget {
  const InviteExecutiveDialog({super.key});

  @override
  State<InviteExecutiveDialog> createState() => _InviteExecutiveDialogState();
}

class _InviteExecutiveDialogState extends State<InviteExecutiveDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _roleController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  // When the edge fn returns 409 with a member_id, we stash it so the user can
  // flip the flag with a single button press instead of re-typing the form.
  String? _existingMemberId;
  String? _existingMemberEmail;

  static final _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _titleController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _existingMemberId = null;
      _existingMemberEmail = null;
    });

    final body = <String, dynamic>{
      'email': _emailController.text.trim(),
      'name': _nameController.text.trim(),
      if (_titleController.text.trim().isNotEmpty)
        'executive_title': _titleController.text.trim(),
      if (_roleController.text.trim().isNotEmpty)
        'executive_role': _roleController.text.trim(),
    };

    try {
      final client = CRMSupabaseService().client;
      final response = await client.functions.invoke(
        'invite-executive',
        body: body,
      );

      final status = response.status;
      final data = response.data;

      if (status >= 200 && status < 300) {
        _onInviteSuccess(body['email'] as String);
        return;
      }

      // 409 conflict: the email is already a member. The edge fn is expected
      // to return `{ error: '...', code: 'already_member', member_id: '...' }`.
      if (status == 409 && data is Map) {
        final code = data['code']?.toString();
        final memberId = data['member_id']?.toString();
        if (code == 'already_member' && memberId != null && memberId.isNotEmpty) {
          setState(() {
            _submitting = false;
            _existingMemberId = memberId;
            _existingMemberEmail = body['email'] as String;
            _errorMessage = data['error']?.toString() ??
                'A member with this email already exists.';
          });
          return;
        }
      }

      // Any other non-2xx: surface a best-effort error message.
      setState(() {
        _submitting = false;
        _errorMessage = _extractError(data) ??
            'Invite failed with status $status';
      });
    } on FunctionException catch (e) {
      // supabase-dart raises FunctionException for non-2xx when the SDK
      // version is configured strictly. Peek inside details for the 409
      // payload before showing a generic error.
      final details = e.details;
      if (e.status == 409 && details is Map) {
        final memberId = details['member_id']?.toString();
        if (memberId != null && memberId.isNotEmpty) {
          setState(() {
            _submitting = false;
            _existingMemberId = memberId;
            _existingMemberEmail = body['email'] as String;
            _errorMessage = details['error']?.toString() ??
                'A member with this email already exists.';
          });
          return;
        }
      }
      setState(() {
        _submitting = false;
        _errorMessage = e.details?.toString() ?? e.reasonPhrase ?? 'Invite failed.';
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = 'Invite failed: $e';
      });
    }
  }

  void _onInviteSuccess(String email) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite sent to $email')),
    );
    Navigator.of(context).pop<bool>(true);
  }

  String? _extractError(dynamic data) {
    if (data is Map) {
      final msg = data['error'] ?? data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    if (data is String && data.isNotEmpty) return data;
    return null;
  }

  Future<void> _promoteExistingMember() async {
    final memberId = _existingMemberId;
    if (memberId == null) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final client = CRMSupabaseService().client;
      await client
          .from('members')
          .update({'executive_committee': true})
          .eq('id', memberId);

      if (!mounted) return;
      final email = _existingMemberEmail ?? _emailController.text.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Promoted $email to executive committee')),
      );
      Navigator.of(context).pop<bool>(true);
    } catch (e) {
      setState(() {
        _submitting = false;
        _errorMessage = 'Failed to promote existing member: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person_add_alt_1, color: BrandColors.unityBlue, size: 22),
          const SizedBox(width: 8),
          const Text('Invite Executive'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    hintText: 'name@example.org',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Email is required';
                    if (!_emailRegex.hasMatch(v)) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Full name *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Executive title (optional)',
                    hintText: 'e.g. Communications Director',
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _roleController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Executive role (optional)',
                    hintText: 'e.g. Officer',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: BrandColors.error.withOpacity(0.08),
                      border:
                          Border.all(color: BrandColors.error.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline,
                            color: BrandColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: BrandColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_existingMemberId != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.upgrade, size: 18),
                      label: const Text(
                          'Flip existing member to executive_committee = true'),
                      onPressed: _submitting ? null : _promoteExistingMember,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop<bool>(null),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send, size: 16),
          label: Text(_submitting ? 'Sending...' : 'Send Invite'),
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }
}
