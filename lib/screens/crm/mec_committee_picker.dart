import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

/// Returns the selected MEC committee as a map { mec_id, committee_name, ... }
/// or null if the user cancels. Typeahead searches `public.mec_committees`.
///
/// Search strategy: ilike on committee_name OR mec_id, limit 25, newest-scraped
/// first. Shows the candidate field so you can distinguish two committees with
/// the same name (e.g. "Friends of Smith" for multiple Smiths).
Future<Map<String, dynamic>?> showMecCommitteePicker(
  BuildContext context, {
  Set<String> excludeMecIds = const {},
}) {
  return showDialog<Map<String, dynamic>?>(
    context: context,
    builder: (_) => MecCommitteePicker(excludeMecIds: excludeMecIds),
  );
}

class MecCommitteePicker extends StatefulWidget {
  final Set<String> excludeMecIds;
  const MecCommitteePicker({super.key, this.excludeMecIds = const {}});

  @override
  State<MecCommitteePicker> createState() => _MecCommitteePickerState();
}

class _MecCommitteePickerState extends State<MecCommitteePicker> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  String? _error;
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    // Kick off an initial listing (most recently scraped)
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final query = client
          .from('mec_committees')
          .select('mec_id, committee_name, candidate_name, committee_type, committee_status, party_affiliation, terminated_date');

      final trimmed = q.trim();
      final dynamic filtered = trimmed.isEmpty
          ? query
          : query.or(
              'committee_name.ilike.%$trimmed%,mec_id.ilike.%$trimmed%,candidate_name.ilike.%$trimmed%',
            );

      final response = await filtered
          .order('scraped_at', ascending: false)
          .limit(25);

      final rows = (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((r) {
        final id = r['mec_id']?.toString() ?? '';
        return id.isNotEmpty && !widget.excludeMecIds.contains(id);
      }).toList();

      if (!mounted) return;
      setState(() {
        _results = rows;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _searching = false;
      });
    }
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
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: mq.size.height - 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const Divider(color: Colors.white12, height: 1),
            _searchBox(),
            const Divider(color: Colors.white12, height: 1),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: BrandColors.steelBlue.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance, color: BrandColors.steelBlue, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attach MEC committee',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                Text('Search by committee name, MEC ID, or candidate name',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
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

  Widget _searchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: TextField(
        controller: _controller,
        autofocus: true,
        onChanged: _onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'e.g. "Smith for Missouri" or "C253556"',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  ),
                )
              : null,
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
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: $_error',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty && !_searching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _controller.text.trim().isEmpty
                ? 'Type to search 15,249 MEC committees'
                : 'No matches. Try a different spelling or search by MEC ID.',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (ctx, i) {
        final row = _results[i];
        final mecId = row['mec_id']?.toString() ?? '';
        final name = row['committee_name'] as String? ?? '—';
        final candidate = row['candidate_name'] as String?;
        final type = row['committee_type'] as String?;
        final status = row['committee_status'] as String?;
        final party = row['party_affiliation'] as String?;
        final terminated = row['terminated_date'] != null;

        return Material(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.of(context).pop(row),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: terminated
                          ? Colors.white.withOpacity(0.05)
                          : BrandColors.steelBlue.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.account_balance,
                      color: terminated ? Colors.white38 : BrandColors.steelBlue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                              color: terminated ? Colors.white60 : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: terminated ? TextDecoration.lineThrough : null,
                            )),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text('MEC $mecId',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                            if (candidate != null && candidate.isNotEmpty) ...[
                              Text('  •  ',
                                  style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
                              Flexible(
                                child: Text(candidate,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
                              ),
                            ],
                          ],
                        ),
                        if (type != null || party != null || status != null) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              if (type != null && type.isNotEmpty) _chip(type, BrandColors.steelBlue),
                              if (party != null && party.isNotEmpty)
                                _chip(party, party.toLowerCase().contains('rep')
                                    ? BrandColors.republicanRed
                                    : BrandColors.democratBlue),
                              if (status != null && status.isNotEmpty) _chip(status, Colors.white24),
                              if (terminated) _chip('Terminated', Colors.orange),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35), width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(color: color.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}
