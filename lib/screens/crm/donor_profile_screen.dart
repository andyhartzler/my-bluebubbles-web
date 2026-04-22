import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/donor_enrichment_record.dart';
import 'package:bluebubbles/models/crm/donor_profile.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';
import 'package:bluebubbles/screens/crm/voter_file/donor_enrichment_card.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_file_card.dart';
import 'package:bluebubbles/services/crm/donor_profile_repository.dart';

class DonorProfileScreen extends StatefulWidget {
  final String profileId;

  const DonorProfileScreen({super.key, required this.profileId});

  @override
  State<DonorProfileScreen> createState() => _DonorProfileScreenState();
}

class _DonorProfileScreenState extends State<DonorProfileScreen>
    with SingleTickerProviderStateMixin {
  final DonorProfileRepository _repository = DonorProfileRepository();
  DonorProfile? _profile;
  VoterFileRecord? _voterRecord;
  DonorEnrichmentRecord? _enrichmentRecord;
  bool _loading = true;
  String? _error;
  late TabController _tabController;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _callNotesController = TextEditingController();

  static final _currencyWhole =
      NumberFormat.currency(symbol: '\$', decimalDigits: 0);
  static final _currencyFull = NumberFormat.currency(symbol: '\$');
  static final _dateFmt = DateFormat.yMMMd();
  static final _dateTimeFmt = DateFormat.yMMMd().add_jm();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    _callNotesController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data helpers
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch the main profile first so the screen can render promptly,
      // then kick off the voter-file + enrichment lookups in parallel.
      final profile = await _repository.getFullProfile(widget.profileId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
        if (profile == null) _error = 'Profile not found';
      });

      if (profile != null) {
        final results = await Future.wait([
          _repository.fetchVoterRecordForProfile(widget.profileId),
          _repository.fetchEnrichmentRecordByProfileUuid(widget.profileId),
        ]);
        if (!mounted) return;
        setState(() {
          _voterRecord = results[0] as VoterFileRecord?;
          _enrichmentRecord = results[1] as DonorEnrichmentRecord?;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _logCallOutcome(String outcome) async {
    double? pledgeAmount;
    if (outcome == 'Pledge') {
      pledgeAmount = await _showPledgeDialog();
      if (pledgeAmount == null) return;
    }
    await _repository.logCallOutcome(
      widget.profileId,
      outcome,
      pledgeAmount: pledgeAmount,
      notes: _callNotesController.text.trim().isNotEmpty
          ? _callNotesController.text.trim()
          : null,
    );
    _callNotesController.clear();
    await _load();
  }

  Future<double?> _showPledgeDialog() async {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Pledge Amount'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '\$ ',
            hintText: '0.00',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              Navigator.pop(ctx, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addNote() async {
    _noteController.clear();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Note'),
        content: TextField(
          controller: _noteController,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Enter note...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, _noteController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _repository.logActivity(
        widget.profileId,
        'note',
        'Note added',
        result,
      );
      await _load();
    }
  }

  Future<void> _addTag() async {
    final allTags = await _repository.getAllTags();
    if (!mounted) return;
    // Mirror of the Autocomplete field's text so the Save button has a value
    // to read regardless of whether the user typed free-form or picked a
    // suggestion. Disposed in the finally block below — never from inside
    // fieldViewBuilder (which rebuilds on every keystroke).
    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add Tag'),
          content: Autocomplete<String>(
            optionsBuilder: (value) {
              if (value.text.isEmpty) return allTags;
              return allTags.where(
                (t) => t.toLowerCase().contains(value.text.toLowerCase()),
              );
            },
            fieldViewBuilder: (ctx, textCtrl, focusNode, onSubmit) {
              return TextField(
                controller: textCtrl,
                focusNode: focusNode,
                decoration: const InputDecoration(hintText: 'Tag name...'),
                onChanged: (v) => controller.text = v,
                onSubmitted: (_) => onSubmit(),
              );
            },
            onSelected: (val) => controller.text = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        ),
      );
      if (result != null && result.isNotEmpty) {
        await _repository.addTag(widget.profileId, result);
        await _load();
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _launchCall() async {
    final phone = _profile?.phoneE164 ?? _profile?.phone;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchEmail() async {
    final email = _profile?.email;
    if (email == null) return;
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Donor Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Donor Profile')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: BrandColors.error),
              const SizedBox(height: 12),
              Text(_error ?? 'Profile not found'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final p = _profile!;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(p),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: BrandColors.sunriseGold,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Giving'),
                  Tab(text: 'Political'),
                  Tab(text: 'Research'),
                  Tab(text: 'Enrichment'),
                  Tab(text: 'Call Time'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildOverviewTab(p),
            _buildGivingTab(p),
            _buildPoliticalTab(p),
            _buildResearchTab(p),
            _buildEnrichmentTab(p),
            _buildCallTimeTab(p),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  SliverAppBar _buildSliverAppBar(DonorProfile p) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      leading: const BackButton(color: Colors.white),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (val) {
            if (val == 'refresh') _load();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'refresh', child: Text('Refresh')),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [BrandColors.unityBlue, BrandColors.momentumBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _tierBadge(p),
                      const SizedBox(width: 6),
                      _partyBadge(p),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Score rings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildScoreRing(
                        (p.wealthScore ?? 0).toDouble(),
                        100,
                        'Wealth',
                        _scoreColor(p.wealthScore ?? 0),
                      ),
                      _buildScoreRing(
                        (p.engagementScore ?? 0).toDouble(),
                        100,
                        'Engagement',
                        _scoreColor(p.engagementScore ?? 0),
                      ),
                      Column(
                        children: [
                          Text(
                            _currencyWhole.format(p.givingCapacity ?? 0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Giving Capacity',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Quick actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.white),
                        tooltip: 'Call',
                        onPressed: _launchCall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.mail, color: Colors.white),
                        tooltip: 'Email',
                        onPressed: _launchEmail,
                      ),
                      IconButton(
                        icon: const Icon(Icons.note_add, color: Colors.white),
                        tooltip: 'Add Note',
                        onPressed: _addNote,
                      ),
                      IconButton(
                        icon: const Icon(Icons.label, color: Colors.white),
                        tooltip: 'Tag',
                        onPressed: _addTag,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Enrichment bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: p.enrichmentCompleteness,
                            backgroundColor: Colors.white24,
                            color: BrandColors.sunriseGold,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(p.enrichmentCompleteness * 100).round()}% enriched',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tierBadge(DonorProfile p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.tierColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        p.tierDisplay,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _partyBadge(DonorProfile p) {
    final isRep =
        p.partyLean == 'strong_rep' || p.partyLean == 'lean_rep';
    final color = isRep ? BrandColors.republicanRed : BrandColors.democratBlue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        p.partyLeanDisplay,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score > 66) return BrandColors.success;
    if (score > 33) return BrandColors.warning;
    return BrandColors.error;
  }

  Widget _buildScoreRing(
      double value, double max, String label, Color color) {
    final fraction = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 54,
          height: 54,
          child: CustomPaint(
            painter: _ScoreRingPainter(fraction, color),
            child: Center(
              child: Text(
                value.round().toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1 - Overview
  // ---------------------------------------------------------------------------

  Widget _buildOverviewTab(DonorProfile p) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Contact Card
        _sectionCard(
          title: 'Contact',
          icon: Icons.contact_phone,
          children: [
            if (p.phone != null) _contactRow(Icons.phone, p.phone!, _launchCall),
            if (p.enrichmentData != null)
              for (final ph in p.enrichmentData!.phones)
                _contactRow(Icons.phone_android, ph, () async {
                  final uri = Uri(scheme: 'tel', path: ph);
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                }),
            if (p.email != null)
              _contactRow(Icons.email, p.email!, _launchEmail),
            if (p.enrichmentData != null)
              for (final em in p.enrichmentData!.emails)
                _contactRow(Icons.alternate_email, em, () async {
                  final uri = Uri(scheme: 'mailto', path: em);
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                }),
            if (p.address != null)
              _contactRow(Icons.home, [
                p.address,
                if (p.city != null) p.city,
                if (p.state != null) '${p.state} ${p.zipCode ?? ''}',
              ].whereType<String>().join(', '), null),
            if (p.employer != null)
              _contactRow(Icons.business, '${p.employer} - ${p.occupation ?? ''}', null),
          ],
        ),
        const SizedBox(height: 12),

        // Quick Stats
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _statChip('Total Given', _currencyWhole.format(p.totalDonatedAll)),
              _statChip('Gifts', '${p.totalDonationCount}'),
              _statChip('Avg Gift', _currencyWhole.format(p.averageGift ?? 0)),
              _statChip('Largest', _currencyWhole.format(p.largestGift ?? 0)),
              _statChip(
                'First Gift',
                p.firstDonationDate != null
                    ? _dateFmt.format(p.firstDonationDate!)
                    : 'N/A',
              ),
              _statChip(
                'Last Gift',
                p.lastDonationDate != null
                    ? _dateFmt.format(p.lastDonationDate!)
                    : 'N/A',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Linked Member
        if (p.memberId != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.person, color: BrandColors.momentumBlue),
              title: const Text('Linked Member'),
              subtitle: Text('Member ID: ${p.memberId}'),
              trailing:
                  TextButton(onPressed: () {}, child: const Text('View Member')),
            ),
          ),
        if (p.memberId != null) const SizedBox(height: 12),

        // VAN Voter Summary
        if (p.vanVoter != null) _buildVanSummaryCard(p),
        if (p.vanVoter != null) const SizedBox(height: 12),

        // MO Voter File
        if (_voterRecord != null) ...[
          VoterFileCard(record: _voterRecord!),
          const SizedBox(height: 12),
        ],

        // Donor Enrichment (skipped entirely when populatedFields is empty)
        if (_enrichmentRecord != null && _enrichmentRecord!.hasData) ...[
          DonorEnrichmentCard(record: _enrichmentRecord!),
          const SizedBox(height: 12),
        ],

        // Key Badges
        if (p.keyBadges.isNotEmpty) ...[
          const Text('Badges',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: p.keyBadges
                .map((b) => Chip(
                      label: Text(b, style: const TextStyle(fontSize: 12)),
                      backgroundColor: BrandColors.momentumBlue.withOpacity(0.15),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Activity Timeline
        Row(
          children: [
            const Expanded(
              child: Text('Recent Activity',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.note_add, size: 18),
              label: const Text('Add Note'),
              onPressed: _addNote,
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...p.activityLog.take(10).map(_buildActivityTile),
        if (p.activityLog.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No activity yet',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }

  Widget _contactRow(IconData icon, String text, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: BrandColors.momentumBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: onTap != null ? BrandColors.momentumBlue : null,
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildVanSummaryCard(DonorProfile p) {
    final v = p.vanVoter!;
    // Recent voting sparkline from voting records
    final recentVotes = p.vanVotingRecords.take(10).toList();
    return _sectionCard(
      title: 'VAN Voter Summary',
      icon: Icons.how_to_vote,
      children: [
        _detailRow('Party', v.party),
        _detailRow(
          'Registered',
          v.registrationDate != null
              ? _dateFmt.format(v.registrationDate!)
              : null,
        ),
        _detailRow('Precinct', v.precinct),
        _detailRow('Ward', v.ward),
        if (recentVotes.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Voting History',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Row(
            children: recentVotes
                .map((r) => Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: r.voted == true
                            ? BrandColors.success
                            : Colors.grey.shade300,
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityTile(ActivityEntry e) {
    IconData icon;
    switch (e.activityType) {
      case 'note':
        icon = Icons.note;
        break;
      case 'call':
        icon = Icons.phone;
        break;
      case 'email':
        icon = Icons.email;
        break;
      case 'donation':
        icon = Icons.attach_money;
        break;
      case 'tag':
        icon = Icons.label;
        break;
      default:
        icon = Icons.circle;
    }
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: BrandColors.momentumBlue),
      title: Text(e.title ?? '', style: const TextStyle(fontSize: 13)),
      subtitle: e.description != null
          ? Text(e.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12))
          : null,
      trailing: e.createdAt != null
          ? Text(_dateFmt.format(e.createdAt!),
              style: const TextStyle(fontSize: 11, color: Colors.grey))
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2 - Giving
  // ---------------------------------------------------------------------------

  Widget _buildGivingTab(DonorProfile p) {
    // Merge donations + MEC into unified list sorted newest first
    final allContribs = <_UnifiedContribution>[
      ...p.donations.map((d) => _UnifiedContribution(
            amount: d.amount ?? 0,
            date: d.date,
            source: d.source ?? 'moyd',
            committeeName: d.committeeName,
          )),
      ...p.mecContributions.map((c) => _UnifiedContribution(
            amount: c.amount ?? 0,
            date: c.date,
            source: 'mec',
            committeeName: c.committeeName,
          )),
    ]..sort((a, b) => (b.date ?? DateTime(1900))
        .compareTo(a.date ?? DateTime(1900)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // LYBUNT / SYBUNT / Active
        _buildDonorStatusCard(p),
        const SizedBox(height: 12),

        // Unified Timeline
        const Text('Donation Timeline',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...allContribs.map(_buildContributionCard),
        if (allContribs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No donations found',
                style:
                    TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
        const SizedBox(height: 16),

        // Yearly giving chart
        const Text('Yearly Giving',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        SizedBox(height: 220, child: _buildYearlyChart(p)),
        const SizedBox(height: 16),

        // Pattern Analysis
        _sectionCard(
          title: 'Giving Pattern',
          icon: Icons.analytics,
          children: [
            Text(
              '${p.totalDonationCount} gifts over '
              '${_yearSpan(p)} years',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Average of ${_currencyWhole.format(p.averageGift ?? 0)} per gift',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            _buildTrendText(p),
            const SizedBox(height: 4),
            if (p.daysSinceLastGift != null)
              Text('${p.daysSinceLastGift} days since last gift',
                  style: const TextStyle(fontSize: 14)),
          ],
        ),
      ],
    );
  }

  int _yearSpan(DonorProfile p) {
    if (p.firstDonationDate == null) return 0;
    return DateTime.now().year - p.firstDonationDate!.year + 1;
  }

  Widget _buildTrendText(DonorProfile p) {
    final trend = p.donationTrend;
    if (trend == null) {
      return const Text('Trend: insufficient data',
          style: TextStyle(fontSize: 14));
    }
    String direction;
    if (trend > 5) {
      direction = 'up';
    } else if (trend < -5) {
      direction = 'down';
    } else {
      direction = 'stable';
    }
    return Text(
      'Trend: $direction ${trend.abs().toStringAsFixed(0)}% vs prior period',
      style: TextStyle(
        fontSize: 14,
        color: direction == 'up'
            ? BrandColors.success
            : direction == 'down'
                ? BrandColors.error
                : null,
      ),
    );
  }

  Widget _buildDonorStatusCard(DonorProfile p) {
    Color bg;
    String label;
    IconData icon;
    if (p.isLybunt) {
      bg = BrandColors.warning.withOpacity(0.15);
      label = 'LYBUNT - Gave last year but not this year';
      icon = Icons.warning_amber;
    } else if (p.isSybunt) {
      bg = BrandColors.error.withOpacity(0.15);
      label = 'SYBUNT - Lapsed donor';
      icon = Icons.error_outline;
    } else {
      bg = BrandColors.success.withOpacity(0.15);
      label = 'Active donor';
      icon = Icons.check_circle_outline;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildContributionCard(_UnifiedContribution c) {
    Color borderColor;
    Color badgeColor;
    String sourceLabel;
    switch (c.source.toLowerCase()) {
      case 'moyd':
        borderColor = BrandColors.momentumBlue;
        badgeColor = BrandColors.momentumBlue;
        sourceLabel = 'MOYD';
        break;
      case 'mec':
        borderColor = BrandColors.warning;
        badgeColor = BrandColors.warning;
        sourceLabel = 'MEC';
        break;
      case 'fec':
        borderColor = const Color(0xFF8B5CF6);
        badgeColor = const Color(0xFF8B5CF6);
        sourceLabel = 'FEC';
        break;
      default:
        borderColor = Colors.grey;
        badgeColor = Colors.grey;
        sourceLabel = c.source.toUpperCase();
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: borderColor, width: 4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currencyFull.format(c.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (c.date != null)
                    Text(_dateFmt.format(c.date!),
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  if (c.committeeName != null)
                    Text(c.committeeName!,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                sourceLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlyChart(DonorProfile p) {
    final moyd = p.yearlyGivingMoyd;
    final political = p.yearlyGivingPolitical;
    final allYears = {...moyd.keys, ...political.keys}.toList()..sort();
    if (allYears.isEmpty) {
      return const Center(
          child: Text('No data',
              style: TextStyle(color: Colors.grey)));
    }
    final displayYears =
        allYears.length > 5 ? allYears.sublist(allYears.length - 5) : allYears;

    final maxY = displayYears.fold<double>(0, (prev, y) {
      final total = (moyd[y] ?? 0) + (political[y] ?? 0);
      return total > prev ? total : prev;
    });

    return BarChart(
      BarChartData(
        maxY: maxY * 1.15,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= displayYears.length) {
                  return const SizedBox.shrink();
                }
                return Text('${displayYears[idx]}',
                    style: const TextStyle(fontSize: 11));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (val, _) => Text(
                _currencyWhole.format(val),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(displayYears.length, (i) {
          final y = displayYears[i];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (moyd[y] ?? 0) + (political[y] ?? 0),
                width: 20,
                rodStackItems: [
                  BarChartRodStackItem(
                      0, moyd[y] ?? 0, BrandColors.momentumBlue),
                  BarChartRodStackItem(moyd[y] ?? 0,
                      (moyd[y] ?? 0) + (political[y] ?? 0), BrandColors.warning),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                color: Colors.transparent,
              ),
            ],
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3 - Political
  // ---------------------------------------------------------------------------

  Widget _buildPoliticalTab(DonorProfile p) {
    // Top 10 committees
    final committeeMap = <String, double>{};
    for (final c in p.mecContributions) {
      if (c.committeeName == null || c.amount == null) continue;
      committeeMap[c.committeeName!] =
          (committeeMap[c.committeeName!] ?? 0) + c.amount!;
    }
    final topCommittees = committeeMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top10 =
        topCommittees.take(10).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // MEC committee bar chart
        const Text('Top Committees by Giving',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (top10.isNotEmpty)
          SizedBox(
            height: (top10.length * 36.0).clamp(100, 380),
            child: _buildCommitteeChart(top10),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No MEC contributions found',
                style:
                    TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
        const SizedBox(height: 16),

        // Party Distribution pie
        const Text('Party Distribution',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (p.partyDistribution.isNotEmpty)
          SizedBox(height: 200, child: _buildPartyPie(p))
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No data',
                style:
                    TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
        const SizedBox(height: 16),

        // VAN Voting History
        if (p.vanVotingRecords.isNotEmpty) ...[
          const Text('Voting History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Voted')),
              ],
              rows: (p.vanVotingRecords.toList()
                    ..sort((a, b) => (b.electionDate ?? DateTime(1900))
                        .compareTo(a.electionDate ?? DateTime(1900))))
                  .map((r) => DataRow(cells: [
                        DataCell(Text(r.electionDate != null
                            ? _dateFmt.format(r.electionDate!)
                            : '')),
                        DataCell(Text(r.electionType ?? '')),
                        DataCell(Icon(
                          r.voted == true ? Icons.check : Icons.close,
                          color: r.voted == true
                              ? BrandColors.success
                              : Colors.grey,
                          size: 18,
                        )),
                      ]))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // VAN Scores
        if (p.vanScores.isNotEmpty) ...[
          const Text('VAN Scores',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          ...p.vanScores.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(s.scoreName ?? '',
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: ((s.scoreValue ?? 0) / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        color: BrandColors.momentumBlue,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(s.scoreValue ?? 0).round()}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildCommitteeChart(List<MapEntry<String, double>> entries) {
    final maxVal = entries.fold<double>(0, (p, e) => e.value > p ? e.value : p);
    return BarChart(
      BarChartData(
        maxY: maxVal * 1.15,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 120,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= entries.length) {
                  return const SizedBox.shrink();
                }
                return SizedBox(
                  width: 115,
                  child: Text(
                    entries[idx].key,
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Text(_currencyWhole.format(entries[idx].value),
                    style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        alignment: BarChartAlignment.spaceAround,
        barGroups: List.generate(entries.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value,
                width: 14,
                color: BrandColors.momentumBlue,
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPartyPie(DonorProfile p) {
    final dist = p.partyDistribution;
    final total = dist.values.fold<double>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    Color colorFor(String party) {
      switch (party) {
        case 'Democrat':
          return BrandColors.democratBlue;
        case 'Republican':
          return BrandColors.republicanRed;
        default:
          return Colors.grey;
      }
    }

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: dist.entries.map((e) {
                final pct = (e.value / total * 100);
                return PieChartSectionData(
                  value: e.value,
                  color: colorFor(e.key),
                  title: '${pct.round()}%',
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                  radius: 60,
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: dist.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colorFor(e.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${e.key}: ${_currencyWhole.format(e.value)}',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4 - Research
  // ---------------------------------------------------------------------------

  Widget _buildResearchTab(DonorProfile p) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Property Records
        _researchSection(
          'Property Records',
          Icons.home_work,
          p.propertyRecords.length,
          p.propertyRecords.isEmpty
              ? [_emptyPlaceholder('property')]
              : p.propertyRecords.map((r) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (r.address != null)
                            Text(r.address!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          if (r.propertyType != null)
                            Text('Type: ${r.propertyType}',
                                style: const TextStyle(fontSize: 13)),
                          if (r.assessedValue != null)
                            Text(
                                'Assessed: ${_currencyWhole.format(r.assessedValue)}',
                                style: const TextStyle(fontSize: 13)),
                          if (r.yearBuilt != null)
                            Text('Built: ${r.yearBuilt}',
                                style: const TextStyle(fontSize: 13)),
                          if (r.lotSizeSqft != null)
                            Text(
                                'Lot: ${NumberFormat('#,###').format(r.lotSizeSqft)} sqft',
                                style: const TextStyle(fontSize: 13)),
                          if (r.lastSaleDate != null || r.lastSalePrice != null)
                            Text(
                              'Last Sale: ${r.lastSaleDate != null ? _dateFmt.format(r.lastSaleDate!) : ''}'
                              '${r.lastSalePrice != null ? ' @ ${_currencyWhole.format(r.lastSalePrice)}' : ''}',
                              style: const TextStyle(fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  )).toList(),
        ),

        // Business Entities
        _researchSection(
          'Business Entities',
          Icons.business,
          p.businessEntities.length,
          p.businessEntities.isEmpty
              ? [_emptyPlaceholder('business entity')]
              : p.businessEntities.map((e) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.entityName ?? 'Unknown',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (e.entityType != null)
                            Text('Type: ${e.entityType}',
                                style: const TextStyle(fontSize: 13)),
                          if (e.status != null)
                            Row(
                              children: [
                                const Text('Status: ',
                                    style: TextStyle(fontSize: 13)),
                                _statusBadge(e.status!),
                              ],
                            ),
                          if (e.formationDate != null)
                            Text(
                                'Formed: ${_dateFmt.format(e.formationDate!)}',
                                style: const TextStyle(fontSize: 13)),
                          if (e.agentName != null)
                            Text('Agent: ${e.agentName}',
                                style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  )).toList(),
        ),

        // Casenet Records
        _researchSection(
          'Court Records (Casenet)',
          Icons.gavel,
          p.casenetRecords.length,
          p.casenetRecords.isEmpty
              ? [_emptyPlaceholder('court')]
              : p.casenetRecords.map((r) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (r.caseNumber != null)
                            Text('Case: ${r.caseNumber}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          if (r.caseType != null)
                            Text('Type: ${r.caseType}',
                                style: const TextStyle(fontSize: 13)),
                          if (r.court != null)
                            Text('Court: ${r.court}',
                                style: const TextStyle(fontSize: 13)),
                          if (r.filingDate != null)
                            Text(
                                'Filed: ${_dateFmt.format(r.filingDate!)}',
                                style: const TextStyle(fontSize: 13)),
                          if (r.status != null)
                            Row(
                              children: [
                                const Text('Status: ',
                                    style: TextStyle(fontSize: 13)),
                                _statusBadge(r.status!),
                              ],
                            ),
                        ],
                      ),
                    ),
                  )).toList(),
        ),

        // SEC Filings
        _researchSection(
          'SEC Filings',
          Icons.description,
          p.secFilings.length,
          p.secFilings.isEmpty
              ? [_emptyPlaceholder('SEC filing')]
              : p.secFilings.map((f) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (f.companyName != null)
                            Text(f.companyName!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          if (f.formType != null)
                            Text('Form: ${f.formType}',
                                style: const TextStyle(fontSize: 13)),
                          if (f.filingDate != null)
                            Text(
                                'Filed: ${_dateFmt.format(f.filingDate!)}',
                                style: const TextStyle(fontSize: 13)),
                          if (f.description != null)
                            Text(f.description!,
                                style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  )).toList(),
        ),

        // Census Context
        if (p.censusData != null) ...[
          _researchSection(
            'Census Context',
            Icons.people,
            1,
            [
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.censusData!.medianIncome != null)
                        Text(
                            'Median Income: ${_currencyWhole.format(p.censusData!.medianIncome)}'),
                      if (p.censusData!.medianHomeValue != null)
                        Text(
                            'Median Home Value: ${_currencyWhole.format(p.censusData!.medianHomeValue)}'),
                      if (p.censusData!.population != null)
                        Text(
                            'Population: ${NumberFormat('#,###').format(p.censusData!.population)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],

        // Zillow Context
        if (p.zillowData != null) ...[
          _researchSection(
            'Zillow Context',
            Icons.real_estate_agent,
            1,
            [
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.zillowData!.zhvi != null)
                        Text(
                            'ZHVI: ${_currencyWhole.format(p.zillowData!.zhvi)}'),
                      if (p.zillowData!.zhviChangePct != null)
                        Text(
                            'Change: ${p.zillowData!.zhviChangePct!.toStringAsFixed(1)}%'),
                      if (p.zillowData!.medianListingPrice != null)
                        Text(
                            'Median Listing: ${_currencyWhole.format(p.zillowData!.medianListingPrice)}'),
                      if (p.zillowData!.medianRent != null)
                        Text(
                            'Median Rent: ${_currencyWhole.format(p.zillowData!.medianRent)}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _researchSection(
      String title, IconData icon, int count, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: BrandColors.momentumBlue),
            const SizedBox(width: 6),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(width: 6),
            if (count > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: BrandColors.momentumBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _emptyPlaceholder(String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('No $type records found',
          style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
    );
  }

  Widget _statusBadge(String status) {
    final lower = status.toLowerCase();
    Color color;
    if (lower == 'active' || lower == 'good standing') {
      color = BrandColors.success;
    } else if (lower == 'inactive' || lower == 'dissolved') {
      color = BrandColors.error;
    } else {
      color = BrandColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 5 - Enrichment
  // ---------------------------------------------------------------------------

  Widget _buildEnrichmentTab(DonorProfile p) {
    final completeness = p.enrichmentCompleteness;
    final ed = p.enrichmentData;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Data quality circle
        Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: completeness,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: completeness > 0.66
                      ? BrandColors.success
                      : completeness > 0.33
                          ? BrandColors.warning
                          : BrandColors.error,
                ),
                Center(
                  child: Text(
                    '${(completeness * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text('Data Quality',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ),
        const SizedBox(height: 16),

        // Demographics
        _enrichmentSection('Demographics', [
          _enrichmentRow('Full Name', ed?.fullName),
          _enrichmentRow('Age', ed?.age?.toString()),
          _enrichmentRow('Gender', ed?.gender),
          _enrichmentRow('Education', ed?.education),
          _enrichmentRow('Marital Status', null), // not in model
        ]),

        // Contact
        _enrichmentSection('Contact', [
          _enrichmentRow(
              'Phones', ed?.phones.isNotEmpty == true ? ed!.phones.join(', ') : null),
          _enrichmentRow(
              'Emails', ed?.emails.isNotEmpty == true ? ed!.emails.join(', ') : null),
        ]),

        // Employment
        _enrichmentSection('Employment', [
          _enrichmentRow('Employer', p.employer),
          _enrichmentRow('Occupation', p.occupation),
          _enrichmentRow('Industry', null),
          _enrichmentRow('Job Title', null),
        ]),

        // Financial
        _enrichmentSection('Financial', [
          _enrichmentRow('Income Range', ed?.incomeRange),
          _enrichmentRow('Net Worth', ed?.netWorth),
          _enrichmentRow(
            'Estimated Home Value',
            p.zillowData?.zhvi != null
                ? _currencyWhole.format(p.zillowData!.zhvi)
                : null,
          ),
          _enrichmentRow('Investment Activity', null),
        ]),

        // Political
        _enrichmentSection('Political', [
          _enrichmentRow('Political Party', ed?.politicalParty),
          _enrichmentRow('Donor Likelihood', ed?.donorLikelihood),
          _enrichmentRow('Party Affiliation Score', null),
        ]),

        // Geographic
        _enrichmentSection('Geographic', [
          _enrichmentRow('Address', p.address),
          _enrichmentRow('City', p.city),
          _enrichmentRow('State', p.state),
          _enrichmentRow('ZIP', p.zipCode),
          _enrichmentRow('County', p.county),
          _enrichmentRow('CD', p.congressionalDistrict),
          _enrichmentRow('Timezone', null),
        ]),

        // Scores
        _enrichmentSection('Scores', [
          _enrichmentRow('Wealth Score', p.wealthScore?.toString()),
          _enrichmentRow('Engagement Score', p.engagementScore?.toString()),
          _enrichmentRow(
              'Giving Capacity',
              p.givingCapacity != null
                  ? _currencyWhole.format(p.givingCapacity)
                  : null),
        ]),

        // Social
        _enrichmentSection('Social', [
          if (ed != null && ed.socialProfiles.isNotEmpty)
            ...ed.socialProfiles.map((url) => _enrichmentRow('Profile', url))
          else
            _enrichmentRow('Social Profiles', null),
        ]),
      ],
    );
  }

  Widget _enrichmentSection(String title, List<Widget> children) {
    // Wrap in a Theme that removes the default Material divider + forces
    // white iconography, so the tile reads correctly on the navy
    // BrandedBackground this screen uses.
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        listTileTheme: const ListTileThemeData(
          textColor: Colors.white,
          iconColor: Colors.white,
        ),
      ),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white70,
        initiallyExpanded: true,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: children,
      ),
    );
  }

  Widget _enrichmentRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              // Muted white instead of default grey — sits legibly on navy.
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: value != null && value.isNotEmpty
                ? Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  )
                : const Text(
                    'Not available',
                    style: TextStyle(
                      color: Colors.white54,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 6 - Call Time
  // ---------------------------------------------------------------------------

  Widget _buildCallTimeTab(DonorProfile p) {
    final phone = p.phoneE164 ?? p.phone;
    final sortedCalls = p.callOutcomes.toList()
      ..sort((a, b) => (b.calledAt ?? DateTime(1900))
          .compareTo(a.calledAt ?? DateTime(1900)));

    final pledges =
        sortedCalls.where((c) => c.pledgeAmount != null && c.pledgeAmount! > 0);
    final totalPledged = pledges.fold<double>(0, (s, c) => s + c.pledgeAmount!);
    // Assume fulfilled = 0 unless tracked elsewhere
    final totalFulfilled = 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Suggested Ask
        Card(
          color: BrandColors.sunriseGold.withOpacity(0.12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Suggested Ask',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                Text(
                  _currencyWhole.format(p.suggestedAskAmount),
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on giving capacity and average gift',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Phone + call button
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  phone ?? 'No phone on file',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: phone != null ? null : Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.phone),
                  label: const Text('Tap to Call'),
                  onPressed: phone != null ? _launchCall : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Quick Outcome Buttons
        const Text('Call Outcome',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _outcomeButton('Answered', BrandColors.success),
            _outcomeButton('Voicemail', BrandColors.momentumBlue),
            _outcomeButton('No Answer', BrandColors.warning),
            _outcomeButton('Busy', Colors.grey),
            _outcomeButton('Wrong Number', BrandColors.error),
            _outcomeButton('Pledge', BrandColors.sunriseGold),
            _outcomeButton('Decline', BrandColors.unityBlue),
            _outcomeButton('Callback', const Color(0xFF8B5CF6)),
          ],
        ),
        const SizedBox(height: 12),

        // Call Notes
        TextField(
          controller: _callNotesController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Call Notes',
            border: OutlineInputBorder(),
            hintText: 'Enter notes about the call...',
          ),
        ),
        const SizedBox(height: 16),

        // Pledge Tracker
        if (pledges.isNotEmpty) ...[
          _sectionCard(
            title: 'Pledge Tracker',
            icon: Icons.monetization_on,
            children: [
              _detailRow('Total Pledged', _currencyWhole.format(totalPledged)),
              _detailRow(
                  'Total Fulfilled', _currencyWhole.format(totalFulfilled)),
              _detailRow('Outstanding',
                  _currencyWhole.format(totalPledged - totalFulfilled)),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Call History
        const Text('Call History',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (sortedCalls.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No calls yet',
                style:
                    TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          ),
        ...sortedCalls.map((c) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: _callOutcomeBadge(c.outcome ?? ''),
                title: Text(c.outcome ?? '',
                    style: const TextStyle(fontSize: 13)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.calledAt != null)
                      Text(_dateTimeFmt.format(c.calledAt!),
                          style: const TextStyle(fontSize: 11)),
                    if (c.notes != null && c.notes!.isNotEmpty)
                      Text(c.notes!,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    if (c.pledgeAmount != null && c.pledgeAmount! > 0)
                      Text('Pledge: ${_currencyFull.format(c.pledgeAmount)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _outcomeButton(String label, Color color) {
    return ElevatedButton(
      onPressed: () => _logCallOutcome(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 13),
      ),
      child: Text(label),
    );
  }

  Widget _callOutcomeBadge(String outcome) {
    Color color;
    switch (outcome.toLowerCase()) {
      case 'answered':
        color = BrandColors.success;
        break;
      case 'voicemail':
        color = BrandColors.momentumBlue;
        break;
      case 'no answer':
        color = BrandColors.warning;
        break;
      case 'pledge':
        color = BrandColors.sunriseGold;
        break;
      case 'wrong number':
        color = BrandColors.error;
        break;
      case 'decline':
        color = BrandColors.unityBlue;
        break;
      case 'callback':
        color = const Color(0xFF8B5CF6);
        break;
      default:
        color = Colors.grey;
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: color.withOpacity(0.2),
      child: Icon(Icons.phone, size: 14, color: color),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: BrandColors.momentumBlue),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(value ?? 'N/A', style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Supporting classes
// =============================================================================

class _UnifiedContribution {
  final double amount;
  final DateTime? date;
  final String source;
  final String? committeeName;

  const _UnifiedContribution({
    required this.amount,
    this.date,
    required this.source,
    this.committeeName,
  });
}

class _ScoreRingPainter extends CustomPainter {
  final double fraction;
  final Color color;

  _ScoreRingPainter(this.fraction, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 5.0;
    final rect = Rect.fromLTWH(
        strokeWidth / 2, strokeWidth / 2,
        size.width - strokeWidth, size.height - strokeWidth);

    // Background ring
    canvas.drawArc(
      rect,
      -1.5708, // -pi/2
      6.2832, // 2*pi
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.white24,
    );

    // Foreground arc
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832 * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) =>
      old.fraction != fraction || old.color != color;
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.unityBlue, BrandColors.momentumBlue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
