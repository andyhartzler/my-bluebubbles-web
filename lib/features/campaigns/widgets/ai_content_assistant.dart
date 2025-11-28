import 'package:flutter/material.dart';

/// AI Content Assistant - Premium wow factor feature
/// Provides smart content suggestions, templates, and optimization tips
class AIContentAssistant extends StatefulWidget {
  final Function(String content) onContentGenerated;
  final String? campaignName;
  final String? subject;

  const AIContentAssistant({
    super.key,
    required this.onContentGenerated,
    this.campaignName,
    this.subject,
  });

  @override
  State<AIContentAssistant> createState() => _AIContentAssistantState();
}

class _AIContentAssistantState extends State<AIContentAssistant> {
  String _selectedCategory = 'fundraising';
  String _tone = 'professional';
  bool _generating = false;

  final Map<String, List<Map<String, dynamic>>> _templates = {
    'fundraising': [
      {
        'name': 'End-of-Quarter Fundraising',
        'description': 'Urgent call to action for quarterly fundraising deadline',
        'preview': 'Help us reach our Q4 goal! Only 3 days left...',
        'content': _fundraisingTemplate,
      },
      {
        'name': 'Grassroots Donation Ask',
        'description': 'Personal appeal for small-dollar donations',
        'preview': 'Our movement is powered by people like you...',
        'content': _grassrootsTemplate,
      },
      {
        'name': 'Impact Report + Ask',
        'description': 'Show impact first, then ask for continued support',
        'preview': 'Here\'s what we accomplished together this month...',
        'content': _impactReportTemplate,
      },
    ],
    'event': [
      {
        'name': 'Event Invitation',
        'description': 'Formal invitation to upcoming event',
        'preview': 'You\'re invited! Join us for...',
        'content': _eventInvitationTemplate,
      },
      {
        'name': 'Event Reminder (1 Week)',
        'description': 'Reminder email one week before event',
        'preview': 'Don\'t forget! Our event is next week...',
        'content': _eventReminderTemplate,
      },
      {
        'name': 'Event Follow-up Thank You',
        'description': 'Thank attendees and share next steps',
        'preview': 'Thank you for joining us! Here\'s what\'s next...',
        'content': _eventThankYouTemplate,
      },
    ],
    'newsletter': [
      {
        'name': 'Monthly Update',
        'description': 'Comprehensive monthly newsletter',
        'preview': 'Your monthly update from Missouri Young Democrats...',
        'content': _monthlyNewsletterTemplate,
      },
      {
        'name': 'Policy Spotlight',
        'description': 'Deep dive into specific policy issue',
        'preview': 'Policy Spotlight: Understanding the latest...',
        'content': _policySpotlightTemplate,
      },
      {
        'name': 'Action Alert',
        'description': 'Urgent call to action on timely issue',
        'preview': 'Action needed: Contact your representative about...',
        'content': _actionAlertTemplate,
      },
    ],
    'volunteer': [
      {
        'name': 'Volunteer Recruitment',
        'description': 'Recruit new volunteers for campaign',
        'preview': 'We need you! Join our volunteer team...',
        'content': _volunteerRecruitmentTemplate,
      },
      {
        'name': 'Volunteer Appreciation',
        'description': 'Thank volunteers for their efforts',
        'preview': 'Thank you for making a difference...',
        'content': _volunteerAppreciationTemplate,
      },
      {
        'name': 'Phone Banking Invite',
        'description': 'Specific ask for phone banking volunteers',
        'preview': 'Help us reach voters! Join our phone bank...',
        'content': _phoneBankingTemplate,
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3A8A).withOpacity(0.05),
            const Color(0xFF3B82F6).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Content Assistant',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Professional templates powered by campaign expertise',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Category selector
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _templates.keys.map((category) {
              final isSelected = _selectedCategory == category;
              return ChoiceChip(
                label: Text(
                  category[0].toUpperCase() + category.substring(1),
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedCategory = category);
                },
                selectedColor: const Color(0xFF1E3A8A),
                backgroundColor: Colors.white,
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Template list
          Expanded(
            child: ListView.builder(
              itemCount: _templates[_selectedCategory]!.length,
              itemBuilder: (context, index) {
                final template = _templates[_selectedCategory]![index];
                return _TemplateCard(
                  name: template['name'] as String,
                  description: template['description'] as String,
                  preview: template['preview'] as String,
                  onUse: () => _useTemplate(template),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _useTemplate(Map<String, dynamic> template) {
    setState(() => _generating = true);

    // Simulate AI processing
    Future.delayed(const Duration(milliseconds: 800), () {
      final contentFunction = template['content'] as String Function();
      final content = contentFunction();

      widget.onContentGenerated(content);
      setState(() => _generating = false);

      Navigator.pop(context);
    });
  }

  // Template content generators
  static String _fundraisingTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h1 style="color: #1E3A8A; font-size: 32px; margin-bottom: 20px;">We're So Close!</h1>

  <p style="font-size: 16px; line-height: 1.6; color: #333;">
    With just <strong>3 days left</strong> until our Q4 deadline, we're only <span style="color: #1E3A8A; font-weight: bold;">\$2,500 away</span> from our goal.
  </p>

  <p style="font-size: 16px; line-height: 1.6; color: #333;">
    Every dollar you contribute goes directly toward organizing young Democrats across Missouri and building the progressive movement our state needs.
  </p>

  <div style="text-align: center; margin: 30px 0;">
    <a href="https://donate.moyoungdemocrats.org" style="background-color: #1E3A8A; color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; display: inline-block;">Donate Now</a>
  </div>

  <p style="font-size: 14px; line-height: 1.6; color: #666;">
    Even \$5 makes a difference. Together, we're building a better Missouri.
  </p>

  <p style="font-size: 14px; color: #666; margin-top: 30px;">
    In solidarity,<br>
    <strong>The Missouri Young Democrats Team</strong>
  </p>
</div>
''';
  }

  static String _grassrootsTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h2 style="color: #1E3A8A; font-size: 28px;">Our Movement is Powered by People Like You</h2>

  <p style="font-size: 16px; line-height: 1.6; color: #333;">
    We don't take money from corporate PACs. We're funded by grassroots supporters who believe in our mission.
  </p>

  <div style="background-color: #F1F5F9; padding: 20px; border-radius: 12px; margin: 20px 0;">
    <p style="margin: 0; font-size: 14px; color: #666;">Average donation this quarter:</p>
    <p style="margin: 5px 0; font-size: 36px; font-weight: bold; color: #1E3A8A;">\$27</p>
  </div>

  <p style="font-size: 16px; line-height: 1.6; color: #333;">
    Whether you can give \$5, \$25, or \$50 - your contribution shows that real change comes from people, not big money.
  </p>

  <div style="text-align: center; margin: 30px 0;">
    <a href="https://donate.moyoungdemocrats.org" style="background-color: #10B981; color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; display: inline-block;">Chip in \$27</a>
  </div>

  <p style="font-size: 13px; color: #999; text-align: center;">
    Or donate any amount that works for you
  </p>
</div>
''';
  }

  static String _impactReportTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <h1 style="color: #1E3A8A; font-size: 32px; text-align: center;">This Month's Impact</h1>

  <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin: 30px 0;">
    <div style="background: linear-gradient(135deg, #1E3A8A, #3B82F6); padding: 20px; border-radius: 12px; text-align: center; color: white;">
      <div style="font-size: 42px; font-weight: bold;">327</div>
      <div style="font-size: 14px;">New Members</div>
    </div>
    <div style="background: linear-gradient(135deg, #10B981, #34D399); padding: 20px; border-radius: 12px; text-align: center; color: white;">
      <div style="font-size: 42px; font-weight: bold;">12</div>
      <div style="font-size: 14px;">Events Hosted</div>
    </div>
  </div>

  <p style="font-size: 16px; line-height: 1.6; color: #333;">
    Thanks to supporters like you, we're making real progress. But there's still so much more to do.
  </p>

  <p style="font-size: 16px; line-height: 1.6; color: #333;">
    <strong>Will you help us keep this momentum going?</strong>
  </p>

  <div style="text-align: center; margin: 30px 0;">
    <a href="https://donate.moyoungdemocrats.org" style="background-color: #1E3A8A; color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; display: inline-block;">Continue Our Work</a>
  </div>
</div>
''';
  }

  static String _eventInvitationTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background: linear-gradient(135deg, #1E3A8A, #3B82F6); padding: 40px; text-align: center; color: white; border-radius: 16px 16px 0 0;">
    <h1 style="margin: 0; font-size: 36px;">You're Invited!</h1>
  </div>

  <div style="padding: 30px; background: white;">
    <h2 style="color: #1E3A8A; font-size: 24px;">Missouri Young Democrats Monthly Meeting</h2>

    <div style="background: #F1F5F9; padding: 20px; border-radius: 12px; margin: 20px 0;">
      <p style="margin: 8px 0;"><strong>📅 When:</strong> Saturday, December 15th at 2:00 PM</p>
      <p style="margin: 8px 0;"><strong>📍 Where:</strong> Virtual (Zoom link will be sent)</p>
      <p style="margin: 8px 0;"><strong>⏰ Duration:</strong> 1.5 hours</p>
    </div>

    <p style="font-size: 16px; line-height: 1.6; color: #333;">
      Join us for our monthly meeting where we'll discuss upcoming initiatives, hear from special guests, and plan our strategy for the new year.
    </p>

    <div style="text-align: center; margin: 30px 0;">
      <a href="https://events.moyoungdemocrats.org/rsvp" style="background-color: #10B981; color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; display: inline-block;">RSVP Now</a>
    </div>

    <p style="font-size: 14px; color: #666; text-align: center;">
      Can't make it? We'll send a recording to all registered attendees.
    </p>
  </div>
</div>
''';
  }

  static String _eventReminderTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: #FEF3C7; border-left: 4px solid #F59E0B; padding: 16px; margin-bottom: 20px;">
    <strong style="color: #92400E;">Reminder: Event in 7 days!</strong>
  </div>

  <h2 style="color: #1E3A8A;">Don't Forget: Our Event is Next Week</h2>

  <p style="font-size: 16px; line-height: 1.6; color: #333;">
    This is your reminder that our event is coming up soon! We can't wait to see you there.
  </p>

  <div style="background: #1E3A8A; color: white; padding: 24px; border-radius: 12px; margin: 20px 0;">
    <h3 style="margin: 0 0 16px 0;">Event Details</h3>
    <p style="margin: 8px 0;">📅 Saturday, December 15th at 2:00 PM</p>
    <p style="margin: 8px 0;">📍 Virtual Event (Zoom)</p>
    <p style="margin: 8px 0;">✅ You're registered!</p>
  </div>

  <div style="text-align: center; margin: 30px 0;">
    <a href="https://events.moyoungdemocrats.org/join" style="background-color: #10B981; color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; display: inline-block;">Add to Calendar</a>
  </div>
</div>
''';
  }

  static String _eventThankYouTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="color: #1E3A8A; font-size: 32px; text-align: center;">Thank You!</h1>

  <p style="font-size: 18px; line-height: 1.6; color: #333; text-align: center;">
    We're grateful you joined us for yesterday's event.
  </p>

  <div style="background: linear-gradient(135deg, #10B981, #34D399); color: white; padding: 30px; border-radius: 12px; margin: 30px 0; text-align: center;">
    <p style="font-size: 48px; margin: 0;">🎉</p>
    <p style="font-size: 24px; font-weight: bold; margin: 10px 0;">67 Attendees</p>
    <p style="margin: 0;">Together we're building a movement!</p>
  </div>

  <h3 style="color: #1E3A8A;">What's Next?</h3>
  <ul style="font-size: 16px; line-height: 1.8; color: #333;">
    <li>Join our next phone bank on Thursday at 6 PM</li>
    <li>Follow us on social media for updates</li>
    <li>Invite a friend to our next event</li>
  </ul>

  <div style="text-align: center; margin: 30px 0;">
    <a href="https://moyoungdemocrats.org/get-involved" style="background-color: #1E3A8A; color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; display: inline-block;">Stay Involved</a>
  </div>
</div>
''';
  }

  static String _monthlyNewsletterTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background: linear-gradient(135deg, #1E3A8A, #3B82F6); padding: 30px; text-align: center; color: white;">
    <h1 style="margin: 0;">Monthly Update</h1>
    <p style="margin: 10px 0 0 0;">December 2024</p>
  </div>

  <div style="padding: 30px;">
    <h2 style="color: #1E3A8A;">📰 This Month's Highlights</h2>

    <div style="border-left: 4px solid #1E3A8A; padding-left: 16px; margin: 20px 0;">
      <h3 style="color: #1E3A8A; margin: 0 0 8px 0;">New Chapter Launched in Columbia</h3>
      <p style="margin: 0; color: #666;">We're excited to welcome our newest chapter...</p>
    </div>

    <div style="border-left: 4px solid #10B981; padding-left: 16px; margin: 20px 0;">
      <h3 style="color: #10B981; margin: 0 0 8px 0;">Legislative Win: Student Voting Rights</h3>
      <p style="margin: 0; color: #666;">Thanks to our advocacy, new legislation will...</p>
    </div>

    <div style="border-left: 4px solid #3B82F6; padding-left: 16px; margin: 20px 0;">
      <h3 style="color: #3B82F6; margin: 0 0 8px 0;">Upcoming: Annual Summit 2025</h3>
      <p style="margin: 0; color: #666;">Save the date for our biggest event of the year...</p>
    </div>

    <div style="text-align: center; margin: 40px 0 20px 0;">
      <a href="https://moyoungdemocrats.org/newsletter" style="background-color: #1E3A8A; color: white; padding: 14px 32px; text-decoration: none; border-radius: 8px; font-weight: bold; display: inline-block;">Read Full Newsletter</a>
    </div>
  </div>
</div>
''';
  }

  static String _policySpotlightTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: #FEF3C7; padding: 12px 20px; border-radius: 8px; display: inline-block; margin-bottom: 20px;">
    <strong style="color: #92400E;">📚 Policy Spotlight</strong>
  </div>

  <h1 style="color: #1E3A8A; font-size: 32px; margin: 10px 0;">Understanding the Clean Energy Jobs Act</h1>

  <p style="font-size: 16px; line-height: 1.6; color: #333;">
    Missouri has a chance to lead the Midwest in clean energy. Here's what you need to know about the proposed legislation...
  </p>

  <div style="background: #F1F5F9; padding: 20px; border-radius: 12px; margin: 30px 0;">
    <h3 style="color: #1E3A8A; margin-top: 0;">Key Points:</h3>
    <ul style="color: #333; line-height: 1.8;">
      <li>Creates 10,000+ new jobs in renewable energy</li>
      <li>Reduces carbon emissions by 40% by 2030</li>
      <li>Provides training programs for workers transitioning from fossil fuels</li>
      <li>Invests \$500M in rural renewable energy infrastructure</li>
    </ul>
  </div>

  <h3 style="color: #1E3A8A;">Take Action</h3>
  <p style="font-size: 16px; line-height: 1.6; color: #333;">
    Contact your state representative and tell them to support the Clean Energy Jobs Act.
  </p>

  <div style="text-align: center; margin: 30px 0;">
    <a href="https://action.moyoungdemocrats.org/clean-energy" style="background-color: #10B981; color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; display: inline-block;">Contact Your Rep</a>
  </div>
</div>
''';
  }

  static String _actionAlertTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
  <div style="background: #DC2626; color: white; padding: 16px; text-align: center; font-weight: bold; font-size: 18px;">
    🚨 URGENT ACTION NEEDED 🚨
  </div>

  <div style="padding: 30px;">
    <h1 style="color: #DC2626; font-size: 28px;">Vote Happening This Week: Contact Your Representative NOW</h1>

    <p style="font-size: 16px; line-height: 1.6; color: #333;">
      <strong>The Missouri House is voting on Thursday</strong> on legislation that would restrict access to voting. We need you to contact your representative TODAY.
    </p>

    <div style="background: #FEE2E2; border-left: 4px solid #DC2626; padding: 16px; margin: 20px 0;">
      <p style="margin: 0; color: #991B1B;"><strong>Time is running out!</strong> The vote is in 2 days.</p>
    </div>

    <h3 style="color: #1E3A8A;">How to Take Action:</h3>
    <ol style="font-size: 16px; line-height: 1.8; color: #333;">
      <li>Click the button below to find your representative</li>
      <li>Call their office (we'll provide a script)</li>
      <li>Share this alert with 3 friends</li>
    </ol>

    <div style="text-align: center; margin: 30px 0;">
      <a href="https://action.moyoungdemocrats.org/voting-rights" style="background-color: #DC2626; color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; display: inline-block;">Take Action Now</a>
    </div>

    <p style="font-size: 14px; color: #666; text-align: center;">
      Your voice matters. Make it heard today.
    </p>
  </div>
</div>
''';
  }

  static String _volunteerRecruitmentTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="color: #1E3A8A; font-size: 36px; text-align: center;">We Need You!</h1>

  <p style="font-size: 18px; line-height: 1.6; color: #333; text-align: center;">
    Help us build a better Missouri by joining our volunteer team
  </p>

  <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin: 30px 0;">
    <div style="background: #F1F5F9; padding: 20px; border-radius: 12px; text-align: center;">
      <div style="font-size: 36px; margin-bottom: 10px;">📱</div>
      <h3 style="color: #1E3A8A; margin: 0;">Phone Banking</h3>
      <p style="color: #666; font-size: 14px; margin: 10px 0;">Call voters from home</p>
    </div>
    <div style="background: #F1F5F9; padding: 20px; border-radius: 12px; text-align: center;">
      <div style="font-size: 36px; margin-bottom: 10px;">🚪</div>
      <h3 style="color: #1E3A8A; margin: 0;">Canvassing</h3>
      <p style="color: #666; font-size: 14px; margin: 10px 0;">Talk to voters door-to-door</p>
    </div>
    <div style="background: #F1F5F9; padding: 20px; border-radius: 12px; text-align: center;">
      <div style="font-size: 36px; margin-bottom: 10px;">📊</div>
      <h3 style="color: #1E3A8A; margin: 0;">Data Entry</h3>
      <p style="color: #666; font-size: 14px; margin: 10px 0;">Help us track our progress</p>
    </div>
    <div style="background: #F1F5F9; padding: 20px; border-radius: 12px; text-align: center;">
      <div style="font-size: 36px; margin-bottom: 10px;">🎨</div>
      <h3 style="color: #1E3A8A; margin: 0;">Social Media</h3>
      <p style="color: #666; font-size: 14px; margin: 10px 0;">Create content and engage</p>
    </div>
  </div>

  <p style="font-size: 16px; line-height: 1.6; color: #333; text-align: center;">
    <strong>No experience necessary!</strong> We'll provide training and support.
  </p>

  <div style="text-align: center; margin: 30px 0;">
    <a href="https://volunteer.moyoungdemocrats.org" style="background-color: #10B981; color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; display: inline-block;">Sign Up to Volunteer</a>
  </div>
</div>
''';
  }

  static String _volunteerAppreciationTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="text-align: center; margin-bottom: 30px;">
    <div style="font-size: 80px; margin: 0;">🌟</div>
    <h1 style="color: #1E3A8A; font-size: 36px; margin: 10px 0;">Thank You!</h1>
  </div>

  <p style="font-size: 18px; line-height: 1.6; color: #333;">
    We wanted to take a moment to recognize your incredible dedication to our cause.
  </p>

  <div style="background: linear-gradient(135deg, #1E3A8A, #3B82F6); color: white; padding: 30px; border-radius: 16px; margin: 30px 0; text-align: center;">
    <h2 style="margin: 0 0 20px 0;">Your Impact This Month:</h2>
    <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20px;">
      <div>
        <div style="font-size: 32px; font-weight: bold;">45</div>
        <div style="font-size: 14px; opacity: 0.9;">Calls Made</div>
      </div>
      <div>
        <div style="font-size: 32px; font-weight: bold;">8</div>
        <div style="font-size: 14px; opacity: 0.9;">Hours Volunteered</div>
      </div>
      <div>
        <div style="font-size: 32px; font-weight: bold;">12</div>
        <div style="font-size: 14px; opacity: 0.9;">Events Attended</div>
      </div>
    </div>
  </div>

  <p style="font-size: 16px; line-height: 1.6; color: #333;">
    Volunteers like you are the heart of our movement. Every call you make, every door you knock, every conversation you have - it all makes a difference.
  </p>

  <p style="font-size: 16px; line-height: 1.6; color: #333; font-weight: bold;">
    Thank you for being part of our team. Together, we're building a better Missouri.
  </p>

  <div style="text-align: center; margin: 30px 0;">
    <a href="https://volunteer.moyoungdemocrats.org/events" style="background-color: #1E3A8A; color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; display: inline-block;">See Upcoming Events</a>
  </div>
</div>
''';
  }

  static String _phoneBankingTemplate() {
    return '''
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #1E3A8A, #3B82F6); color: white; padding: 30px; border-radius: 16px; text-align: center;">
    <div style="font-size: 60px; margin-bottom: 10px;">📱</div>
    <h1 style="margin: 0; font-size: 32px;">Join Our Phone Bank!</h1>
  </div>

  <div style="margin: 30px 0;">
    <h2 style="color: #1E3A8A;">Help us reach voters from the comfort of your home</h2>

    <p style="font-size: 16px; line-height: 1.6; color: #333;">
      We're hosting a virtual phone bank this <strong>Thursday at 6:00 PM</strong> and we'd love to have you join us!
    </p>

    <div style="background: #F1F5F9; padding: 20px; border-radius: 12px; margin: 20px 0;">
      <h3 style="color: #1E3A8A; margin-top: 0;">What You'll Need:</h3>
      <ul style="color: #333; line-height: 1.8; margin: 0;">
        <li>A phone or computer</li>
        <li>1-2 hours of your time</li>
        <li>A quiet space to make calls</li>
        <li>A passion for making a difference!</li>
      </ul>
    </div>

    <div style="background: #DBEAFE; border-left: 4px solid #3B82F6; padding: 16px; margin: 20px 0;">
      <p style="margin: 0; color: #1E3A8A;"><strong>Never phone banked before?</strong> No problem! We'll provide training and a script.</p>
    </div>

    <h3 style="color: #1E3A8A;">Why Phone Banking Matters:</h3>
    <p style="font-size: 16px; line-height: 1.6; color: #333;">
      Personal phone calls are one of the most effective ways to reach voters. Your conversations help us understand what issues matter most to Missourians and get people engaged in our movement.
    </p>

    <div style="text-align: center; margin: 30px 0;">
      <a href="https://phonebank.moyoungdemocrats.org/signup" style="background-color: #10B981; color: white; padding: 16px 40px; text-decoration: none; border-radius: 8px; font-weight: bold; font-size: 18px; display: inline-block;">Sign Up for Thursday</a>
    </div>

    <p style="font-size: 14px; color: #666; text-align: center;">
      Can't make it Thursday? We host phone banks weekly!
    </p>
  </div>
</div>
''';
  }
}

class _TemplateCard extends StatefulWidget {
  final String name;
  final String description;
  final String preview;
  final VoidCallback onUse;

  const _TemplateCard({
    required this.name,
    required this.description,
    required this.preview,
    required this.onUse,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        elevation: _isHovered ? 4 : 1,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _isHovered ? const Color(0xFF1E3A8A) : Colors.grey[300]!,
            width: _isHovered ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: widget.onUse,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isHovered ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.preview,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isHovered ? const Color(0xFF1E3A8A) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    color: _isHovered ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
