import 'package:flutter/material.dart';
import '../models/audience_demographics.dart';
import '../theme/communications_committee_theme.dart';

/// Displays audience demographics data with enhanced visualization
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
    final isDark = theme.brightness == Brightness.dark;

    // Combine demographics from all accounts
    final combinedAgeGender = <String, num>{};
    final combinedCountries = <String, num>{};
    final combinedCities = <String, num>{};
    final deviceTypes = <String, num>{};
    final trafficSources = <String, num>{};

    for (final demo in demographics.values) {
      // Process age/gender data
      demo.ageGenderBreakdown.forEach((key, value) {
        final numValue = _toNum(value);
        combinedAgeGender[key] = (combinedAgeGender[key] ?? 0) + numValue;
      });

      // Process countries
      demo.topCountries.forEach((key, value) {
        final numValue = _toNum(value);
        combinedCountries[key] = (combinedCountries[key] ?? 0) + numValue;
      });

      // Process cities
      demo.topCities.forEach((key, value) {
        final numValue = _toNum(value);
        combinedCities[key] = (combinedCities[key] ?? 0) + numValue;
      });

      // Extract device types and traffic sources from platform_demographics
      final platformDemo = demo.platformDemographics;
      if (platformDemo.containsKey('device_types')) {
        final devices = platformDemo['device_types'];
        if (devices is List) {
          for (final device in devices) {
            if (device is Map) {
              final name = device['device']?.toString() ?? 'Unknown';
              final views = _toNum(device['views']);
              deviceTypes[name] = (deviceTypes[name] ?? 0) + views;
            }
          }
        }
      }

      if (platformDemo.containsKey('traffic_sources')) {
        final sources = platformDemo['traffic_sources'];
        if (sources is List) {
          for (final source in sources) {
            if (source is Map) {
              final name = _formatTrafficSource(source['source']?.toString() ?? 'Unknown');
              final views = _toNum(source['views']);
              trafficSources[name] = (trafficSources[name] ?? 0) + views;
            }
          }
        }
      }
    }

    // If no data at all, don't show section
    if (combinedAgeGender.isEmpty &&
        combinedCountries.isEmpty &&
        combinedCities.isEmpty &&
        deviceTypes.isEmpty &&
        trafficSources.isEmpty) {
      return const SizedBox.shrink();
    }

    // Parse age/gender into structured data
    final ageData = _parseAgeGenderData(combinedAgeGender);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CommunicationsCommitteeTheme.primary.withOpacity(0.1),
                  CommunicationsCommitteeTheme.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CommunicationsCommitteeTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.insights,
                    color: CommunicationsCommitteeTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Audience Demographics',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Understanding your audience across all platforms',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                final isMedium = constraints.maxWidth > 500;

                if (isWide) {
                  return Column(
                    children: [
                      // First row: Age distribution and Gender split
                      if (ageData.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _AgeDistributionChart(ageData: ageData),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _GenderSplitCard(ageData: ageData),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Second row: Countries, Cities, and Device/Traffic
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (combinedCountries.isNotEmpty)
                            Expanded(
                              child: _DemographicCard(
                                title: 'Top Countries',
                                icon: Icons.public,
                                data: _convertToIntMap(combinedCountries),
                                limit: 5,
                                showFlags: true,
                              ),
                            ),
                          if (combinedCountries.isNotEmpty && combinedCities.isNotEmpty)
                            const SizedBox(width: 20),
                          if (combinedCities.isNotEmpty)
                            Expanded(
                              child: _DemographicCard(
                                title: 'Top Cities',
                                icon: Icons.location_city,
                                data: _convertToIntMap(combinedCities),
                                limit: 5,
                              ),
                            ),
                          if ((combinedCountries.isNotEmpty || combinedCities.isNotEmpty) &&
                              (deviceTypes.isNotEmpty || trafficSources.isNotEmpty))
                            const SizedBox(width: 20),
                          if (deviceTypes.isNotEmpty || trafficSources.isNotEmpty)
                            Expanded(
                              child: Column(
                                children: [
                                  if (deviceTypes.isNotEmpty)
                                    _DemographicCard(
                                      title: 'Device Types',
                                      icon: Icons.devices,
                                      data: _convertToIntMap(deviceTypes),
                                      limit: 4,
                                    ),
                                  if (deviceTypes.isNotEmpty && trafficSources.isNotEmpty)
                                    const SizedBox(height: 16),
                                  if (trafficSources.isNotEmpty)
                                    _DemographicCard(
                                      title: 'Traffic Sources',
                                      icon: Icons.trending_up,
                                      data: _convertToIntMap(trafficSources),
                                      limit: 4,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                }

                // Mobile/tablet layout - stacked
                return Column(
                  children: [
                    if (ageData.isNotEmpty) ...[
                      _AgeDistributionChart(ageData: ageData),
                      const SizedBox(height: 16),
                      _GenderSplitCard(ageData: ageData),
                      const SizedBox(height: 16),
                    ],
                    if (isMedium && combinedCountries.isNotEmpty && combinedCities.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _DemographicCard(
                              title: 'Top Countries',
                              icon: Icons.public,
                              data: _convertToIntMap(combinedCountries),
                              limit: 5,
                              showFlags: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _DemographicCard(
                              title: 'Top Cities',
                              icon: Icons.location_city,
                              data: _convertToIntMap(combinedCities),
                              limit: 5,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      if (combinedCountries.isNotEmpty) ...[
                        _DemographicCard(
                          title: 'Top Countries',
                          icon: Icons.public,
                          data: _convertToIntMap(combinedCountries),
                          limit: 5,
                          showFlags: true,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (combinedCities.isNotEmpty) ...[
                        _DemographicCard(
                          title: 'Top Cities',
                          icon: Icons.location_city,
                          data: _convertToIntMap(combinedCities),
                          limit: 5,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                    if (deviceTypes.isNotEmpty) ...[
                      _DemographicCard(
                        title: 'Device Types',
                        icon: Icons.devices,
                        data: _convertToIntMap(deviceTypes),
                        limit: 4,
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (trafficSources.isNotEmpty)
                      _DemographicCard(
                        title: 'Traffic Sources',
                        icon: Icons.trending_up,
                        data: _convertToIntMap(trafficSources),
                        limit: 4,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _convertToIntMap(Map<String, num> input) {
    return input.map((k, v) => MapEntry(k, v.toInt()));
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    if (value is Map) {
      // If value is a map, try to get 'views' or 'count' from it
      return _toNum(value['views'] ?? value['count'] ?? value['value'] ?? 0);
    }
    return 0;
  }

  String _formatTrafficSource(String source) {
    return source
        .replaceAll('_', ' ')
        .replaceAll('YT ', 'YouTube ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join(' ');
  }

  Map<String, _AgeGenderBucket> _parseAgeGenderData(Map<String, num> raw) {
    final result = <String, _AgeGenderBucket>{};

    for (final entry in raw.entries) {
      String key = entry.key;
      String gender;
      String ageRange;

      // Handle formats like "F_18-24", "M_25-34", "U_35-44" (Instagram)
      // or "male_age18-24", "female_age25-34" (YouTube)
      if (key.contains('_')) {
        final parts = key.split('_');
        if (parts[0].toLowerCase() == 'male' || parts[0].toLowerCase() == 'm') {
          gender = 'M';
        } else if (parts[0].toLowerCase() == 'female' || parts[0].toLowerCase() == 'f') {
          gender = 'F';
        } else {
          gender = 'U'; // Unknown/unspecified
        }
        ageRange = parts.length > 1 ? parts[1].replaceAll('age', '') : 'Unknown';
      } else {
        continue; // Skip malformed entries
      }

      result.putIfAbsent(ageRange, () => _AgeGenderBucket(ageRange: ageRange));
      if (gender == 'M') {
        result[ageRange]!.male += entry.value;
      } else if (gender == 'F') {
        result[ageRange]!.female += entry.value;
      } else {
        result[ageRange]!.other += entry.value;
      }
    }

    return result;
  }
}

class _AgeGenderBucket {
  final String ageRange;
  num male = 0;
  num female = 0;
  num other = 0;

  _AgeGenderBucket({required this.ageRange});

  num get total => male + female + other;
}

class _AgeDistributionChart extends StatelessWidget {
  final Map<String, _AgeGenderBucket> ageData;

  const _AgeDistributionChart({required this.ageData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sort by age range
    final sortedRanges = ageData.keys.toList()
      ..sort((a, b) {
        final aStart = int.tryParse(a.split('-').first) ?? 0;
        final bStart = int.tryParse(b.split('-').first) ?? 0;
        return aStart.compareTo(bStart);
      });

    final maxTotal = ageData.values.map((b) => b.total).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, size: 18, color: CommunicationsCommitteeTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Age Distribution',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedRanges.map((range) {
            final bucket = ageData[range]!;
            final percentage = maxTotal > 0 ? bucket.total / maxTotal : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        range,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatNumber(bucket.total.toInt()),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          if (bucket.male > 0)
                            Expanded(
                              flex: bucket.male.toInt(),
                              child: Container(color: const Color(0xFF42A5F5)),
                            ),
                          if (bucket.female > 0)
                            Expanded(
                              flex: bucket.female.toInt(),
                              child: Container(color: const Color(0xFFEC407A)),
                            ),
                          if (bucket.other > 0)
                            Expanded(
                              flex: bucket.other.toInt(),
                              child: Container(color: Colors.grey),
                            ),
                          Expanded(
                            flex: ((maxTotal - bucket.total) * 0.3).toInt().clamp(0, 999999),
                            child: Container(
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: const Color(0xFF42A5F5), label: 'Male'),
              const SizedBox(width: 16),
              _LegendItem(color: const Color(0xFFEC407A), label: 'Female'),
              const SizedBox(width: 16),
              _LegendItem(color: Colors.grey, label: 'Other'),
            ],
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _GenderSplitCard extends StatelessWidget {
  final Map<String, _AgeGenderBucket> ageData;

  const _GenderSplitCard({required this.ageData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    num totalMale = 0;
    num totalFemale = 0;
    num totalOther = 0;

    for (final bucket in ageData.values) {
      totalMale += bucket.male;
      totalFemale += bucket.female;
      totalOther += bucket.other;
    }

    final total = totalMale + totalFemale + totalOther;
    if (total == 0) return const SizedBox.shrink();

    final malePercent = (totalMale / total * 100).toStringAsFixed(1);
    final femalePercent = (totalFemale / total * 100).toStringAsFixed(1);
    final otherPercent = (totalOther / total * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, size: 18, color: CommunicationsCommitteeTheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Gender Split',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _GenderRow(
            icon: Icons.male,
            label: 'Male',
            value: '$malePercent%',
            color: const Color(0xFF42A5F5),
            percent: totalMale / total,
          ),
          const SizedBox(height: 12),
          _GenderRow(
            icon: Icons.female,
            label: 'Female',
            value: '$femalePercent%',
            color: const Color(0xFFEC407A),
            percent: totalFemale / total,
          ),
          if (totalOther > 0) ...[
            const SizedBox(height: 12),
            _GenderRow(
              icon: Icons.person_outline,
              label: 'Other',
              value: '$otherPercent%',
              color: Colors.grey,
              percent: totalOther / total,
            ),
          ],
        ],
      ),
    );
  }
}

class _GenderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final double percent;

  const _GenderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12)),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: percent,
                  backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DemographicCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Map<String, int> data;
  final int limit;
  final bool showFlags;

  const _DemographicCard({
    required this.title,
    required this.icon,
    required this.data,
    this.limit = 10,
    this.showFlags = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sort by value descending
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(limit).toList();
    final total = data.values.fold(0, (a, b) => a + b);
    final maxValue = topEntries.isNotEmpty ? topEntries.first.value : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
        ),
      ),
      child: Column(
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
              style: TextStyle(color: theme.textTheme.bodySmall?.color?.withOpacity(0.5), fontSize: 12),
            )
          else
            ...topEntries.asMap().entries.map((mapEntry) {
              final index = mapEntry.key;
              final entry = mapEntry.value;
              final percentage = total > 0 ? (entry.value / total * 100) : 0.0;
              final barWidth = maxValue > 0 ? entry.value / maxValue : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showFlags) ...[
                          Text(
                            _getCountryFlag(entry.key),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            _formatLabel(entry.key),
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: barWidth,
                        backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          CommunicationsCommitteeTheme.getChartColor(index),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _formatLabel(String label) {
    // Clean up labels like "MOBILE" -> "Mobile"
    return label
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
        .join(' ');
  }

  String _getCountryFlag(String countryCode) {
    // Convert country code to flag emoji
    if (countryCode.length != 2) return '';
    final code = countryCode.toUpperCase();
    final firstLetter = code.codeUnitAt(0) - 65 + 0x1F1E6;
    final secondLetter = code.codeUnitAt(1) - 65 + 0x1F1E6;
    return String.fromCharCodes([firstLetter, secondLetter]);
  }
}
