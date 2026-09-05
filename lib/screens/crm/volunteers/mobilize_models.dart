import 'package:bluebubbles/models/crm/candidate.dart' show Candidate;
import 'package:bluebubbles/models/crm/member.dart';

import 'volunteers_map_models.dart';

// ═══════════════════════════════════════════════════════════════
//  MOBILIZE DESK MODELS
//  Pure data. No widgets, no I/O, no colors.
//
//  Two value objects live here and they answer two different questions:
//   • [MobilizeRequest] is what the MAP knows at the instant MOBILIZE is
//     pressed. It travels one way, map to Desk, through the workspace's
//     handoff notifier.
//   • [OrganizingSeed] is what a NEW organizing activity starts life with. It
//     is the one shape every call site that opens the toolkit passes, so the
//     seeding logic stops being retyped at each of them.
// ═══════════════════════════════════════════════════════════════

/// Which section of the Desk opens focused on arrival.
///
/// It only decides focus. All three sections are always on the page, because
/// the whole point of the Desk is that writing a text, planning the canvass
/// and linking the nominee are one scroll rather than three destinations.
enum MobilizeIntent { send, plan, connect }

/// Everything the map knows at the moment MOBILIZE is pressed. The Desk never
/// reaches back into the map for context; if it is not in here, it is not
/// available.
class MobilizeRequest {
  const MobilizeRequest({
    required this.members,
    this.candidates = const <Candidate>[],
    this.regionMode,
    this.regionId,
    this.intent = MobilizeIntent.send,
    this.seedKind,
    this.seedTitle,
  });

  final List<Member> members;
  final List<Candidate> candidates;

  /// Null for an audience that spans no single region.
  final MapMode? regionMode;
  final String? regionId;

  final MobilizeIntent intent;

  /// An [OutreachDisplay.kinds] key, for a plan intent.
  final String? seedKind;
  final String? seedTitle;

  /// "Boone County", "House District 42", or null when the audience carries no
  /// single region.
  String? get regionLabel {
    final mode = regionMode;
    final id = regionId;
    if (mode == null || id == null) return null;
    return mode.regionTitle(id);
  }
}

/// What a new organizing activity starts life with.
///
/// The toolkit sheet used to take ten loose named parameters and every one of
/// its call sites rebuilt the same geo/candidate/participant seeding by hand.
/// This is that seeding, named once. The geo lists carry the map's own region
/// keys: county names in [counties], bare-digit district numbers in the other
/// three.
class OrganizingSeed {
  const OrganizingSeed({
    this.counties = const <String>[],
    this.congressionalDistricts = const <String>[],
    this.senateDistricts = const <String>[],
    this.houseDistricts = const <String>[],
    this.candidates = const <Candidate>[],
    this.participants = const <Member>[],
    this.kind,
    this.channel,
    this.status,
    this.titleSuggestion,
  });

  final List<String> counties;
  final List<String> congressionalDistricts;
  final List<String> senateDistricts;
  final List<String> houseDistricts;
  final List<Candidate> candidates;
  final List<Member> participants;

  /// Stored `kind` / `channel` / `status` keys, matching the column checks.
  final String? kind;
  final String? channel;
  final String? status;

  final String? titleSuggestion;

  /// Nothing pre-filled: the hub's own "Plan activity" button.
  const OrganizingSeed.empty() : this();

  /// A region, plus whatever else the gesture that named it already knew.
  ///
  /// Every region-first entry point in the workspace goes through here: the
  /// map's organizing plays, the panel's candidate-first canvass, and the
  /// Desk's own audience. [mode] decides which of the four geo lists [id]
  /// lands in and the other three stay empty, which is the single rule that
  /// used to be retyped, slightly differently, at each of those call sites.
  factory OrganizingSeed.forRegion(
    MapMode mode,
    String id, {
    List<Candidate> candidates = const <Candidate>[],
    List<Member> participants = const <Member>[],
    String? kind,
    String? titleSuggestion,
  }) =>
      OrganizingSeed(
        counties: mode == MapMode.county ? <String>[id] : const <String>[],
        congressionalDistricts:
            mode == MapMode.congressional ? <String>[id] : const <String>[],
        senateDistricts:
            mode == MapMode.senate ? <String>[id] : const <String>[],
        houseDistricts: mode == MapMode.house ? <String>[id] : const <String>[],
        candidates: candidates,
        participants: participants,
        kind: kind,
        titleSuggestion: titleSuggestion,
      );

  /// One nominee, optionally in a region. The caller supplies [mode] and
  /// [regionId] because only the caller knows whether the candidate's office
  /// maps to a single geography: a statewide or US Senate seat does not, and
  /// pre-filling a district there would be a guess.
  factory OrganizingSeed.forCandidate(
    Candidate candidate, {
    MapMode? mode,
    String? regionId,
    String? kind,
    String? titleSuggestion,
  }) {
    final title = titleSuggestion ?? 'Organizing for ${candidate.name}';
    if (mode == null || regionId == null) {
      return OrganizingSeed(
        candidates: <Candidate>[candidate],
        kind: kind,
        titleSuggestion: title,
      );
    }
    return OrganizingSeed.forRegion(
      mode,
      regionId,
      candidates: <Candidate>[candidate],
      kind: kind,
      titleSuggestion: title,
    );
  }

  /// One member on the roster, plus their county when we have one.
  factory OrganizingSeed.forMember(Member member) {
    final county = (member.county ?? '').trim();
    return OrganizingSeed(
      counties: county.isEmpty ? const <String>[] : <String>[county],
      participants: <Member>[member],
      titleSuggestion: 'Organizing with ${member.name}',
    );
  }

  /// The Desk's current audience: its members on the roster, its nominees
  /// attached, and its region on the geo arrays.
  factory OrganizingSeed.forAudience(MobilizeRequest request) {
    final mode = request.regionMode;
    final id = request.regionId;
    if (mode == null || id == null) {
      return OrganizingSeed(
        candidates: request.candidates,
        participants: request.members,
        kind: request.seedKind,
        titleSuggestion: request.seedTitle,
      );
    }
    return OrganizingSeed.forRegion(
      mode,
      id,
      candidates: request.candidates,
      participants: request.members,
      kind: request.seedKind,
      titleSuggestion: request.seedTitle,
    );
  }
}
