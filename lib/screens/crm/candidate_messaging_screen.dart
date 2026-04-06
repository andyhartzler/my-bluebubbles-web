import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/services/crm/crm_email_service.dart';
import 'package:bluebubbles/config/crm_config.dart';

// ═══════════════════════════════════════════════════════════════
//  CANDIDATE MESSAGING SCREEN
//  Compose and send emails/messages to candidates with
//  pre-filled templates, CC/BCC support, and auto-logging
//  to the candidate_contacts table.
// ═══════════════════════════════════════════════════════════════

class CandidateMessagingScreen extends StatefulWidget {
  final Candidate candidate;
  final List<Candidate>? additionalRecipients;
  final String? preSelectedTemplate;

  const CandidateMessagingScreen({
    super.key,
    required this.candidate,
    this.additionalRecipients,
    this.preSelectedTemplate,
  });

  @override
  State<CandidateMessagingScreen> createState() =>
      _CandidateMessagingScreenState();
}

class _CandidateMessagingScreenState extends State<CandidateMessagingScreen>
    with SingleTickerProviderStateMixin {
  final CandidateRepository _repo = CandidateRepository();
  final CRMEmailService _emailService = CRMEmailService.instance;

  final TextEditingController _toController = TextEditingController();
  final TextEditingController _ccController = TextEditingController();
  final TextEditingController _bccController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  late TabController _tabController;
  late String _selectedFromEmail;
  String? _selectedTemplate;
  bool _showCcBcc = false;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  // Templates
  static const _templates = {
    'moyd_introduction': _EmailTemplate(
      name: 'MOYD Introduction',
      icon: Icons.handshake,
      subject: 'Missouri Young Democrats — Introduction & Support',
      body: '''Dear {{candidate_name}},

Congratulations on your candidacy for {{office}}! I'm reaching out on behalf of the Missouri Young Democrats (MOYD).

We're a statewide organization dedicated to electing young, progressive leaders across Missouri. We've been following your campaign and are excited about your commitment to our community.

We'd love to schedule a brief call to discuss:
• How MOYD can support your campaign
• Upcoming endorsement opportunities
• Access to our volunteer network and digital resources

Please let us know a time that works for you. We look forward to connecting!

Best regards,
Missouri Young Democrats
www.moyoungdemocrats.org''',
    ),
    'endorsement_inquiry': _EmailTemplate(
      name: 'Endorsement Inquiry',
      icon: Icons.thumb_up,
      subject: 'MOYD Endorsement Process — {{candidate_name}}',
      body: '''Dear {{candidate_name}},

Thank you for running for {{office}}. The Missouri Young Democrats endorsement committee is reviewing candidates for the upcoming cycle.

We're reaching out to invite you to participate in our endorsement process. This involves:

1. **Questionnaire** — A brief survey about your platform and priorities
2. **Interview** — A 20-minute conversation with our Political Affairs Committee
3. **Vote** — Our membership votes on endorsements at our next meeting

Endorsed candidates receive:
✓ Social media promotion to our 5,000+ followers
✓ Volunteer mobilization support
✓ Campaign strategy consultation
✓ Inclusion in our voter guide

Would you be interested in pursuing a MOYD endorsement? Please reply to this email or reach out at your earliest convenience.

Sincerely,
Political Affairs Committee
Missouri Young Democrats''',
    ),
    'event_invitation': _EmailTemplate(
      name: 'Event Invitation',
      icon: Icons.event,
      subject: 'You\'re Invited — MOYD Candidate Forum',
      body: '''Dear {{candidate_name}},

The Missouri Young Democrats invites you to participate in our upcoming Candidate Forum.

**Event Details:**
📅 Date: [TBD]
🕐 Time: [TBD]
📍 Location: [TBD]
💻 Virtual Option: Zoom link will be provided

This is an opportunity to:
• Share your vision with young voters
• Answer questions from our membership
• Network with other candidates and party leaders

Each candidate will have 5 minutes for opening remarks followed by a Q&A session.

Please RSVP by replying to this email by [deadline].

We look forward to hearing from you!

Best,
Missouri Young Democrats Events Team''',
    ),
    'follow_up': _EmailTemplate(
      name: 'Follow-Up',
      icon: Icons.replay,
      subject: 'Following Up — Missouri Young Democrats',
      body: '''Dear {{candidate_name}},

I hope this message finds you well. I wanted to follow up on our previous conversation about MOYD's support for your {{office}} campaign.

We remain excited about your candidacy and want to make sure we're doing everything we can to help.

Is there anything specific you need from us right now? Whether it's volunteers, digital strategy support, or just a sounding board — we're here.

Looking forward to hearing from you.

Best regards,
Missouri Young Democrats''',
    ),
    'congratulations': _EmailTemplate(
      name: 'Congratulations',
      icon: Icons.celebration,
      subject: 'Congratulations on Your Victory!',
      body: '''Dear {{candidate_name}},

On behalf of the Missouri Young Democrats, congratulations on your victory!

We're thrilled to see you elected and look forward to working with you to advance progressive priorities in Missouri.

Please don't hesitate to reach out if there's anything MOYD can do to support you in your new role.

Best wishes,
Missouri Young Democrats''',
    ),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize from email
    final senders = CRMConfig.allowedSenderEmails;
    _selectedFromEmail = senders.contains(CRMConfig.defaultSenderEmail)
        ? CRMConfig.defaultSenderEmail
        : senders.isNotEmpty
            ? senders.first
            : 'info@moyoungdemocrats.org';

    // Set recipient
    _toController.text = widget.candidate.email ?? '';

    // Add additional recipients
    if (widget.additionalRecipients != null) {
      final additionalEmails = widget.additionalRecipients!
          .where((c) => c.email != null && c.email!.isNotEmpty)
          .map((c) => c.email!)
          .join(', ');
      if (additionalEmails.isNotEmpty) {
        if (_toController.text.isNotEmpty) {
          _toController.text += ', $additionalEmails';
        } else {
          _toController.text = additionalEmails;
        }
      }
    }

    // Apply pre-selected template
    if (widget.preSelectedTemplate != null) {
      _applyTemplate(widget.preSelectedTemplate!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _toController.dispose();
    _ccController.dispose();
    _bccController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _applyTemplate(String templateKey) {
    final template = _templates[templateKey];
    if (template == null) return;

    final c = widget.candidate;
    String subject = template.subject
        .replaceAll('{{candidate_name}}', c.name)
        .replaceAll('{{office}}', c.officeDisplay);
    String body = template.body
        .replaceAll('{{candidate_name}}', c.firstName)
        .replaceAll('{{office}}', c.officeDisplay)
        .replaceAll('{{district}}', c.district ?? '')
        .replaceAll('{{party}}', c.party);

    setState(() {
      _selectedTemplate = templateKey;
      _subjectController.text = subject;
      _bodyController.text = body;
    });
  }

  Future<void> _sendEmail() async {
    if (_toController.text.isEmpty) {
      setState(() => _error = 'Recipient email is required');
      return;
    }
    if (_subjectController.text.isEmpty) {
      setState(() => _error = 'Subject is required');
      return;
    }
    if (_bodyController.text.isEmpty) {
      setState(() => _error = 'Message body is required');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    CandidateContact? contact;
    try {
      // Log the contact BEFORE sending so the attempt is captured even if
      // the send fails (prevents lost contact records).
      contact = await _repo.addContact({
        'candidate_id': widget.candidate.id,
        'contact_type': 'email',
        'subject': _subjectController.text,
        'body': _bodyController.text,
        'contacted_by': _selectedFromEmail,
        'contact_date': DateTime.now().toIso8601String(),
        'outcome': 'pending',
      });

      // Send via Gmail API
      await _emailService.sendEmail(
        fromEmail: _selectedFromEmail,
        to: _toController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        cc: _ccController.text.isNotEmpty
            ? _ccController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : null,
        bcc: _bccController.text.isNotEmpty
            ? _bccController.text
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : null,
        subject: _subjectController.text,
        textBody: _bodyController.text,
      );

      // Mark contact as successfully sent
      if (contact != null) {
        _repo.updateContactOutcome(contact.id, 'sent');
      }

      setState(() {
        _sending = false;
        _sent = true;
      });

      // Show success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Email sent successfully!'),
              ],
            ),
            backgroundColor: BrandColors.success,
            duration: const Duration(seconds: 3),
          ),
        );

        // Pop after a brief delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    } catch (e) {
      // Update contact log to reflect failure (contact was already logged as 'pending')
      if (contact != null) {
        _repo.updateContactOutcome(contact.id, 'failed');
      }
      setState(() {
        _sending = false;
        _error = 'Failed to send: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B1E37), BrandColors.unityBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildTabs(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildComposeTab(),
                    _buildTemplatesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message ${widget.candidate.firstName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.candidate.officeDisplay,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: _sent
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: BrandColors.success,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text('Sent!',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _sending ? null : _sendEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BrandColors.sunriseGold,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    label: Text(_sending ? 'Sending…' : 'Send'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: BrandColors.sunriseGold.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: BrandColors.sunriseGold,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Compose'),
          Tab(text: 'Templates'),
        ],
      ),
    );
  }

  Widget _buildComposeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error banner
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BrandColors.republicanRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: BrandColors.republicanRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: BrandColors.republicanRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: BrandColors.republicanRed, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // From selector
          _buildField(
            'From',
            child: DropdownButtonFormField<String>(
              value: _selectedFromEmail,
              dropdownColor: BrandColors.unityBlue,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _fieldDecoration('Select sender'),
              items: CRMConfig.allowedSenderEmails
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedFromEmail = v);
              },
            ),
          ),

          // To field
          _buildField(
            'To',
            trailing: !_showCcBcc
                ? GestureDetector(
                    onTap: () => setState(() => _showCcBcc = true),
                    child: const Text(
                      'CC/BCC',
                      style: TextStyle(
                        color: BrandColors.sunriseGold,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : null,
            child: TextField(
              controller: _toController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _fieldDecoration(
                widget.candidate.email ?? 'Enter email address…',
              ),
            ),
          ),

          // CC/BCC fields
          if (_showCcBcc) ...[
            _buildField(
              'CC',
              child: TextField(
                controller: _ccController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _fieldDecoration('CC recipients…'),
              ),
            ),
            _buildField(
              'BCC',
              child: TextField(
                controller: _bccController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _fieldDecoration('BCC recipients…'),
              ),
            ),
          ],

          // Subject
          _buildField(
            'Subject',
            child: TextField(
              controller: _subjectController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _fieldDecoration('Email subject…'),
            ),
          ),

          // Selected template badge
          if (_selectedTemplate != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: BrandColors.sunriseGold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _templates[_selectedTemplate]?.icon ?? Icons.description,
                      color: BrandColors.sunriseGold,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Template: ${_templates[_selectedTemplate]?.name ?? ''}',
                      style: const TextStyle(
                        color: BrandColors.sunriseGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedTemplate = null;
                        _subjectController.clear();
                        _bodyController.clear();
                      }),
                      child: const Icon(Icons.close,
                          color: BrandColors.sunriseGold, size: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Body
          Container(
            constraints: const BoxConstraints(minHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _bodyController,
              maxLines: null,
              minLines: 12,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Write your message…',
                hintStyle: const TextStyle(color: Colors.white30),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick actions
          Row(
            children: [
              _quickAction(Icons.attach_file, 'Attach', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('File attachments are not yet supported'),
                    backgroundColor: BrandColors.momentumBlue,
                  ),
                );
              }),
              const SizedBox(width: 8),
              _quickAction(Icons.schedule, 'Schedule', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Scheduled sending is not yet supported'),
                    backgroundColor: BrandColors.momentumBlue,
                  ),
                );
              }),
            ],
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Choose a template to get started quickly.',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 16),
        ..._templates.entries.map((entry) {
          final key = entry.key;
          final template = entry.value;
          final isSelected = _selectedTemplate == key;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [
                        BrandColors.sunriseGold.withOpacity(0.15),
                        BrandColors.sunriseGold.withOpacity(0.05),
                      ]
                    : [
                        Colors.white.withOpacity(0.06),
                        Colors.white.withOpacity(0.03),
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? BrandColors.sunriseGold.withOpacity(0.4)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: InkWell(
              onTap: () {
                _applyTemplate(key);
                _tabController.animateTo(0);
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: BrandColors.sunriseGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        template.icon,
                        color: BrandColors.sunriseGold,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            template.subject
                                .replaceAll('{{candidate_name}}',
                                    widget.candidate.name)
                                .replaceAll('{{office}}',
                                    widget.candidate.officeDisplay),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: BrandColors.sunriseGold, size: 22)
                    else
                      const Icon(Icons.chevron_right,
                          color: Colors.white30, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildField(String label, {required Widget child, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white30),
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
            color: BrandColors.sunriseGold.withOpacity(0.4)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailTemplate {
  final String name;
  final IconData icon;
  final String subject;
  final String body;

  const _EmailTemplate({
    required this.name,
    required this.icon,
    required this.subject,
    required this.body,
  });
}
