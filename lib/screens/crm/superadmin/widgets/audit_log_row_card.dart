import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

/// Compact card representing a single row of `public.audit_log` or an overlaid
/// `auth.audit_log_entries` login event. Tapping the card opens the drill-in
/// diff modal (parent wires the onTap).
class AuditLogRowCard extends StatelessWidget {
  const AuditLogRowCard({
    super.key,
    required this.row,
    required this.onTap,
  });

  /// Raw row from `audit_log` OR a synthesized row from `auth.audit_log_entries`.
  /// Synthesized auth rows are distinguished by `action == 'AUTH'` AND
  /// `schema_name == 'auth'` (set when we overlay them into the timeline).
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  static final _absoluteFormatter = DateFormat('MMM d, y h:mm:ss a');

  @override
  Widget build(BuildContext context) {
    final action = (row['action'] as String?) ?? 'UPDATE';
    final schema = (row['schema_name'] as String?) ?? 'public';
    final table = (row['table_name'] as String?) ?? '(unknown)';
    final rowId = row['row_id']?.toString();
    final actorEmail = (row['actor_email'] as String?) ?? 'system';
    final actorRole = (row['actor_role'] as String?) ?? 'unknown';
    final occurredAt = DateTime.tryParse((row['occurred_at'] as String?) ?? '')
            ?.toLocal() ??
        DateTime.now();
    final changedColumns = row['changed_columns'];

    final summary = _buildSummary(action, changedColumns);
    final relative = _formatRelative(occurredAt);
    final absolute = _absoluteFormatter.format(occurredAt);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActionBadge(action: action, schema: schema),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$schema.$table${rowId != null ? " · $rowId" : ""}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Tooltip(
                          message: absolute,
                          child: Text(
                            relative,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '$actorEmail · $actorRole',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  String _buildSummary(String action, dynamic changedColumns) {
    switch (action) {
      case 'INSERT':
        return 'Row inserted';
      case 'DELETE':
        return 'Row deleted';
      case 'UPDATE':
        if (changedColumns is List) {
          return '${changedColumns.length} column${changedColumns.length == 1 ? "" : "s"} changed';
        }
        return 'Row updated';
      case 'RPC':
        return 'RPC called';
      case 'EDGE_FN':
        return 'Edge function invoked';
      case 'AUTH':
        return 'Auth event';
      default:
        return action;
    }
  }

  String _formatRelative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _ActionBadge extends StatelessWidget {
  const _ActionBadge({required this.action, required this.schema});

  final String action;
  final String schema;

  @override
  Widget build(BuildContext context) {
    final isAuth = schema == 'auth' || action == 'AUTH';
    final color = _colorForAction(action, isAuth: isAuth);
    final label = isAuth && action == 'AUTH' ? 'AUTH' : action;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      constraints: const BoxConstraints(minWidth: 64),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _colorForAction(String action, {required bool isAuth}) {
    if (isAuth) return BrandColors.sunriseGold;
    switch (action) {
      case 'INSERT':
        return BrandColors.success;
      case 'UPDATE':
        return BrandColors.momentumBlue;
      case 'DELETE':
        return BrandColors.error;
      case 'RPC':
        return BrandColors.royalBlue;
      case 'EDGE_FN':
        return BrandColors.slateBlue;
      default:
        return Colors.grey;
    }
  }
}
