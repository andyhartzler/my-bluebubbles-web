import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

/// Drill-in modal for a single `audit_log` row. Renders:
/// - UPDATE: side-by-side before/after with changed keys highlighted in yellow.
/// - INSERT: just the `after` block.
/// - DELETE: just the `before` block.
/// - RPC/EDGE_FN/AUTH: the `context` jsonb.
class BeforeAfterDiffModal extends StatelessWidget {
  const BeforeAfterDiffModal({
    super.key,
    required this.row,
    this.onViewActorProfile,
  });

  final Map<String, dynamic> row;

  /// Optional callback for "View actor profile" link — parent supplies a
  /// navigator jump to the member detail screen keyed on `actor_id`.
  final void Function(String actorId)? onViewActorProfile;

  static final _absoluteFormatter = DateFormat('MMM d, y · h:mm:ss a');

  @override
  Widget build(BuildContext context) {
    final action = (row['action'] as String?) ?? 'UPDATE';
    final schema = (row['schema_name'] as String?) ?? 'public';
    final table = (row['table_name'] as String?) ?? '(unknown)';
    final rowId = row['row_id']?.toString();
    final actorEmail = (row['actor_email'] as String?) ?? 'system';
    final actorId = row['actor_id']?.toString();
    final actorRole = (row['actor_role'] as String?) ?? 'unknown';
    final occurredAt =
        DateTime.tryParse((row['occurred_at'] as String?) ?? '')?.toLocal();

    final before = row['before'];
    final after = row['after'];
    final context2 = row['context'];
    final changedCols = _asStringList(row['changed_columns']);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              action: action,
              schema: schema,
              table: table,
              rowId: rowId,
              onClose: () => Navigator.of(context).pop(),
            ),
            _MetaBar(
              occurredAt: occurredAt,
              actorEmail: actorEmail,
              actorRole: actorRole,
              actorId: actorId,
              onViewActorProfile: onViewActorProfile,
              absoluteFormatter: _absoluteFormatter,
            ),
            const Divider(height: 1),
            Expanded(
              child: _Body(
                action: action,
                before: before,
                after: after,
                context: context2,
                changedCols: changedCols,
              ),
            ),
            const Divider(height: 1),
            _Footer(
              onCopy: () => _copyJson(context),
              payload: _composeCopyPayload(),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _asStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  Map<String, dynamic> _composeCopyPayload() {
    return {
      'occurred_at': row['occurred_at'],
      'action': row['action'],
      'schema_name': row['schema_name'],
      'table_name': row['table_name'],
      'row_id': row['row_id'],
      'actor_id': row['actor_id'],
      'actor_email': row['actor_email'],
      'actor_role': row['actor_role'],
      'changed_columns': row['changed_columns'],
      'before': row['before'],
      'after': row['after'],
      'context': row['context'],
    };
  }

  void _copyJson(BuildContext context) {
    final encoded =
        const JsonEncoder.withIndent('  ').convert(_composeCopyPayload());
    Clipboard.setData(ClipboardData(text: encoded));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Audit row JSON copied to clipboard')),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.action,
    required this.schema,
    required this.table,
    required this.rowId,
    required this.onClose,
  });

  final String action;
  final String schema;
  final String table;
  final String? rowId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        color: BrandColors.unityBlue,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$action · $schema.$table',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (rowId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'row_id: $rowId',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _MetaBar extends StatelessWidget {
  const _MetaBar({
    required this.occurredAt,
    required this.actorEmail,
    required this.actorRole,
    required this.actorId,
    required this.onViewActorProfile,
    required this.absoluteFormatter,
  });

