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
        accentColor: widget.accentColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? Theme.of(context).colorScheme.primary;

    return OutlinedButton.icon(
      onPressed: _loading ? null : _showSubscribeDialog,
      icon: _loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          : Icon(Icons.calendar_month, size: 18, color: color),
      label: Text(
        'Subscribe',
        style: TextStyle(color: color),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SubscribeDialog extends StatelessWidget {
  final String subscriptionUrl;
  final String? committeeName;
  final Color? accentColor;

  const _SubscribeDialog({
    required this.subscriptionUrl,
    this.committeeName,
    this.accentColor,
  });

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: subscriptionUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calendar URL copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openGoogleCalendar(BuildContext context) async {
    // Create Google Calendar add URL
    final googleCalendarUrl = Uri.parse(
      'https://calendar.google.com/calendar/render?cid=${Uri.encodeComponent(subscriptionUrl)}',
    );

    if (await canLaunchUrl(googleCalendarUrl)) {
      await launchUrl(googleCalendarUrl, mode: LaunchMode.externalApplication);
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
    final theme = Theme.of(context);
    final color = accentColor ?? theme.colorScheme.primary;
    final calendarName = committeeName != null
        ? '$committeeName Calendar'
        : 'Organization Calendar';

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subscribe to Calendar',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        calendarName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              'Add this calendar to your personal calendar app to stay updated with all events.',
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 20),

            // Google Calendar button
            FilledButton.icon(
              onPressed: () => _openGoogleCalendar(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Add to Google Calendar'),
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            const SizedBox(height: 12),

            // Copy URL section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Or copy the calendar URL:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subscriptionUrl,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copyUrl(context),
                        icon: Icon(Icons.copy, color: color, size: 20),
                        tooltip: 'Copy URL',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Events will automatically sync to your calendar. Updates may take up to 24 hours to appear.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade800,
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
