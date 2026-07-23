import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/screens/crm/intelligence_profile_section.dart';
import 'package:bluebubbles/screens/crm/mec_committee_screen.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Full history for a MEC expenditure payee — every committee that paid this
/// payee (or vendor) across all time, aggregated via
/// get_payee_profile_by_natural_key. Mirrors MECDonorScreen on the contribution
/// side.
///
/// Individual payee: pass firstName + lastName.
/// Vendor / company payee: pass company (leave firstName/lastName empty).
class MECPayeeScreen extends StatefulWidget {
  final String? firstName;
  final String? lastName;
  final String? company;
  final String? city;
  final String? state;

  const MECPayeeScreen({
    super.key,
    this.firstName,
    this.lastName,
    this.company,
    this.city,
    this.state,
  }) : assert(
          (lastName != null && lastName.length > 0) ||
              (company != null && company.length > 0),
          'MECPayeeScreen requires either lastName or company',
        );

  @override
  State<MECPayeeScreen> createState() => _MECPayeeScreenState();
}

class _MECPayeeScreenState extends State<MECPayeeScreen> {
  final CRMSupabaseService _supabase = CRMSupabaseService();
  final CandidateRepository _candidateRepo = CandidateRepository();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _loadError;

  bool get _isCompany => (widget.company ?? '').trim().isNotEmpty;

