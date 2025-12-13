import 'package:flutter/material.dart';
import '../models/audience_demographics.dart';
import '../theme/communications_committee_theme.dart';

/// Displays audience demographics data
class DemographicsSection extends StatelessWidget {
  final Map<String, AudienceDemographics> demographics;

  const DemographicsSection({
    super.key,
    required this.demographics,
  });

  @override
  Widget build(BuildContext context) {
    if (demographics.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    // Combine demographics from all accounts
    final combinedAgeGender = <String, int>{};
    final combinedCountries = <String, int>{};
    final combinedCities = <String, int>{};

    for (final demo in demographics.values) {
      demo.ageGenderBreakdown.forEach((key, value) {
        final intValue = _toInt(value);
        combinedAgeGender[key] = (combinedAgeGender[key] ?? 0) + intValue;
      });
      demo.topCountries.forEach((key, value) {
        final intValue = _toInt(value);
        combinedCountries[key] = (combinedCountries[key] ?? 0) + intValue;
      });
      demo.topCities.forEach((key, value) {
        final intValue = _toInt(value);
        combinedCities[key] = (combinedCities[key] ?? 0) + intValue;
      });
    }

    // If no data at all, don't show section
    if (combinedAgeGender.isEmpty && combinedCountries.isEmpty && combinedCities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audience Demographics',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DemographicCard(
                        title: 'Age & Gender',
                        icon: Icons.people_outline,
                        data: combinedAgeGender,
                        limit: 10,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DemographicCard(
                        title: 'Top Countries',
                        icon: Icons.public,
                        data: combinedCountries,
                        limit: 5,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DemographicCard(
                        title: 'Top Cities',
                        icon: Icons.location_city,
                        data: combinedCities,
                        limit: 5,
                      ),
                    ),
                  ],
                );
              }

              // Mobile layout - stacked
              return Column(
                children: [
                  _DemographicCard(
                    title: 'Age & Gender',
                    icon: Icons.people_outline,
                    data: combinedAgeGender,
                    limit: 10,
                  ),
                  const SizedBox(height: 16),
                  _DemographicCard(
                    title: 'Top Countries',
                    icon: Icons.public,
                    data: combinedCountries,
                    limit: 5,
                  ),
                  const SizedBox(height: 16),
                  _DemographicCard(
                    title: 'Top Cities',
                    icon: Icons.location_city,
                    data: combinedCities,
                    limit: 5,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class _DemographicCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, int> data;
  final int limit;

  const _DemographicCard({
    required this.title,
    required this.icon,
    required this.data,
    this.limit = 10,
  });

  @override
  Widget build(BuildContext context) {
    // Sort by value descending
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(limit).toList();
    final total = data.values.fold(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: CommunicationsCommitteeTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (topEntries.isEmpty)
          Text(
            'No data available',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          )
        else
          ...topEntries.map((entry) {
            final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      CommunicationsCommitteeTheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
