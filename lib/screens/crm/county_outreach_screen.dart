import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/ge_nominee_repository.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';

import 'bulk_email_screen.dart';
import 'bulk_message_screen.dart';

/// County Outreach — the Candidate Volunteers workspace.
///
/// Pick one or more counties, see everyone who lives there, select all of them
/// or hand-pick specific people, and send a text OR an email through the same
/// BlueBubbles / email paths the rest of the CRM uses. Each person is shown
/// with the Democrat they can be connected to in November — their congressional
/// nominee always, and their state house / senate nominee where we know the
/// member's district and that seat is on the 2026 ballot.
///
/// It NEVER invents a candidate match. The nominees come from the official
/// August 4 primary results (top Democrat per race); where a member's state
/// district is unknown, the row simply shows the races we can prove rather than
/// guessing.
class CountyOutreachScreen extends StatefulWidget {
  const CountyOutreachScreen({super.key});

  @override
  State<CountyOutreachScreen> createState() => _CountyOutreachScreenState();
}

class _CountyOutreachScreenState extends State<CountyOutreachScreen> {
  final _members = MemberRepository();
  final _nominees = GeNomineeRepository();

  List<String> _counties = [];
  Map<String, GeNominee> _nomineeLookup = const {};
  final Set<String> _selectedCounties = {};

  List<Member> _people = const [];
  final Set<String> _selectedPeople = {}; // member ids
  bool _loadingCounties = true;
  bool _loadingPeople = false;
  String _search = '';

  static const _navy = BrandColors.unityBlue;
  static const _gold = BrandColors.sunriseGold;
  static const _green = Color(0xFF43A047);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      _members.getUniqueCounties(),
      _nominees.getLookup(),
    ]);
    if (!mounted) return;
    setState(() {
      _counties = results[0] as List<String>;
      _nomineeLookup = results[1] as Map<String, GeNominee>;
      _loadingCounties = false;
    });
  }

  Future<void> _loadPeople() async {
    if (_selectedCounties.isEmpty) {
      setState(() {
        _people = const [];
        _selectedPeople.clear();
      });
      return;
    }
    setState(() => _loadingPeople = true);
    try {
      final people =
          await _members.getMembersInCounties(_selectedCounties.toList());
      if (!mounted) return;
      setState(() {
        _people = people;
        // Default: everyone selected. Picking counties then unchecking a few is
        // the common path; starting from all-selected matches that intent.
        _selectedPeople
          ..clear()
          ..addAll(people.map((m) => m.id));
        _loadingPeople = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPeople = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load members: $e')),
      );
    }
  }

  void _toggleCounty(String county) {
    setState(() {
      if (!_selectedCounties.add(county)) _selectedCounties.remove(county);
    });
    _loadPeople();
  }

  List<Member> get _visiblePeople {
    if (_search.trim().isEmpty) return _people;
    final q = _search.toLowerCase();
    return _people
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            (m.county ?? '').toLowerCase().contains(q))
        .toList();
  }

  List<Member> get _chosen =>
      _people.where((m) => _selectedPeople.contains(m.id)).toList();

  int get _textable => _chosen.where((m) => m.canContact).length;
  int get _emailable =>
      _chosen.where((m) => (m.preferredEmail ?? '').isNotEmpty).length;

  void _text() {
    final people = _chosen;
    if (people.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BulkMessageScreen(initialManualMembers: people),
    ));
  }

  void _email() {
    final people = _chosen;
    if (people.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BulkEmailScreen(initialManualMembers: people),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a2038), _navy],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: _loadingCounties
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    children: [
                      _header(),
                      const SizedBox(height: 16),
                      _countySection(),
                      const SizedBox(height: 20),
                      _peopleSection(),
                    ],
                  ),
          ),
          if (_selectedPeople.isNotEmpty) _sendBar(),
        ],
      ),
    );
  }

  Widget _header() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.campaign_outlined, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text('County Outreach',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick counties, choose who, and text or email them — with the '
            'Democrat on their November ballot.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
          ),
        ],
      );

  // ---- counties ----

  Widget _countySection() {
    return _card(
      title: 'Counties',
      trailing: _selectedCounties.isEmpty
          ? null
          : _pill('${_selectedCounties.length} selected'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _counties.map((c) {
              final on = _selectedCounties.contains(c);
              return _CountyChip(
                label: c,
                selected: on,
                onTap: () => _toggleCounty(c),
              );
            }).toList(),
          ),
          if (_selectedCounties.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                setState(_selectedCounties.clear);
                _loadPeople();
              },
              icon: const Icon(Icons.clear_all, size: 16, color: _gold),
              label: const Text('Clear counties',
                  style: TextStyle(color: _gold)),
              style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ],
        ],
      ),
    );
  }

  // ---- people ----

  Widget _peopleSection() {
    if (_selectedCounties.isEmpty) {
      return _card(
        title: 'Members',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('Pick a county above to see who lives there.',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      );
    }
    if (_loadingPeople) {
      return _card(
        title: 'Members',
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
              child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }
    final visible = _visiblePeople;
    return _card(
      title: 'Members',
      trailing: _pill('${_selectedPeople.length} of ${_people.length}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$_textable can be texted · $_emailable can be emailed',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => setState(() =>
                    _selectedPeople.addAll(_people.map((m) => m.id))),
                child: const Text('All',
                    style: TextStyle(color: _gold, fontSize: 13)),
              ),
              TextButton(
                onPressed: () => setState(_selectedPeople.clear),
                child: const Text('None',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search these members',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white54, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...visible.map(_personRow),
        ],
      ),
    );
  }

  Widget _personRow(Member m) {
    final on = _selectedPeople.contains(m.id);
    final match = GeNomineeRepository.matchFor(m, _nomineeLookup);
    final canText = m.canContact;
    final canEmail = (m.preferredEmail ?? '').isNotEmpty;

    return InkWell(
      onTap: () => setState(() {
        if (!_selectedPeople.add(m.id)) _selectedPeople.remove(m.id);
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(on ? Icons.check_circle : Icons.circle_outlined,
                color: on ? _green : Colors.white38, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(m.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      if (canText)
                        const Icon(Icons.sms_outlined,
                            size: 14, color: Colors.white54),
                      if (canEmail) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.email_outlined,
                            size: 14, color: Colors.white54),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(m.county ?? '—',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                  if (match.hasAny) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (match.congressional != null)
                          _candChip('Congress', match.congressional!),
                        if (match.senate != null)
                          _candChip('State Senate', match.senate!),
                        if (match.house != null)
                          _candChip('State House', match.house!),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _candChip(String office, GeNominee n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _green.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _green.withOpacity(0.4)),
        ),
        child: Text('$office: ${n.nominee}',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  // ---- chrome ----

  Widget _card(
      {required String title, Widget? trailing, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title.toUpperCase(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1)),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      );

  Widget _sendBar() {
    final count = _selectedPeople.length;
    final enabled = count > 0;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: _navy,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled && _emailable > 0 ? _email : null,
              icon: const Icon(Icons.email_outlined, size: 18),
              label: Text('Email $_emailable'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: enabled && _textable > 0 ? _text : null,
              icon: const Icon(Icons.sms, size: 18),
              label: Text('Text $_textable'),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _navy,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A selectable county pill. 44px min so it is a comfortable tap target.
class _CountyChip extends StatelessWidget {
  const _CountyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label county${selected ? ', selected' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected
                  ? BrandColors.sunriseGold
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? BrandColors.sunriseGold
                    : Colors.white.withOpacity(0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(Icons.check,
                      size: 15, color: BrandColors.unityBlue),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? BrandColors.unityBlue : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
