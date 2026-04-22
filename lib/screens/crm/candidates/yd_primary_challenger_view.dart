import 'package:flutter/material.dart';
import 'package:bluebubbles/features/committees/theme/brand_colors.dart';
import 'package:bluebubbles/models/crm/candidate.dart';
import 'package:bluebubbles/models/crm/primary_challenge_pair.dart';
import 'package:bluebubbles/services/crm/candidate_primary_detector.dart';

typedef CandidateTap = void Function(Candidate c);

/// Dedicated Young-Democrats view — hero pair cards for any YD primarying a
/// sitting Dem incumbent (sourced from the get_yd_primary_challengers() RPC
/// with pure-Dart fallback), plus a secondary list of every other YD.
class YdPrimaryChallengerView extends StatelessWidget {
  /// Authoritative pairs from the `get_yd_primary_challengers()` RPC. If
  /// empty, the pure-Dart fallback detector runs over [allCandidates].
  final List<PrimaryChallengePair> rpcPairs;

  /// All loaded candidates — used both for (a) fallback detection and (b)
  /// resolving challenger/incumbent names to full [Candidate] objects so the
  /// cards can render photos + ages.
  final List<Candidate> allCandidates;

  /// Every Young Dem candidate (irrespective of whether they're primarying
  /// an incumbent). Rendered as the secondary "All Young Democrats" list.
  final List<Candidate> allYoungDems;

  final String? selectedCandidateId;
  final CandidateTap onSelect;
  final CandidateTap? onOpen;

  const YdPrimaryChallengerView({
    super.key,
    required this.rpcPairs,
    required this.allCandidates,
    required this.allYoungDems,
    required this.selectedCandidateId,
    required this.onSelect,
    this.onOpen,
  });

  List<PrimaryChallengePair> get _pairs {
    if (rpcPairs.isNotEmpty) return rpcPairs;
    return CandidatePrimaryDetector.detect(allCandidates);
  }

  Candidate? _find(String id) {
    for (final c in allCandidates) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pairs = _pairs;

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
      children: [
        _sectionHeader(
          icon: Icons.flash_on,
          title: 'Primary challenges',
          subtitle: pairs.isEmpty
              ? 'No Young Dems are primarying Democratic incumbents right now.'
              : '${pairs.length} Young Dem ${pairs.length == 1 ? 'challenger' : 'challengers'} running against sitting Democrat ${pairs.length == 1 ? 'incumbent' : 'incumbents'}',
          color: BrandColors.sunriseGold,
        ),
        const SizedBox(height: 8),
        if (pairs.isEmpty)
          _emptyPairState()
        else
          ...pairs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PrimaryPairCard(
                  pair: p,
                  challenger: _find(p.challengerId),
                  incumbent: _find(p.incumbentId),
                  selectedCandidateId: selectedCandidateId,
                  onSelect: onSelect,
                  onOpen: onOpen,
                ),
              )),
        const SizedBox(height: 16),
        _sectionHeader(
          icon: Icons.star,
          title: 'All Young Democrats',
          subtitle:
              '${allYoungDems.length} flagged candidates across the state',
          color: BrandColors.sunriseGold,
        ),
        const SizedBox(height: 8),
        ...allYoungDems.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _YdListRow(
                candidate: c,
                selected: c.id == selectedCandidateId,
                onTap: () => onSelect(c),
                onOpen: onOpen == null ? null : () => onOpen!(c),
              ),
            )),
      ],
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPairState() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: BrandColors.unityBlue.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white54),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "When a Young Democrat files to primary a sitting Democratic incumbent, they'll surface here automatically.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryPairCard extends StatelessWidget {
  final PrimaryChallengePair pair;
  final Candidate? challenger;
  final Candidate? incumbent;
  final String? selectedCandidateId;
  final CandidateTap onSelect;
  final CandidateTap? onOpen;

  const _PrimaryPairCard({
    required this.pair,
    required this.challenger,
    required this.incumbent,
    required this.selectedCandidateId,
    required this.onSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            BrandColors.unityBlue.withOpacity(0.92),
            BrandColors.momentumBlue.withOpacity(0.60),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.sunriseGold.withOpacity(0.45)),
        boxShadow: [
          BoxShadow(
              color: BrandColors.sunriseGold.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: BrandColors.sunriseGold.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: BrandColors.sunriseGold.withOpacity(0.6)),
                ),
                child: const Text('PRIMARY',
                    style: TextStyle(
                        color: BrandColors.sunriseGold,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(pair.seatLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Side(
                    title: 'Challenger',
                    name: pair.challengerName,
                    subtitle: 'Young Democrat',
                    accent: BrandColors.sunriseGold,
                    candidate: challenger,
                    selected: challenger?.id == selectedCandidateId,
                    onTap: () {
                      if (challenger != null) onSelect(challenger!);
                    },
                    onOpen: onOpen == null || challenger == null
                        ? null
                        : () => onOpen!(challenger!),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 1,
                  color: Colors.white24,
                ),
                Expanded(
                  child: _Side(
                    title: 'Incumbent',
                    name: pair.incumbentName,
                    subtitle: 'Sitting Democrat',
                    accent: BrandColors.democratBlue,
                    candidate: incumbent,
                    selected: incumbent?.id == selectedCandidateId,
                    onTap: () {
                      if (incumbent != null) onSelect(incumbent!);
                    },
                    onOpen: onOpen == null || incumbent == null
                        ? null
                        : () => onOpen!(incumbent!),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  final String title;
  final String name;
  final String subtitle;
  final Color accent;
  final Candidate? candidate;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onOpen;

  const _Side({
    required this.title,
    required this.name,
    required this.subtitle,
    required this.accent,
    required this.candidate,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final initials = candidate?.initials ??
        (name.isNotEmpty ? name.substring(0, 1) : '?');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:
                selected ? accent.withOpacity(0.20) : Colors.black.withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accent : accent.withOpacity(0.35),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(),
                  style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: accent.withOpacity(0.3),
                    backgroundImage: (candidate?.photoUrl != null &&
                            candidate!.photoUrl!.isNotEmpty)
                        ? NetworkImage(candidate!.photoUrl!)
                        : null,
                    child: (candidate?.photoUrl == null ||
                            candidate!.photoUrl!.isEmpty)
                        ? Text(initials,
                            style: TextStyle(
                                color: accent, fontWeight: FontWeight.w700))
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        Text(subtitle,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YdListRow extends StatelessWidget {
  final Candidate candidate;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onOpen;

  const _YdListRow({
    required this.candidate,
    required this.selected,
    required this.onTap,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? BrandColors.sunriseGold.withOpacity(0.18)
                : BrandColors.unityBlue.withOpacity(0.75),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? BrandColors.sunriseGold.withOpacity(0.7)
                  : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: BrandColors.sunriseGold.withOpacity(0.25),
                backgroundImage:
                    (c.photoUrl != null && c.photoUrl!.isNotEmpty)
                        ? NetworkImage(c.photoUrl!)
                        : null,
                child: (c.photoUrl == null || c.photoUrl!.isEmpty)
                    ? Text(c.initials,
                        style: const TextStyle(
                            color: BrandColors.sunriseGold,
                            fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    Text(c.officeDisplay,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (c.estimatedAge != null)
                Text('Age ${c.estimatedAge}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
