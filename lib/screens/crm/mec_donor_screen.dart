import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/donor_enrichment_record.dart';
import 'package:bluebubbles/models/crm/voter_file_record.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/screens/crm/mec_committee_screen.dart';
import 'package:bluebubbles/screens/crm/voter_file/donor_enrichment_card.dart';
import 'package:bluebubbles/screens/crm/voter_file/voter_file_card.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/services/crm/donor_profile_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';
import 'package:bluebubbles/services/crm/voter_file_service.dart';

/// Screen showing a donor's full contribution history, identified by the
/// natural key (first_name, last_name, city, state) rather than the
/// unreliable mec_contributions.donor_id column (which is ~96% broken —
/// pointed at the wrong mec_donors row on almost every contribution).
///
/// Pulls everything via the get_donor_profile_by_natural_key RPC. From
/// here, every committee is tappable → MECCommitteeScreen and every
/// candidate is tappable → CandidateDetailScreen.
class MECDonorScreen extends StatefulWidget {
  /// When non-null, the screen loads via `get_donor_profile_by_id(donorId)`
  /// — the canonical, donor-row-based view. This is what most call sites
  /// should pass now: it disambiguates the "two Jake Zimmermans" case
  /// where the natural-key match by city only finds half the donor's
  /// contributions (because the city spelling drifts across rows even
  /// when they're the same person/donor entity).
  final int? donorId;

  /// Natural-key fallback. Used when `donorId` is null — typical case:
  /// a contribution row that doesn't carry a resolved `donor_id` (e.g.
  /// orphan rows in the contributions table or mec_payee searches).
  final String firstName;
  final String lastName;
  final String? city;
  final String? state;
  final String? employerHint;

  const MECDonorScreen({
    super.key,
    this.donorId,
    required this.firstName,
    required this.lastName,
    this.city,
    this.state,
    this.employerHint,
  });

  @override
  State<MECDonorScreen> createState() => _MECDonorScreenState();
}

