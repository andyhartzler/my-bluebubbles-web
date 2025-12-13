import 'package:flutter/material.dart';

import 'package:bluebubbles/features/calendar/widgets/committee_calendar_widget.dart';
import 'package:bluebubbles/features/calendar/widgets/mobile_calendar_view.dart';

/// Responsive calendar widget that automatically switches between
/// desktop (month grid) and mobile (week strip) views based on screen width
class ResponsiveCalendarWidget extends StatelessWidget {
  final String? committeeName;
  final Color? accentColor;
  final VoidCallback? onAddEvent;

  /// Breakpoint for switching between mobile and desktop views
  static const double mobileBreakpoint = 600;

  const ResponsiveCalendarWidget({
    super.key,
    this.committeeName,
    this.accentColor,
    this.onAddEvent,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use mobile view for narrow screens
        if (constraints.maxWidth < mobileBreakpoint) {
          return MobileCalendarView(
            committeeName: committeeName,
            onAddEvent: onAddEvent,
          );
        }

        // Use desktop view for wider screens
        return CommitteeCalendarWidget(
          committeeName: committeeName,
          accentColor: accentColor,
          onAddEvent: onAddEvent,
        );
      },
    );
  }
}
