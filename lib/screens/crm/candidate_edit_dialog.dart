import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';

/// Full-screen edit dialog for a candidate profile.
///
/// Click pencil → shows all editable fields (including ones that are empty
/// and hidden on the read view). Save returns a Map<String,dynamic> of
/// changed fields only, keyed by DB column name, ready to pass to
/// `CandidateRepository.updateCandidate`. Cancel returns null.
///
/// Kept as a single dialog rather than inline-per-card because the profile
/// has ~30 editable fields; one scroll is less click-heavy than toggling
/// each card, and empty fields are trivially visible in one form.
class CandidateEditDialog extends StatefulWidget {
  final Candidate candidate;
  const CandidateEditDialog({super.key, required this.candidate});

  @override
  State<CandidateEditDialog> createState() => _CandidateEditDialogState();
}

class _CandidateEditDialogState extends State<CandidateEditDialog> {
  // ── Controllers for each editable field ──
  late final Map<String, TextEditingController> _ctrls;
  DateTime? _dob;
  String? _partyValue;
  String? _officeLevelValue;
  String? _genderValue;

  // Dropdown options
  static const _partyOptions = [
    'Democratic',
    'Republican',
    'Libertarian',
    'Green',
    'Constitution',
    'Independent',
    'Nonpartisan',
    'Other',
  ];
  static const _officeLevelOptions = ['federal', 'state', 'county', 'municipal', 'school', 'other'];
  static const _genderOptions = ['Female', 'Male', 'Non-binary', 'Other', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    final c = widget.candidate;
    _ctrls = {
      // Identity
      'name': TextEditingController(text: c.name),
      'first_name': TextEditingController(text: _safe(c.firstName)),
      'last_name': TextEditingController(text: _safe(c.lastName)),
      // Race
      'office': TextEditingController(text: c.office),
      'district': TextEditingController(text: c.district ?? ''),
      'county': TextEditingController(text: _jsonField(c, 'county')),
      'city': TextEditingController(text: _jsonField(c, 'city')),
      'state': TextEditingController(text: _jsonField(c, 'state', fallback: 'MO')),
      'zip': TextEditingController(text: _jsonField(c, 'zip')),
      'address': TextEditingController(text: c.address ?? ''),
      // Demographics
      'occupation': TextEditingController(text: c.occupation ?? ''),
      'education': TextEditingController(text: c.education ?? ''),
      'bio': TextEditingController(text: c.bio ?? ''),
      // Campaign
      'campaign_website': TextEditingController(text: c.campaignWebsite ?? ''),
      'campaign_email': TextEditingController(text: c.email ?? ''),
      'campaign_phone': TextEditingController(text: c.phone ?? ''),
      'campaign_issues': TextEditingController(text: c.campaignIssues ?? ''),
      'endorsements': TextEditingController(text: c.endorsements ?? ''),
      'photo_url': TextEditingController(text: c.photoUrl ?? ''),
      // Social
      'social_twitter': TextEditingController(text: c.socialTwitter ?? ''),
      'social_instagram': TextEditingController(text: c.socialInstagram ?? ''),
      'social_facebook': TextEditingController(text: c.socialFacebook ?? ''),
      'social_linkedin': TextEditingController(text: c.socialLinkedin ?? ''),
      'social_tiktok': TextEditingController(text: c.socialTiktok ?? ''),
      'ballotpedia_url': TextEditingController(text: c.ballotpediaUrl ?? ''),
      // External IDs
      'fec_candidate_id': TextEditingController(text: c.fecCandidateId ?? ''),
    };
    _dob = c.dateOfBirth;
    _partyValue = _dropdownMatch(c.party, _partyOptions);
    _officeLevelValue = _dropdownMatch(c.officeLevel, _officeLevelOptions);
    _genderValue = _dropdownMatch(_jsonField(c, 'gender'), _genderOptions);
  }

  static String _safe(String s) => s.isEmpty ? '' : s;

  /// Candidate model doesn't expose county/city/state/zip/gender — they
  /// round-trip through the raw json. We read them from toJson() for the
  /// initial controller values, then submit back under the same keys.
  static String _jsonField(Candidate c, String key, {String fallback = ''}) {
    final j = c.toJson();
    final v = j[key];
    if (v is String && v.isNotEmpty) return v;
    return fallback;
  }

