import 'package:flutter/material.dart';

import 'package:bluebubbles/features/committees/theme/brand_colors.dart';

/// Wrap of information chips — CD, MO House, MO Senate, Precinct — derived
/// from the voter file. Only renders non-null values.
class VoterDistrictStrip extends StatelessWidget {
  final String? congressionalDistrict;
  final String? legislativeDistrict;
  final String? senateDistrict;
  final String? precinct;

  const VoterDistrictStrip({
    super.key,
    this.congressionalDistrict,
    this.legislativeDistrict,
    this.senateDistrict,
    this.precinct,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    void add(String? value, String label, IconData icon) {
      if (value == null || value.isEmpty) return;
      chips.add(_DistrictChip(label: label, value: value, icon: icon));
    }

    add(congressionalDistrict, 'CD', Icons.flag_outlined);
    add(legislativeDistrict, 'MO House', Icons.account_balance);
    add(senateDistrict, 'MO Senate', Icons.gavel);
    add(precinct, 'Precinct', Icons.pin_drop_outlined);

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }
}

class _DistrictChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DistrictChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BrandColors.steelBlue.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BrandColors.steelBlue.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: BrandColors.steelBlue, size: 13),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
