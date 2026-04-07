import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/screens/crm/candidate_ui_helpers.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

/// Screen showing an MEC donor's full contribution history.
/// Uses mec_donors table directly — not dependent on the 49-row donor_profiles table.
class MECDonorScreen extends StatefulWidget {
  final int donorId;

  const MECDonorScreen({super.key, required this.donorId});

  @override
  State<MECDonorScreen> createState() => _MECDonorScreenState();
}

class _MECDonorScreenState extends State<MECDonorScreen> {
  final CRMSupabaseService _supabase = CRMSupabaseService();
  Map<String, dynamic>? _donor;
  List<Map<String, dynamic>> _contributions = [];
  List<Map<String, dynamic>> _candidates = [];
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
      // Fetch donor info from mec_donors
      final donorResp = await _supabase.privilegedClient
          .from('mec_donors')
          .select()
          .eq('id', widget.donorId)
          .maybeSingle();

      // Fetch their contributions (last 200)
      final contribResp = await _supabase.privilegedClient
          .from('mec_contributions')
          .select('mec_id, committee_name, contribution_amount, contribution_date, monetary_or_inkind')
          .eq('donor_id', widget.donorId)
          .order('contribution_date', ascending: false)
          .limit(200);

      // Fetch candidates they donated to
      final candidatesResp = await _supabase.privilegedClient.rpc(
        'get_donor_candidates',
        params: {'p_donor_id': widget.donorId},
      );

      if (mounted) {
        setState(() {
          _donor = donorResp as Map<String, dynamic>?;
          _contributions = (contribResp as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
          _candidates = (candidatesResp is List ? candidatesResp.cast<Map<String, dynamic>>() : []);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ MECDonorScreen load error: $e');
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
                    : _donor == null
                        ? CandidateUI.emptyState(Icons.person_off, 'Not Found', 'No donor data found.')
                        : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _donor != null
        ? '${_donor!['first_name'] ?? ''} ${_donor!['last_name'] ?? ''}'.trim()
        : 'Donor';
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
            child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final d = _donor!;
    final name = '${d['first_name'] ?? ''} ${d['last_name'] ?? ''}'.trim();
    final company = d['company_name'] as String? ?? '';
    final city = d['city'] as String? ?? '';
    final state = d['state'] as String? ?? '';
    final employer = d['employer'] as String? ?? '';
    final occupation = d['occupation'] as String? ?? '';
    final totalContributed = (d['total_contributed'] as num?)?.toDouble() ?? 0;
    final contributionCount = (d['contribution_count'] as num?)?.toInt() ?? 0;
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Hero card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [BrandColors.sunriseGold.withOpacity(0.15), Colors.white.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: BrandColors.sunriseGold.withOpacity(0.2),
                    child: Text(name.isNotEmpty ? name[0] : '?',
                        style: const TextStyle(color: BrandColors.sunriseGold, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isNotEmpty ? name : company,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        if (location.isNotEmpty)
                          Text(location, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                        if (employer.isNotEmpty)
                          Text('$occupation${occupation.isNotEmpty && employer.isNotEmpty ? " at " : ""}$employer',
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statChip('Total Given', '\$${CandidateUI.formatMoney(totalContributed)}', BrandColors.sunriseGold),
                  const SizedBox(width: 8),
                  _statChip('Contributions', '$contributionCount', BrandColors.momentumBlue),
                  const SizedBox(width: 8),
                  _statChip('Avg Gift', contributionCount > 0
                      ? '\$${CandidateUI.formatMoney(totalContributed / contributionCount)}'
                      : '—', BrandColors.steelBlue),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Candidates donated to
        if (_candidates.isNotEmpty) ...[
          CandidateUI.card('Candidates Donated To', Icons.how_to_vote, BrandColors.democratBlue, child: Column(
            children: [
              const SizedBox(height: 8),
              ..._candidates.map((c) {
                final candName = c['name'] as String? ?? '';
                final party = c['party'] as String? ?? '';
                final office = c['office'] as String? ?? '';
                final amount = (c['total_amount'] as num?)?.toDouble() ?? 0;
                final candId = c['candidate_id'] as String?;
                final photoUrl = c['photo_url'] as String?;

                Color partyColor;
                if (party.contains('Dem')) partyColor = BrandColors.democratBlue;
                else if (party.contains('Rep')) partyColor = BrandColors.republicanRed;
                else partyColor = Colors.grey;

                return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: partyColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: partyColor.withOpacity(0.2),
                          backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null || photoUrl.isEmpty
                              ? Text(candName.isNotEmpty ? candName[0] : '?',
                                  style: TextStyle(color: partyColor, fontWeight: FontWeight.bold, fontSize: 14))
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(candName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              Text('$party • $office', style: TextStyle(color: partyColor.withOpacity(0.8), fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('\$${CandidateUI.formatMoney(amount)}',
                            style: const TextStyle(color: BrandColors.sunriseGold, fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
              }),
            ],
          )),
          const SizedBox(height: 16),
        ],

        // Full contribution history
        CandidateUI.card('Contribution History (${_contributions.length})', Icons.receipt_long, BrandColors.steelBlue, child: Column(
          children: [
            const SizedBox(height: 8),
            if (_contributions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No contributions found', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              )
            else
              ..._contributions.map((c) {
                final amount = (c['contribution_amount'] as num?)?.toDouble() ?? 0;
                final date = c['contribution_date'] as String? ?? '';
                final committee = c['committee_name'] as String? ?? '';
                final type = c['monetary_or_inkind'] as String? ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(committee, style: const TextStyle(color: Colors.white, fontSize: 12),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(date, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          amount > 0 ? '\$${CandidateUI.formatMoney(amount)}' : type.isNotEmpty ? type : 'In-Kind',
                          style: TextStyle(
                            color: amount > 0 ? BrandColors.success : Colors.white.withOpacity(0.6),
                            fontSize: 13, fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
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

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