  /// Try to match a free-text value to a dropdown option (case-insensitive).
  static String? _dropdownMatch(String? value, List<String> options) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    for (final o in options) {
      if (o.toLowerCase() == lower) return o;
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Compute the diff between current controller values and the source
  /// candidate, returning a map of { db_column: new_value } for fields
  /// that actually changed. Empty strings become null so we don't write
  /// "" into columns that should be NULL.
  Map<String, dynamic> _buildUpdates() {
    final c = widget.candidate;
    final j = c.toJson();
    final out = <String, dynamic>{};

    void setIfChanged(String col, dynamic newVal, dynamic oldVal) {
      // Normalize empty strings → null
      if (newVal is String && newVal.trim().isEmpty) newVal = null;
      if (oldVal is String && oldVal.trim().isEmpty) oldVal = null;
      if (newVal != oldVal) {
        out[col] = newVal;
      }
    }

    // Name logic: if first+last changed, rebuild full name. Otherwise
    // use the name field directly.
    final fn = _ctrls['first_name']!.text.trim();
    final ln = _ctrls['last_name']!.text.trim();
    final manualName = _ctrls['name']!.text.trim();
    final originalName = c.name;
    final originalFirst = c.firstName;
    final originalLast = c.lastName;
    if (fn != originalFirst || ln != originalLast) {
      // Rebuild name from parts
      final rebuilt = [fn, ln].where((p) => p.isNotEmpty).join(' ');
      if (rebuilt.isNotEmpty && rebuilt != originalName) {
        out['name'] = rebuilt;
      }
      setIfChanged('first_name', fn, originalFirst);
      setIfChanged('last_name', ln, originalLast);
    } else if (manualName != originalName) {
      out['name'] = manualName;
    }

    // Simple string columns
    const stringCols = [
      'office', 'district', 'county', 'city', 'state', 'zip', 'address',
      'occupation', 'education', 'bio', 'campaign_website', 'campaign_email',
      'campaign_phone', 'campaign_issues', 'endorsements', 'photo_url',
      'social_twitter', 'social_instagram', 'social_facebook', 'social_linkedin',
      'social_tiktok', 'ballotpedia_url', 'fec_candidate_id',
    ];
    for (final col in stringCols) {
      setIfChanged(col, _ctrls[col]!.text.trim(), j[col]);
    }

    // Dropdowns
    if (_partyValue != null && _partyValue != c.party) out['party'] = _partyValue;
    if (_officeLevelValue != null && _officeLevelValue != c.officeLevel) {
      out['office_level'] = _officeLevelValue;
    }
    if (_genderValue != _jsonField(c, 'gender', fallback: '')) {
      out['gender'] = _genderValue;
    }

    // DOB → also recompute estimated_age server-side? Keep simple: update
    // estimated_age derived from DOB for the local copy too.
    final dobChanged = (_dob?.toIso8601String().split('T').first) !=
        c.dateOfBirth?.toIso8601String().split('T').first;
    if (dobChanged) {
      out['date_of_birth'] = _dob?.toIso8601String().split('T').first;
      // Recompute estimated_age from DOB so the "Young Dem?" calc stays right
      if (_dob != null) {
        final now = DateTime.now();
        int age = now.year - _dob!.year;
        if (now.month < _dob!.month || (now.month == _dob!.month && now.day < _dob!.day)) {
          age--;
        }
        out['estimated_age'] = age;
        out['is_young_dem'] = age <= 36;
      }
    }

    return out;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select date of birth',
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  void _clearDob() => setState(() => _dob = null);

  void _save() {
    final updates = _buildUpdates();
    Navigator.of(context).pop(updates);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: mediaQuery.size.width > 600 ? 48 : 12,
        vertical: 24,
      ),
      backgroundColor: BrandColors.unityBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: mediaQuery.size.height - 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionHeader('Identity'),
                    _twoCol(
                      _textField('first_name', 'First name'),
                      _textField('last_name', 'Last name'),
                    ),
                    _textField('name', 'Full name (auto-built from first/last if those changed)', hint: 'Leave alone unless you want a different display name'),
                    _twoCol(
                      _partyDropdown(),
                      _textField('office', 'Office'),
                    ),
                    _twoCol(
                      _officeLevelDropdown(),
                      _textField('district', 'District'),
                    ),

                    const SizedBox(height: 16),
                    _sectionHeader('Demographics'),
                    _dobPicker(),
                    _twoCol(
                      _genderDropdown(),
                      _textField('occupation', 'Occupation'),
                    ),
                    _textField('education', 'Education', maxLines: 2),
                    _textField('bio', 'Bio', maxLines: 4),

                    const SizedBox(height: 16),
                    _sectionHeader('Location'),
                    _textField('address', 'Address'),
                    _twoCol(
                      _textField('city', 'City'),
                      _textField('county', 'County'),
                    ),
                    _twoCol(
                      _textField('state', 'State', maxLength: 2),
                      _textField('zip', 'ZIP', maxLength: 10),
                    ),

                    const SizedBox(height: 16),
                    _sectionHeader('Campaign'),
                    _textField('campaign_website', 'Campaign website', hint: 'https://…'),
                    _twoCol(
                      _textField('campaign_email', 'Campaign email'),
                      _textField('campaign_phone', 'Campaign phone'),
                    ),
                    _textField('campaign_issues', 'Campaign issues', maxLines: 3, hint: 'Comma or newline separated'),
                    _textField('endorsements', 'Endorsements', maxLines: 3),
                    _textField('photo_url', 'Photo URL', hint: 'https://…'),

                    const SizedBox(height: 16),
                    _sectionHeader('Social & Profiles'),
                    _twoCol(
                      _textField('social_twitter', 'Twitter / X'),
                      _textField('social_instagram', 'Instagram'),
                    ),
                    _twoCol(
                      _textField('social_facebook', 'Facebook'),
                      _textField('social_linkedin', 'LinkedIn'),
                    ),
                    _twoCol(
                      _textField('social_tiktok', 'TikTok'),
                      _textField('ballotpedia_url', 'Ballotpedia'),
                    ),
                    _textField('fec_candidate_id', 'FEC candidate ID', hint: 'Only for federal races'),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BrandColors.sunriseGold.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit, color: BrandColors.sunriseGold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit candidate',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                ),
                Text(
                  widget.candidate.name,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(null),
            tooltip: 'Cancel',
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
            child: const Text('Cancel'),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BrandColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: BrandColors.sunriseGold.withOpacity(0.9),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _twoCol(Widget a, Widget b) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth < 440) {
          return Column(children: [a, b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _textField(String key, String label, {String? hint, int maxLines = 1, int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _ctrls[key],
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        inputFormatters: maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          counterStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: BrandColors.momentumBlue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        dropdownColor: BrandColors.unityBlue,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        iconEnabledColor: Colors.white70,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: BrandColors.momentumBlue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('—', style: TextStyle(color: Colors.white54))),
          ...options.map((o) => DropdownMenuItem<String>(value: o, child: Text(o))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _partyDropdown() => _dropdown(
        label: 'Party',
        value: _partyValue,
        options: _partyOptions,
        onChanged: (v) => setState(() => _partyValue = v),
      );

  Widget _officeLevelDropdown() => _dropdown(
        label: 'Office level',
        value: _officeLevelValue,
        options: _officeLevelOptions,
        onChanged: (v) => setState(() => _officeLevelValue = v),
      );

  Widget _genderDropdown() => _dropdown(
        label: 'Gender',
        value: _genderValue,
        options: _genderOptions,
        onChanged: (v) => setState(() => _genderValue = v),
      );

  Widget _dobPicker() {
    final label = _dob != null
        ? '${_dob!.month}/${_dob!.day}/${_dob!.year}'
        : 'Not set';
    final age = _dob != null ? _computeAge(_dob!) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: _pickDob,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cake, color: BrandColors.sunriseGold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Date of birth',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      label + (age != null ? '  •  age $age' : ''),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (_dob != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                  onPressed: _clearDob,
                  tooltip: 'Clear date',
                ),
              const Icon(Icons.edit_calendar, color: Colors.white54, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  static int _computeAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }
}
