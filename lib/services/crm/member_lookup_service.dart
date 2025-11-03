import 'package:bluebubbles/config/crm_config.dart';
import 'package:bluebubbles/models/crm/member.dart';
import 'package:bluebubbles/services/crm/member_repository.dart';
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

  Future<Member?> fetchByPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty || !isReady) {
      return Future.value(null);
    }

    if (_membersByPhone.containsKey(trimmed)) {
      return Future.value(_membersByPhone[trimmed]);
    }

    final inFlight = _inFlightPhoneRequests[trimmed];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _memberRepository.getMemberByPhone(trimmed).then((member) {
      if (member != null) {
        cacheMember(member);
      } else {
        _membersByPhone[trimmed] = null;
      }
      _inFlightPhoneRequests.remove(trimmed);
      return member;
    }).catchError((error) {
      _inFlightPhoneRequests.remove(trimmed);
      throw error;
    });

    _inFlightPhoneRequests[trimmed] = future;
    return future;
  }

  void cacheMember(Member member) {
    _membersById[member.id] = member;
    if (member.phoneE164 != null && member.phoneE164!.trim().isNotEmpty) {
      _membersByPhone[member.phoneE164!] = member;
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
