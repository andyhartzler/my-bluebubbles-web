import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../../models/crm/dashboard_metrics.dart';
import '../../../models/crm/member.dart';
import '../models/dashboard_widget_config.dart';

// Brand colors
const _unityBlue = Color(0xFF273351);
const _momentumBlue = Color(0xFF32A6DE);
const _sunriseGold = Color(0xFFFDB813);
const _actionRed = Color(0xFFE63946);
const _justicePurple = Color(0xFF6A1B9A);
const _grassrootsGreen = Color(0xFF43A047);

// Additional blue variants
const _deepNavy = Color(0xFF0F4C75);
const _oceanBlue = Color(0xFF3282B8);
const _darkSlate = Color(0xFF1B262C);
const _skyBlue = Color(0xFF5DADE2);
const _royalBlue = Color(0xFF2E86AB);
const _midnightBlue = Color(0xFF1A237E);
const _indigoBlue = Color(0xFF3949AB);
const _tealBlue = Color(0xFF00838F);

/// Default gradient sets for widgets
class WidgetGradients {
  static const List<List<Color>> all = [
    // Brand gradients
    [_unityBlue, _momentumBlue],
    [_momentumBlue, _justicePurple],
    [_grassrootsGreen, _momentumBlue],
    [_sunriseGold, _actionRed],
    [_justicePurple, _actionRed],
    [_actionRed, _sunriseGold],
    [_grassrootsGreen, _sunriseGold],
    [_unityBlue, _grassrootsGreen],
    // Blue variants
    [_deepNavy, _oceanBlue],
    [_darkSlate, _oceanBlue],
    [_unityBlue, _skyBlue],
    [_royalBlue, _momentumBlue],
    [_midnightBlue, _indigoBlue],
    [_tealBlue, _momentumBlue],
    [_deepNavy, _momentumBlue],
    [_indigoBlue, _skyBlue],
  ];

  /// Names for the gradients (for display in UI)
  static const List<String> names = [
    'Unity Blue',
    'Momentum Purple',
    'Grassroots Teal',
    'Sunrise Fire',
    'Purple Heat',
    'Warm Sunset',
    'Nature Glow',
    'Forest Blue',
    'Deep Ocean',
    'Slate Ocean',
    'Sky Gradient',
    'Royal Momentum',
    'Midnight Indigo',
    'Teal Momentum',
    'Navy Momentum',
    'Indigo Sky',
  ];

  static List<Color> get random => all[math.Random().nextInt(all.length)];

  /// Get gradient index from colors
  static int? indexOfColors(List<Color> colors) {
    if (colors.isEmpty) return null;
    for (int i = 0; i < all.length; i++) {
      if (all[i].length >= 2 &&
          colors.length >= 2 &&
          all[i][0].value == colors[0].value &&
          all[i][1].value == colors[1].value) {
        return i;
      }
    }
    return null;
  }
}

/// Background color options for widgets with white backgrounds
class WidgetBackgrounds {
  /// Solid background colors (null = white/default)
  static const List<Color?> solidColors = [
    null, // White (default)
    Color(0xFFF8F9FA), // Light gray
    Color(0xFFE3F2FD), // Light blue
    Color(0xFFE8F5E9), // Light green
    Color(0xFFFFF3E0), // Light orange
    Color(0xFFFCE4EC), // Light pink
    Color(0xFFF3E5F5), // Light purple
    Color(0xFFE0F7FA), // Light cyan
    Color(0xFFFFFDE7), // Light yellow
    Color(0xFFEFEBE9), // Light brown
    Color(0xFFECEFF1), // Blue gray
    Color(0xFF263238), // Dark slate (for dark mode look)
  ];

  static const List<String> colorNames = [
    'White',
    'Light Gray',
    'Light Blue',
    'Light Green',
    'Light Orange',
    'Light Pink',
    'Light Purple',
    'Light Cyan',
    'Light Yellow',
    'Light Brown',
    'Blue Gray',
    'Dark Slate',
  ];

  /// Get color by index from options value
  static Color? getColorFromIndex(int? index) {
    if (index == null || index < 0 || index >= solidColors.length) return null;
    return solidColors[index];
  }

  /// Get background color from widget options
  static Color getBackgroundColor(Map<String, dynamic> options) {
    final index = options['backgroundColorIndex'] as int?;
    return getColorFromIndex(index) ?? Colors.white;
  }

  /// Check if using dark background
  static bool isDarkBackground(Map<String, dynamic> options) {
    final index = options['backgroundColorIndex'] as int?;
    return index == solidColors.length - 1; // Dark slate
  }

  /// Get text color based on background
  static Color getTextColor(Map<String, dynamic> options) {
    return isDarkBackground(options) ? Colors.white : _unityBlue;
  }

  /// Get secondary text color based on background
  static Color getSecondaryTextColor(Map<String, dynamic> options) {
    return isDarkBackground(options) ? Colors.white70 : Colors.grey[600]!;
  }
}

