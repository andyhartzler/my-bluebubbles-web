import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

/// Minimal "create candidate" dialog. Collects the required fields and returns
/// a Map<String,dynamic> keyed by DB column (or null on cancel). The caller
/// feeds this to `CandidateRepository.createCandidate`, then opens the new
/// candidate's detail screen where the full edit dialog can fill everything
/// else.
///
/// Kept minimal on purpose: we don't want the new-candidate flow to feel like
/// filling out a form — just enough to get them into the list, then the
/// full-edit surface takes over.
class CandidateNewDialog extends StatefulWidget {
  const CandidateNewDialog({super.key});

  @override
  State<CandidateNewDialog> createState() => _CandidateNewDialogState();
}

class _CandidateNewDialogState extends State<CandidateNewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _officeCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  String? _party;
  String? _officeLevel;

  static const _partyOptions = [
    'Democratic', 'Republican', 'Libertarian', 'Green', 'Constitution',
    'Independent', 'Nonpartisan', 'Other',
  ];
  static const _officeLevelOptions = ['federal', 'state', 'county', 'municipal', 'school', 'other'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _officeCtrl.dispose();
    _districtCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length >= 2 ? parts.last : '';
    final data = <String, dynamic>{
      'name': name,
      'first_name': first.isEmpty ? null : first,
      'last_name': last.isEmpty ? null : last,
      'office': _officeCtrl.text.trim(),
      'party': _party,
      if (_officeLevel != null) 'office_level': _officeLevel,
      if (_districtCtrl.text.trim().isNotEmpty) 'district': _districtCtrl.text.trim(),
      'source': 'manual_entry',
      'state': 'MO',
    };
    Navigator.of(context).pop(data);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Dialog(
      backgroundColor: BrandColors.unityBlue,
      insetPadding: EdgeInsets.symmetric(
        horizontal: mq.size.width > 600 ? 48 : 12,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BrandColors.success.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add, color: BrandColors.success, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add candidate',
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                          Text('County, municipal, or any race not already in the list',
                              style: TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // ── Form body ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _input(
                      controller: _nameCtrl,
                      label: 'Full name *',
                      hint: 'Jane Smith',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      autofocus: true,
                    ),
                    _input(
                      controller: _officeCtrl,
                      label: 'Office *',
                      hint: 'Mayor, State Rep, School Board …',
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _dropdown(
                            label: 'Office level *',
                            value: _officeLevel,
                            options: _officeLevelOptions,
                            onChanged: (v) => setState(() => _officeLevel = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _input(
                            controller: _districtCtrl,
                            label: 'District (optional)',
                            hint: 'e.g. 1, 42',
                          ),
                        ),
                      ],
                    ),
                    _dropdown(
                      label: 'Party *',
                      value: _party,
                      options: _partyOptions,
                      onChanged: (v) => setState(() => _party = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Padding(
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
                      onPressed: _submit,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Create candidate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BrandColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    bool autofocus = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        autofocus: autofocus,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
          filled: true,
          fillColor: Colors.white.withOpacity(0.12),
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
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        dropdownColor: BrandColors.unityBlue,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        iconEnabledColor: Colors.white70,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
          filled: true,
          fillColor: Colors.white.withOpacity(0.12),
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
        items: options.map((o) => DropdownMenuItem<String>(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
