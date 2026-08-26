import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/candidate.dart' show Candidate;
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';

import 'volunteers_map_models.dart';

// ═══════════════════════════════════════════════════════════════
//  OUTREACH LOG SHEET (Layer 2 of Candidate Volunteers)
//  A modal bottom sheet that plans or records a field-outreach activity:
//  kind, title, schedule, status, channel, description, editable geography,
//  a searchable candidate picker and a per-row participant roster. Saving a
//  new activity calls OutreachRepository.createActivity; editing an existing
//  one flips its status via updateStatus.
//
//  Public entry: OutreachLogSheet.show(...). Returns true if a save landed.
// ═══════════════════════════════════════════════════════════════

class OutreachLogSheet {
  const OutreachLogSheet._();

  /// Modal bottom sheet / dialog. Returns true if an activity was saved.
  static Future<bool?> show(
    BuildContext context, {
    OutreachActivity? existing, // non-null = edit/read mode
    List<String> counties = const <String>[],
    List<String> congressionalDistricts = const <String>[],
    List<String> senateDistricts = const <String>[],
    List<String> houseDistricts = const <String>[],
    List<Candidate> candidates = const <Candidate>[], // prefilled, selectable
    List<Member> participants = const <Member>[], // prefilled participant roster
    String? kind,
    String? channel,
    String? status,
    String? titleSuggestion,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OutreachLogSheetBody(
        existing: existing,
        counties: counties,
        congressionalDistricts: congressionalDistricts,
        senateDistricts: senateDistricts,
        houseDistricts: houseDistricts,
        candidates: candidates,
        participants: participants,
        kind: kind,
        channel: channel,
        status: status,
        titleSuggestion: titleSuggestion,
      ),
    );
  }
}

/// The four allowed channels + a "None" option, with display labels. Keys match
/// the stored `channel` check constraint on outreach_activities.
const Map<String, String> _kChannelLabels = <String, String>{
  'in_person': 'In person',
  'sms': 'Text',
  'email': 'Email',
  'phone': 'Phone',
  'social': 'Social',
};

const List<String> _kRoles = <String>['volunteer', 'captain', 'organizer'];

/// One editable participant line: a member plus their per-activity role.
class _Participant {
  _Participant(this.member);
  final Member member;
  String role = 'volunteer';
}

class _OutreachLogSheetBody extends StatefulWidget {
  const _OutreachLogSheetBody({
    required this.existing,
    required this.counties,
    required this.congressionalDistricts,
    required this.senateDistricts,
    required this.houseDistricts,
    required this.candidates,
    required this.participants,
    required this.kind,
    required this.channel,
    required this.status,
    required this.titleSuggestion,
  });

  final OutreachActivity? existing;
  final List<String> counties;
  final List<String> congressionalDistricts;
  final List<String> senateDistricts;
  final List<String> houseDistricts;
  final List<Candidate> candidates;
  final List<Member> participants;
  final String? kind;
  final String? channel;
  final String? status;
  final String? titleSuggestion;

  @override
  State<_OutreachLogSheetBody> createState() => _OutreachLogSheetBodyState();
}

class _OutreachLogSheetBodyState extends State<_OutreachLogSheetBody> {
  final OutreachRepository _repo = OutreachRepository();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  final TextEditingController _candSearchCtrl = TextEditingController();

  late String _kind;
  late String _status;
  String? _channel;
  DateTime? _scheduledOn;

  late final List<String> _counties;
  late final List<String> _cds;
  late final List<String> _sds;
  late final List<String> _hds;

  late final Set<String> _selectedCandidateIds;
  late final List<_Participant> _participants;

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;

    _kind = widget.kind ?? ex?.kind ?? OutreachDisplay.kinds.keys.first;
    _status = widget.status ?? ex?.status ?? 'planned';
    _channel = widget.channel ?? ex?.channel;
    _scheduledOn = ex?.scheduledOn;

    _titleCtrl = TextEditingController(
      text: ex?.title ?? widget.titleSuggestion ?? '',
    );
    _descCtrl = TextEditingController(text: ex?.description ?? '');

