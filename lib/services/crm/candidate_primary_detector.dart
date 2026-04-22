import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/models/crm/primary_challenge_pair.dart';

/// Pure-Dart fallback for detecting "MOYD Young Democrat running against an
/// incumbent Democrat" pairs from an already-loaded candidate list. The
/// authoritative source is the `public.get_yd_primary_challengers()` RPC; this
/// detector is used when the RPC is unreachable or when we want to compute
/// pairs client-side to avoid a round-trip.
class CandidatePrimaryDetector {
  const CandidatePrimaryDetector._();

  /// Group `all` by `(office, district)` and emit a [PrimaryChallengePair] for
  /// every MOYD Young Democratic challenger whose seat also contains an
  /// incumbent Democrat.
  static List<PrimaryChallengePair> detect(List<Candidate> all) {
    if (all.isEmpty) return const [];

    final bySeat = <String, List<Candidate>>{};
    for (final c in all) {
      final district = c.district;
      final office = c.office;
      if (district == null || district.isEmpty) continue;
      if (office.isEmpty) continue;
      final key = '${office.trim().toLowerCase()}|${district.trim()}';
      bySeat.putIfAbsent(key, () => <Candidate>[]).add(c);
    }

    final pairs = <PrimaryChallengePair>[];
    for (final seatCandidates in bySeat.values) {
      if (seatCandidates.length < 2) continue;
      final youngDemChallengers = seatCandidates.where(_isYoungDemDemocrat);
      final incumbentDems = seatCandidates.where(_isIncumbentDemocrat).toList();
      if (incumbentDems.isEmpty) continue;

      for (final yd in youngDemChallengers) {
        for (final inc in incumbentDems) {
          if (yd.id == inc.id) continue;
          pairs.add(PrimaryChallengePair(
            challengerId: yd.id,
            challengerName: yd.name,
            incumbentId: inc.id,
            incumbentName: inc.name,
            office: yd.office,
            district: yd.district ?? '',
          ));
        }
      }
    }

    pairs.sort((a, b) {
      final byOffice = a.office.compareTo(b.office);
      if (byOffice != 0) return byOffice;
      final byDistrict = a.district.compareTo(b.district);
      if (byDistrict != 0) return byDistrict;
      return a.challengerName.compareTo(b.challengerName);
    });
    return pairs;
  }

  static bool _isYoungDemDemocrat(Candidate c) =>
      c.isYoungDem && c.party.toLowerCase() == 'democratic';

  static bool _isIncumbentDemocrat(Candidate c) =>
      c.isIncumbent && c.party.toLowerCase() == 'democratic';
}
