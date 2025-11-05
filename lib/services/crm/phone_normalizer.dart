import 'dart:collection';

import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:get/get.dart';

/// Build a list of possible representations for a phone number so we can
/// perform tolerant lookups against Supabase.
List<String> buildPhoneLookupCandidates(String rawPhone) {
  final trimmed = rawPhone.trim();
  if (trimmed.isEmpty) {
    return const [];
  }

  final candidates = LinkedHashSet<String>();

  void addCandidate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    candidates.add(normalized);
  }

  addCandidate(trimmed);

  final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isNotEmpty) {
    addCandidate(digitsOnly);
  }

  final defaultRegion = trimmed.startsWith('+')
      ? null
      : (Get.deviceLocale?.countryCode?.toUpperCase() ?? 'US');

  try {
    final parsed = PhoneNumberUtil.instance.parse(trimmed, defaultRegion);
    final e164 = PhoneNumberUtil.instance.format(parsed, PhoneNumberFormat.e164);
    addCandidate(e164);

    final international = PhoneNumberUtil.instance
        .format(parsed, PhoneNumberFormat.international)
        .replaceAll(RegExp(r'[^0-9+]'), '');
    addCandidate(international);

    final national = PhoneNumberUtil.instance
        .format(parsed, PhoneNumberFormat.national)
        .replaceAll(RegExp(r'[^0-9+]'), '');
    addCandidate(national);
  } catch (_) {
    if (digitsOnly.isNotEmpty) {
      if (digitsOnly.length == 10) {
        addCandidate('1$digitsOnly');
        addCandidate('+1$digitsOnly');
      } else if (digitsOnly.length > 10 && !digitsOnly.startsWith('0')) {
        addCandidate('+${digitsOnly}');
      }
    }
  }

  if (digitsOnly.isNotEmpty && digitsOnly.length > 10 && !digitsOnly.startsWith('0')) {
    addCandidate('+${digitsOnly}');
  }

  return candidates.where((value) => value.isNotEmpty).toList(growable: false);
}