class _MECDonorScreenState extends State<MECDonorScreen> {
  final CRMSupabaseService _supabase = CRMSupabaseService();
  final CandidateRepository _candidateRepo = CandidateRepository();
  final DonorProfileRepository _donorProfileRepo = DonorProfileRepository();
  Map<String, dynamic>? _profile;
  VoterFileRecord? _voterRecord;
  DonorEnrichmentRecord? _enrichmentRecord;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_supabase.isInitialized) {
      setState(() => _loading = false);
      return;
    }
    try {
      final dynamic resp;
      if (widget.donorId != null) {
        resp = await _supabase.client.rpc(
          'get_donor_profile_by_id',
          params: {'p_donor_id': widget.donorId},
        );
      } else {
        resp = await _supabase.client.rpc(
          'get_donor_profile_by_natural_key',
          params: {
            'p_first_name': widget.firstName,
            'p_last_name': widget.lastName,
            'p_city': widget.city,
            'p_state': widget.state,
          },
        );
      }
      if (mounted) {
        setState(() {
          _profile = resp is Map<String, dynamic> ? resp : null;
          _loading = false;
        });
      }

      // Kick off voter-file + enrichment lookups in parallel after the
      // base profile is shown. If either key is missing or the query
      // returns nothing, the corresponding card simply isn't rendered —
      // this is the primary fix for the "MECDonorScreen is enrichment-blind"
      // audit finding.
      final profile = _profile;
      if (profile != null) {
        final voterId = profile['mo_voter_file_id'] as String?;
        final profileId = profile['id'] as String? ?? profile['profile_id'] as String?;

        final futures = <Future<dynamic>>[];
        futures.add(VoterFileService.fetchRecord(voterId));
        if (profileId != null && profileId.isNotEmpty) {
          futures.add(_donorProfileRepo.fetchEnrichmentRecord(profileId));
        } else {
          futures.add(Future.value(null));
        }
        final results = await Future.wait(futures);
        if (!mounted) return;
        setState(() {
          _voterRecord = results[0] as VoterFileRecord?;
          _enrichmentRecord = results[1] as DonorEnrichmentRecord?;
        });
      }
    } catch (e) {
      debugPrint('❌ MECDonorScreen load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _openCandidate(String candidateId) async {
    final cand = await _candidateRepo.fetchCandidate(candidateId);
    if (!mounted || cand == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CandidateDetailScreen(candidate: cand),
    ));
  }

  void _openCommittee(String mecId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MECCommitteeScreen(mecId: mecId),
    ));
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _profile = null;
    });
    await _load();
  }

  void _copyDonorName() {
    final name = '${widget.firstName} ${widget.lastName}'.trim();
    final loc = [widget.city, widget.state]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
    final full = loc.isEmpty ? name : '$name ($loc)';
    Clipboard.setData(ClipboardData(text: full));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Donor identity copied: $full'),
        duration: const Duration(seconds: 2),
        backgroundColor: BrandColors.momentumBlue,
      ),
    );
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
              _header(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  color: BrandColors.sunriseGold,
                  backgroundColor: BrandColors.unityBlue,
                  child: _loading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [CandidateUI.shimmerSkeleton(cardCount: 4)],
                        )
                      : _profile == null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.6,
                                  child: CandidateUI.emptyState(
                                    _loadError != null
                                        ? Icons.error_outline
                                        : Icons.person_off,
                                    _loadError != null
                                        ? 'Failed to load donor'
                                        : 'Not Found',
                                    _loadError != null
                                        ? 'RPC error: $_loadError'
                                        : 'No donor data for ${widget.firstName} ${widget.lastName}'
                                            '${(widget.city?.isNotEmpty ?? false) ? " from ${widget.city}, ${widget.state ?? ""}" : ""}.',
                                  ),
                                ),
                              ],
                            )
                          : _content(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final name = '${widget.firstName} ${widget.lastName}'.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Back',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if ((widget.city ?? '').isNotEmpty || (widget.state ?? '').isNotEmpty)
                  Text(
                    [widget.city, widget.state].where((s) => s != null && s.isNotEmpty).join(', '),
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: const Icon(Icons.ios_share, color: Colors.white70),
              onPressed: _profile == null ? null : _copyDonorName,
              tooltip: 'Copy donor identity',
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final p = _profile!;
    final name = '${widget.firstName} ${widget.lastName}'.trim();
    final totalGiven = _asDouble(p['total_given']);
    final count = _asInt(p['contribution_count']);
    final uniqueComms = _asInt(p['unique_committees']);
    final uniqueCands = _asInt(p['unique_candidates']);
    final employer = p['employer'] as String? ?? widget.employerHint ?? '';
    final occupation = p['occupation'] as String? ?? '';
    final firstDate = p['first_contribution'] as String?;
    final lastDate = p['last_contribution'] as String?;
    final location = [widget.city, widget.state].where((s) => s != null && s!.isNotEmpty).join(', ');
    final byCommittee = (p['by_committee'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final byCandidate = (p['by_candidate'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final recent = (p['recent_contributions'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    final isMobile = MediaQuery.of(context).size.width < 600;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 12, isMobile ? 12 : 16, 40),
      children: [
        // ── Hero ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [BrandColors.sunriseGold.withOpacity(0.18), Colors.white.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: BrandColors.sunriseGold.withOpacity(0.25),
                  child: Text(name.isNotEmpty ? name[0] : '?',
                      style: const TextStyle(color: BrandColors.sunriseGold, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      if (location.isNotEmpty)
                        Text(location, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                      if (employer.isNotEmpty)
                        Text('${occupation.isNotEmpty ? occupation : "Worked at"} $employer'.trim(),
                            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _statChip('Total Given', '\$${CandidateUI.formatMoney(totalGiven)}', BrandColors.sunriseGold),
                const SizedBox(width: 8),
                _statChip('Gifts', '$count', BrandColors.momentumBlue),
                const SizedBox(width: 8),
                _statChip(uniqueComms == 1 ? 'Committee' : 'Committees', '$uniqueComms', BrandColors.steelBlue),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _statChip('Candidates', '$uniqueCands', BrandColors.democratBlue),
                const SizedBox(width: 8),
                _statChip('Avg Gift',
                    count > 0 ? '\$${CandidateUI.formatMoney(totalGiven / count)}' : '—',
                    Colors.purpleAccent),
                const SizedBox(width: 8),
                _statChip('Span',
                    (firstDate != null && lastDate != null) ? '${_year(firstDate)}–${_year(lastDate)}' : '—',
                    BrandColors.success),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Candidates donated to — tappable ──
        if (byCandidate.isNotEmpty) ...[
          CandidateUI.card('Candidates Supported (${byCandidate.length})',
              Icons.how_to_vote, BrandColors.democratBlue,
              child: Column(children: [
                const SizedBox(height: 8),
                ...byCandidate.map((cand) => _candidateRow(cand)),
              ])),
          const SizedBox(height: 16),
        ],

        // ── Committees donated to — tappable ──
        if (byCommittee.isNotEmpty) ...[
          CandidateUI.card('Committees Given To (${byCommittee.length})',
              Icons.account_balance, BrandColors.steelBlue,
              child: Column(children: [
                const SizedBox(height: 8),
                ...byCommittee.map((com) => _committeeRow(com)),
              ])),
          const SizedBox(height: 16),
        ],

        // ── Recent contributions log ──
        CandidateUI.card('Recent Contributions (showing ${recent.length} of $count)',
            Icons.receipt_long, Colors.white.withOpacity(0.4),
            child: Column(children: [
              const SizedBox(height: 8),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No contributions on record',
                      style: TextStyle(color: Colors.white.withOpacity(0.5))),
                )
              else
                ...recent.map((contrib) => _contributionRow(contrib)),
            ])),

        // ── MO Voter File (lazy, post-profile) ──
        if (_voterRecord != null) ...[
          const SizedBox(height: 16),
          VoterFileCard(record: _voterRecord!, showDebug: kDebugMode),
        ],

        // ── Donor Enrichment (skipped entirely when populatedFields empty) ──
        if (_enrichmentRecord != null && _enrichmentRecord!.hasData) ...[
          const SizedBox(height: 16),
          DonorEnrichmentCard(record: _enrichmentRecord!),
        ],
      ],
    );
  }

  Widget _candidateRow(Map<String, dynamic> cand) {
    final cid = cand['candidate_id'] as String?;
    final name = cand['candidate_name'] as String? ?? '';
    final party = (cand['candidate_party'] as String? ?? '').toLowerCase();
    final amount = _asDouble(cand['total']);
    final count = _asInt(cand['count']);
    Color partyColor;
    if (party.contains('dem')) partyColor = BrandColors.democratBlue;
    else if (party.contains('rep')) partyColor = BrandColors.republicanRed;
    else partyColor = Colors.grey;

    return Material(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: cid != null ? () => _openCandidate(cid) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: partyColor.withOpacity(0.3)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: partyColor.withOpacity(0.25),
              child: Text(name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(color: partyColor, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('$count gift${count == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                ],
              ),
            ),
            Text('\$${CandidateUI.formatMoney(amount)}',
                style: const TextStyle(
                    color: BrandColors.sunriseGold, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
          ]),
        ),
      ),
    );
  }

  Widget _committeeRow(Map<String, dynamic> com) {
    final mecId = com['mec_id'] as String? ?? '';
    final name = com['committee_name'] as String? ?? mecId;
    final amount = _asDouble(com['total']);
    final count = _asInt(com['count']);
    final first = com['first_given'] as String?;
    final last = com['last_given'] as String?;

    return Material(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: mecId.isNotEmpty ? () => _openCommittee(mecId) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BrandColors.steelBlue.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.account_balance, color: BrandColors.steelBlue, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    [
                      'MEC $mecId',
                      '$count gift${count == 1 ? '' : 's'}',
                      if (first != null && last != null) '${_year(first)}–${_year(last)}',
                    ].join(' · '),
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                  ),
                ],
              ),
            ),
            Text('\$${CandidateUI.formatMoney(amount)}',
                style: const TextStyle(color: BrandColors.success, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
          ]),
        ),
      ),
    );
  }

  Widget _contributionRow(Map<String, dynamic> c) {
    final amount = _asDouble(c['contribution_amount']);
    final date = c['contribution_date'] as String? ?? '';
    final committee = c['committee_name'] as String? ?? '';
    final mecId = c['mec_id'] as String? ?? '';
    final type = c['monetary_or_inkind'] as String? ?? '';
    final candidateName = c['candidate_name'] as String? ?? '';

    return Material(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: mecId.isNotEmpty ? () => _openCommittee(mecId) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(committee,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    [date, if (candidateName.isNotEmpty) candidateName].join(' · '),
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                amount > 0 ? '\$${CandidateUI.formatMoney(amount)}' : (type.isNotEmpty ? type : 'In-Kind'),
                style: TextStyle(
                  color: amount > 0 ? BrandColors.success : Colors.white.withOpacity(0.7),
                  fontSize: 13, fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  String _year(String isoDate) {
    if (isoDate.length < 4) return isoDate;
    return isoDate.substring(0, 4);
  }
}