/// Renders a stat card widget
class StatCardWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final dynamic value;
  final String? trend;
  final VoidCallback? onTap;

  const StatCardWidget({
    super.key,
    required this.config,
    required this.value,
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : WidgetGradients.all[0];

    final displayValue = _formatValue(value);
    final isMini = config.size == DashboardWidgetSize.mini;
    final isSmall = config.size == DashboardWidgetSize.small;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.all(isSmall ? 12 : (isMini ? 16 : 20)),
          child: isSmall
              ? _buildSmallLayout(displayValue)
              : (isMini
                    ? _buildMiniLayout(displayValue)
                    : _buildStandardLayout(displayValue)),
        ),
      ),
    );
  }

  /// Compact square layout for mini size - number on top, name/icon below
  /// Fully responsive - scales to any screen size
  Widget _buildMiniLayout(String displayValue) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive sizes based on available space
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        // Number takes up ~60% of height, label takes ~40%
        final numberHeight = availableHeight * 0.55;
        final labelHeight = availableHeight * 0.35;
        final spacing = availableHeight * 0.1;

        // Calculate icon size proportional to available width
        final iconSize = (availableWidth * 0.15).clamp(12.0, 20.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Large number at the top - takes majority of space
            SizedBox(
              height: numberHeight,
              width: availableWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72, // Large base size, FittedBox will scale down
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            SizedBox(height: spacing),
            // Stat name and icon at the bottom - smaller, compact
            SizedBox(
              height: labelHeight,
              width: availableWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (config.icon != null) ...[
                      Icon(
                        config.icon,
                        color: Colors.white.withOpacity(0.9),
                        size: iconSize,
                      ),
                      SizedBox(width: iconSize * 0.3),
                    ],
                    Text(
                      config.title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 14, // Base size, FittedBox scales
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Compact horizontal layout for small size (half-height row)
  Widget _buildSmallLayout(String displayValue) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            config.icon ?? Icons.analytics,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                config.title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Text(
          displayValue,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Standard vertical layout for small and larger sizes
  Widget _buildStandardLayout(String displayValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                config.icon ?? Icons.analytics,
                color: Colors.white,
                size: 24,
              ),
            ),
            if (trend != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trend!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const Spacer(),
        Text(
          displayValue,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          config.title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (config.subtitle != null)
          Text(
            config.subtitle!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  String _formatValue(dynamic val) {
    if (val is num) {
      // For monetary values, show full amount with dollar sign and commas, no decimals
      if (config.dataSourceKey.contains('Amount') ||
          config.dataSourceKey.contains('Donation')) {
        return '\$${_formatWithCommas(val.toInt())}';
      }
      // For all other numbers, show full value with commas (no K/M abbreviation)
      if (val is double) {
        // If it's a whole number (no decimal or .0), show as integer with commas
        if (val == val.truncateToDouble()) {
          return _formatWithCommas(val.toInt());
        }
        return val.toStringAsFixed(1);
      }
      return _formatWithCommas(val.toInt());
    }
    return val?.toString() ?? '-';
  }

  /// Format number with comma separators (e.g., 1500 -> "1,500")
  String _formatWithCommas(int value) {
    final str = value.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(str[i]);
    }
    return result.toString();
  }
}

/// Renders a bar chart widget with horizontal scrolling for mobile
class BarChartWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final List<NameCount> data;
  final int maxItems;

  const BarChartWidget({
    super.key,
    required this.config,
    required this.data,
    this.maxItems = 20,
  });

  @override
  Widget build(BuildContext context) {
    final sortedData = List<NameCount>.from(data)
      ..sort((a, b) => b.count.compareTo(a.count));
    final displayData = sortedData.take(maxItems).toList();
    final backgroundColor = WidgetBackgrounds.getBackgroundColor(
      config.options,
    );

    if (displayData.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Safety check: ensure valid constraints before rendering chart
                  if (constraints.maxWidth <= 0 ||
                      constraints.maxHeight <= 0 ||
                      !constraints.maxWidth.isFinite ||
                      !constraints.maxHeight.isFinite) {
                    return const SizedBox.shrink();
                  }
                  // Use horizontal bar chart for small screens
                  final isSmall = constraints.maxWidth < 300;
                  if (isSmall) {
                    return _buildHorizontalBars(displayData, constraints);
                  }
                  return _buildVerticalChart(displayData, constraints);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalChart(
    List<NameCount> displayData,
    BoxConstraints constraints,
  ) {
    final maxValue = displayData.fold<int>(
      0,
      (prev, e) => e.count > prev ? e.count : prev,
    );
    final barWidth = ((constraints.maxWidth - 60) / displayData.length).clamp(
      12.0,
      28.0,
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxValue * 1.2).clamp(1, double.infinity).toDouble(),
        barGroups: List.generate(displayData.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: displayData[index].count.toDouble(),
                width: barWidth,
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: config.gradientColors.isNotEmpty
                      ? config.gradientColors
                      : [_momentumBlue, _justicePurple],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
          );
        }),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          // X-axis labels removed - hover/tap on bars to see names in tooltip
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  _formatNumber(value.toInt()),
                  style: const TextStyle(fontSize: 9, color: _unityBlue),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: _unityBlue.withOpacity(0.95),
            tooltipRoundedRadius: 8,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final entry = displayData[groupIndex];
              return BarTooltipItem(
                '${entry.name}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: '${entry.count} members',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalBars(
    List<NameCount> displayData,
    BoxConstraints constraints,
  ) {
    final maxValue = displayData.fold<int>(
      0,
      (prev, e) => e.count > prev ? e.count : prev,
    );

    return ListView.builder(
      itemCount: displayData.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final entry = displayData[index];
        final percentage = maxValue > 0 ? entry.count / maxValue : 0.0;

        return Tooltip(
          message: '${entry.name}: ${entry.count}',
          waitDuration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                // Label - show full name with overflow handling
                SizedBox(
                  width: 70,
                  child: Text(
                    entry.name,
                    style: const TextStyle(fontSize: 10, color: _unityBlue),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                // Bar
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: config.gradientColors.isNotEmpty
                                  ? config.gradientColors
                                  : [_momentumBlue, _justicePurple],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Value
                SizedBox(
                  width: 32,
                  child: Text(
                    _formatNumber(entry.count),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _unityBlue,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatNumber(int value) {
    // Show full numbers with commas instead of abbreviated K/M
    final str = value.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(str[i]);
    }
    return result.toString();
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _momentumBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            config.icon ?? Icons.bar_chart,
            color: _momentumBlue,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            config.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: _unityBlue,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dynamic distribution chart with dropdown selector
class DynamicDistributionChartWidget extends StatefulWidget {
  final DashboardWidgetConfig config;
  final DashboardMetrics metrics;

  const DynamicDistributionChartWidget({
    super.key,
    required this.config,
    required this.metrics,
  });

  @override
  State<DynamicDistributionChartWidget> createState() =>
      _DynamicDistributionChartWidgetState();
}

class _DynamicDistributionChartWidgetState
    extends State<DynamicDistributionChartWidget> {
  late String _selectedKey;

  static const _distributionOptions = [
    ('membersByCounty', 'Top Counties', Icons.map),
    (
      'membersByCongressionalDistrict',
      'Congressional Districts',
      Icons.location_city,
    ),
    ('membersByCommittee', 'Committees', Icons.groups),
    ('membersByHighSchool', 'High Schools', Icons.school),
    ('membersByCollege', 'Colleges', Icons.account_balance),
    ('membersByChapter', 'Chapters', Icons.flag),
    ('membersByChapterStatus', 'Chapter Status', Icons.verified),
    ('membersByGraduationYear', 'Graduation Years', Icons.calendar_today),
    ('ageDistribution', 'Age Distribution', Icons.cake),
    ('membersBySexualOrientation', 'Sexual Orientation', Icons.favorite),
    ('membersByPronouns', 'Pronouns', Icons.record_voice_over),
    ('membersByGenderIdentity', 'Gender Identity', Icons.wc),
    ('membersByRace', 'Race & Ethnicity', Icons.diversity_3),
    ('membersByCommunityType', 'Community Type', Icons.location_city),
    ('membersByIndustry', 'Industries', Icons.work),
    ('membersByEducationLevel', 'Education Level', Icons.school),
    ('membersByVoterRegistration', 'Voter Registration', Icons.how_to_vote),
    ('membersByReferralSource', 'Referral Sources', Icons.share),
  ];

  @override
  void initState() {
    super.initState();
    // Use stored selection from options, or default to first option
    _selectedKey =
        widget.config.options['selectedDistribution'] as String? ??
        _distributionOptions.first.$1;
  }

  List<NameCount> _getDataForKey(String key) {
    final metrics = widget.metrics;
    switch (key) {
      case 'membersByCounty':
        return metrics.membersByCounty;
      case 'membersByCongressionalDistrict':
        return metrics.membersByCongressionalDistrict;
      case 'membersByHouseDistrict':
        return metrics.membersByHouseDistrict;
      case 'membersBySenateDistrict':
        return metrics.membersBySenateDistrict;
      case 'membersByCommunityType':
        return metrics.membersByCommunityType;
      case 'membersByCollege':
        return metrics.membersByCollege;
      case 'membersByHighSchool':
        return metrics.membersByHighSchool;
      case 'membersByGraduationYear':
        return metrics.membersByGraduationYear;
      case 'membersByEducationLevel':
        return metrics.membersByEducationLevel;
      case 'membersByChapter':
        return metrics.membersByChapter;
      case 'membersByChapterStatus':
        return metrics.membersByChapterStatus;
      case 'membersByCommittee':
        return metrics.membersByCommittee;
      case 'membersByGenderIdentity':
        return metrics.membersByGenderIdentity;
      case 'membersByPronouns':
        return metrics.membersByPronouns;
      case 'membersByRace':
        return metrics.membersByRace;
      case 'membersBySexualOrientation':
        return metrics.membersBySexualOrientation;
      case 'membersByVoterRegistration':
        return metrics.membersByVoterRegistration;
      case 'membersByIndustry':
        return metrics.membersByIndustry;
      case 'membersByReferralSource':
        return metrics.membersByReferralSource;
      case 'ageDistribution':
        return [
          NameCount(name: '14-17', count: metrics.age14To17Count),
          NameCount(name: '18-21', count: metrics.age18To21Count),
          NameCount(name: '22-25', count: metrics.age22To25Count),
          NameCount(name: '26-30', count: metrics.age26To30Count),
          NameCount(name: '31-36', count: metrics.age31To36Count),
          NameCount(name: 'Unknown', count: metrics.ageUnknownCount),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOption = _distributionOptions.firstWhere(
      (opt) => opt.$1 == _selectedKey,
      orElse: () => _distributionOptions.first,
    );
    final data = _getDataForKey(_selectedKey);
    final backgroundColor = WidgetBackgrounds.getBackgroundColor(
      widget.config.options,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(currentOption),
            const SizedBox(height: 12),
            Expanded(
              child: data.isEmpty
                  ? _buildEmptyState()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Safety check: ensure valid constraints before rendering chart
                        // This prevents layout errors during animation transitions
                        if (constraints.maxWidth <= 0 ||
                            constraints.maxHeight <= 0 ||
                            !constraints.maxWidth.isFinite ||
                            !constraints.maxHeight.isFinite) {
                          return const SizedBox.shrink();
                        }
                        return _buildChart(data, constraints);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader((String, String, IconData) currentOption) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _momentumBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(currentOption.$3, color: _momentumBlue, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PopupMenuButton<String>(
            initialValue: _selectedKey,
            onSelected: (key) {
              if (!mounted) return;
              try {
                setState(() {
                  _selectedKey = key;
                });
              } catch (e) {
                // Silently ignore errors from setState during invalid states
              }
            },
            constraints: const BoxConstraints(maxHeight: 400),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    currentOption.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _unityBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: _momentumBlue, size: 20),
              ],
            ),
            color: _unityBlue,
            itemBuilder: (context) => _distributionOptions.map((opt) {
              return PopupMenuItem<String>(
                value: opt.$1,
                child: Row(
                  children: [
                    Icon(
                      opt.$3,
                      size: 18,
                      color: opt.$1 == _selectedKey
                          ? _grassrootsGreen
                          : Colors.white70,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        opt.$2,
                        style: TextStyle(
                          fontWeight: opt.$1 == _selectedKey
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: opt.$1 == _selectedKey
                              ? Colors.white
                              : Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                    if (opt.$1 == _selectedKey)
                      const Icon(
                        Icons.check,
                        size: 16,
                        color: _grassrootsGreen,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildChart(List<NameCount> rawData, BoxConstraints constraints) {
    // Sort and limit data - show up to 20 bars for comprehensive view
    final sortedData = List<NameCount>.from(rawData)
      ..sort((a, b) => b.count.compareTo(a.count));
    final displayData = sortedData.take(20).toList();

    if (displayData.isEmpty) {
      return _buildEmptyState();
    }

    final maxValue = displayData.fold<int>(
      0,
      (prev, e) => e.count > prev ? e.count : prev,
    );
    final isSmall = constraints.maxWidth < 280;
    // Use horizontal bars for mobileFull size (like tall layout but full width)
    final isMobileFull = widget.config.size == DashboardWidgetSize.mobileFull;

    // Use horizontal bars for small screens OR mobileFull size
    if (isSmall || isMobileFull) {
      return _buildHorizontalBars(displayData, maxValue);
    }

    return _buildVerticalBars(displayData, maxValue, constraints);
  }

  Widget _buildVerticalBars(
    List<NameCount> displayData,
    int maxValue,
    BoxConstraints constraints,
  ) {
    final barWidth = ((constraints.maxWidth - 60) / displayData.length).clamp(
      14.0,
      32.0,
    );

    // Calculate a nice interval for y-axis labels (aim for 4-5 labels)
    final yAxisInterval = _calculateNiceInterval(maxValue, 4);
    final adjustedMaxY =
        ((maxValue / yAxisInterval).ceil() * yAxisInterval * 1.1).clamp(
          1.0,
          double.infinity,
        );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: adjustedMaxY,
        barGroups: List.generate(displayData.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: displayData[index].count.toDouble(),
                width: barWidth,
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: widget.config.gradientColors.isNotEmpty
                      ? widget.config.gradientColors
                      : [_momentumBlue, _justicePurple],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ],
          );
        }),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          // X-axis labels removed - hover/tap on bars to see names in tooltip
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: yAxisInterval,
              getTitlesWidget: (value, meta) {
                // Skip 0 and values very close to max (to avoid cramping at top)
                if (value == 0 || value > adjustedMaxY * 0.95) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _formatNumber(value.toInt()),
                    style: const TextStyle(fontSize: 10, color: _unityBlue),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: _unityBlue.withOpacity(0.95),
            tooltipRoundedRadius: 8,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final entry = displayData[groupIndex];
              return BarTooltipItem(
                '${entry.name}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                children: [
                  TextSpan(
                    text: '${entry.count} members',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalBars(List<NameCount> displayData, int maxValue) {
    return ListView.builder(
      itemCount: displayData.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final entry = displayData[index];
        final percentage = maxValue > 0 ? entry.count / maxValue : 0.0;

        return Tooltip(
          message: '${entry.name}: ${entry.count}',
          waitDuration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                // Label - show full name with ellipsis if needed
                SizedBox(
                  width: 65,
                  child: Text(
                    entry.name,
                    style: const TextStyle(fontSize: 10, color: _unityBlue),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                // Bar
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.config.gradientColors.isNotEmpty
                                  ? widget.config.gradientColors
                                  : [_momentumBlue, _justicePurple],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Value
                SizedBox(
                  width: 28,
                  child: Text(
                    _formatNumber(entry.count),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _unityBlue,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatNumber(int value) {
    // Show full numbers with commas instead of abbreviated K/M
    final str = value.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result.write(',');
      }
      result.write(str[i]);
    }
    return result.toString();
  }

  /// Calculate a nice round interval for y-axis labels
  double _calculateNiceInterval(int maxValue, int targetLabels) {
    if (maxValue <= 0) return 1.0;

    // Calculate raw interval
    final rawInterval = maxValue / targetLabels;

    // Find the order of magnitude
    final magnitude = math
        .pow(10, (math.log(rawInterval) / math.ln10).floor())
        .toDouble();

    // Calculate normalized value (1-10 range)
    final normalized = rawInterval / magnitude;

    // Round to nice values (1, 2, 2.5, 5, or 10)
    double niceNormalized;
    if (normalized <= 1) {
      niceNormalized = 1;
    } else if (normalized <= 2) {
      niceNormalized = 2;
    } else if (normalized <= 2.5) {
      niceNormalized = 2.5;
    } else if (normalized <= 5) {
      niceNormalized = 5;
    } else {
      niceNormalized = 10;
    }

    return niceNormalized * magnitude;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No data available',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Renders a pie/donut chart widget
class PieChartWidget extends StatefulWidget {
  final DashboardWidgetConfig config;
  final List<NameCount> data;
  final bool isDonut;

  const PieChartWidget({
    super.key,
    required this.config,
    required this.data,
    this.isDonut = false,
  });

  @override
  State<PieChartWidget> createState() => _PieChartWidgetState();
}

class _PieChartWidgetState extends State<PieChartWidget> {
  int _touchedIndex = -1;

  static const List<Color> _pieColors = [
    _momentumBlue,
    _grassrootsGreen,
    _sunriseGold,
    _justicePurple,
    _actionRed,
    Color(0xFF00BCD4),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFFE91E63),
    Color(0xFF3F51B5),
  ];

  @override
  Widget build(BuildContext context) {
    final backgroundColor = WidgetBackgrounds.getBackgroundColor(
      widget.config.options,
    );
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: backgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _buildResponsiveChart(constraints);
        },
      ),
    );
  }

  Widget _buildResponsiveChart(BoxConstraints constraints) {
    // Safety check: ensure valid constraints before rendering chart
    if (constraints.maxWidth <= 0 ||
        constraints.maxHeight <= 0 ||
        !constraints.maxWidth.isFinite ||
        !constraints.maxHeight.isFinite) {
      return const SizedBox.shrink();
    }
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final isCompact = width < 250 || height < 200;
    final isLarge = width >= 400 && height >= 300;
    final isMedium = !isCompact && !isLarge;
    final textColor = WidgetBackgrounds.getTextColor(widget.config.options);
    final secondaryTextColor = WidgetBackgrounds.getSecondaryTextColor(
      widget.config.options,
    );

    // Dynamic maxItems based on size
    final maxItems = isCompact ? 5 : (isLarge ? 12 : 8);

    final sortedData = List<NameCount>.from(widget.data)
      ..sort((a, b) => b.count.compareTo(a.count));
    final displayData = sortedData.take(maxItems).toList();

    // Add "Other" category if there are more items
    if (sortedData.length > maxItems) {
      final otherCount = sortedData
          .skip(maxItems)
          .fold<int>(0, (sum, e) => sum + e.count);
      if (otherCount > 0) {
        displayData.add(
          NameCount(
            name: 'Other (${sortedData.length - maxItems} more)',
            count: otherCount,
          ),
        );
      }
    }

    if (displayData.isEmpty) {
      return _buildEmptyState();
    }

    final total = displayData.fold<int>(0, (sum, e) => sum + e.count);

    // Calculate dynamic pie radius based on available space
    final availableChartHeight = height - 80; // Account for header
    final availableChartWidth = isCompact ? width - 40 : (width - 40) * 0.55;
    final maxRadius =
        math.min(availableChartHeight / 2, availableChartWidth / 2) - 10;
    final baseRadius = maxRadius.clamp(30.0, 120.0);
    final touchedRadius = baseRadius + 10;

    // For compact view, show chart only with tooltip on hover/touch
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(compact: true),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: _buildPieWithTooltip(
                  displayData,
                  total,
                  baseRadius,
                  touchedRadius,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // For medium/large views, show chart with legend
    return Container(
      padding: EdgeInsets.all(isLarge ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(compact: false),
          SizedBox(height: isLarge ? 16 : 12),
          Expanded(
            child: Row(
              children: [
                // Pie chart section
                Expanded(
                  flex: isLarge ? 5 : 4,
                  child: Center(
                    child: _buildPieWithTooltip(
                      displayData,
                      total,
                      baseRadius,
                      touchedRadius,
                    ),
                  ),
                ),
                SizedBox(width: isLarge ? 20 : 12),
                // Legend section
                Expanded(
                  flex: isLarge ? 4 : 3,
                  child: _buildLegend(displayData, total, isLarge: isLarge),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieWithTooltip(
    List<NameCount> displayData,
    int total,
    double baseRadius,
    double touchedRadius,
  ) {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            // Guard against callbacks firing after widget disposal
            // and handle any type errors from fl_chart touch handling on Flutter Web
            if (!mounted) return;
            try {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    response == null ||
                    response.touchedSection == null) {
                  _touchedIndex = -1;
                  return;
                }
                _touchedIndex = response.touchedSection!.touchedSectionIndex;
              });
            } catch (e) {
              // Silently ignore touch callback errors to prevent rendering crashes
              // This can happen on Flutter Web with fl_chart touch handling
            }
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: widget.isDonut ? baseRadius * 0.5 : 0,
        sections: List.generate(displayData.length, (index) {
          final isTouched = index == _touchedIndex;
          final entry = displayData[index];
          final percentage = total > 0 ? (entry.count / total * 100) : 0.0;

          return PieChartSectionData(
            color: _pieColors[index % _pieColors.length],
            value: entry.count.toDouble(),
            // Show full name and percentage when touched
            title: isTouched
                ? '${entry.name}\n${percentage.toStringAsFixed(1)}%'
                : '',
            radius: isTouched ? touchedRadius : baseRadius,
            titleStyle: TextStyle(
              fontSize: isTouched ? 11 : 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
            titlePositionPercentageOffset: 0.55,
            badgePositionPercentageOffset: 1.1,
          );
        }),
      ),
    );
  }

  Widget _buildLegend(
    List<NameCount> displayData,
    int total, {
    required bool isLarge,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(displayData.length, (index) {
          final entry = displayData[index];
          final percentage = total > 0 ? (entry.count / total * 100) : 0.0;
          final isSelected = _touchedIndex == index;

          return Tooltip(
            message:
                '${entry.name}: ${entry.count} (${percentage.toStringAsFixed(1)}%)',
            waitDuration: const Duration(milliseconds: 300),
            child: InkWell(
              onTap: () {
                if (!mounted) return;
                try {
                  setState(() {
                    _touchedIndex = _touchedIndex == index ? -1 : index;
                  });
                } catch (e) {
                  // Silently ignore errors from setState during invalid states
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  vertical: isLarge ? 6 : 4,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _pieColors[index % _pieColors.length].withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: isLarge ? 12 : 10,
                      height: isLarge ? 12 : 10,
                      decoration: BoxDecoration(
                        color: _pieColors[index % _pieColors.length],
                        shape: BoxShape.circle,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _pieColors[index % _pieColors.length]
                                      .withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    SizedBox(width: isLarge ? 10 : 6),
                    Expanded(
                      child: Text(
                        entry.name, // Always show full name
                        style: TextStyle(
                          fontSize: isLarge ? 13 : 11,
                          color: isSelected ? _unityBlue : Colors.grey[700],
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: isLarge ? 12 : 10,
                        color: isSelected ? _unityBlue : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader({required bool compact}) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(compact ? 6 : 8),
          decoration: BoxDecoration(
            color: _momentumBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            widget.config.icon ?? Icons.pie_chart,
            color: _momentumBlue,
            size: compact ? 16 : 20,
          ),
        ),
        SizedBox(width: compact ? 8 : 12),
        Expanded(
          child: Text(
            widget.config.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 14 : 16,
              color: _unityBlue,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pie_chart, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No data available',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a line chart widget
class LineChartWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final List<MonthlyCount> data;

  const LineChartWidget({super.key, required this.config, required this.data});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = WidgetBackgrounds.getBackgroundColor(
      config.options,
    );

    if (data.isEmpty) {
      return _buildEmptyState();
    }

    final sortedData = List<MonthlyCount>.from(data)
      ..sort((a, b) => a.month.compareTo(b.month));

    final maxValue = sortedData.fold<int>(
      0,
      (prev, e) => e.count > prev ? e.count : prev,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Safety check: ensure valid constraints before rendering chart
                  if (constraints.maxWidth <= 0 ||
                      constraints.maxHeight <= 0 ||
                      !constraints.maxWidth.isFinite ||
                      !constraints.maxHeight.isFinite) {
                    return const SizedBox.shrink();
                  }
                  return LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: (maxValue * 1.2)
                          .clamp(1, double.infinity)
                          .toDouble(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxValue > 0 ? maxValue / 4 : 1,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: Colors.grey[300]!, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= sortedData.length) {
                                return const SizedBox.shrink();
                              }
                              final month = sortedData[index].month;
                              // Format: 2025-10 -> Oct
                              final parts = month.split('-');
                              if (parts.length < 2)
                                return const SizedBox.shrink();
                              final monthNames = [
                                'Jan',
                                'Feb',
                                'Mar',
                                'Apr',
                                'May',
                                'Jun',
                                'Jul',
                                'Aug',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dec',
                              ];
                              final monthNum = int.tryParse(parts[1]) ?? 1;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  monthNames[monthNum - 1],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: _unityBlue,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 35,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: _unityBlue,
                              ),
                            ),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(sortedData.length, (index) {
                            return FlSpot(
                              index.toDouble(),
                              sortedData[index].count.toDouble(),
                            );
                          }),
                          isCurved: true,
                          color: _momentumBlue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: _momentumBlue,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                _momentumBlue.withOpacity(0.3),
                                _momentumBlue.withOpacity(0.05),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: _unityBlue.withOpacity(0.9),
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              final entry = sortedData[spot.x.toInt()];
                              return LineTooltipItem(
                                '${entry.month}\n${entry.count} new members',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _momentumBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            config.icon ?? Icons.show_chart,
            color: _momentumBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            config.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _unityBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a leaderboard widget
class LeaderboardWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final List<dynamic> data; // Can be TopDonor or TopSlackMember
  final bool isDonors;
  final int maxItems;
  final VoidCallback? onTap;

  const LeaderboardWidget({
    super.key,
    required this.config,
    required this.data,
    this.isDonors = false,
    this.maxItems = 25,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayData = data.take(maxItems).toList();
    final backgroundColor = WidgetBackgrounds.getBackgroundColor(
      config.options,
    );

    if (displayData.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: displayData.length,
                  itemBuilder: (context, index) {
                    final item = displayData[index];
                    final name = isDonors
                        ? (item as TopDonor).name
                        : (item as TopSlackMember).name;
                    final value = isDonors
                        ? '\$${(item as TopDonor).totalDonated.toStringAsFixed(0)}'
                        : '${(item as TopSlackMember).messageCount} msgs';
                    final profilePhotoUrl = isDonors
                        ? null
                        : (item as TopSlackMember).profilePhotoUrl;

                    return _buildLeaderboardItem(
                      rank: index + 1,
                      name: name,
                      value: value,
                      profilePhotoUrl: profilePhotoUrl,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _sunriseGold.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            config.icon ?? Icons.emoji_events,
            color: _sunriseGold,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            config.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _unityBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardItem({
    required int rank,
    required String name,
    required String value,
    String? profilePhotoUrl,
  }) {
    final rankColors = [_sunriseGold, Colors.grey[400]!, Color(0xFFCD7F32)];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : Colors.grey[300]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.2),
              shape: BoxShape.circle,
              border: rank <= 3 ? Border.all(color: rankColor, width: 2) : null,
            ),
            child: Center(
              child: rank <= 3
                  ? Icon(Icons.emoji_events, size: 12, color: rankColor)
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          // Profile photo avatar
          _buildMemberAvatar(name, profilePhotoUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: rank <= 3 ? FontWeight.w600 : FontWeight.normal,
                color: _unityBlue,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _grassrootsGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _grassrootsGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build member avatar with photo or initials fallback
  Widget _buildMemberAvatar(String name, String? photoUrl) {
    const size = 32.0;

    // Generate initials for fallback
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials =
        parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');

    // Generate a consistent color based on the name
    final colorIndex = name.hashCode.abs() % WidgetGradients.all.length;
    final gradientColors = WidgetGradients.all[colorIndex];

    Widget fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      );
    }

    return fallback;
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.leaderboard, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No data available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress ring widget for showing percentage/goal progress
/// Supports gradient backgrounds and customizable progress bar colors
class ProgressRingWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final int current;
  final int total;
  final String? suffix;

  const ProgressRingWidget({
    super.key,
    required this.config,
    required this.current,
    required this.total,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

    // Check if using gradient background (default true for progress rings)
    final useGradientBg = config.options['useGradientBackground'] as bool? ?? true;

    // Get gradient colors for background
    final gradientColors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : WidgetGradients.all[0];

    // Get progress bar color - can be customized independently
    final progressBarColorIndex = config.options['progressBarColorIndex'] as int?;
    final Color progressBarColor;
    if (progressBarColorIndex != null && progressBarColorIndex >= 0 &&
        progressBarColorIndex < WidgetGradients.all.length) {
      progressBarColor = WidgetGradients.all[progressBarColorIndex].first;
    } else {
      // Default to white for gradient backgrounds, or primary color for solid
      progressBarColor = useGradientBg ? Colors.white : gradientColors.first;
    }

    // Text colors - white for gradient backgrounds
    final textColor = useGradientBg ? Colors.white : Colors.black87;
    final secondaryTextColor = useGradientBg
        ? Colors.white.withOpacity(0.8)
        : Colors.grey[600]!;

    // Progress background color
    final progressBgColor = useGradientBg
        ? Colors.white.withOpacity(0.25)
        : progressBarColor.withOpacity(0.15);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: useGradientBg
              ? LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: useGradientBg ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate the ring size based on available space
            // Use the smaller of width/height to ensure a perfect circle
            final availableWidth = constraints.maxWidth;
            final availableHeight = constraints.maxHeight;

            // Reserve space for title and padding
            final titleHeight = 40.0; // Space for title
            final padding = 16.0;
            final ringAreaHeight = availableHeight - titleHeight - (padding * 2);
            final ringAreaWidth = availableWidth - (padding * 2);

            // Ring size is the minimum of available width and height for the ring area
            final ringSize = (ringAreaWidth < ringAreaHeight ? ringAreaWidth : ringAreaHeight) * 0.85;
            final clampedRingSize = ringSize.clamp(60.0, 200.0);

            // Scale font sizes based on ring size
            final valueFontSize = (clampedRingSize * 0.25).clamp(16.0, 36.0);
            final suffixFontSize = (clampedRingSize * 0.12).clamp(10.0, 16.0);
            final strokeWidth = (clampedRingSize * 0.08).clamp(6.0, 12.0);

            return Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Progress Ring - centered and properly circular
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: clampedRingSize,
                        height: clampedRingSize,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Progress ring
                            CircularProgressIndicator(
                              value: percentage,
                              strokeWidth: strokeWidth,
                              backgroundColor: progressBgColor,
                              valueColor: AlwaysStoppedAnimation<Color>(progressBarColor),
                              strokeCap: StrokeCap.round,
                            ),
                            // Center content
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Current value
                                  Text(
                                    current.toString(),
                                    style: TextStyle(
                                      fontSize: valueFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                      height: 1.1,
                                    ),
                                  ),
                                  // Suffix (e.g., "/ 114" or "%" for percentages)
                                  Text(
                                    suffix ?? '/ $total',
                                    style: TextStyle(
                                      fontSize: suffixFontSize,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Title - always at bottom
                  const SizedBox(height: 8),
                  Text(
                    config.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Renders a member list widget with profile photos
class MemberListWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final List<Member> members;
  final void Function(Member member)? onMemberTap;
  final int maxItems;

  const MemberListWidget({
    super.key,
    required this.config,
    required this.members,
    this.onMemberTap,
    this.maxItems = 25,
  });

  @override
  Widget build(BuildContext context) {
    final displayMembers = members.take(maxItems).toList();
    final backgroundColor = WidgetBackgrounds.getBackgroundColor(
      config.options,
    );

    if (displayMembers.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: displayMembers.length,
                itemBuilder: (context, index) {
                  final member = displayMembers[index];
                  return _buildMemberItem(context, member, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _grassrootsGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            config.icon ?? Icons.person_add,
            color: _grassrootsGreen,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            config.title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: _unityBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberItem(BuildContext context, Member member, int index) {
    // Calculate how many days ago they joined
    String joinedText = '';
    if (member.createdAt != null) {
      final daysAgo = DateTime.now().difference(member.createdAt!).inDays;
      if (daysAgo == 0) {
        joinedText = 'Today';
      } else if (daysAgo == 1) {
        joinedText = 'Yesterday';
      } else if (daysAgo < 7) {
        joinedText = '$daysAgo days ago';
      } else if (daysAgo < 30) {
        final weeks = (daysAgo / 7).floor();
        joinedText = weeks == 1 ? '1 week ago' : '$weeks weeks ago';
      } else {
        final months = (daysAgo / 30).floor();
        joinedText = months == 1 ? '1 month ago' : '$months months ago';
      }
    }

    return InkWell(
      onTap: onMemberTap != null ? () => onMemberTap!(member) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Profile photo or avatar
            _buildMemberAvatar(member),
            const SizedBox(width: 12),
            // Member info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _unityBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (member.chapterName != null || member.county != null)
                    Text(
                      member.chapterName ?? member.county ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Joined date badge
            if (joinedText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _momentumBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  joinedText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _momentumBlue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(Member member) {
    final photoUrl = member.primaryProfilePhotoUrl;
    final size = 44.0;

    // Generate initials for fallback
    final initials = _getInitials(member.name);

    // Generate a consistent color based on the member's name
    final colorIndex = member.name.hashCode.abs() % WidgetGradients.all.length;
    final gradientColors = WidgetGradients.all[colorIndex];

    Widget fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return fallback;
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    // Check both parts are non-empty before indexing
    final first = parts[0];
    final last = parts[parts.length - 1];
    if (first.isEmpty || last.isEmpty) {
      return first.isNotEmpty
          ? first[0].toUpperCase()
          : (last.isNotEmpty ? last[0].toUpperCase() : '?');
    }
    return '${first[0]}${last[0]}'.toUpperCase();
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No recent members',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick Links Button Widget - navigates to the Quick Links page
/// Styled to match StatCardWidget with gradient background
class QuickLinksButtonWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final VoidCallback? onTap;
  final int linkCount;

  const QuickLinksButtonWidget({
    super.key,
    required this.config,
    this.onTap,
    this.linkCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = config.gradientColors.isNotEmpty
        ? config.gradientColors
        : WidgetGradients.all[0];

    final isMini = config.size == DashboardWidgetSize.mini;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMini ? 12 : 16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.all(isMini ? 12 : 20),
          child: isMini ? _buildMiniLayout() : _buildStandardLayout(),
        ),
      ),
    );
  }

  /// Compact horizontal layout for mini size
  Widget _buildMiniLayout() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(config.icon ?? Icons.link, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                config.title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (linkCount > 0)
          Text(
            '$linkCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
      ],
    );
  }

  /// Standard vertical layout for small and larger sizes
  Widget _buildStandardLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                config.icon ?? Icons.link,
                color: Colors.white,
                size: 24,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (linkCount > 0)
          Text(
            '$linkCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          config.title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (config.subtitle != null)
          Text(
            config.subtitle!,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          )
        else if (linkCount > 0)
          Text(
            'resources available',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}
