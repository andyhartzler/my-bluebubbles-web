import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
import 'package:bluebubbles/services/crm/phone_normalizer.dart';
import 'package:bluebubbles/services/crm/supabase_service.dart';

class CRMMemberLookupService {
  CRMMemberLookupService._();

  static final CRMMemberLookupService _instance = CRMMemberLookupService._();

  factory CRMMemberLookupService() => _instance;

  final MemberRepository _memberRepository = MemberRepository();
  final Map<String, Member?> _membersByPhone = {};
  final Map<String, Member?> _membersById = {};
  final Map<String, Future<Member?>> _inFlightPhoneRequests = {};

  bool get isReady => CRMConfig.crmEnabled && CRMSupabaseService().isInitialized;

  Member? getCachedByPhone(String phone) => _membersByPhone[phone];

  bool hasCachedPhone(String phone) => _membersByPhone.containsKey(phone);

  Future<Member?> fetchByPhone(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty || !isReady) {
      return null;
    }

    final candidates = buildPhoneLookupCandidates(trimmed);
    if (candidates.isEmpty) {
      return null;
    }

    for (final candidate in candidates) {
      if (_membersByPhone.containsKey(candidate)) {
        final cached = _membersByPhone[candidate];
        if (cached != null) {
          for (final alias in candidates) {
            _membersByPhone.putIfAbsent(alias, () => cached);
          }
          return cached;
        }
      }
    }

    for (final candidate in candidates) {
      final inFlight = _inFlightPhoneRequests[candidate];
      if (inFlight != null) {
        return inFlight;
      }
    }

    for (final candidate in candidates) {
      final member = await _fetchCandidate(candidate, candidates);
      if (member != null) {
        return member;
      }
    }

    for (final alias in candidates) {
      _membersByPhone.putIfAbsent(alias, () => null);
    }
    return null;
  }

  Future<Member?> _fetchCandidate(String candidate, List<String> aliases) {
    if (_membersByPhone.containsKey(candidate)) {
      return Future.value(_membersByPhone[candidate]);
    }

    final inFlight = _inFlightPhoneRequests[candidate];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _memberRepository.getMemberByPhone(candidate).then((member) {
      if (member != null) {
        cacheMember(member);
        for (final alias in aliases) {
          _membersByPhone[alias] = member;
        }
      } else {
        _membersByPhone[candidate] = null;
      }
      return member;
    }).catchError((error) {
      throw error;
    });

    _inFlightPhoneRequests[candidate] = future;
    return future.whenComplete(() {
      _inFlightPhoneRequests.remove(candidate);
    });
  }

  void cacheMember(Member member) {
    _membersById[member.id] = member;
    final phones = <String>[
      if (member.phoneE164 != null) member.phoneE164!,
      if (member.phone != null) member.phone!,
    ];
    for (final phone in phones) {
      for (final candidate in buildPhoneLookupCandidates(phone)) {
        _membersByPhone[candidate] = member;
      }
    }
  }

  void cacheNegativePhone(String phone) {
    _membersByPhone[phone] = null;
  }

  Member? getCachedById(String id) => _membersById[id];

  void clearCache() {
    _membersByPhone.clear();
    _membersById.clear();
    _inFlightPhoneRequests.clear();
  }
}
