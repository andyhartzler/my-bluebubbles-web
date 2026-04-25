// Stub for flutter_date_range_picker (Dart 3.7+). tmail's advanced search
// filter uses this. Phase 1 doesn't expose advanced search; shim returns
// no-op widgets so imports resolve.
import 'package:flutter/material.dart';

class DateRangePickerView extends StatelessWidget {
  final ValueChanged<DateTimeRange>? onSelected;
  const DateRangePickerView({super.key, this.onSelected});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class MaterialDateRangePickerDialog extends StatelessWidget {
  final DateTimeRange? initialDateRange;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTimeRange?>? onChanged;
  const MaterialDateRangePickerDialog({
    super.key,
    this.initialDateRange,
    this.firstDate,
    this.lastDate,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  // tmail's date-range filter dialog static entry point. We stubbed the
  // package; this no-op satisfies the call sites in
  // features/base/mixin/date_range_picker_mixin.dart so the project compiles.
  static Future<void> showDateRangePicker(
    BuildContext context, {
    String? confirmText,
    String? cancelText,
    String? last7daysTitle,
    String? last30daysTitle,
    String? last6monthsTitle,
    String? lastYearTitle,
    DateTime? initStartDate,
    DateTime? initEndDate,
    DateTime? firstDate,
    DateTime? lastDate,
    Function(DateTime? startDate, DateTime? endDate)? onCallbackAction,
    Function(DateTime? startDate, DateTime? endDate)? selectDateRangeActionCallback,
    bool? autoClose,
    bool? barrierDismissible,
    String? barrierLabel,
    bool? usePointerInterceptor,
  }) async {}
}

class CupertinoDateRangePickerDialog extends StatelessWidget {
  final DateTimeRange? initialDateRange;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTimeRange?>? onChanged;
  const CupertinoDateRangePickerDialog({
    super.key,
    this.initialDateRange,
    this.firstDate,
    this.lastDate,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
