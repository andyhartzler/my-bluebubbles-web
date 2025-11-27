import 'package:flutter/material.dart';

class MergeTagPickerDialog extends StatefulWidget {
  const MergeTagPickerDialog({super.key});

  @override
  State<MergeTagPickerDialog> createState() => _MergeTagPickerDialogState();
}

class _MergeTagPickerDialogState extends State<MergeTagPickerDialog> {
  String _searchQuery = '';

  final List<MergeTag> _mergeTags = [
    MergeTag(
      tag: 'first_name',
      label: 'First Name',
      category: 'Personal',
      example: 'John',
      fallback: 'there',
    ),
    MergeTag(
      tag: 'last_name',
      label: 'Last Name',
      category: 'Personal',
      example: 'Smith',
      fallback: 'Friend',
    ),
    MergeTag(
      tag: 'email',
      label: 'Email Address',
      category: 'Personal',
      example: 'john@example.com',
    ),
    MergeTag(
      tag: 'phone',
      label: 'Phone Number',
      category: 'Personal',
      example: '(555) 123-4567',
    ),
    MergeTag(
      tag: 'county',
      label: 'County',
      category: 'Location',
      example: 'Jackson County',
      fallback: 'Missouri',
    ),
    MergeTag(
      tag: 'city',
      label: 'City',
      category: 'Location',
      example: 'Kansas City',
    ),
    MergeTag(
      tag: 'state',
      label: 'State',
      category: 'Location',
      example: 'Missouri',
    ),
    MergeTag(
      tag: 'zip_code',
      label: 'ZIP Code',
      category: 'Location',
      example: '64101',
    ),
    MergeTag(
      tag: 'chapter_name',
      label: 'Chapter Name',
      category: 'Membership',
      example: 'Kansas City Young Dems',
    ),
    MergeTag(
      tag: 'membership_status',
      label: 'Membership Status',
      category: 'Membership',
      example: 'Active Member',
    ),
    MergeTag(
      tag: 'join_date',
      label: 'Join Date',
      category: 'Membership',
      example: 'January 15, 2024',
    ),
    MergeTag(
      tag: 'congressional_district',
      label: 'Congressional District',
      category: 'Location',
      example: 'MO-5',
    ),
    MergeTag(
      tag: 'state_house_district',
      label: 'State House District',
      category: 'Location',
      example: 'HD-25',
    ),
    MergeTag(
      tag: 'state_senate_district',
      label: 'State Senate District',
      category: 'Location',
      example: 'SD-10',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredTags = _searchQuery.isEmpty
        ? _mergeTags
        : _mergeTags.where((tag) {
            return tag.label.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                tag.tag.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();

    final tagsByCategory = <String, List<MergeTag>>{};
    for (final tag in filteredTags) {
      tagsByCategory.putIfAbsent(tag.category, () => []).add(tag);
    }

    return AlertDialog(
      title: const Text('Insert Merge Tag'),
      content: SizedBox(
        width: 600,
        height: 700,
        child: Column(
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Merge tags insert personalized content for each recipient',
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search field
            TextField(
              decoration: InputDecoration(
                hintText: 'Search merge tags...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),

            const SizedBox(height: 16),

            // Merge tags list
            Expanded(
              child: tagsByCategory.isEmpty
                  ? Center(
                      child: Text(
                        'No merge tags found',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView(
                      children: tagsByCategory.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 4),
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            ...entry.value.map((tag) => _MergeTagItem(
                                  tag: tag,
                                  onSelect: () => Navigator.pop(context, tag),
                                )),
                            const SizedBox(height: 8),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _MergeTagItem extends StatefulWidget {
  final MergeTag tag;
  final VoidCallback onSelect;

  const _MergeTagItem({
    required this.tag,
    required this.onSelect,
  });

  @override
  State<_MergeTagItem> createState() => _MergeTagItemState();
}

class _MergeTagItemState extends State<_MergeTagItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: _isHovered ? 4 : 1,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue[100],
            child: Icon(Icons.label, color: Colors.blue[700], size: 20),
          ),
          title: Text(widget.tag.label),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '{{${widget.tag.tag}}}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (widget.tag.example != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Example: ${widget.tag.example}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
              if (widget.tag.fallback != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Fallback: ${widget.tag.fallback}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            color: Theme.of(context).primaryColor,
            onPressed: widget.onSelect,
            tooltip: 'Insert merge tag',
          ),
          onTap: widget.onSelect,
        ),
      ),
    );
  }
}

class MergeTag {
  final String tag;
  final String label;
  final String category;
  final String? example;
  final String? fallback;

  MergeTag({
    required this.tag,
    required this.label,
    required this.category,
    this.example,
    this.fallback,
  });

  String toMarkup() {
    return '{{${tag}}}';
  }

  String toHTML() {
    if (fallback != null) {
      return '*|${tag.toUpperCase()}:$fallback|*';
    }
    return '*|${tag.toUpperCase()}|*';
  }
}
