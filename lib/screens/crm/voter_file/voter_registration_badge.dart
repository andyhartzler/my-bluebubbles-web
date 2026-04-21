import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

/// Chip-style badge showing voter registration status (Active / Inactive /
/// Cancelled) plus optional registration date underneath.
class VoterRegistrationBadge extends StatelessWidget {
  final String? status;
  final DateTime? registrationDate;

  const VoterRegistrationBadge({
    super.key,
    required this.status,
    this.registrationDate,
  });

  ({Color color, IconData icon, String label}) _statusMeta() {
    final s = (status ?? '').toLowerCase();
    if (s == 'active') {
      return (
        color: BrandColors.success,
        icon: Icons.how_to_reg,
        label: 'Active Voter',
      );
    }
    if (s == 'inactive') {
      return (
        color: BrandColors.sunriseGold,
        icon: Icons.warning_amber_rounded,
        label: 'Inactive',
      );
    }
    if (s == 'cancelled' || s == 'canceled') {
      return (
        color: BrandColors.republicanRed,
        icon: Icons.cancel_outlined,
        label: 'Cancelled',
      );
    }
    return (
      color: Colors.white70,
      icon: Icons.help_outline,
      label: status ?? 'Unknown',
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: meta.color.withOpacity(0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: meta.color.withOpacity(0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(meta.icon, color: meta.color, size: 14),
              const SizedBox(width: 6),
              Text(
                meta.label,
                style: TextStyle(
                  color: meta.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (registrationDate != null) ...[
          const SizedBox(height: 4),
          Text(
            'Registered ${DateFormat.yMMMd().format(registrationDate!)}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}