  String get _displayName => _isCompany
      ? widget.company!.trim()
      : '${widget.firstName ?? ''} ${widget.lastName ?? ''}'.trim();

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
      final resp = await _supabase.client.rpc(
        'get_payee_profile_by_natural_key',
        params: {
          'p_first_name': widget.firstName,
          'p_last_name': widget.lastName,
          'p_company': widget.company,
          'p_city': widget.city,
          'p_state': widget.state,
        },
      );
      if (mounted) {
        setState(() {
          _profile = resp is Map<String, dynamic> ? resp : null;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('MECPayeeScreen load error: $e');
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

  void _copyPayeeIdentity() {
    Clipboard.setData(ClipboardData(text: _displayName));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $_displayName'),
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
                                        : Icons.storefront_outlined,
                                    _loadError != null
                                        ? 'Failed to load payee'
                                        : 'Not Found',
                                    _loadError != null
                                        ? 'RPC error: $_loadError'
                                        : 'No expenditure records found for $_displayName.',
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
                Text(_displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if ((widget.city ?? '').isNotEmpty || (widget.state ?? '').isNotEmpty)
                  Text(
                    [widget.city, widget.state].where((s) => s != null && s!.isNotEmpty).join(', '),
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
              onPressed: _profile == null ? null : _copyPayeeIdentity,
              tooltip: 'Copy payee identity',
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final p = _profile!;
    final totalPaid = _asDouble(p['total_paid']);
    final count = _asInt(p['expenditure_count']);
    final uniqueComms = _asInt(p['unique_committees']);
    final uniqueCands = _asInt(p['unique_candidates']);
    final firstDate = p['first_payment'] as String?;
    final lastDate = p['last_payment'] as String?;
    final location = [widget.city, widget.state].where((s) => s != null && s!.isNotEmpty).join(', ');
    final byCommittee = (p['by_committee'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final byCandidate = (p['by_candidate'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final byPurpose = (p['by_purpose'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final recent = (p['recent_expenditures'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    final heroColor = _isCompany ? BrandColors.sunriseGold : BrandColors.momentumBlue;
    final heroIcon = _isCompany ? Icons.storefront : Icons.person_outline;

    final isMobile = MediaQuery.of(context).size.width < 600;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 12, isMobile ? 12 : 16, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [heroColor.withOpacity(0.18), Colors.white.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: heroColor.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: heroColor.withOpacity(0.25),
                  child: Icon(heroIcon, color: heroColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      Text(_isCompany ? 'Vendor / Company' : 'Individual payee',
                          style: TextStyle(color: heroColor.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                      if (location.isNotEmpty)
                        Text(location, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                _statChip('Total Paid', '\$${CandidateUI.formatMoney(totalPaid)}', BrandColors.sunriseGold),
                const SizedBox(width: 8),
                _statChip('Payments', '$count', BrandColors.momentumBlue),
                const SizedBox(width: 8),
                _statChip(uniqueComms == 1 ? 'Committee' : 'Committees', '$uniqueComms', BrandColors.steelBlue),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _statChip('Candidates', '$uniqueCands', BrandColors.democratBlue),
                const SizedBox(width: 8),
                _statChip('Avg Payment',
                    count > 0 ? '\$${CandidateUI.formatMoney(totalPaid / count)}' : '—',
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

        // ── Intelligence Profile — payee entity_key is the normalized payee
        // name, which equals the raw payee_company value in the aggregate. ──
        IntelligenceProfileSection(
          entityType: 'payee',
          entityKey: widget.company,
          accentColor: _isCompany
              ? BrandColors.sunriseGold
              : BrandColors.momentumBlue,
        ),
        const SizedBox(height: 16),

        if (byCandidate.isNotEmpty) ...[
          CandidateUI.card('Candidates Who Paid (${byCandidate.length})',
              Icons.how_to_vote, BrandColors.democratBlue,
              child: Column(children: [
                const SizedBox(height: 8),
                ...byCandidate.map(_candidateRow),
              ])),
          const SizedBox(height: 16),
        ],

        if (byCommittee.isNotEmpty) ...[
          CandidateUI.card('Committees Who Paid (${byCommittee.length})',
              Icons.account_balance, BrandColors.steelBlue,
              child: Column(children: [
                const SizedBox(height: 8),
                ...byCommittee.map(_committeeRow),
              ])),
          const SizedBox(height: 16),
        ],

        if (byPurpose.isNotEmpty) ...[
          CandidateUI.card('Spent On (${byPurpose.length} categories)',
              Icons.pie_chart, Colors.amber,
              child: Column(children: [
                const SizedBox(height: 8),
                ...byPurpose.take(12).map(_purposeRow),
              ])),
          const SizedBox(height: 16),
        ],

        CandidateUI.card('Recent Payments (showing ${recent.length} of $count)',
            Icons.receipt_long, Colors.white.withOpacity(0.4),
            child: Column(children: [
              const SizedBox(height: 8),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No payments on record',
                      style: TextStyle(color: Colors.white.withOpacity(0.5))),
                )
              else
                ...recent.map(_expenditureRow),
            ])),
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
    if (party.contains('dem')) {
      partyColor = BrandColors.democratBlue;
    } else if (party.contains('rep')) {
      partyColor = BrandColors.republicanRed;
    } else {
      partyColor = Colors.grey;
    }

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
                  Text('$count payment${count == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                ],
              ),
            ),
            Text('\$${CandidateUI.formatMoney(amount)}',
                style: const TextStyle(color: BrandColors.sunriseGold, fontSize: 14, fontWeight: FontWeight.w700)),
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
    final first = com['first_paid'] as String?;
    final last = com['last_paid'] as String?;

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
                      '$count payment${count == 1 ? '' : 's'}',
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

  Widget _purposeRow(Map<String, dynamic> p) {
    final purpose = p['purpose'] as String? ?? '(unspecified)';
    final amount = _asDouble(p['total']);
    final count = _asInt(p['count']);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Expanded(
          child: Text(purpose,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text('$count × ', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
        Text('\$${CandidateUI.formatMoney(amount)}',
            style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _expenditureRow(Map<String, dynamic> e) {
    final amount = _asDouble(e['expenditure_amount']);
    final date = e['expenditure_date'] as String? ?? '';
    final committee = e['committee_name'] as String? ?? '';
    final mecId = e['mec_id'] as String? ?? '';
    final purpose = e['expenditure_purpose'] as String? ?? '';
    final candidateName = e['candidate_name'] as String? ?? '';

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
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    [date, if (candidateName.isNotEmpty) candidateName, if (purpose.isNotEmpty) purpose]
                        .join(' · '),
                    style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 84,
              child: Text(
                '\$${CandidateUI.formatMoney(amount)}',
                style: const TextStyle(
                  color: BrandColors.sunriseGold,
                  fontSize: 13, fontWeight: FontWeight.w700,
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
