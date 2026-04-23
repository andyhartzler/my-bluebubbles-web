import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/screens/crm/candidate_detail_screen.dart';
import 'package:bluebubbles/screens/crm/mec_donor_screen.dart';
import 'package:bluebubbles/screens/crm/mec_payee_screen.dart';
import 'package:bluebubbles/services/crm/candidate_repository.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Full committee profile page. From a donor screen you can click any
/// committee they've given to → land here → see the committee's top
/// donors → click any top donor → land on THEIR profile → and so on.
/// Everything is exploratory.
class MECCommitteeScreen extends StatefulWidget {
  final String mecId;

  const MECCommitteeScreen({super.key, required this.mecId});

  @override
  State<MECCommitteeScreen> createState() => _MECCommitteeScreenState();
}

class _MECCommitteeScreenState extends State<MECCommitteeScreen> {
  final CRMSupabaseService _supabase = CRMSupabaseService();
  final CandidateRepository _repo = CandidateRepository();
  Map<String, dynamic>? _data;
  bool _loading = true;

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
      final resp = await _supabase.privilegedClient.rpc(
        'get_committee_full_profile',
        params: {'p_mec_id': widget.mecId},
      );
      if (mounted) {
        setState(() {
          _data = resp is Map<String, dynamic> ? resp : null;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ MECCommitteeScreen load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  void _openDonor(Map<String, dynamic> donor) {
    final first = donor['first_name'] as String? ?? '';
    final last = donor['last_name'] as String? ?? '';
    if (first.isEmpty && last.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => MECDonorScreen(
        firstName: first,
        lastName: last,
        city: donor['city'] as String?,
        state: donor['state'] as String?,
      ),
    ));
  }

  Future<void> _openCandidate(String candidateId) async {
    final cand = await _repo.fetchCandidate(candidateId);
    if (!mounted || cand == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CandidateDetailScreen(candidate: cand),
    ));
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _data = null;
    });
    await _load();
  }

  void _copyMecId() {
    Clipboard.setData(ClipboardData(text: widget.mecId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('MEC ID ${widget.mecId} copied'),
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
                      : _data == null
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.6,
                                  child: CandidateUI.emptyState(
                                    Icons.search_off,
                                    'Not Found',
                                    'No committee data found for ${widget.mecId}.',
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
    final committee = _data?['committee'] as Map<String, dynamic>?;
    final name = committee?['committee_name'] as String? ?? 'Committee';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(children: [
        // 48×48 back button (Material minimum).
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
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('MEC ${widget.mecId}',
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
            ],
          ),
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            icon: const Icon(Icons.copy_all, color: Colors.white70),
            onPressed: _copyMecId,
            tooltip: 'Copy MEC ID',
          ),
        ),
      ]),
    );
  }

  Widget _content() {
    final committee = _data?['committee'] as Map<String, dynamic>?;
    final candidate = _data?['candidate'] as Map<String, dynamic>?;
    final totals = _data?['totals'] as Map<String, dynamic>?;
    final expTotals = _data?['expenditure_totals'] as Map<String, dynamic>?;
    final topDonors = (_data?['top_donors'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final topPayees = (_data?['top_payees'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final recentExp = (_data?['recent_expenditures'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final recentContrib = (_data?['recent_contributions'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    final totalRaised = _asDouble(totals?['total_raised']);
    final totalSpent = _asDouble(expTotals?['total_spent']);
    final count = _asInt(totals?['contribution_count']);
    final uniqueDonors = _asInt(totals?['unique_donors']);

    final isMobile = MediaQuery.of(context).size.width < 600;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, 8, isMobile ? 12 : 16, 40),
      children: [
        _heroCard(committee, totalRaised, count, uniqueDonors, totalSpent),
        if (candidate != null) ...[
          const SizedBox(height: 16),
          _candidateCard(candidate),
        ],
        const SizedBox(height: 16),
        if (topDonors.isNotEmpty) ...[
          CandidateUI.card('Top Donors (${topDonors.length})',
              Icons.star, BrandColors.sunriseGold,
              child: Column(children: [
                const SizedBox(height: 8),
                ...topDonors.map((d) => _donorRow(d, totalRaised)),
              ])),
          const SizedBox(height: 16),
        ],
        if (topPayees.isNotEmpty) ...[
          CandidateUI.card('Top Payees (${topPayees.length})',
              Icons.payments, Colors.purpleAccent,
              child: Column(children: [
                const SizedBox(height: 8),
                ...topPayees.map((p) => _payeeRow(p)),
              ])),
          const SizedBox(height: 16),
        ],
        if (recentExp.isNotEmpty) ...[
          CandidateUI.card('Recent Expenditures (${recentExp.length})',
              Icons.receipt_long, BrandColors.republicanRed,
              child: Column(children: [
                const SizedBox(height: 8),
                ...recentExp.map(_expenditureRow),
              ])),
          const SizedBox(height: 16),
        ],
        if (recentContrib.isNotEmpty)
          CandidateUI.card('Recent Contributions (${recentContrib.length})',
              Icons.volunteer_activism, BrandColors.success,
              child: Column(children: [
                const SizedBox(height: 8),
                ...recentContrib.map(_contributionRow),
              ])),
      ],
    );
  }

  Widget _expenditureRow(Map<String, dynamic> e) {
    final amount = _asDouble(e['expenditure_amount']);
    final date = e['expenditure_date'] as String? ?? '';
    final purpose = e['expenditure_purpose'] as String? ?? '';
    final first = (e['payee_first_name'] as String? ?? '').trim();
    final last = (e['payee_last_name'] as String? ?? '').trim();
    final company = (e['payee_company'] as String? ?? '').trim();
    final city = (e['city'] as String? ?? '').trim();
    final state = (e['state'] as String? ?? '').trim();
    final displayName = company.isNotEmpty ? company : '${first.isNotEmpty ? '$first ' : ''}$last'.trim();
    final canOpen = company.isNotEmpty || last.isNotEmpty;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: canOpen
            ? () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MECPayeeScreen(
                    firstName: first.isNotEmpty ? first : null,
                    lastName: last.isNotEmpty ? last : null,
                    company: company.isNotEmpty ? company : null,
                    city: city.isNotEmpty ? city : null,
                    state: state.isNotEmpty ? state : null,
                  ),
                ))
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName.isEmpty ? '(no payee)' : displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text([date, if (purpose.isNotEmpty) purpose].join(' · '),
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 80,
              child: Text(
                '\$${CandidateUI.formatMoney(amount)}',
                style: const TextStyle(color: BrandColors.republicanRed, fontSize: 13, fontWeight: FontWeight.w700),
                textAlign: TextAlign.right,
              ),
            ),
            if (canOpen) const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(Icons.chevron_right, color: Colors.white38, size: 16),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _contributionRow(Map<String, dynamic> c) {
    final amount = _asDouble(c['contribution_amount']);
    final date = c['contribution_date'] as String? ?? '';
    final first = (c['contributor_first_name'] as String? ?? '').trim();
    final last = (c['contributor_last_name'] as String? ?? '').trim();
    final comm = (c['contributor_committee'] as String? ?? '').trim();
    final company = (c['contributor_company'] as String? ?? '').trim();
    final city = (c['city'] as String? ?? '').trim();
    final state = (c['state'] as String? ?? '').trim();
    final employer = c['employer'] as String? ?? '';
    final isIndividual = last.isNotEmpty;
    final displayName = isIndividual
        ? '${first.isNotEmpty ? '$first ' : ''}$last'.trim()
        : (comm.isNotEmpty ? comm : (company.isNotEmpty ? company : '(unknown)'));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isIndividual
            ? () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MECDonorScreen(
                    firstName: first,
                    lastName: last,
                    city: city.isNotEmpty ? city : null,
                    state: state.isNotEmpty ? state : null,
                    employerHint: employer.isNotEmpty ? employer : null,
                  ),
                ))
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text([date, if (employer.isNotEmpty) employer].join(' · '),
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 80,
              child: Text(
                '\$${CandidateUI.formatMoney(amount)}',
                style: const TextStyle(color: BrandColors.success, fontSize: 13, fontWeight: FontWeight.w700),
                textAlign: TextAlign.right,
              ),
            ),
            if (isIndividual) const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(Icons.chevron_right, color: Colors.white38, size: 16),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _heroCard(Map<String, dynamic>? committee, double raised, int count, int donors, double spent) {
    final name = committee?['committee_name'] as String? ?? widget.mecId;
    final treasurer = committee?['treasurer_name'] as String?;
    final status = committee?['committee_status'] as String?;
    final party = committee?['party_affiliation'] as String?;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [BrandColors.steelBlue.withOpacity(0.18), Colors.white.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.steelBlue.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: BrandColors.steelBlue.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance, color: BrandColors.steelBlue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                if (treasurer != null && treasurer.isNotEmpty)
                  Text('Treasurer: $treasurer',
                      style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12)),
              ],
            ),
          ),
        ]),
        if (status != null || party != null) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            if (party != null && party.isNotEmpty) _chip(party, BrandColors.democratBlue),
            if (status != null && status.isNotEmpty) _chip(status, Colors.white30),
          ]),
        ],
        const SizedBox(height: 14),
        Row(children: [
          _statChip('Raised', '\$${CandidateUI.formatMoney(raised)}', BrandColors.success),
          const SizedBox(width: 8),
          _statChip('Spent', '\$${CandidateUI.formatMoney(spent)}', BrandColors.republicanRed),
          const SizedBox(width: 8),
          _statChip('Donors', '$donors', BrandColors.sunriseGold),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _statChip('Gifts', '$count', BrandColors.momentumBlue),
          const SizedBox(width: 8),
          _statChip(
            'Avg Gift',
            count > 0 ? '\$${CandidateUI.formatMoney(raised / count)}' : '—',
            Colors.purpleAccent,
          ),
          const SizedBox(width: 8),
          _statChip('Net',
              '\$${CandidateUI.formatMoney(raised - spent)}',
              raised - spent >= 0 ? BrandColors.success : BrandColors.republicanRed),
        ]),
      ]),
    );
  }

  Widget _candidateCard(Map<String, dynamic> cand) {
    final id = cand['id'] as String?;
    final name = cand['name'] as String? ?? '';
    final office = cand['office'] as String? ?? '';
    final district = cand['district'] as String? ?? '';
    final party = (cand['party'] as String? ?? '').toLowerCase();
    final photoUrl = cand['photo_url'] as String?;
    final incumbent = cand['incumbent'] == true;

    Color partyColor;
    if (party.contains('dem')) partyColor = BrandColors.democratBlue;
    else if (party.contains('rep')) partyColor = BrandColors.republicanRed;
    else partyColor = Colors.grey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: id != null ? () => _openCandidate(id) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: partyColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: partyColor.withOpacity(0.35)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: partyColor.withOpacity(0.25),
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? Text(name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(color: partyColor, fontSize: 18, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (incumbent) ...[
                      const SizedBox(width: 6),
                      _chip('INCUMBENT', BrandColors.sunriseGold),
                    ],
                  ]),
                  Text([office, if (district.isNotEmpty) 'D-$district'].where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _donorRow(Map<String, dynamic> d, double totalRaised) {
    final name = (d['donor_name'] as String? ?? '').trim();
    final company = d['company'] as String? ?? '';
    final city = d['city'] as String? ?? '';
    final state = d['state'] as String? ?? '';
    final amount = _asDouble(d['total_amount']);
    final count = _asInt(d['contribution_count']);
    final displayName = name.isNotEmpty ? name : (company.isNotEmpty ? company : 'Anonymous');
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');
    final ratio = totalRaised > 0 ? amount / totalRaised : 0.0;

    return Material(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: name.isNotEmpty ? () => _openDonor(d) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.15)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text([if (location.isNotEmpty) location, '$count gift${count == 1 ? '' : 's'}'].join(' · '),
                        style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
                  ],
                ),
              ),
              Text('\$${CandidateUI.formatMoney(amount)}',
                  style: const TextStyle(color: BrandColors.sunriseGold, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 3,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(BrandColors.sunriseGold.withOpacity(0.75)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _payeeRow(Map<String, dynamic> p) {
    final name = p['payee_name'] as String? ?? 'Unknown';
    final amount = _asDouble(p['total_amount']);
    final count = _asInt(p['payment_count']);
    final firstName = (p['payee_first_name'] as String? ?? '').trim();
    final lastName = (p['payee_last_name'] as String? ?? '').trim();
    final company = (p['payee_company'] as String? ?? '').trim();
    final city = (p['city'] as String? ?? '').trim();
    final state = (p['state'] as String? ?? '').trim();
    final canOpen = company.isNotEmpty || lastName.isNotEmpty;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: canOpen
            ? () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MECPayeeScreen(
                    firstName: firstName.isNotEmpty ? firstName : null,
                    lastName: lastName.isNotEmpty ? lastName : null,
                    company: company.isNotEmpty ? company : null,
                    city: city.isNotEmpty ? city : null,
                    state: state.isNotEmpty ? state : null,
                  ),
                ))
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('$count payment${count == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                ],
              ),
            ),
            Text('\$${CandidateUI.formatMoney(amount)}',
                style: const TextStyle(color: Colors.purpleAccent, fontSize: 13, fontWeight: FontWeight.w600)),
            if (canOpen) const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.chevron_right, color: Colors.white38, size: 16),
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
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.45), width: 0.8),
      ),
      child: Text(label.toUpperCase(),
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
    );
  }
}

