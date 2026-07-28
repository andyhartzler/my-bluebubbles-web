import 'package:flutter/material.dart';

import '../../../../theme/moyd_brand.dart';
import '../../models/candidate_entry.dart';
import '../../theme/hub_theme.dart';
import '../headshot_avatar.dart';
import 'endorsement_vote_repository.dart';

/// The reason vocabulary lives in app code (it will iterate); the DB stores
/// only the stable snake_case codes. Single-select today — `reason_codes` is
/// an array column so future multi-select stays free.
class VoteReasonOption {
  final String code;
  final String label;
  const VoteReasonOption(this.code, this.label);
}

/// Why this candidate is a No.
const List<VoteReasonOption> kNoReasonOptions = [
  VoteReasonOption('repro_rights', 'Off on reproductive rights'),
  VoteReasonOption('lgbtq_rights', 'Shaky on LGBTQ+ rights'),
  VoteReasonOption('labor_unions', 'Weak on labor & unions'),
  VoteReasonOption('record_statements', 'Problematic record or statements'),
  VoteReasonOption('not_winnable', 'Not a winnable race'),
  VoteReasonOption('no_yd_engagement', 'No engagement with Young Dems'),
  VoteReasonOption('questionnaire_flags', 'Questionnaire raised red flags'),
  VoteReasonOption('weird_about_young', 'Weird about young people'),
  VoteReasonOption('rancid_vibes', 'The vibes are rancid'),
  VoteReasonOption('other', 'Other (add a note)'),
];

/// Why this exec is still Undecided.
const List<VoteReasonOption> kUndecidedReasonOptions = [
  VoteReasonOption('need_more_info', 'Need more info'),
  VoteReasonOption('fundraising_numbers', 'Want to see fundraising numbers'),
  VoteReasonOption('waiting_interview', 'Waiting on their interview'),
  VoteReasonOption('competitive_primary', 'Competitive primary, another good Dem'),
  VoteReasonOption('questionnaire_incomplete', 'Questionnaire incomplete'),
  VoteReasonOption('never_heard', 'Never heard of them'),
  VoteReasonOption('discussion_first', "Want tonight's discussion first"),
  VoteReasonOption('other', 'Other (add a note)'),
];

/// Month names for [provenanceReasonLabel].
const List<String> _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Display label for a provenance tag (`meeting_YYYY_MM_DD`), or null when the
/// code is not one.
///
/// `meeting_2026_07_14` is on 166 of the 260 ballots on record: the July 14
/// committee call, backfilled into `endorsement_votes` as ordinary ballots. It
/// is in NEITHER option list, so the old "unknown codes echo back verbatim"
/// fallback rendered the raw string as if the exec had typed it, on 14 to 23
/// rows for everyone who was on that call.
String? provenanceReasonLabel(String code) {
  if (!isProvenanceReasonCode(code)) return null;
  final parts = code.substring(kProvenanceReasonPrefix.length).split('_');
  if (parts.length == 3) {
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month != null && month >= 1 && month <= 12 && day != null) {
      return 'Recorded at the ${_kMonthNames[month - 1]} $day meeting';
    }
  }
  return 'Recorded at a committee meeting';
}

/// Resolve a stored reason code to its display label (both vocabularies, plus
/// the provenance tags). Unknown codes echo back verbatim so an older client
/// never renders blank.
String voteReasonLabel(String code) {
  for (final o in kNoReasonOptions) {
    if (o.code == code) return o.label;
  }
  for (final o in kUndecidedReasonOptions) {
    if (o.code == code) return o.label;
  }
  return provenanceReasonLabel(code) ?? code;
}

/// Optional follow-up sheet after a No / Undecided ballot: one tap to say
/// why. NON-BLOCKING by design — the ballot was already recorded before this
/// sheet opened; dismissing or skipping leaves it standing with no reason.
Future<void> showVoteReasonSheet(
  BuildContext context, {
  required CandidateEntry entry,
  required String vote, // 'no' | 'undecided'
  required EndorsementVoteRepository votes,
}) {
  assert(vote == 'no' || vote == 'undecided');
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _VoteReasonSheet(entry: entry, vote: vote, votes: votes),
  );
}

