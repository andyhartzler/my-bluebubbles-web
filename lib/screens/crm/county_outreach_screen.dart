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

  // ---- styling constants (visual only) ----

  static const _momentum = BrandColors.momentumBlue;

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
                ? _loadingState('Loading counties…')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
                    children: [
                      _header(),
                      const SizedBox(height: 20),
                      _countySection(),
                      const SizedBox(height: 16),
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
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withOpacity(0.35)),
                ),
                child: const Icon(Icons.campaign_outlined,
                    color: _gold, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CANDIDATE VOLUNTEERS',
                        style: TextStyle(
                            color: _momentum,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2)),
                    SizedBox(height: 3),
                    Text('County Outreach',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Pick counties, choose who, and text or email them — with the '
            'Democrat on their November ballot.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 13.5,
                height: 1.45),
          ),
        ],
      );

  // ---- counties ----

  Widget _countySection() {
    final hasSelection = _selectedCounties.isNotEmpty;
    return _card(
      title: 'Counties',
      icon: Icons.place_outlined,
      trailing: hasSelection
          ? _pill('${_selectedCounties.length} selected', accent: true)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasSelection) ...[
            Text(
              'Tap a county to add everyone who lives there.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.55), fontSize: 12.5),
            ),
            const SizedBox(height: 12),
          ],
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
          if (hasSelection) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                setState(_selectedCounties.clear);
                _loadPeople();
              },
              icon: const Icon(Icons.clear_all, size: 16, color: _gold),
              label: const Text('Clear counties',
                  style:
                      TextStyle(color: _gold, fontWeight: FontWeight.w600)),
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
        icon: Icons.groups_outlined,
        child: _emptyState(
          icon: Icons.map_outlined,
          title: 'No counties selected',
          message: 'Pick a county above to see who lives there.',
        ),
      );
    }
    if (_loadingPeople) {
      return _card(
        title: 'Members',
        icon: Icons.groups_outlined,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: _loadingState('Finding members…'),
        ),
      );
    }
    final visible = _visiblePeople;
    return _card(
      title: 'Members',
      icon: Icons.groups_outlined,
      trailing: _pill('${_selectedPeople.length} of ${_people.length}'),
      child: _people.isEmpty
          ? _emptyState(
              icon: Icons.person_search_outlined,
              title: 'No members found',
              message: 'No members live in the selected counties yet.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _momentumBar(),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          _dotStat(_green, '$_textable can be texted'),
                          _dotStat(_momentum, '$_emailable can be emailed'),
                        ],
                      ),
                    ),
                    _miniAction(
                      'All',
                      _gold,
                      'Select all members',
                      () => setState(() =>
                          _selectedPeople.addAll(_people.map((m) => m.id))),
                    ),
                    const SizedBox(width: 2),
                    _miniAction(
                      'None',
                      Colors.white70,
                      'Clear member selection',
                      () => setState(_selectedPeople.clear),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: _momentum,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search these members',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.45)),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white54, size: 20),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.10)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: _momentum.withOpacity(0.7), width: 1.4),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  _emptyState(
                    icon: Icons.search_off,
                    title: 'No matches',
                    message: 'No members match your search.',
                  )
                else
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

    return Semantics(
      button: true,
      selected: on,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() {
              if (!_selectedPeople.add(m.id)) _selectedPeople.remove(m.id);
            }),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: on
                    ? _momentum.withOpacity(0.12)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: on
                      ? _momentum.withOpacity(0.5)
                      : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(m.name, on),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(m.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                            ),
                            if (canText) _capTag(Icons.sms_outlined, 'Text'),
                            if (canEmail) ...[
                              const SizedBox(width: 4),
                              _capTag(Icons.email_outlined, 'Email'),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.place_outlined,
                                size: 12,
                                color: Colors.white.withOpacity(0.45)),
                            const SizedBox(width: 3),
                            Text(m.county ?? '—',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 12)),
                          ],
                        ),
                        if (match.hasAny) ...[
                          const SizedBox(height: 10),
                          Text('ON THEIR NOVEMBER BALLOT',
                              style: TextStyle(
                                  color: _gold.withOpacity(0.9),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
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
                  const SizedBox(width: 10),
                  _selectIndicator(on),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _candChip(String office, GeNominee n) => Semantics(
        label: '$office nominee: ${n.nominee}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: _green.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _green.withOpacity(0.38)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: _green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(office.toUpperCase(),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                ],
              ),
              const SizedBox(height: 2),
              Text(n.nominee,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  // ---- small pieces ----

  Widget _avatar(String name, bool selected) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _gold : Colors.white.withOpacity(0.10),
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? _gold : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(
          _initials(name),
          style: TextStyle(
            color: selected ? _navy : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  Widget _selectIndicator(bool on) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? _green : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: on ? _green : Colors.white.withOpacity(0.35),
            width: 2,
          ),
        ),
        child: on
            ? const Icon(Icons.check, size: 15, color: Colors.white)
            : null,
      );

  Widget _capTag(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: Colors.white.withOpacity(0.65)),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _dotStat(Color color, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ],
      );

  Widget _miniAction(
          String label, Color color, String semanticLabel, VoidCallback onTap) =>
      Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _momentumBar() {
    final total = _people.length;
    final frac =
        total == 0 ? 0.0 : (_selectedPeople.length / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedPeople.length} of $total selected',
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 5,
            color: Colors.white.withOpacity(0.10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                widthFactor: frac,
                heightFactor: 1,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_momentum, _gold]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _loadingState(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    color: _momentum, strokeWidth: 2.5),
              ),
              const SizedBox(height: 14),
              Text(message,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _emptyState(
          {required IconData icon,
          required String title,
          required String message}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _momentum.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: _momentum.withOpacity(0.3)),
                ),
                child: Icon(icon, color: _momentum, size: 26),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 12.5)),
            ],
          ),
        ),
      );

  // ---- chrome ----

  Widget _card(
      {required String title,
      IconData? icon,
      Widget? trailing,
      required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: _momentum.withOpacity(0.9)),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(title.toUpperCase(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4)),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _pill(String text, {bool accent = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: accent
              ? _gold.withOpacity(0.16)
              : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: accent
                  ? _gold.withOpacity(0.5)
                  : Colors.white.withOpacity(0.18)),
        ),
        child: Text(text,
            style: TextStyle(
                color: accent ? _gold : Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
      );

  Widget _sendBar() {
    final count = _selectedPeople.length;
    final total = _people.length;
    final enabled = count > 0;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2742),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 2.5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_momentum, _gold]),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.how_to_vote_outlined,
                        size: 15, color: _gold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$count of $total members selected',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: enabled && _emailable > 0 ? _email : null,
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: Text('Email $_emailable'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor:
                              Colors.white.withOpacity(0.35),
                          side: BorderSide(
                              color: _momentum.withOpacity(0.6), width: 1.2),
                          minimumSize: const Size(0, 52),
                          textStyle: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
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
                          disabledBackgroundColor: _gold.withOpacity(0.25),
                          disabledForegroundColor: _navy.withOpacity(0.6),
                          minimumSize: const Size(0, 52),
                          textStyle: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w800),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A selectable county pill. 44px min so it is a comfortable tap target.
/// Unselected chips carry a "+" affordance; selected chips flip to solid
/// sunrise gold with a check and a soft glow.
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
          splashColor: BrandColors.sunriseGold.withOpacity(0.2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? BrandColors.sunriseGold
                  : Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? BrandColors.sunriseGold
                    : Colors.white.withOpacity(0.22),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: BrandColors.sunriseGold.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check : Icons.add,
                  size: 15,
                  color: selected
                      ? BrandColors.unityBlue
                      : Colors.white.withOpacity(0.55),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? BrandColors.unityBlue : Colors.white,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
