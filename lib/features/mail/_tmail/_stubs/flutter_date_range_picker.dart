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
