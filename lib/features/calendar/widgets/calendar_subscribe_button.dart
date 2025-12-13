import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:bluebubbles/features/calendar/services/calendar_service.dart';

/// Button widget for subscribing to a Google Calendar
class CalendarSubscribeButton extends StatefulWidget {
  final String? committeeName;
  final Color? accentColor;

  const CalendarSubscribeButton({
    super.key,
    this.committeeName,
    this.accentColor,
  });

  @override
  State<CalendarSubscribeButton> createState() => _CalendarSubscribeButtonState();
}

class _CalendarSubscribeButtonState extends State<CalendarSubscribeButton> {
  final CalendarService _calendarService = CalendarService();
  bool _loading = false;
  String? _subscriptionUrl;

  Future<void> _fetchSubscriptionUrl() async {
    if (_subscriptionUrl != null) return;

    setState(() => _loading = true);

    try {
      final url = await _calendarService.getCalendarSubscriptionUrl(
        committeeName: widget.committeeName,
      );
      if (mounted) {
        setState(() {
          _subscriptionUrl = url;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get subscription URL: $e')),
        );
      }
    }
  }

  Future<void> _showSubscribeDialog() async {
    await _fetchSubscriptionUrl();

    if (!mounted || _subscriptionUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => _SubscribeDialog(
        subscriptionUrl: _subscriptionUrl!,
        committeeName: widget.committeeName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton.icon(
      onPressed: _loading ? null : _showSubscribeDialog,
      icon: _loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? Colors.white : const Color(0xFF374151),
              ),
            )
          : Icon(
              Icons.add_alert_outlined,
              size: 16,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
      label: Text(
        'Subscribe',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white : const Color(0xFF374151),
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(
          color: isDark ? const Color(0xFF38383A) : const Color(0xFFD1D5DB),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _SubscribeDialog extends StatelessWidget {
  final String subscriptionUrl;
  final String? committeeName;

  const _SubscribeDialog({
    required this.subscriptionUrl,
    this.committeeName,
  });

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: subscriptionUrl));
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calendar URL copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openGoogleCalendar(BuildContext context) async {
    final googleCalendarUrl = Uri.parse(
      'https://calendar.google.com/calendar/render?cid=${Uri.encodeComponent(subscriptionUrl)}',
    );

    if (await canLaunchUrl(googleCalendarUrl)) {
      await launchUrl(googleCalendarUrl, mode: LaunchMode.externalApplication);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Calendar')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calendarName = committeeName != null
        ? '$committeeName Calendar'
        : 'MOYD Calendar';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subscribe to Calendar',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        calendarName,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF98989F)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: isDark
                        ? const Color(0xFF98989F)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              'Add this calendar to your personal calendar app to stay updated with all organization events.',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFFD1D5DB)
                    : const Color(0xFF4B5563),
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            // Google Calendar button
            FilledButton.icon(
              onPressed: () => _openGoogleCalendar(context),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text(
                'Add to Google Calendar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Copy URL button
            OutlinedButton.icon(
              onPressed: () => _copyUrl(context),
              icon: Icon(
                Icons.copy,
                size: 18,
                color: isDark ? Colors.white : const Color(0xFF374151),
              ),
              label: Text(
                'Copy Calendar URL',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF374151),
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(
                  color: isDark
                      ? const Color(0xFF38383A)
                      : const Color(0xFFD1D5DB),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E3A5F)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3B82F6).withOpacity(0.3)
                      : const Color(0xFF3B82F6).withOpacity(0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: isDark
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Events will automatically sync to your calendar. Updates may take up to 24 hours to appear.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFFBFDBFE)
                            : const Color(0xFF1E40AF),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