class _VoteReasonSheet extends StatefulWidget {
  final CandidateEntry entry;
  final String vote;
  final EndorsementVoteRepository votes;
  const _VoteReasonSheet({
    required this.entry,
    required this.vote,
    required this.votes,
  });

  @override
  State<_VoteReasonSheet> createState() => _VoteReasonSheetState();
}

class _VoteReasonSheetState extends State<_VoteReasonSheet> {
  final TextEditingController _other = TextEditingController();
  String? _selected;
  bool _saving = false;

  bool get _isNo => widget.vote == 'no';
  Color get _accent => _isNo ? MoydBrand.opposeFg : MoydBrand.neutralFg;
  Color get _accentBg => _isNo ? MoydBrand.opposeBg : MoydBrand.neutralBg;
  List<VoteReasonOption> get _options =>
      _isNo ? kNoReasonOptions : kUndecidedReasonOptions;

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final code = _selected;
    if (code == null || _saving) return;
    setState(() => _saving = true);
    final ok = await widget.votes.updateReason(
      widget.entry.id,
      reasonCodes: [code],
      otherText: code == 'other' && _other.text.trim().isNotEmpty
          ? _other.text.trim()
          : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
      return;
    }
    // Same branch as the vote control: an RLS denial is not a connection
    // problem, and offering Retry on one is offering a loop.
    final denied =
        widget.votes.lastFailure == VoteWriteFailure.permissionDenied;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(denied
          ? 'The server rejected the reason because your account is not '
              'recognized as an executive. Your ballot itself is unaffected. '
              'Message Andrew.'
          : "Reason didn't save. Check connection."),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: denied ? 12 : 4),
      action: denied
          ? null
          : SnackBarAction(label: 'Retry', onPressed: _save),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final e = widget.entry;
    // Keyboard-aware: same viewInsets pattern as the decision panel so the
    // Other note field stays visible while typing on a phone.
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HeadshotAvatar(file: e.headshot, name: e.name, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    if (e.officeLine.isNotEmpty)
                      Text(e.officeLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // "You voted No/Undecided" banner in the matching accent.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _accentBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accent.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(_isNo ? Icons.cancel : Icons.help_outline,
                    size: 16, color: _accent),
                const SizedBox(width: 7),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'You voted ',
                      children: [
                        TextSpan(
                            text: _isNo ? 'No' : 'Undecided',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: ' on ${e.name}'),
                      ],
                    ),
                    style: TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Why? (optional — your ballot already counted)',
              style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in _options)
                _reasonChip(o, selected: _selected == o.code),
            ],
          ),
          if (_selected == 'other') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _other,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: 'Your reason',
                hintText: 'A sentence is plenty…',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Skip is a FIRST CLASS action here, not a footnote.
          //
          // The vote is already saved by the time this sheet opens; the reason
          // is genuinely optional. A small grey text button next to a filled
          // primary button says the opposite, and an exec working through 73
          // candidates on a phone should be able to dismiss this without
          // aiming. Same height as Save, equal width, real border.
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.onSurface,
                      side: BorderSide(color: cs.outline, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Skip',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _selected == null || _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.flag, size: 17),
                    label: const Text('Save reason',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: HubTheme.navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Single-select chip matching the hub's pill treatment: light bg + dark fg
  /// unselected; solid accent fill + white text + icon when selected.
  Widget _reasonChip(VoteReasonOption o, {required bool selected}) {
    return InkWell(
      onTap: () => setState(() => _selected = selected ? null : o.code),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accent : _accentBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _accent : _accent.withOpacity(0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 14, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(o.label,
                  style: TextStyle(
                      color: selected ? Colors.white : _accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
