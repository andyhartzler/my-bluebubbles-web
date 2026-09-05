import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bluebubbles/models/crm/candidate.dart' show Candidate;
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/models/crm/outreach_activity.dart';
import 'package:bluebubbles/providers/user_session_provider.dart';
import 'package:bluebubbles/services/crm/outreach_repository.dart';

import 'mobilize_models.dart';
import 'volunteers_map_models.dart';
import 'volunteers_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  ORGANIZING TOOLKIT (Layer 2 of Candidate Volunteers)
//  Plans a new organizing activity or edits one that already exists. The
//  create flow reads as a toolkit: pick a play (grouped by intent), then plan
//  it: name, schedule, status, channel, the plan, editable geography, a
//  searchable nominee picker and a per-row participant roster. The stored
//  kind/status/channel keys are unchanged, so old rows round-trip untouched.
//
//  ONE FORM, TWO MOUNTS. [OrganizingToolkitForm] is the whole thing;
//  [OrganizingToolkitSheet.show] is a thin wrapper that mounts it inside a
//  modal bottom sheet. The Desk's PLAN section mounts the SAME widget inline
//  with [OrganizingToolkitMount.inline], so the CRM has exactly one activity
//  form rather than a modal and a fork of it.
//
//  SEEDING. Every caller passes one [OrganizingSeed] instead of the ten loose
//  named parameters this used to take. Each of those call sites had rebuilt
//  the same geo/candidate/participant logic by hand, which is precisely the
//  drift the seed exists to end.
//
//  Every color resolves from [VolunteersTheme] (the Slack palette).
// ═══════════════════════════════════════════════════════════════

class OrganizingToolkitSheet {
  const OrganizingToolkitSheet._();

