import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import 'endorsement_vote_repository.dart';

/// Branded gradient scoreboard: the room's shared consensus buckets
/// (ready / split / still open), the live quorum, and the signed-in member's
/// ballot progress. Dark navy gradient with white/gold text so it reads
/// identically in both themes.
class VoteScoreboard extends StatelessWidget {
  final List<CandidateEntry> ballot;
  final EndorsementVoteRepository votes;
  final VoteBuckets buckets;
  final VoidCallback onCopy;

  const VoteScoreboard({
    super.key,
    required this.ballot,
    required this.votes,
    required this.buckets,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    var mine = 0;
    for (final e in ballot) {
      if (votes.myVote(e.id) != null) mine++;
    }
    final total = ballot.length;
    final done = total > 0 && mine == total;

    return Container(
      decoration: BoxDecoration(
        gradient: HubTheme.hero,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: HubTheme.royal.withOpacity(0.30),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.how_to_vote,
                    color: HubTheme.gold, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Committee vote',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              const _LivePill(),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Copy vote summary (markdown)',
                child: IconButton(
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy,
                      color: Colors.white, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            quorumSentence(buckets.effectiveQuorum, buckets.participants),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 11.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryTile(
                icon: Icons.verified,
                iconBg: MoydBrand.supportFg,
                count: buckets.consensusReady.length,
                label: 'CONSENSUS READY',
              ),
              _SummaryTile(
                icon: Icons.forum,
                iconBg: MoydBrand.opposeFg,
                count: buckets.split.length,
                label: 'SPLIT',
              ),
              _SummaryTile(
                icon: Icons.hourglass_empty,
                iconBg: MoydBrand.neutralFg,
                count: buckets.stillOpen.length,
                label: 'STILL OPEN',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : mine / total,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(HubTheme.gold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                done
                    ? 'You voted on all $total 🗳️'
                    : 'You voted on $mine of $total',
                // White in both states: this text sits over the gradient's
                // skyDeep end where goldBright drops below 4.5:1. The gold
                // celebration stays on the (decorative) full progress bar.
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final int count;
  final String label;
  const _SummaryTile({
    required this.icon,
    required this.iconBg,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.0)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pulsing "LIVE" pill (white text on navy stays AA; the dot is decorative).
class _LivePill extends StatefulWidget {
  const _LivePill();

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(
                CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4ADE80),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('LIVE',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
        ],
      ),
    );
  }
}
