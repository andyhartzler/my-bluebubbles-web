import 'dart:async';

import 'package:flutter/material.dart';

import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';

Future<Member?> showMemberSearchSheet(BuildContext context) {
  return showModalBottomSheet<Member>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _MemberSearchSheet(),
  );
}

class _MemberSearchSheet extends StatefulWidget {
  const _MemberSearchSheet();

  @override
  State<_MemberSearchSheet> createState() => _MemberSearchSheetState();
}

class _MemberSearchSheetState extends State<_MemberSearchSheet> {
  final MemberRepository _memberRepository = MemberRepository();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  bool _loading = false;
  String _error = '';
  List<Member> _results = [];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.search),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search Members',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone number',
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _controller.clear();
                              _results = [];
                              _error = '';
                            });
                          },
                        ),
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    _performSearch(value.trim());
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              )
            else if (_results.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No members found. Try another search.'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final member = _results[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text(member.name.isNotEmpty ? member.name[0].toUpperCase() : '?')),
                      title: Text(member.name),
                      subtitle: Text(member.phoneE164 ?? member.phone ?? 'No phone available'),
                      onTap: () => Navigator.of(context).pop(member),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _results = [];
        _error = query.isEmpty ? '' : 'Keep typing to search';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final results = await _memberRepository.searchMembers(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        if (results.isEmpty) {
          _error = 'No members matched "$query"';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed: $e';
      });
    }
  }
}