  /// Modal bottom sheet. Returns true if an activity was saved.
  ///
  /// [onSaved] additionally hands back the row as it now reads, for a caller
  /// that renders the activity itself and would otherwise have to re-fetch it
  /// to show the edit.
  static Future<bool?> show(
    BuildContext context, {
    OutreachActivity? existing, // non-null = edit mode
    OrganizingSeed seed = const OrganizingSeed.empty(),
    ValueChanged<OutreachActivity>? onSaved,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
            child: Container(
              decoration: BoxDecoration(
                color: VolunteersTheme.of(ctx).surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              clipBehavior: Clip.antiAlias,
              child: OrganizingToolkitForm(
                existing: existing,
                seed: seed,
                onClose: () => Navigator.of(ctx).pop(),
                onSaved: (activity) {
                  onSaved?.call(activity);
                  Navigator.of(ctx).pop(true);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Where the form is mounted, which is the only thing that differs between the
/// two containers: the sheet owns its own scroll, carries the title header and
/// pays the device's bottom inset; inline it is one card inside the Desk's
/// single scroll, so it must not scroll itself, must not repeat a header the
/// section already draws, and must not add a device inset mid-page.
enum OrganizingToolkitMount { sheet, inline }

/// The one map geography a nominee's office fills, with the district in the
/// map's bare-digit key form. Null when the office has no single mappable
/// district: statewide, US Senate, county, municipal, school and judicial
/// races all return null and contribute nothing, because a district written
/// here that the exec never chose would be a guess on the activity row.
///
/// The office text is the primary signal and office_level only a backstop:
/// the live `candidates.office` values are "State Representative" / "State
/// House of Representatives", "State Senator" / "State Senate" and "U.S.
/// Representative", and office_level is null on some of those rows.
({MapMode mode, String id})? nomineeDistrict(Candidate candidate) {
  final district = (candidate.district ?? '').trim();
  if (!RegExp(r'\d').hasMatch(district)) return null;
  final office = candidate.office.toLowerCase();
  final level = (candidate.officeLevel ?? '').toLowerCase();

  final MapMode? mode;
  if (office.contains('state sen') || office.contains('senate district')) {
    mode = MapMode.senate;
  } else if (office.contains('state rep') ||
      office.contains('state house') ||
      office.contains('house district') ||
      (office.contains('representative') && level == 'state')) {
    mode = MapMode.house;
  } else if (office.contains('congress') ||
      office.contains('u.s. rep') ||
      office.contains('us rep') ||
      office.contains('u.s. house') ||
      office.contains('us house') ||
      (office.contains('representative') && level == 'federal')) {
    mode = MapMode.congressional;
  } else {
    mode = null;
  }
  if (mode == null) return null;
  return (mode: mode, id: bareDigits(district));
}

/// The four allowed channels, with display labels. Keys match the stored
/// `channel` check constraint on outreach_activities.
const Map<String, String> _kChannelLabels = <String, String>{
  'in_person': 'In person',
  'sms': 'Text',
  'email': 'Email',
  'phone': 'Phone',
  'social': 'Social',
};

const List<String> _kRoles = <String>['volunteer', 'captain', 'organizer'];

/// The kind picker, grouped by organizing intent. Each entry is a stored `kind`
/// key plus a one-line description. The eight keys here match OutreachDisplay
/// exactly, so every stored activity has a home and old rows still edit.
const List<({String title, List<({String key, String desc})> items})>
    _kKindGroups = <({String title, List<({String key, String desc})> items})>[
  (
    title: 'RALLY THE VOTE',
    items: <({String key, String desc})>[
      (key: 'canvass', desc: 'Knock doors with members'),
      (key: 'phone_bank', desc: 'Call voters together'),
      (key: 'text_bank', desc: 'Text voters from anywhere'),
      (key: 'day_of_action', desc: 'One big day, one district'),
    ],
  ),
  (
    title: 'BUILD COMMUNITY',
    items: <({String key, String desc})>[
      (key: 'volunteer_day', desc: 'Get members together to serve'),
      (key: 'other', desc: 'Socials, watch parties, anything else'),
    ],
  ),
  (
    title: 'GET THE WORD OUT',
    items: <({String key, String desc})>[
      (key: 'email_blast', desc: 'Email members a call to action'),
      (key: 'social_blitz', desc: 'Coordinated posts for a nominee'),
    ],
  ),
];

/// One editable participant line: a member plus their per-activity role.
class _Participant {
  _Participant(this.member);
  final Member member;
  String role = 'volunteer';
}

/// The activity form itself. Mount it in the sheet above, or inline anywhere
/// that wants planning on the page rather than on top of it.
class OrganizingToolkitForm extends StatefulWidget {
  const OrganizingToolkitForm({
    super.key,
    this.existing,
    this.seed = const OrganizingSeed.empty(),
    required this.onSaved,
    this.onClose,
    this.mount = OrganizingToolkitMount.sheet,
  });

  /// Non-null puts the form in edit mode, where every field the stored row
  /// carries is editable and the seed is ignored in favour of the row.
  final OutreachActivity? existing;

  /// What a NEW activity starts life with. Ignored when [existing] is set.
  final OrganizingSeed seed;

  /// Called with the row as it now reads once the write lands. The sheet pops
  /// on it; an inline mount reloads whatever it renders around the form. On a
  /// create the id is the one the database just returned.
  final ValueChanged<OutreachActivity> onSaved;

  /// Close affordance for the sheet's header. Null draws no close button.
  final VoidCallback? onClose;

  final OrganizingToolkitMount mount;

  @override
  State<OrganizingToolkitForm> createState() => _OrganizingToolkitFormState();
}

class _OrganizingToolkitFormState extends State<OrganizingToolkitForm> {
  final OutreachRepository _repo = OutreachRepository();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  final TextEditingController _candSearchCtrl = TextEditingController();

  /// One persistent add-field controller per geography editor, keyed by label.
  /// Hoisted out of build() so typed input is not wiped on every rebuild and
  /// the controllers are actually disposed.
  final Map<String, TextEditingController> _geoCtrls = {};

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
  bool get _inline => widget.mount == OrganizingToolkitMount.inline;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    final seed = widget.seed;

    _kind = seed.kind ?? ex?.kind ?? OutreachDisplay.kinds.keys.first;
    _status = seed.status ?? ex?.status ?? 'planned';
    _channel = seed.channel ?? ex?.channel;
    _scheduledOn = ex?.scheduledOn;

    _titleCtrl = TextEditingController(
      text: ex?.title ?? seed.titleSuggestion ?? '',
    );
    _descCtrl = TextEditingController(text: ex?.description ?? '');

    _counties = [...(ex?.counties ?? seed.counties)];
    _cds = [...(ex?.congressionalDistricts ?? seed.congressionalDistricts)];
    _sds = [...(ex?.senateDistricts ?? seed.senateDistricts)];
    _hds = [...(ex?.houseDistricts ?? seed.houseDistricts)];

    // Seed every prefilled nominee as selected; the picker lets HQ narrow it.
    _selectedCandidateIds =
        seed.candidates.map((c) => c.id).where((id) => id.isNotEmpty).toSet();

    // A new activity also starts with the districts its nominees run in. The
    // exec attached the nominees, so the system already knows where they are
    // on the ballot; the form used to show a filled nominee list over three
    // empty "Add # " fields and ask for the numbers again. The region the
    // seed carried stays first, the nominees' districts are folded in behind
    // it, and every chip stays removable. An edit keeps the stored row as is.
    if (ex == null) {
      for (final c in seed.candidates) {
        _addNomineeDistrict(c);
      }
    }
    _participants = seed.participants.map((m) => _Participant(m)).toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _candSearchCtrl.dispose();
    for (final c in _geoCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fold one nominee's district into the matching WHERE list, deduped.
  ///
  /// This only ever ADDS. A nominee with no mappable district adds nothing,
  /// and nothing is removed here, so a statewide nominee cannot blank a
  /// district another nominee supplied and a district the region or the exec
  /// put there stays put. Deselecting a nominee in the picker leaves its
  /// district chip in place for the same reason: the form cannot tell whether
  /// the exec still wants that district, and the chip's own remove control is
  /// one tap away.
  void _addNomineeDistrict(Candidate c) {
    final hit = nomineeDistrict(c);
    if (hit == null) return;
    final List<String>? list = switch (hit.mode) {
      MapMode.congressional => _cds,
      MapMode.senate => _sds,
      MapMode.house => _hds,
      MapMode.county => null,
    };
    if (list == null || list.contains(hit.id)) return;
    list.add(hit.id);
  }

  // ── Palette (the ONE VolunteersTheme, resolved per build) ──────
  VolunteersTheme get _vt => VolunteersTheme.of(context);
  Color get _surface => _vt.surface;
  Color get _inset => _vt.inset;
  Color get _text => _vt.text;
  Color get _secondary => _vt.secondary;
  Color get _divider => _vt.divider;
  Color get _accent => _vt.accent;
  // Emphasis pair for anything that carries a LABEL on a filled surface.
  // White on accent (momentumBlue) is 2.75:1 and fails even the 3:1
  // large-text floor, so accent stays on rules, rings and strokes.
  Color get _emphasisFill => _vt.emphasisFill;
  Color get _onEmphasis => _vt.onEmphasis;
  Color get _accentSoft => _vt.accentSoft;
  Color get _onAccentSoft => _vt.onAccentSoft;

  bool get _canSave => !_saving && _titleCtrl.text.trim().isNotEmpty;

  // ── Save ───────────────────────────────────────────────────────
  //
  // The two ids are never interchangeable: created_by references auth.users
  // and organizer_member_id references public.members. Both are bare uuids, so
  // a swap is only caught at insert time as an opaque 23503. They come from
  // UserSessionProvider and nowhere else.
  ({String userId, String memberId})? _actor() {
    final session = context.read<UserSessionProvider>();
    final memberId = session.currentMember?.id;
    final userId = session.authUserId;
    if (memberId == null || userId == null) return null;
    return (userId: userId, memberId: memberId);
  }

  /// The organizer the roster names, if it names one. Whoever is given the
  /// `organizer` role owns the activity; with nobody named, the repository
  /// stamps the acting exec, which is the gap that left every activity in the
  /// system anonymous.
  String? _namedOrganizerId() {
    for (final p in _participants) {
      if (p.role == 'organizer') return p.member.id;
    }
    return null;
  }

  String? _trimmedOrNull(TextEditingController ctrl) {
    final v = ctrl.text.trim();
    return v.isEmpty ? null : v;
  }

  /// The row exactly as the form currently reads it. [id] is empty for a
  /// create, which the database replaces.
  OutreachActivity _formActivity({
    required String id,
    DateTime? completedAt,
    String? organizerMemberId,
    String? createdBy,
  }) =>
      OutreachActivity(
        id: id,
        kind: _kind,
        title: _titleCtrl.text.trim(),
        description: _trimmedOrNull(_descCtrl),
        status: _status,
        channel: _channel,
        scheduledOn: _scheduledOn,
        completedAt: completedAt,
        counties: _counties,
        congressionalDistricts: _cds,
        senateDistricts: _sds,
        houseDistricts: _hds,
        organizerMemberId: organizerMemberId,
        createdBy: createdBy,
      );

  /// The edited row, with completed_at kept honest: a status that did not move
  /// keeps whatever timestamp it had, and one that moved off 'completed'
  /// clears it rather than leaving a stale completion behind.
  OutreachActivity _editedActivity(OutreachActivity ex) {
    final completedAt = _status == ex.status
        ? ex.completedAt
        : (_status == 'completed' ? DateTime.now() : null);
    return _formActivity(
      id: ex.id,
      completedAt: completedAt,
      organizerMemberId: ex.organizerMemberId,
      createdBy: ex.createdBy,
    );
  }

  /// The columns an edit writes.
  ///
  /// Built from a whole rebuilt row rather than through copyWith because three
  /// of the editable columns are nullable (channel, scheduled_on, description)
  /// and a copyWith cannot express "clear this": an exec who removed the date
  /// would silently keep the old one.
  Map<String, dynamic> _updateFields(
      OutreachActivity ex, OutreachActivity edited) {
    final fields = edited.toInsertJson()..remove('created_by');
    if (_status == ex.status) {
      // completed_at is updateStatus's to own. An edit that left the status
      // alone must not rewrite it.
      fields.remove('completed_at');
    }
    return fields;
  }

  Future<void> _save() async {
    if (_saving) return;

    final actor = _actor();
    if (actor == null) {
      _snack('Could not tell who you are signed in as. Reload and try again.');
      return;
    }

    setState(() => _saving = true);

    OutreachActivity? saved;
    try {
      if (_isEdit) {
        final ex = widget.existing!;
        final edited = _editedActivity(ex);
        await _repo.updateActivity(ex.id, _updateFields(ex, edited));
        saved = edited;
      } else {
        final draft = _formActivity(
          id: '',
          completedAt: _status == 'completed' ? DateTime.now() : null,
          organizerMemberId: _namedOrganizerId(),
        );
        final id = await _repo.createActivity(
          draft,
          actorUserId: actor.userId,
          actorMemberId: actor.memberId,
          candidateIds: _selectedCandidateIds.toList(),
          participants: [
            for (final p in _participants)
              OutreachParticipantInput(memberId: p.member.id, role: p.role),
          ],
        );
        saved = id == null
            ? null
            : _formActivity(
                id: id,
                completedAt: draft.completedAt,
                organizerMemberId: draft.organizerMemberId ?? actor.memberId,
                createdBy: actor.userId,
              );
      }
    } catch (_) {
      saved = null;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) {
      widget.onSaved(saved);
    } else {
      _snack('Could not save this activity. Try again.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    final fields = _fields();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_inline) _header(),
        if (_inline)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: fields,
            ),
          )
        else
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              children: fields,
            ),
          ),
        _saveBar(),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, color: _accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEdit ? 'Update activity' : 'Plan an activity',
                    style: TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          if (widget.onClose != null)
            // Material > InkWell, matching every other close affordance in
            // this workspace: without it the ripple draws on whatever Material
            // happens to be above, which on the inline mount is the page.
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onClose,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _inset,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, color: _secondary, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── The fields ─────────────────────────────────────────────────
  //
  // ONE list for both modes. Edit mode used to offer a status chip row and
  // nothing else, which made a saved activity permanently mis-titled and
  // mis-dated. The two things it still leaves out are the nominee picker and
  // the roster: both are stored in join tables this form does not read back,
  // and both already have a home on the activity page.
  List<Widget> _fields() {
    final ideas = _isEdit ? const <String>[] : _ideaTitles();
    return [
      _label('PICK A PLAY'),
      const SizedBox(height: 12),
      _kindGroups(),
      const SizedBox(height: 24),
      if (ideas.isNotEmpty) ...[
        _ideaStrip(ideas),
        const SizedBox(height: 20),
      ],
      _label('NAME THE ACTIVITY'),
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
      _label('THE PLAN'),
      const SizedBox(height: 8),
      _textField(_descCtrl,
          'What is the plan, who runs it, and what does success look like',
          maxLines: 3),
      const SizedBox(height: 24),
      _label('WHERE'),
      const SizedBox(height: 10),
      _geoEditor('Counties', _counties, 'Add county'),
      _geoEditor('Congressional', _cds, 'Add CD #', digitsOnly: true),
      _geoEditor('Senate', _sds, 'Add SD #', digitsOnly: true),
      _geoEditor('House', _hds, 'Add HD #', digitsOnly: true),
      const SizedBox(height: 12),
      if (_isEdit)
        _emptyNote('Nominees and the roster are managed on the activity page.')
      else ...[
        _label('FOR WHICH NOMINEES'),
        const SizedBox(height: 10),
        _candidatePicker(),
        const SizedBox(height: 24),
        _label("WHO'S IN (${_participants.length})"),
        const SizedBox(height: 10),
        _participantRoster(),
      ],
    ];
  }

  // ── Kind groups ("pick a play") ────────────────────────────────
  Widget _kindGroups() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var g = 0; g < _kKindGroups.length; g++) ...[
          if (g > 0) const SizedBox(height: 16),
          _groupTitle(_kKindGroups[g].title),
          const SizedBox(height: 8),
          for (final item in _kKindGroups[g].items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _kindCard(item.key, item.desc),
            ),
        ],
      ],
    );
  }

  Widget _groupTitle(String label) => Text(label,
      style: TextStyle(
          color: _secondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9));

  Widget _kindCard(String key, String desc) {
    final meta = OutreachDisplay.kinds[key]!;
    final selected = _kind == key;
    final fg = selected ? _onAccentSoft : _text;
    final sub = selected ? _onAccentSoft.withValues(alpha: 0.85) : _secondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _kind = key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _accentSoft : _inset,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _accent : _divider),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? _onAccentSoft.withValues(alpha: 0.14)
                      : _surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon,
                    size: 18, color: selected ? _onAccentSoft : _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(meta.label,
                        style: TextStyle(
                            color: fg,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(desc,
                        style:
                            TextStyle(color: sub, fontSize: 12, height: 1.2)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: selected ? _onAccentSoft : _secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Idea strip (client-side title templates) ───────────────────
  //
  // Shown only when a NEW activity is seeded from a region and/or nominee.
  // Tapping a chip drops the template into the title field so HQ names it in
  // one tap. An activity that already has a name has nothing to suggest.
  List<String> _ideaTitles() {
    final region = _seedRegionLabel();
    final nominee =
        widget.seed.candidates.isNotEmpty ? widget.seed.candidates.first.name : null;
    final out = <String>[];
    if (region != null) out.add('Saturday canvass in $region');
    if (nominee != null) out.add('Text bank for $nominee');
    if (region != null) out.add('New member meet-up in $region');
    return out.take(3).toList();
  }

  String? _seedRegionLabel() {
    if (_counties.isNotEmpty) return '${_counties.first} County';
    if (_cds.isNotEmpty) return 'CD ${_cds.first}';
    if (_sds.isNotEmpty) return 'SD ${_sds.first}';
    if (_hds.isNotEmpty) return 'HD ${_hds.first}';
    return null;
  }

  Widget _ideaStrip(List<String> ideas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline, size: 15, color: _secondary),
            const SizedBox(width: 6),
            Text('Tap to name it fast',
                style: TextStyle(
                    color: _secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final t in ideas) _ideaChip(t)],
        ),
      ],
    );
  }

  Widget _ideaChip(String title) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _titleCtrl.text = title;
        }),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _accentSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(title,
              style: TextStyle(
                  color: _onAccentSoft,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
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
  Widget _geoEditor(String label, List<String> list, String hint,
      {bool digitsOnly = false}) {
    final ctrl = _geoCtrls.putIfAbsent(label, () => TextEditingController());
    void add() {
      var v = ctrl.text.trim();
      // District lists must store bare digits ("59"), matching the map's
      // region queries; a hand-typed "HD 59" or "District 59" would never match.
      if (digitsOnly) {
        final m = RegExp(r'\d+').firstMatch(v);
        v = m == null ? '' : int.parse(m.group(0)!).toString();
      }
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
                      borderSide: BorderSide(color: _accent),
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
        color: _accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: _onAccentSoft,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 13, color: _onAccentSoft),
          ),
        ],
      ),
    );
  }

  // ── Nominee picker ─────────────────────────────────────────────
  Widget _candidatePicker() {
    final seeded = widget.seed.candidates;
    if (seeded.isEmpty) {
      return _emptyNote('No nominees tied to this region yet.');
    }
    final q = _candSearchCtrl.text.trim().toLowerCase();
    final visible = q.isEmpty
        ? seeded
        : seeded
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.office.toLowerCase().contains(q))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textField(_candSearchCtrl, 'Search nominees…',
            prefix: Icons.search, onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        for (final c in visible) _candidateTile(c),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No nominees match “$q”.',
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
              _addNomineeDistrict(c);
            }
          }),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? _accent.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? _accent : _divider),
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
                  color: selected ? _accent : _secondary,
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
      return _emptyNote(
          'Nobody is on the roster yet. Select members on the map to add them.');
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
    // The device inset belongs to the sheet, which sits against the bottom of
    // the window. Inline the form is mid-page and adding it would open a gap.
    final bottomInset =
        _inline ? 0.0 : MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
          _inline ? 0 : 16, 12, _inline ? 0 : 16, 12 + bottomInset),
      decoration: BoxDecoration(
        color: _inline ? Colors.transparent : _surface,
        border: _inline
            ? null
            : Border(top: BorderSide(color: _divider)),
      ),
      child: Opacity(
        opacity: _canSave ? 1 : 0.5,
        child: Material(
          color: _emphasisFill,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _canSave ? _save : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: _onEmphasis),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Save plan',
                      style: TextStyle(
                          color: _onEmphasis,
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
          borderSide: BorderSide(color: _accent),
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
