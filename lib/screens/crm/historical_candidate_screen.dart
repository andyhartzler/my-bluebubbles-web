import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detail screen for historical candidates — shows their full race
/// history, campaign finance, bio, and social links.
class HistoricalCandidateScreen extends StatefulWidget {
  final String candidateName;

  const HistoricalCandidateScreen({super.key, required this.candidateName});

  @override
  State<HistoricalCandidateScreen> createState() => _HistoricalCandidateScreenState();
}

class _HistoricalCandidateScreenState extends State<HistoricalCandidateScreen> {
  final CandidateRepository _repo = CandidateRepository();
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await _repo.getHistoricalCandidateProfile(widget.candidateName);
      if (mounted) setState(() { _profile = response; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
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
              _buildHeader(),
              Expanded(
                child: _loading
                    ? CandidateUI.shimmerSkeleton(cardCount: 4)
                    : _profile == null
                        ? CandidateUI.emptyState(Icons.person_off, 'Not Found', 'No data found for ${widget.candidateName}')
                        : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.candidateName,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final candidate = _profile!['candidate'] as Map<String, dynamic>? ?? {};
    final races = (_profile!['races'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final finance = (_profile!['finance'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final party = candidate['party'] as String? ?? '';
    final photo = candidate['photo_url'] as String?;
    final bpUrl = candidate['ballotpedia_url'] as String?;
    final district = candidate['district'] as String? ?? '';
    final office = candidate['office'] as String? ?? '';

    Color partyColor;
    if (party.contains('Dem')) partyColor = BrandColors.democratBlue;
    else if (party.contains('Rep')) partyColor = BrandColors.republicanRed;
    else if (party.contains('Lib')) partyColor = Colors.amber;
    else partyColor = Colors.grey;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Hero card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [partyColor.withOpacity(0.15), Colors.white.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: partyColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: partyColor.withOpacity(0.3),
                backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo == null || photo.isEmpty
                    ? Text(widget.candidateName.isNotEmpty ? widget.candidateName[0] : '?',
                        style: TextStyle(color: partyColor, fontSize: 28, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.candidateName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('$party • $office${district.isNotEmpty ? " d.$district" : ""}',
                        style: TextStyle(color: partyColor.withOpacity(0.9), fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${races.length} races on record', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Quick links
        if (bpUrl != null && bpUrl.startsWith('http'))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () {
                final uri = Uri.tryParse(bpUrl);
                if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF009688).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF009688).withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.how_to_vote, color: Color(0xFF009688), size: 16),
                    SizedBox(width: 8),
                    Text('View on Ballotpedia', style: TextStyle(color: Color(0xFF009688), fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),

        // Race history
        CandidateUI.card('Race History', Icons.how_to_vote, partyColor, child: Column(
          children: [
            const SizedBox(height: 8),
            if (races.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No race data found', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              )
            else
              ...races.map((r) {
                final year = r['election_year'] as int? ?? 0;
                final type = (r['election_type'] as String? ?? 'general').replaceAll('_', ' ');
                final votes = r['votes'] as int?;
                final pct = (r['vote_percentage'] as num?)?.toDouble();
                final won = r['winner'] as bool? ?? false;
                final raceOffice = r['office'] as String? ?? '';
                final raceDist = r['district'] as String? ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: won ? partyColor.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: won ? partyColor.withOpacity(0.4) : Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: won ? partyColor.withOpacity(0.25) : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('$year', style: TextStyle(
                          color: won ? partyColor : Colors.white70,
                          fontSize: 14, fontWeight: FontWeight.w800,
                        )),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$raceOffice${raceDist.isNotEmpty ? " d.$raceDist" : ""}',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                            Text(type.isNotEmpty ? type.substring(0, 1).toUpperCase() + type.substring(1) : 'General',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (votes != null)
                            Text('${CandidateUI.formatNumber(votes)} votes',
                                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                          if (pct != null)
                            Text('${pct.toStringAsFixed(1)}%',
                                style: TextStyle(color: partyColor, fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      if (won) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.emoji_events, color: partyColor, size: 16),
                      ],
                    ],
                  ),
                );
              }),
          ],
        )),
        const SizedBox(height: 16),

        // Campaign finance
        if (finance.isNotEmpty)
          CandidateUI.card('Campaign Finance', Icons.attach_money, BrandColors.sunriseGold, child: Column(
            children: [
              const SizedBox(height: 8),
              ...finance.map((f) {
                final committeeName = f['committee_name'] as String? ?? '';
                final mecId = f['mec_id'] as String? ?? '';
                final totalRaised = (f['total_raised'] as num?)?.toDouble() ?? 0;
                final contribCount = (f['contribution_count'] as num?)?.toInt() ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(committeeName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('MEC: $mecId', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                          const Spacer(),
                          Text('\$${CandidateUI.formatMoney(totalRaised)}', style: const TextStyle(color: BrandColors.sunriseGold, fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Text('$contribCount donors', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          )),
      ],
    );
  }
}
