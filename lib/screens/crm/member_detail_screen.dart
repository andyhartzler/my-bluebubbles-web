import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum _SocialPlatform { instagram, tiktok, x }

import 'package:bluebubbles/app/layouts/chat_creator/chat_creator.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/services/services.dart';

/// Detailed view of a single member
class MemberDetailScreen extends StatefulWidget {
  final Member member;

  const MemberDetailScreen({
    Key? key,
    required this.member,
  }) : super(key: key);

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final MemberRepository _memberRepo = MemberRepository();
  final CRMSupabaseService _supabaseService = CRMSupabaseService();
  late Member _member;
  final TextEditingController _notesController = TextEditingController();
  bool _editingNotes = false;

  bool get _crmReady => _supabaseService.isInitialized;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _notesController.text = _member.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    if (!_crmReady) return;

    try {
      await _memberRepo.updateNotes(_member.id, _notesController.text);
      if (!mounted) return;
      setState(() {
        _member = _member.copyWith(notes: _notesController.text);
        _editingNotes = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving notes: $e')),
      );
    }
  }

  Future<void> _toggleOptOut() async {
    if (!_crmReady) return;
    final newOptOutStatus = !_member.optOut;

    try {
      await _memberRepo.updateOptOutStatus(
        _member.id,
        newOptOutStatus,
        reason: newOptOutStatus ? 'Manually opted out' : null,
      );

      if (!mounted) return;
      setState(() {
        _member = _member.copyWith(
          optOut: newOptOutStatus,
          optOutDate: newOptOutStatus ? DateTime.now() : _member.optOutDate,
          optInDate: !newOptOutStatus ? DateTime.now() : _member.optInDate,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newOptOutStatus ? 'Member opted out' : 'Member opted in'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating opt-out status: $e')),
      );
    }
  }

  Future<void> _startChat() async {
    final address = _cleanText(_member.phoneE164) ?? _cleanText(_member.phone);
    if (address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
      return;
    }

    final navContext = ns.key.currentContext ?? context;

    try {
      await ns.pushAndRemoveUntil(
        navContext,
        ChatCreator(
          initialSelected: [
            SelectedContact(
              displayName: _member.name,
              address: address,
            ),
          ],
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open chat composer: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_member.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: _member.canContact ? _startChat : null,
            tooltip: 'Start Chat',
          ),
        ],
      ),
      body: !_crmReady
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'CRM Supabase is not configured. View only mode.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : () {
              final phoneDisplay = _cleanText(_member.phone);
              final phoneE164 = _cleanText(_member.phoneE164);
              final primaryPhone = phoneDisplay ?? phoneE164;
              final phoneCopyValue = phoneE164 ?? phoneDisplay;
              final email = _cleanText(_member.email);
              final address = _cleanText(_member.address);
              final county = _cleanText(_member.county);
              final districtLabel = _formatDistrict(_member.congressionalDistrict);
              final committees = (_member.committee != null && _member.committee!.isNotEmpty)
                  ? _member.committeesString
                  : null;
              final notesValue = _cleanText(_member.notes);
              final chapterStatus = _cleanText(_member.currentChapterMember);
              final chapterName = _cleanText(_member.chapterName);
              final graduationYear = _cleanText(_member.graduationYear);

              final sections = <Widget?>[
                _buildOptionalSection('Contact Information', [
                  _copyRow('Phone', primaryPhone, copyValue: phoneCopyValue),
                  _copyRow('Email', email),
                  _infoRowOrNull('Address', address),
                ]),
                _buildOptionalSection('Chapter Involvement', [
                  _infoRowOrNull('Current Chapter Member', chapterStatus),
                  _infoRowOrNull('Chapter Name', chapterName),
                  _infoRowOrNull('Graduation Year', graduationYear),
                ]),
                _buildOptionalSection('Social Profiles', [
                  _socialRow(_SocialPlatform.instagram, 'Instagram', _member.instagram),
                  _socialRow(_SocialPlatform.tiktok, 'TikTok', _member.tiktok),
                  _socialRow(_SocialPlatform.x, 'X (Twitter)', _member.x),
                ]),
                _buildOptionalSection('Political & Civic', [
                  _infoRowOrNull('County', county),
                  if (districtLabel != null) _buildInfoRow('Congressional District', districtLabel),
                  if (committees != null) _buildInfoRow('Committees', committees),
                  if (_member.registeredVoter != null)
                    _buildInfoRow('Registered Voter', _member.registeredVoter! ? 'Yes' : 'No'),
                  _infoRowOrNull('Political Experience', _member.politicalExperience),
                  _infoRowOrNull('Current Involvement', _member.currentInvolvement),
                ]),
                _buildOptionalSection('Education & Employment', [
                  _infoRowOrNull('Education Level', _member.educationLevel),
                  _infoRowOrNull('In School', _member.inSchool),
                  _infoRowOrNull('School Name', _member.schoolName),
                  _infoRowOrNull('Employed', _member.employed),
                  _infoRowOrNull('Industry', _member.industry),
                  _infoRowOrNull('Leadership Experience', _member.leadershipExperience),
                ]),
                _buildOptionalSection('Personal Details', [
                  if (_member.dateOfBirth != null)
                    _buildInfoRow('Date of Birth', _formatDateOnly(_member.dateOfBirth!)),
                  if (_member.age != null)
                    _buildInfoRow('Age', '${_member.age} years old'),
                  _infoRowOrNull('Pronouns', _member.preferredPronouns),
                  _infoRowOrNull('Gender Identity', _member.genderIdentity),
                  _infoRowOrNull('Race', _member.race),
                  _infoRowOrNull('Sexual Orientation', _member.sexualOrientation),
                  if (_member.hispanicLatino != null)
                    _buildInfoRow('Hispanic/Latino', _member.hispanicLatino! ? 'Yes' : 'No'),
                  _infoRowOrNull('Languages', _member.languages),
                  _infoRowOrNull('Community Type', _member.communityType),
                  _infoRowOrNull('Disability', _member.disability),
                  _infoRowOrNull('Religion', _member.religion),
                  _infoRowOrNull('Zodiac Sign', _member.zodiacSign),
                ]),
                _buildOptionalSection('Engagement & Interests', [
                  _infoRowOrNull('Desire to Lead', _member.desireToLead),
                  _infoRowOrNull('Hours per Week', _member.hoursPerWeek),
                  _infoRowOrNull('Why Join', _member.whyJoin),
                  _infoRowOrNull('Goals & Ambitions', _member.goalsAndAmbitions),
                  _infoRowOrNull('Qualified Experience', _member.qualifiedExperience),
                  _infoRowOrNull('Referral Source', _member.referralSource),
                  _infoRowOrNull('Passionate Issues', _member.passionateIssues),
                  _infoRowOrNull('Why Issues Matter', _member.whyIssuesMatter),
                  _infoRowOrNull('Areas of Interest', _member.areasOfInterest),
                  _infoRowOrNull('Accommodations', _member.accommodations),
                ]),
              ].whereType<Widget>().toList();

              final metadataSection = _buildOptionalSection('CRM Metadata', [
                _copyRow('Member ID', _member.id),
                if (_member.lastContacted != null)
                  _buildInfoRow('Last Contacted', _formatDate(_member.lastContacted!)),
                if (_member.introSentAt != null)
                  _buildInfoRow('Intro Sent', _formatDate(_member.introSentAt!)),
                if (_member.dateJoined != null)
                  _buildInfoRow('Date Joined', _formatDate(_member.dateJoined!)),
                if (_member.createdAt != null)
                  _buildInfoRow('Added to System', _formatDate(_member.createdAt!)),
                _infoRowOrNull('Opt-Out Reason', _member.optOutReason),
                if (_member.optOutDate != null)
                  _buildInfoRow('Opt-Out Date', _formatDateOnly(_member.optOutDate!)),
                if (_member.optInDate != null)
                  _buildInfoRow('Opt-In Date', _formatDateOnly(_member.optInDate!)),
              ]);

              final notesChildren = <Widget>[];
              if (!_editingNotes && notesValue == null) {
                notesChildren.add(TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add notes'),
                  onPressed: () => setState(() => _editingNotes = true),
                ));
              }
              if (!_editingNotes && notesValue != null) {
                notesChildren.add(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notesValue),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () => setState(() => _editingNotes = true),
                    ),
                  ],
                ));
              }
              if (_editingNotes) {
                notesChildren.add(Column(
                  children: [
                    TextField(
                      controller: _notesController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Add notes about this member...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _notesController.text = _member.notes ?? '';
                            setState(() => _editingNotes = false);
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveNotes,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ));
              }
              final notesSection =
                  notesChildren.isEmpty ? null : _buildSection('Notes', notesChildren);

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      child: Text(
                        _member.name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _member.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_member.optOut)
                    const Center(
                      child: Chip(
                        label: Text('OPTED OUT'),
                        backgroundColor: Colors.red,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                    ),
                  const SizedBox(height: 24),
                  ...sections,
                  if (notesSection != null) notesSection,
                  if (metadataSection != null) metadataSection,
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: Icon(_member.optOut ? Icons.check_circle : Icons.block),
                    label: Text(_member.optOut ? 'Opt In' : 'Opt Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _member.optOut ? Colors.green : Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _crmReady ? _toggleOptOut : null,
                  ),
                ],
              );
            }(),
    );
  }

  String? _cleanText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _hasText(String? value) => _cleanText(value) != null;

  String? _formatDistrict(String? value) => Member.formatDistrictLabel(value);

  Widget? _infoRowOrNull(String label, String? value, {Widget? trailing, Uri? link}) {
    final cleaned = _cleanText(value);
    if (cleaned == null) return null;
    return _buildInfoRow(label, cleaned, trailing: trailing, link: link);
  }

  Widget? _copyRow(String label, String? value, {String? copyValue, Uri? link}) {
    final cleaned = _cleanText(value);
    if (cleaned == null) return null;

    final toCopy = _cleanText(copyValue) ?? cleaned;
    final actions = <Widget>[
      IconButton(
        icon: const Icon(Icons.copy, size: 20),
        tooltip: 'Copy $label',
        onPressed: () {
          Clipboard.setData(ClipboardData(text: toCopy));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label copied')),
          );
        },
      ),
      if (link != null)
        IconButton(
          icon: const Icon(Icons.open_in_new, size: 20),
          tooltip: 'Open $label',
          onPressed: () => _openLink(link),
        ),
    ];

    return _buildInfoRow(
      label,
      cleaned,
      trailing: actions.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: actions,
            ),
      link: link,
    );
  }

  Widget? _socialRow(_SocialPlatform platform, String label, String? value) {
    final cleaned = _cleanText(value);
    if (cleaned == null) return null;

    final uri = _resolveSocialLink(platform, cleaned);
    final display = _formatSocialDisplay(platform, cleaned, uri);
    final copyTarget = uri?.toString() ?? cleaned;

    return _copyRow(label, display, copyValue: copyTarget, link: uri);
  }

  Widget? _buildOptionalSection(String title, Iterable<Widget?> rows) {
    final visible = rows.whereType<Widget>().toList();
    if (visible.isEmpty) return null;
    return _buildSection(title, visible);
  }

  Widget _buildSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing, Uri? link}) {
    final theme = Theme.of(context);
    final valueWidget = link != null
        ? InkWell(
            onTap: () => _openLink(link),
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          )
        : Text(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(child: valueWidget),
                if (trailing != null) ...[
                  const SizedBox(width: 4),
                  Flexible(child: trailing),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Uri? _resolveSocialLink(_SocialPlatform platform, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    Uri? parseUrl(String input) {
      final candidate = input.startsWith('http://') || input.startsWith('https://')
          ? input
          : 'https://$input';
      final uri = Uri.tryParse(candidate);
      if (uri == null || uri.host.isEmpty) return null;
      return uri;
    }

    final lower = trimmed.toLowerCase();
    const knownDomains = [
      'instagram.com',
      'www.instagram.com',
      'tiktok.com',
      'www.tiktok.com',
      'twitter.com',
      'www.twitter.com',
      'x.com',
      'www.x.com',
    ];

    if (lower.startsWith('http://') || lower.startsWith('https://') ||
        knownDomains.any((domain) => lower.contains(domain))) {
      return parseUrl(trimmed);
    }

    final username = trimmed.replaceFirst(RegExp(r'^@+'), '');
    if (username.isEmpty) return null;

    switch (platform) {
      case _SocialPlatform.instagram:
        return Uri.https('instagram.com', '/$username');
      case _SocialPlatform.tiktok:
        return Uri.https('www.tiktok.com', '/@$username');
      case _SocialPlatform.x:
        return Uri.https('x.com', '/$username');
    }
  }

  String _formatSocialDisplay(_SocialPlatform _platform, String raw, Uri? link) {
    final trimmed = raw.trim();

    if (link != null) {
      final segments = link.pathSegments.where((segment) => segment.isNotEmpty).toList();
      if (segments.isNotEmpty) {
        final last = segments.last;
        final normalized = last.replaceFirst(RegExp(r'^@+'), '');
        if (normalized.isNotEmpty) {
          return '@$normalized';
        }
      }

      final host = link.host.replaceFirst(RegExp(r'^www\.'), '');
      final path = link.pathSegments.where((segment) => segment.isNotEmpty).join('/');
      if (path.isNotEmpty) {
        return '$host/$path';
      }
      return host;
    }

    final username = trimmed.replaceFirst(RegExp(r'^@+'), '');
    if (username.isEmpty) return trimmed;
    return '@$username';
  }

  Future<void> _openLink(Uri url) async {
    final success = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${url.toString()}')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  String _formatDateOnly(DateTime date) => '${date.month}/${date.day}/${date.year}';
}