  final DateTime? occurredAt;
  final String actorEmail;
  final String actorRole;
  final String? actorId;
  final void Function(String actorId)? onViewActorProfile;
  final DateFormat absoluteFormatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.grey.shade50,
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (occurredAt != null)
            _metaChip(Icons.access_time, absoluteFormatter.format(occurredAt!)),
          _metaChip(Icons.person, '$actorEmail ($actorRole)'),
          if (actorId != null && onViewActorProfile != null)
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('View actor profile',
                  style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => onViewActorProfile!(actorId!),
            ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade700),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(color: Colors.grey.shade800, fontSize: 12)),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.action,
    required this.before,
    required this.after,
    required this.context,
    required this.changedCols,
  });

  final String action;
  final dynamic before;
  final dynamic after;
  // ignore: library_private_types_in_public_api
  final dynamic context;
  final List<String> changedCols;

  @override
  Widget build(BuildContext ctx) {
    switch (action) {
      case 'UPDATE':
        return _SideBySide(before: before, after: after, changed: changedCols);
      case 'INSERT':
        return _SinglePane(title: 'After (inserted)', data: after);
      case 'DELETE':
        return _SinglePane(title: 'Before (deleted)', data: before);
      case 'RPC':
      case 'EDGE_FN':
      case 'AUTH':
        return _SinglePane(title: 'Context', data: context);
      default:
        return _SinglePane(title: 'Payload', data: after ?? before ?? context);
    }
  }
}

class _SideBySide extends StatelessWidget {
  const _SideBySide({
    required this.before,
    required this.after,
    required this.changed,
  });

  final dynamic before;
  final dynamic after;
  final List<String> changed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final narrow = constraints.maxWidth < 700;
        if (narrow) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _JsonPane(title: 'Before', data: before, highlightKeys: changed),
              const SizedBox(height: 12),
              _JsonPane(title: 'After', data: after, highlightKeys: changed),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _JsonPane(
                  title: 'Before',
                  data: before,
                  highlightKeys: changed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _JsonPane(
                  title: 'After',
                  data: after,
                  highlightKeys: changed,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SinglePane extends StatelessWidget {
  const _SinglePane({required this.title, required this.data});

  final String title;
  final dynamic data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _JsonPane(title: title, data: data, highlightKeys: const []),
    );
  }
}

class _JsonPane extends StatelessWidget {
  const _JsonPane({
    required this.title,
    required this.data,
    required this.highlightKeys,
  });

  final String title;
  final dynamic data;
  final List<String> highlightKeys;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText.rich(
                _buildRichJson(data, highlightKeys),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _buildRichJson(dynamic data, List<String> highlightKeys) {
    if (data == null) {
      return const TextSpan(
        text: '(null)',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }
    if (data is! Map) {
      // Fallback for non-map payloads: dump the whole thing.
      return TextSpan(
        text: const JsonEncoder.withIndent('  ').convert(data),
      );
    }
    final highlight = highlightKeys.toSet();
    final keys = data.keys.toList()..sort();
    final spans = <InlineSpan>[
      const TextSpan(text: '{\n'),
    ];
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final value = data[key];
      final isLast = i == keys.length - 1;
      final valueText = const JsonEncoder.withIndent('  ').convert(value);
      final isHighlighted = highlight.contains(key);
      spans.add(TextSpan(
        children: [
          TextSpan(
            text: '  "$key"',
            style: TextStyle(
              color: Colors.blueGrey.shade800,
              fontWeight: FontWeight.w600,
              backgroundColor: isHighlighted
                  ? const Color(0xFFFFF59D) // subtle yellow
                  : null,
            ),
          ),
          const TextSpan(text: ': '),
          TextSpan(
            text: _indentValue(valueText, 2),
            style: TextStyle(
              backgroundColor:
                  isHighlighted ? const Color(0xFFFFF59D) : null,
            ),
          ),
          TextSpan(text: isLast ? '\n' : ',\n'),
        ],
      ));
    }
    spans.add(const TextSpan(text: '}'));
    return TextSpan(children: spans);
  }

  String _indentValue(String encoded, int indent) {
    final lines = encoded.split('\n');
    if (lines.length == 1) return encoded;
    final pad = ' ' * indent;
    return [
      lines.first,
      ...lines.skip(1).map((l) => '$pad$l'),
    ].join('\n');
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onCopy, required this.payload});

  final VoidCallback onCopy;
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Audit row #${payload['occurred_at'] ?? ""}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy JSON'),
                onPressed: onCopy,
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
