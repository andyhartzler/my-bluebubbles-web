import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

/// Chair identity. The uid is primary (verified against auth.users
/// last_sign_in 2026-07-21: andrew@hartzler.us); the email set is a safety
/// net so a stale uid can never lock the chair out of Confirm / final call
/// on meeting night. Not user-configurable tonight.
const String kChairUserId = 'f1ac8208-ad64-405f-8b55-8284ddef51cf';
const Set<String> kChairEmails = {
  'andrew@hartzler.us',
  'andrew@moyoungdemocrats.org',
};

/// Whether the signed-in auth user is the committee chair.
bool isChairUser(User? u) {
  if (u == null) return false;
  if (u.id == kChairUserId) return true;
  final email = u.email?.toLowerCase();
  if (email != null && kChairEmails.contains(email)) {
    debugPrint(
        'CHAIR FALLBACK: uid ${u.id} matched by email $email, kChairUserId is wrong');
    return true; // email fallback so a stale uid does not brick the meeting
  }
  return false;
}
