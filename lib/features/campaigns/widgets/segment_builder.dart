import 'package:bluebubbles/models/crm/message_filter.dart';
import 'package:flutter/material.dart';

class SegmentBuilder extends StatefulWidget {
  final MessageFilter filter;
  final ValueChanged<MessageFilter> onChanged;
  final int? estimatedRecipients;
  final VoidCallback? onRequestEstimate;

  const SegmentBuilder({
    super.key,
    required this.filter,
    required this.onChanged,
    this.estimatedRecipients,
    this.onRequestEstimate,
  });

  @override
  State<SegmentBuilder> createState() => _SegmentBuilderState();
}

class _SegmentBuilderState extends State<SegmentBuilder> {
  late MessageFilter _filter;
  late final TextEditingController _countyController;
  late final TextEditingController _districtController;
  late final TextEditingController _chapterController;
  late final TextEditingController _committeesController;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
    _countyController = TextEditingController(text: _filter.county);
    _districtController = TextEditingController(text: _filter.congressionalDistrict);
    _chapterController = TextEditingController(text: _filter.chapterName);
    _committeesController = TextEditingController(text: _filter.committees?.join(', ') ?? '');
  }

  @override
  void dispose() {
    _countyController.dispose();
    _districtController.dispose();
    _chapterController.dispose();
    _committeesController.dispose();
    super.dispose();
  }

  void _updateFilter(MessageFilter newFilter) {
    setState(() => _filter = newFilter);
    widget.onChanged(_filter);
  }

  void _handleTextChange() {
    final committees = _committeesController.text
        .split(',')
        .map((e) => e.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    _updateFilter(_filter.copyWith(
      county: _countyController.text.trim().isEmpty ? null : _countyController.text.trim(),
      congressionalDistrict:
          _districtController.text.trim().isEmpty ? null : _districtController.text.trim(),
      chapterName: _chapterController.text.trim().isEmpty ? null : _chapterController.text.trim(),
      committees: committees.isEmpty ? null : committees,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _countyController,
                decoration: const InputDecoration(
                  labelText: 'County',
                  hintText: 'St. Louis, Jackson, Boone...',
                ),
                onChanged: (_) => _handleTextChange(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _districtController,
                decoration: const InputDecoration(
                  labelText: 'Congressional District',
                  hintText: 'MO-1, MO-2...'
                ),
                onChanged: (_) => _handleTextChange(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chapterController,
                decoration: const InputDecoration(
                  labelText: 'Chapter name',
                  hintText: 'Kansas City Young Dems',
                ),
                onChanged: (_) => _handleTextChange(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _committeesController,
                decoration: const InputDecoration(
                  labelText: 'Committees',
                  hintText: 'Comma separated list',
                ),
                onChanged: (_) => _handleTextChange(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 2.8),
                child: RangeSlider(
                  values: () {
                    final start = (_filter.minAge ?? 16).clamp(14, 40).toDouble();
                    final end = (_filter.maxAge ?? 36).clamp(start, 40).toDouble();
                    return RangeValues(start, end);
                  }(),
                  min: 14,
                  max: 40,
                  divisions: 26,
                  labels: RangeLabels(
                    '${_filter.minAge ?? 16}',
                    '${_filter.maxAge ?? 36}',
                  ),
                  onChanged: (values) {
                    _updateFilter(_filter.copyWith(
                      minAge: values.start.round(),
                      maxAge: values.end.round(),
                    ));
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Switch(
                      value: _filter.excludeOptedOut,
                      onChanged: (value) => _updateFilter(_filter.copyWith(excludeOptedOut: value)),
                    ),
                    const SizedBox(width: 8),
                    const Text('Exclude opted-out'),
                  ],
                ),
                Row(
                  children: [
                    Switch(
                      value: _filter.excludeRecentlyContacted,
                      onChanged: (value) => _updateFilter(
                        _filter.copyWith(excludeRecentlyContacted: value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Exclude recent outreach'),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.estimatedRecipients != null)
          Text(
            'Estimated recipients: ${widget.estimatedRecipients}',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        if (widget.onRequestEstimate != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onRequestEstimate,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Refresh estimate'),
            ),
          ),
      ],
    );
  }
}