    _counties = [...(ex?.counties ?? widget.counties)];
    _cds = [...(ex?.congressionalDistricts ?? widget.congressionalDistricts)];
    _sds = [...(ex?.senateDistricts ?? widget.senateDistricts)];
    _hds = [...(ex?.houseDistricts ?? widget.houseDistricts)];

    // Seed every prefilled candidate as selected; the picker lets HQ narrow it.
    _selectedCandidateIds =
        widget.candidates.map((c) => c.id).where((id) => id.isNotEmpty).toSet();
    _participants =
        widget.participants.map((m) => _Participant(m)).toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _candSearchCtrl.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _surface => _isDark ? const Color(0xFF1B2337) : Colors.white;
  Color get _inset => _isDark ? const Color(0xFF212B44) : const Color(0xFFF4F6FA);
  Color get _text => _isDark ? const Color(0xFFF4F6FA) : const Color(0xFF1E2637);
  Color get _secondary =>
      _isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF5A6478);
  Color get _divider =>
      _isDark ? const Color(0xFF2E3A57) : const Color(0xFFE5E9F0);

  bool get _canSave => !_saving && _titleCtrl.text.trim().isNotEmpty;

  // ── Save ───────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    bool ok;
    if (_isEdit) {
      await _repo.updateStatus(widget.existing!.id, _status);
      ok = true;
    } else {
      final activity = OutreachActivity(
        id: '',
        kind: _kind,
        title: _titleCtrl.text.trim(),
        description:
            _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        status: _status,
        channel: _channel,
        scheduledOn: _scheduledOn,
        completedAt: _status == 'completed' ? DateTime.now() : null,
        counties: _counties,
        congressionalDistricts: _cds,
        senateDistricts: _sds,
        houseDistricts: _hds,
      );
      final id = await _repo.createActivity(
        activity,
        candidateIds: _selectedCandidateIds.toList(),
        participants: [
          for (final p in _participants)
            OutreachParticipantInput(memberId: p.member.id, role: p.role),
        ],
      );
      ok = id != null;
    }

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this outreach. Try again.')),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledOn ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _scheduledOn = picked);
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  children: _isEdit ? _editFields() : _createFields(),
                ),
              ),
              _saveBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: MoydMapTheme.navy,
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.campaign_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEdit ? 'Update outreach' : 'Log outreach',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: MoydMapTheme.gold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── EDIT MODE ──────────────────────────────────────────────────
  List<Widget> _editFields() {
    final ex = widget.existing!;
    return [
      _summaryTile(ex),
      const SizedBox(height: 20),
      _label('STATUS'),
      const SizedBox(height: 10),
      _statusChips(),
    ];
  }

  Widget _summaryTile(OutreachActivity ex) {
    final geo = _allGeoLabels();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _inset,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ex.kindIcon, size: 18, color: MoydMapTheme.unityBlue),
              const SizedBox(width: 8),
              Text(ex.kindLabel,
                  style: TextStyle(
                      color: _secondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Text(ex.title,
              style: TextStyle(
                  color: _text, fontSize: 16, fontWeight: FontWeight.w700)),
          if (ex.scheduledOn != null) ...[
            const SizedBox(height: 6),
            Text('Scheduled ${_fmtDate(ex.scheduledOn!)}',
                style: TextStyle(color: _secondary, fontSize: 12.5)),
          ],
          if (geo.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final g in geo) _readChip(g)],
            ),
          ],
        ],
      ),
    );
  }

  // ── CREATE MODE ────────────────────────────────────────────────
  List<Widget> _createFields() {
    return [
      _label('KIND'),
      const SizedBox(height: 10),
      _kindChips(),
      const SizedBox(height: 20),
      _label('TITLE'),
      const SizedBox(height: 8),
      _textField(_titleCtrl, 'e.g. Saturday canvass in HD 42',
          onChanged: (_) => setState(() {})),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _dateField()),
          const SizedBox(width: 14),
          Expanded(child: _channelField()),
        ],
      ),
      const SizedBox(height: 20),
      _label('STATUS'),
      const SizedBox(height: 10),
      _statusChips(),
      const SizedBox(height: 20),
      _label('NOTES'),
      const SizedBox(height: 8),
      _textField(_descCtrl, 'What is the plan, who is running it…',
          maxLines: 3),
      const SizedBox(height: 22),
      _label('GEOGRAPHY'),
      const SizedBox(height: 10),
      _geoEditor('Counties', _counties, 'Add county'),
      _geoEditor('Congressional', _cds, 'Add CD #'),
      _geoEditor('Senate', _sds, 'Add SD #'),
      _geoEditor('House', _hds, 'Add HD #'),
      const SizedBox(height: 12),
      _label('CANDIDATES'),
      const SizedBox(height: 10),
      _candidatePicker(),
      const SizedBox(height: 22),
      _label('PARTICIPANTS (${_participants.length})'),
      const SizedBox(height: 10),
      _participantRoster(),
    ];
  }

  // ── Kind icon-chip row ─────────────────────────────────────────
  Widget _kindChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in OutreachDisplay.kinds.entries)
          _kindChip(entry.key, entry.value.label, entry.value.icon),
      ],
    );
  }

  Widget _kindChip(String key, String label, IconData icon) {
    final selected = _kind == key;
    final fg = selected
        ? (_isDark ? MoydMapTheme.gold : MoydMapTheme.goldText)
        : _secondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _kind = key),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? MoydMapTheme.gold.withValues(alpha: _isDark ? 0.20 : 0.16)
                : _inset,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? MoydMapTheme.gold.withValues(alpha: 0.7)
                  : _divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: selected ? fg : _text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status chips ───────────────────────────────────────────────
  Widget _statusChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in OutreachDisplay.statuses.entries)
          _statusChip(entry.key, entry.value.label, entry.value.color),
      ],
    );
  }

  Widget _statusChip(String key, String label, Color color) {
    final selected = _status == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _status = key),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : _inset,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : _divider),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : _text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // ── Date + channel ─────────────────────────────────────────────
  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('SCHEDULED'),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _inset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _divider),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 17, color: _secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _scheduledOn == null ? 'Pick a date' : _fmtDate(_scheduledOn!),
                    style: TextStyle(
                        color: _scheduledOn == null ? _secondary : _text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (_scheduledOn != null)
                  GestureDetector(
                    onTap: () => setState(() => _scheduledOn = null),
                    child: Icon(Icons.close, size: 15, color: _secondary),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _channelField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('CHANNEL'),
        const SizedBox(height: 8),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _inset,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: _channel,
              isExpanded: true,
              icon: Icon(Icons.expand_more, color: _secondary, size: 20),
              dropdownColor: _surface,
              style: TextStyle(
                  color: _text, fontSize: 13.5, fontWeight: FontWeight.w600),
              hint: Text('None',
                  style: TextStyle(color: _secondary, fontSize: 13.5)),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None',
                      style: TextStyle(color: _secondary, fontSize: 13.5)),
                ),
                for (final e in _kChannelLabels.entries)
                  DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value),
                  ),
              ],
              onChanged: (v) => setState(() => _channel = v),
            ),
          ),
        ),
      ],
    );
  }

  // ── Geography editor ───────────────────────────────────────────
  Widget _geoEditor(String label, List<String> list, String hint) {
    final ctrl = TextEditingController();
    void add() {
      final v = ctrl.text.trim();
      if (v.isEmpty || list.contains(v)) return;
      setState(() => list.add(v));
      ctrl.clear();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: _secondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final v in list) _removableChip(v, () {
                setState(() => list.remove(v));
              }),
              SizedBox(
                width: 118,
                height: 34,
                child: TextField(
                  controller: ctrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => add(),
                  style: TextStyle(color: _text, fontSize: 12.5),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    hintText: hint,
                    hintStyle: TextStyle(color: _secondary, fontSize: 12),
                    filled: true,
                    fillColor: _inset,
                    suffixIcon: GestureDetector(
                      onTap: add,
                      child: Icon(Icons.add, size: 16, color: _secondary),
                    ),
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: _divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: _divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide:
                          const BorderSide(color: MoydMapTheme.unityBlue),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _removableChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 6, 6, 6),
      decoration: BoxDecoration(
        color: MoydMapTheme.unityBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: MoydMapTheme.unityBlue,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 13, color: MoydMapTheme.unityBlue),
          ),
        ],
      ),
    );
  }

  Widget _readChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: MoydMapTheme.unityBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: const TextStyle(
                color: MoydMapTheme.unityBlue,
                fontSize: 11,
                fontWeight: FontWeight.w800)),
      );

  // ── Candidate picker ───────────────────────────────────────────
  Widget _candidatePicker() {
    if (widget.candidates.isEmpty) {
      return _emptyNote('No candidates tied to this region.');
    }
    final q = _candSearchCtrl.text.trim().toLowerCase();
    final visible = q.isEmpty
        ? widget.candidates
        : widget.candidates
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.office.toLowerCase().contains(q))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textField(_candSearchCtrl, 'Search candidates…',
            prefix: Icons.search, onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        for (final c in visible) _candidateTile(c),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No candidates match “$q”.',
                style: TextStyle(color: _secondary, fontSize: 12.5)),
          ),
      ],
    );
  }

  Widget _candidateTile(Candidate c) {
    final selected = _selectedCandidateIds.contains(c.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() {
            if (selected) {
              _selectedCandidateIds.remove(c.id);
            } else {
              _selectedCandidateIds.add(c.id);
            }
          }),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? MoydMapTheme.unityBlue.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? MoydMapTheme.unityBlue : _divider),
            ),
            child: Row(
              children: [
                _avatar(c.effectivePhotoUrl, c.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      if (c.officeDisplay.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(c.officeDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: _secondary, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: selected ? MoydMapTheme.unityBlue : _secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Participant roster ─────────────────────────────────────────
  Widget _participantRoster() {
    if (_participants.isEmpty) {
      return _emptyNote('No participants selected on the map.');
    }
    return Column(
      children: [for (final p in _participants) _participantRow(p)],
    );
  }

  Widget _participantRow(_Participant p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          _avatar(p.member.effectiveAvatarUrl, p.member.name),
          const SizedBox(width: 12),
          Expanded(
            child: Text(p.member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: _text, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _inset,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: p.role,
                isDense: true,
                icon: Icon(Icons.expand_more, color: _secondary, size: 18),
                dropdownColor: _surface,
                style: TextStyle(
                    color: _text, fontSize: 12.5, fontWeight: FontWeight.w600),
                items: [
                  for (final r in _kRoles)
                    DropdownMenuItem<String>(
                      value: r,
                      child: Text('${r[0].toUpperCase()}${r.substring(1)}'),
                    ),
                ],
                onChanged: (v) => setState(() => p.role = v ?? p.role),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _participants.remove(p)),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: _secondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Save bar ───────────────────────────────────────────────────
  Widget _saveBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _divider)),
      ),
      child: Opacity(
        opacity: _canSave ? 1 : 0.5,
        child: Material(
          color: MoydMapTheme.unityBlue,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _canSave ? _save : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Save status' : 'Log outreach',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Small building blocks ──────────────────────────────────────
  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: _secondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1));

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    IconData? prefix,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(color: _text, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: TextStyle(color: _secondary, fontSize: 13.5),
        prefixIcon: prefix == null
            ? null
            : Icon(prefix, size: 18, color: _secondary),
        filled: true,
        fillColor: _inset,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoydMapTheme.unityBlue),
        ),
      ),
    );
  }

  Widget _emptyNote(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _inset,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _divider),
        ),
        child: Text(text,
            style: TextStyle(color: _secondary, fontSize: 12.5)),
      );

  Widget _avatar(String? url, String name) {
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(url,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialsAvatar(name)),
      );
    }
    return _initialsAvatar(name);
  }

  Widget _initialsAvatar(String name) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MapPalette.avatarColorFor(name),
          shape: BoxShape.circle,
        ),
        child: Text(_initials(name),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  List<String> _allGeoLabels() => [
        for (final c in _counties) '$c County',
        for (final d in _cds) 'CD $d',
        for (final d in _sds) 'SD $d',
        for (final d in _hds) 'HD $d',
      ];

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }
}
