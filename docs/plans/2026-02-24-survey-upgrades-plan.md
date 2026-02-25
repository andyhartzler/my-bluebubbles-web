# Survey System Upgrades Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Upgrade survey system with new question types (true/false, multi-select, configurable rating scale), redesigned stats dashboard with member identity, partial completion tracking, and correct STOP behavior.

**Architecture:** 7 tasks in dependency order: webhook STOP fix first (trivial), then model/repo data layer, then webhook question type support, then builder UI, then results widget overhaul. Each task is a complete vertical slice.

**Tech Stack:** Flutter/Dart, Supabase Edge Functions (Deno/TypeScript), Supabase Postgres

---

### Task 1: Fix STOP Message (Survey-Only Opt-Out)

**Files:**
- Modify: `supabase/functions/survey-webhook/index.ts:217-219`

**Context:** When a user replies STOP during a survey, the webhook correctly sets only `survey_sessions.status = 'opted_out'` (per-survey, not global). But the confirmation message incorrectly says "Reply START to any future survey to re-subscribe" implying a global opt-out.

**Step 1: Update the STOP confirmation message**

In `supabase/functions/survey-webhook/index.ts`, find the STOP handler block (around line 211-225). Change the `sendBBMessage` call:

```typescript
// BEFORE:
await sendBBMessage(
  phone,
  "You've been opted out of this survey. Reply START to any future survey to re-subscribe."
);

// AFTER:
await sendBBMessage(
  phone,
  "You've opted out of this survey. You'll still receive future surveys."
);
```

**Step 2: Deploy the webhook**

```bash
cd /tmp/my-bluebubbles-web
npx supabase functions deploy survey-webhook --project-ref faajpcarasilbfndzkmd --no-verify-jwt
```

**Step 3: Commit**

```bash
git add supabase/functions/survey-webhook/index.ts
git commit -m "fix: STOP message now clarifies survey-only opt-out"
```

---

### Task 2: Add SurveySessionDetail Model + Enrich Repository

**Files:**
- Modify: `lib/models/crm/survey_model.dart`
- Modify: `lib/services/crm/survey_repository.dart`

**Context:** The results widget currently shows only aggregate data. We need per-respondent data with member identity and partial completion tracking. This task adds the data model and enriches `fetchResultsSummary`.

**Step 1: Add `SurveySessionDetail` class to survey_model.dart**

At the end of `survey_model.dart` (before the closing of the file), after the `QuestionResultSummary` class, add:

```dart
// ─── SurveySessionDetail ────────────────────────────────────────────────────

class SurveySessionDetail {
  final SurveySession session;
  final String? memberName;
  final String? memberPhone;
  final String? profilePhotoUrl;
  final int questionsAnswered;
  final int totalQuestions;
  final List<SurveyResponse> responses;

  const SurveySessionDetail({
    required this.session,
    this.memberName,
    this.memberPhone,
    this.profilePhotoUrl,
    this.questionsAnswered = 0,
    this.totalQuestions = 0,
    this.responses = const [],
  });

  /// Computed status label for display
  String get displayStatus {
    switch (session.status) {
      case 'completed':
        return 'Completed';
      case 'opted_out':
        return 'Opted Out';
      case 'active':
        return questionsAnswered > 0 ? 'In Progress' : 'No Response';
      default:
        return session.status;
    }
  }

  /// Display name: member name if available, otherwise formatted phone
  String get displayName => memberName ?? session.phoneE164;

  /// Progress as fraction (0.0 to 1.0)
  double get progress =>
      totalQuestions > 0 ? questionsAnswered / totalQuestions : 0.0;
}
```

**Step 2: Add fields to `SurveyResultsSummary`**

In the existing `SurveyResultsSummary` class, add:

```dart
class SurveyResultsSummary {
  final int totalSent;
  final int totalResponded;
  final int totalCompleted;
  final int totalOptedOut;
  final int totalInProgress;    // NEW
  final int totalNoResponse;    // NEW
  final List<QuestionResultSummary> questionSummaries;
  final List<SurveySessionDetail> sessionDetails;  // NEW

  const SurveyResultsSummary({
    this.totalSent = 0,
    this.totalResponded = 0,
    this.totalCompleted = 0,
    this.totalOptedOut = 0,
    this.totalInProgress = 0,    // NEW
    this.totalNoResponse = 0,    // NEW
    this.questionSummaries = const [],
    this.sessionDetails = const [],  // NEW
  });

  double get responseRate => totalSent > 0 ? totalResponded / totalSent : 0;
  double get completionRate => totalSent > 0 ? totalCompleted / totalSent : 0;
}
```

**Step 3: Enrich `fetchResultsSummary` in survey_repository.dart**

Replace the entire `fetchResultsSummary` method with this enriched version that joins member data:

```dart
Future<SurveyResultsSummary> fetchResultsSummary(String surveyId) async {
  if (!isReady) {
    return const SurveyResultsSummary();
  }

  // Fetch sessions with member join
  final sessionsData = await _readClient
      .from('survey_sessions')
      .select('id, status, phone_e164, member_id, current_question_order, started_at, completed_at, last_message_at')
      .eq('survey_id', surveyId);

  final sessions =
      (sessionsData as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();

  // Fetch questions
  final questionsData = await _readClient
      .from('survey_questions')
      .select('*')
      .eq('survey_id', surveyId)
      .order('question_order');

  final questions = (questionsData as List<dynamic>? ?? [])
      .whereType<Map<String, dynamic>>()
      .map((json) => SurveyQuestion.fromJson(json))
      .toList();

  final totalQuestions = questions.length;

  // Fetch all responses for this survey's sessions
  final sessionIds = sessions.map((s) => s['id'] as String).toList();
  List<SurveyResponse> allResponses = [];

  if (sessionIds.isNotEmpty) {
    final responsesData = await _readClient
        .from('survey_responses')
        .select('*')
        .inFilter('session_id', sessionIds);

    allResponses = (responsesData as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((json) => SurveyResponse.fromJson(json))
        .toList();
  }

  // Fetch member data for sessions that have member_id
  final memberIds = sessions
      .map((s) => s['member_id'] as String?)
      .where((id) => id != null)
      .cast<String>()
      .toSet()
      .toList();

  Map<String, Map<String, dynamic>> memberMap = {};
  if (memberIds.isNotEmpty) {
    final membersData = await _readClient
        .from('members')
        .select('id, name, phone_e164, profile_pictures')
        .inFilter('id', memberIds);

    for (final m in (membersData as List<dynamic>? ?? [])) {
      if (m is Map<String, dynamic> && m['id'] != null) {
        memberMap[m['id'] as String] = m;
      }
    }
  }

  // Also try to match by phone for sessions without member_id
  final phonesWithoutMember = sessions
      .where((s) => s['member_id'] == null)
      .map((s) => s['phone_e164'] as String?)
      .where((p) => p != null && p.isNotEmpty)
      .cast<String>()
      .toSet()
      .toList();

  Map<String, Map<String, dynamic>> phoneMemberMap = {};
  if (phonesWithoutMember.isNotEmpty) {
    final phoneMembers = await _readClient
        .from('members')
        .select('id, name, phone_e164, profile_pictures')
        .inFilter('phone_e164', phonesWithoutMember);

    for (final m in (phoneMembers as List<dynamic>? ?? [])) {
      if (m is Map<String, dynamic> && m['phone_e164'] != null) {
        phoneMemberMap[m['phone_e164'] as String] = m;
      }
    }
  }

  // Build session details
  final sessionDetails = <SurveySessionDetail>[];
  int totalInProgress = 0;
  int totalNoResponse = 0;

  for (final s in sessions) {
    final sessionId = s['id'] as String;
    final memberId = s['member_id'] as String?;
    final phone = s['phone_e164'] as String? ?? '';
    final status = s['status'] as String? ?? '';

    // Get member info
    Map<String, dynamic>? member;
    if (memberId != null && memberMap.containsKey(memberId)) {
      member = memberMap[memberId];
    } else if (phoneMemberMap.containsKey(phone)) {
      member = phoneMemberMap[phone];
    }

    // Extract profile photo URL
    String? photoUrl;
    if (member != null && member['profile_pictures'] != null) {
      final pics = member['profile_pictures'];
      if (pics is List && pics.isNotEmpty) {
        final first = pics.first;
        if (first is Map<String, dynamic>) {
          photoUrl = first['publicUrl'] as String? ?? first['public_url'] as String?;
        }
      }
    }

    // Count responses for this session
    final sessionResponses = allResponses.where((r) => r.sessionId == sessionId).toList();
    final answeredCount = sessionResponses.length;

    if (status == 'active') {
      if (answeredCount > 0) {
        totalInProgress++;
      } else {
        totalNoResponse++;
      }
    }

    sessionDetails.add(SurveySessionDetail(
      session: SurveySession.fromJson(s),
      memberName: member?['name'] as String?,
      memberPhone: phone,
      profilePhotoUrl: photoUrl,
      questionsAnswered: answeredCount,
      totalQuestions: totalQuestions,
      responses: sessionResponses,
    ));
  }

  // Sort: completed first, then in-progress, then no response, then opted out
  sessionDetails.sort((a, b) {
    const order = {'completed': 0, 'active': 1, 'opted_out': 2};
    final aOrder = order[a.session.status] ?? 3;
    final bOrder = order[b.session.status] ?? 3;
    if (aOrder != bOrder) return aOrder.compareTo(bOrder);
    // Within active, sort by progress descending
    return b.questionsAnswered.compareTo(a.questionsAnswered);
  });

  // Aggregate counts
  final totalSent = sessions.length;
  final totalCompleted = sessions.where((s) => s['status'] == 'completed').length;
  final totalOptedOut = sessions.where((s) => s['status'] == 'opted_out').length;
  final respondedSessionIds = allResponses.map((r) => r.sessionId).toSet();
  final totalResponded = respondedSessionIds.length;

  // Group responses by question
  final questionSummaries = questions.map((q) {
    final qResponses = allResponses.where((r) => r.questionId == q.id).toList();
    return QuestionResultSummary(question: q, responses: qResponses);
  }).toList();

  return SurveyResultsSummary(
    totalSent: totalSent,
    totalResponded: totalResponded,
    totalCompleted: totalCompleted,
    totalOptedOut: totalOptedOut,
    totalInProgress: totalInProgress,
    totalNoResponse: totalNoResponse,
    questionSummaries: questionSummaries,
    sessionDetails: sessionDetails,
  );
}
```

**Step 4: Commit**

```bash
git add lib/models/crm/survey_model.dart lib/services/crm/survey_repository.dart
git commit -m "feat: add SurveySessionDetail model with member identity and partial completion"
```

---

### Task 3: Webhook — New Question Types + Rating Scale

**Files:**
- Modify: `supabase/functions/survey-webhook/index.ts`

**Context:** The webhook's `parseResponse` function currently handles yes_no, rating (1-5 hardcoded), multiple_choice, and short_answer. We're adding true_false, multi_select, and configurable rating scales.

**Step 1: Add TRUE/FALSE word lists at the top of the file**

After the existing `SKIP_WORDS` set (line 20), add:

```typescript
const TRUE_WORDS = new Set([
  "true", "t", "yes", "y", "correct", "right",
]);
const FALSE_WORDS = new Set([
  "false", "f", "no", "n", "incorrect", "wrong",
]);
```

**Step 2: Update `parseResponse` function**

Replace the entire `parseResponse` function with this version that handles all 6 types:

```typescript
function parseResponse(
  text: string,
  questionType: string,
  options: any
): ParseResult {
  const lower = text.toLowerCase().trim();

  switch (questionType) {
    case "yes_no": {
      if (YES_WORDS.has(lower)) return { parsed: "yes", hint: null };
      if (NO_WORDS.has(lower)) return { parsed: "no", hint: null };
      return { parsed: null, hint: 'Please reply YES or NO.' };
    }

    case "true_false": {
      if (TRUE_WORDS.has(lower)) return { parsed: "true", hint: null };
      if (FALSE_WORDS.has(lower)) return { parsed: "false", hint: null };
      return { parsed: null, hint: "Please reply TRUE or FALSE." };
    }

    case "rating": {
      // Support configurable scale: options may be {"min":1,"max":10} or a list
      let min = 1;
      let max = 5;
      if (options && !Array.isArray(options) && typeof options === "object") {
        if (options.min != null) min = Number(options.min);
        if (options.max != null) max = Number(options.max);
      }
      const num = parseInt(text.trim(), 10);
      if (!isNaN(num) && num >= min && num <= max) {
        return { parsed: String(num), hint: null };
      }
      return { parsed: null, hint: `Please reply with a number ${min}-${max}.` };
    }

    case "multiple_choice": {
      const opts = _extractOptions(options);
      if (!opts || opts.length === 0) {
        return { parsed: text.trim(), hint: null };
      }
      // Match by number
      const num = parseInt(text.trim(), 10);
      if (!isNaN(num) && num >= 1 && num <= opts.length) {
        return { parsed: opts[num - 1], hint: null };
      }
      // Match by exact text (case-insensitive)
      const exact = opts.find((o) => o.toLowerCase() === lower);
      if (exact) return { parsed: exact, hint: null };
      // Match by first letter if unambiguous
      if (lower.length === 1) {
        const matches = opts.filter((o) => o.toLowerCase().startsWith(lower));
        if (matches.length === 1) return { parsed: matches[0], hint: null };
      }
      const optionsList = opts.map((o, i) => `${i + 1}. ${o}`).join(", ");
      return { parsed: null, hint: `Please reply with a number: ${optionsList}` };
    }

    case "multi_select": {
      const opts = _extractOptions(options);
      if (!opts || opts.length === 0) {
        return { parsed: text.trim(), hint: null };
      }
      // Parse comma-separated numbers: "1,3,4" or "1, 3, 4"
      const parts = text.split(/[,\s]+/).map((p) => p.trim()).filter((p) => p.length > 0);
      const selected: string[] = [];
      for (const part of parts) {
        const num = parseInt(part, 10);
        if (!isNaN(num) && num >= 1 && num <= opts.length) {
          const opt = opts[num - 1];
          if (!selected.includes(opt)) selected.push(opt);
        }
      }
      if (selected.length > 0) {
        return { parsed: JSON.stringify(selected), hint: null };
      }
      const optionsList = opts.map((o, i) => `${i + 1}. ${o}`).join(", ");
      return {
        parsed: null,
        hint: `Reply with numbers separated by commas (e.g. 1,3): ${optionsList}`,
      };
    }

    case "short_answer":
      return { parsed: text.trim(), hint: null };

    default:
      return { parsed: text.trim(), hint: null };
  }
}

/** Extract string array of options from the options field (handles both array and object formats) */
function _extractOptions(options: any): string[] | null {
  if (!options) return null;
  if (Array.isArray(options)) return options.map(String);
  // For multi_select, options might be stored as { choices: [...] }
  if (options.choices && Array.isArray(options.choices)) return options.choices.map(String);
  return null;
}
```

**Step 3: Update `formatQuestion` function**

Replace the `formatQuestion` function to handle all types:

```typescript
function formatQuestion(
  surveyTitle: string,
  question: any,
  order: number,
  total: number
): string {
  const lines: string[] = [];
  lines.push(`Q${order} of ${total}: ${question.question_text}`);
  lines.push("");

  switch (question.question_type) {
    case "yes_no":
      lines.push("Reply YES or NO");
      break;
    case "true_false":
      lines.push("Reply TRUE or FALSE");
      break;
    case "rating": {
      let min = 1;
      let max = 5;
      const opts = question.options;
      if (opts && !Array.isArray(opts) && typeof opts === "object") {
        if (opts.min != null) min = Number(opts.min);
        if (opts.max != null) max = Number(opts.max);
      }
      const minLabel = opts?.labels?.[String(min)] ?? "Poor";
      const maxLabel = opts?.labels?.[String(max)] ?? "Excellent";
      lines.push(`Reply ${min}-${max} (${min}=${minLabel}, ${max}=${maxLabel})`);
      break;
    }
    case "multiple_choice": {
      const opts = question.options;
      if (opts && Array.isArray(opts)) {
        opts.forEach((opt: string, i: number) => {
          lines.push(`${i + 1}. ${opt}`);
        });
        lines.push("");
        lines.push("Reply with the number");
      }
      break;
    }
    case "multi_select": {
      const opts = question.options;
      const choices = Array.isArray(opts) ? opts : opts?.choices ?? [];
      choices.forEach((opt: string, i: number) => {
        lines.push(`${i + 1}. ${opt}`);
      });
      lines.push("");
      lines.push("Reply with numbers separated by commas (e.g. 1,3)");
      break;
    }
    case "short_answer":
      lines.push("Reply with your answer");
      break;
  }

  lines.push("");
  lines.push("Reply SKIP to skip \u00B7 STOP to opt out");
  return lines.join("\n");
}
```

**Step 4: Deploy**

```bash
cd /tmp/my-bluebubbles-web
npx supabase functions deploy survey-webhook --project-ref faajpcarasilbfndzkmd --no-verify-jwt
```

**Step 5: Commit**

```bash
git add supabase/functions/survey-webhook/index.ts
git commit -m "feat: webhook supports true_false, multi_select, configurable rating scale"
```

---

### Task 4: Survey Builder — New Question Types + Rating Scale UI

**Files:**
- Modify: `lib/screens/crm/survey_builder_screen.dart`
- Modify: `lib/models/crm/survey_model.dart` (SurveyQuestion.formatForMessage)

**Context:** The builder's question type dropdown currently has 4 options: Yes/No, Rating (1-5), Multiple Choice, Short Answer. We're adding True/False, Multi-Select, and a configurable rating scale.

**Step 1: Add `ratingMax` field to `_EditableQuestion`**

In `_EditableQuestion` class (line ~1634), add a new field:

```dart
class _EditableQuestion {
  final String key;
  final String? existingId;
  final TextEditingController textController;
  String type;
  List<TextEditingController> optionControllers;
  int ratingMax;  // NEW — configurable rating scale max

  String? suggestedType;
  Timer? _typeSuggestDebounce;

  _EditableQuestion({
    String? key,
    this.existingId,
    String? text,
    this.type = 'yes_no',
    List<String>? options,
    this.ratingMax = 5,  // NEW — default 1-5
  })  : key = key ?? const Uuid().v4(),
        textController = TextEditingController(text: text ?? ''),
        optionControllers = (options != null && options.isNotEmpty)
            ? options.map((o) => TextEditingController(text: o)).toList()
            : [TextEditingController(), TextEditingController()];

  factory _EditableQuestion.fromModel(SurveyQuestion q) {
    // Parse ratingMax from options if it's a rating question
    int ratingMax = 5;
    if (q.questionType == 'rating' && q.options.isNotEmpty) {
      // options might contain a JSON-encoded scale config
      // For rating, options stores ["max:10"] or we check the raw JSON
      // Actually, we'll store it differently — see _buildQuestions
    }
    return _EditableQuestion(
      existingId: q.id,
      text: q.questionText,
      type: q.questionType,
      options: q.options.isNotEmpty ? q.options : null,
      ratingMax: ratingMax,
    );
  }
  // ... dispose unchanged
}
```

**Step 2: Update the dropdown items in `_buildQuestionCard`**

Find the `DropdownButtonFormField<String>` at line ~1129. Replace its `items` list:

```dart
items: const [
  DropdownMenuItem(value: 'yes_no', child: Text('Yes / No')),
  DropdownMenuItem(value: 'true_false', child: Text('True / False')),
  DropdownMenuItem(value: 'rating', child: Text('Rating')),
  DropdownMenuItem(
    value: 'multiple_choice',
    child: Text('Multiple Choice'),
  ),
  DropdownMenuItem(
    value: 'multi_select',
    child: Text('Multi-Select'),
  ),
  DropdownMenuItem(
    value: 'short_answer',
    child: Text('Short Answer'),
  ),
],
```

**Step 3: Update `_typeLabel` and `_typeColor` to include new types**

```dart
String _typeLabel(String type) {
  switch (type) {
    case 'yes_no':
      return 'Yes/No';
    case 'true_false':
      return 'True/False';
    case 'rating':
      return 'Rating';
    case 'multiple_choice':
      return 'Multiple Choice';
    case 'multi_select':
      return 'Multi-Select';
    case 'short_answer':
      return 'Short Answer';
    default:
      return type;
  }
}

Color _typeColor(String type) {
  switch (type) {
    case 'yes_no':
      return BrandColors.success;
    case 'true_false':
      return BrandColors.royalBlue;
    case 'rating':
      return BrandColors.sunriseGold;
    case 'multiple_choice':
      return BrandColors.momentumBlue;
    case 'multi_select':
      return const Color(0xFF8B5CF6); // Purple
    case 'short_answer':
      return BrandColors.slateBlue;
    default:
      return Colors.grey;
  }
}
```

**Step 4: Add rating scale selector and multi-select options UI to `_buildQuestionCard`**

After the existing multiple_choice options block (after line ~1269), add the rating scale UI and multi-select UI:

```dart
// Rating scale selector
if (q.type == 'rating') ...[
  const SizedBox(height: 14),
  const Divider(),
  const SizedBox(height: 8),
  const Text(
    'Rating Scale',
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: BrandColors.unityBlue,
    ),
  ),
  const SizedBox(height: 8),
  DropdownButtonFormField<int>(
    value: q.ratingMax,
    decoration: InputDecoration(
      labelText: 'Scale',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    items: const [
      DropdownMenuItem(value: 3, child: Text('1 - 3')),
      DropdownMenuItem(value: 5, child: Text('1 - 5')),
      DropdownMenuItem(value: 7, child: Text('1 - 7')),
      DropdownMenuItem(value: 10, child: Text('1 - 10')),
    ],
    onChanged: (v) {
      if (v != null) setState(() => q.ratingMax = v);
    },
  ),
],

// Multi-select options (reuse same UI as multiple_choice)
if (q.type == 'multi_select') ...[
  const SizedBox(height: 14),
  const Divider(),
  const SizedBox(height: 8),
  Row(
    children: [
      const Expanded(
        child: Text(
          'Answer Options',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: BrandColors.unityBlue,
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Recipients can select multiple',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF8B5CF6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  ),
  const SizedBox(height: 8),
  ...q.optionControllers.asMap().entries.map((entry) {
    final oi = entry.key;
    final oc = entry.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Center(
              child: Text(
                '${oi + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: oc,
              decoration: InputDecoration(
                hintText: 'Option ${oi + 1}',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (q.optionControllers.length > 2)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
              onPressed: () {
                setState(() {
                  q.optionControllers[oi].dispose();
                  q.optionControllers.removeAt(oi);
                });
              },
            ),
        ],
      ),
    );
  }),
  TextButton.icon(
    onPressed: () {
      setState(() {
        q.optionControllers.add(TextEditingController());
      });
    },
    icon: const Icon(Icons.add, size: 18),
    label: const Text('Add option'),
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFF8B5CF6),
    ),
  ),
],
```

**Step 5: Update `_buildQuestions()` to handle new types**

Replace the `_buildQuestions` method:

```dart
List<SurveyQuestion> _buildQuestions() {
  return _questions.asMap().entries.map((entry) {
    final i = entry.key;
    final q = entry.value;

    List<String> options = [];
    if (q.type == 'multiple_choice' || q.type == 'multi_select') {
      options = q.optionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }

    return SurveyQuestion(
      id: q.existingId,
      questionText: q.textController.text.trim(),
      questionType: q.type,
      options: options,
      questionOrder: i + 1,
      ratingMax: q.type == 'rating' ? q.ratingMax : null,
    );
  }).toList();
}
```

**Step 6: Add `ratingMax` to `SurveyQuestion` model**

In `lib/models/crm/survey_model.dart`, update the `SurveyQuestion` class:

```dart
class SurveyQuestion {
  final String? id;
  final String? surveyId;
  final String questionText;
  final String questionType;
  final List<String> options;
  final int questionOrder;
  final int? ratingMax;  // NEW

  const SurveyQuestion({
    this.id,
    this.surveyId,
    required this.questionText,
    required this.questionType,
    this.options = const [],
    required this.questionOrder,
    this.ratingMax,  // NEW
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    List<String> options = [];
    int? ratingMax;
    final raw = json['options'];
    if (raw is List) {
      options = raw.map((e) => e.toString()).toList();
    } else if (raw is Map) {
      // Rating scale config: {"min": 1, "max": 10}
      if (raw['max'] != null) {
        ratingMax = int.tryParse(raw['max'].toString());
      }
      // Multi-select options stored as {"choices": [...]}
      if (raw['choices'] is List) {
        options = (raw['choices'] as List).map((e) => e.toString()).toList();
      }
    }

    return SurveyQuestion(
      id: json['id'] as String?,
      surveyId: json['survey_id'] as String?,
      questionText: json['question_text'] as String? ?? '',
      questionType: json['question_type'] as String? ?? 'short_answer',
      options: options,
      questionOrder: _parseSurveyInt(json['question_order']) ?? 0,
      ratingMax: ratingMax,
    );
  }

  Map<String, dynamic> toInsertPayload(String surveyId) {
    final payload = <String, dynamic>{
      'survey_id': surveyId,
      'question_text': questionText,
      'question_type': questionType,
      'question_order': questionOrder,
    };

    if (questionType == 'multiple_choice' && options.isNotEmpty) {
      payload['options'] = options;
    } else if (questionType == 'multi_select' && options.isNotEmpty) {
      payload['options'] = options;
    } else if (questionType == 'rating' && ratingMax != null && ratingMax != 5) {
      payload['options'] = {'min': 1, 'max': ratingMax};
    }

    return payload;
  }
  // ... copyWith and formatForMessage also need ratingMax param
}
```

Also update `copyWith`:

```dart
SurveyQuestion copyWith({
  String? id,
  String? surveyId,
  String? questionText,
  String? questionType,
  List<String>? options,
  int? questionOrder,
  int? ratingMax,
}) =>
    SurveyQuestion(
      id: id ?? this.id,
      surveyId: surveyId ?? this.surveyId,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      options: options ?? this.options,
      questionOrder: questionOrder ?? this.questionOrder,
      ratingMax: ratingMax ?? this.ratingMax,
    );
```

And update `formatForMessage`:

```dart
String formatForMessage({required int questionNumber, required int totalQuestions}) {
  final buf = StringBuffer();
  buf.writeln('Q$questionNumber of $totalQuestions: $questionText');
  buf.writeln();

  switch (questionType) {
    case 'yes_no':
      buf.writeln('Reply YES or NO');
      break;
    case 'true_false':
      buf.writeln('Reply TRUE or FALSE');
      break;
    case 'rating':
      final max = ratingMax ?? 5;
      buf.writeln('Reply 1-$max (1=Poor, $max=Excellent)');
      break;
    case 'multiple_choice':
      for (int i = 0; i < options.length; i++) {
        buf.writeln('${i + 1}. ${options[i]}');
      }
      buf.writeln();
      buf.writeln('Reply with the number');
      break;
    case 'multi_select':
      for (int i = 0; i < options.length; i++) {
        buf.writeln('${i + 1}. ${options[i]}');
      }
      buf.writeln();
      buf.writeln('Reply with numbers separated by commas (e.g. 1,3)');
      break;
    case 'short_answer':
      buf.writeln('Reply with your answer');
      break;
  }

  buf.writeln();
  buf.write('Reply SKIP to skip \u00B7 STOP to opt out');
  return buf.toString();
}
```

**Step 7: Update the iMessage preview in builder**

Update `_buildPreviewText()` to handle new types:

```dart
String _buildPreviewText() {
  final title = _titleController.text.trim().isEmpty
      ? 'Survey Title'
      : _titleController.text.trim();

  if (_questions.isEmpty) return '\u{1F4CA} $title\n\nNo questions added yet.';

  final q = _questions.first;
  final qText = q.textController.text.trim().isEmpty
      ? 'Your question here?'
      : q.textController.text.trim();

  final total = _questions.length;
  final buf = StringBuffer();
  buf.writeln('\u{1F4CA} $title');
  buf.writeln('Q1 of $total: $qText');
  buf.writeln();

  switch (q.type) {
    case 'yes_no':
      buf.writeln('Reply YES or NO');
      break;
    case 'true_false':
      buf.writeln('Reply TRUE or FALSE');
      break;
    case 'rating':
      buf.writeln('Reply 1-${q.ratingMax} (1=Poor, ${q.ratingMax}=Excellent)');
      break;
    case 'multiple_choice':
    case 'multi_select':
      final opts = q.optionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (opts.isEmpty) {
        buf.writeln('1. Option 1\n2. Option 2');
      } else {
        for (int i = 0; i < opts.length; i++) {
          buf.writeln('${i + 1}. ${opts[i]}');
        }
      }
      buf.writeln();
      if (q.type == 'multi_select') {
        buf.writeln('Reply with numbers separated by commas (e.g. 1,3)');
      } else {
        buf.writeln('Reply with the number');
      }
      break;
    case 'short_answer':
      buf.writeln('Reply with your answer');
      break;
  }

  buf.writeln();
  buf.write('Reply SKIP to skip \u00B7 STOP to opt out');
  return buf.toString();
}
```

**Step 8: Update `_EditableQuestion.fromModel` to parse ratingMax from existing questions**

```dart
factory _EditableQuestion.fromModel(SurveyQuestion q) {
  return _EditableQuestion(
    existingId: q.id,
    text: q.questionText,
    type: q.questionType,
    options: q.options.isNotEmpty ? q.options : null,
    ratingMax: q.ratingMax ?? 5,
  );
}
```

**Step 9: Commit**

```bash
git add lib/screens/crm/survey_builder_screen.dart lib/models/crm/survey_model.dart
git commit -m "feat: builder supports true/false, multi-select, configurable rating scale"
```

---

### Task 5: Redesigned Stats Dashboard (Tiers 1-2)

**Files:**
- Modify: `lib/screens/crm/survey_results_widget.dart`

**Context:** Replace the current `_buildSummaryRow` (uneven gradient tiles) with a premium 3-tier stats layout. This task handles Tiers 1 and 2 (hero metrics + breakdown chips).

**Step 1: Replace `_buildSummaryRow` with new 3-tier layout**

Replace the entire `_buildSummaryRow` method and `_buildGradientSummaryCard` method with:

```dart
// ── Stats Dashboard — Tier 1: Hero Metrics ─────────────────────────────────

Widget _buildStatsDashboard(SurveyResultsSummary s) {
  return Column(
    children: [
      // Tier 1: Hero metrics — 3 equal cards
      Row(
        children: [
          Expanded(child: _buildHeroCard(
            label: 'Sent',
            value: '${s.totalSent}',
            icon: Icons.send_rounded,
            iconColor: BrandColors.momentumBlue,
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildCircularProgressCard(
            label: 'Response Rate',
            value: s.responseRate,
            color: BrandColors.momentumBlue,
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildCircularProgressCard(
            label: 'Completion',
            value: s.completionRate,
            color: BrandColors.success,
          )),
        ],
      ),

      const SizedBox(height: 12),

      // Tier 2: Breakdown chips — 4 equal mini-stats
      Row(
        children: [
          Expanded(child: _buildBreakdownChip(
            label: 'Completed',
            count: s.totalCompleted,
            color: BrandColors.success,
          )),
          const SizedBox(width: 8),
          Expanded(child: _buildBreakdownChip(
            label: 'In Progress',
            count: s.totalInProgress,
            color: BrandColors.momentumBlue,
          )),
          const SizedBox(width: 8),
          Expanded(child: _buildBreakdownChip(
            label: 'Opted Out',
            count: s.totalOptedOut,
            color: BrandColors.error,
          )),
          const SizedBox(width: 8),
          Expanded(child: _buildBreakdownChip(
            label: 'No Response',
            count: s.totalNoResponse,
            color: Colors.grey,
          )),
        ],
      ),
    ],
  );
}

Widget _buildHeroCard({
  required String label,
  required String value,
  required IconData icon,
  required Color iconColor,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: BrandColors.unityBlue,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

Widget _buildCircularProgressCard({
  required String label,
  required double value,
  required Color color,
}) {
  final pct = (value * 100).toStringAsFixed(0);
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 5,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: BrandColors.unityBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Widget _buildBreakdownChip({
  required String label,
  required int count,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}
```

**Step 2: Update `build()` to use new stats dashboard**

In the `build` method, replace `_buildSummaryRow(s)` with `_buildStatsDashboard(s)`.

**Step 3: Commit**

```bash
git add lib/screens/crm/survey_results_widget.dart
git commit -m "feat: redesigned stats dashboard with hero metrics and breakdown chips"
```

---

### Task 6: Respondent List (Tier 3) with Member Identity

**Files:**
- Modify: `lib/screens/crm/survey_results_widget.dart`
- Modify: `lib/models/crm/member.dart` (import only)

**Context:** Add the Tier 3 respondent list below the breakdown chips. Shows each survey recipient with profile photo, name, progress bar, status badge, and expandable per-question responses.

**Step 1: Add member.dart import at top of survey_results_widget.dart**

```dart
import 'package:bluebubbles/models/crm/member.dart';
import 'package:cached_network_image/cached_network_image.dart';
```

**Step 2: Add respondent list to the build method**

In the `build` method's Column children, after the export row and before the per-question breakdown, add:

```dart
// ── Respondent list (Tier 3) ──
if (s.sessionDetails.isNotEmpty) ...[
  _buildRespondentList(s),
  const SizedBox(height: 16),
],
```

**Step 3: Build the respondent list widget**

```dart
// ── Respondent List (Tier 3) ──────────────────────────────────────────────

Widget _buildRespondentList(SurveyResultsSummary s) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Text(
            'Respondents',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: BrandColors.unityBlue,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: BrandColors.momentumBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${s.sessionDetails.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: BrandColors.momentumBlue,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ...s.sessionDetails.map((detail) => _buildRespondentCard(detail, s)),
    ],
  );
}

Widget _buildRespondentCard(SurveySessionDetail detail, SurveyResultsSummary summary) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: _buildRespondentAvatar(detail),
        title: Text(
          detail.displayName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: BrandColors.unityBlue,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detail.memberName != null)
              Text(
                detail.memberPhone ?? detail.session.phoneE164,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: detail.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(
                        _statusColor(detail.displayStatus),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${detail.questionsAnswered}/${detail.totalQuestions}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: _buildStatusBadge(detail.displayStatus),
        children: [
          if (detail.responses.isNotEmpty)
            ...detail.responses.map((r) {
              // Find the question for this response
              final question = summary.questionSummaries
                  .where((qs) => qs.question.id == r.questionId)
                  .firstOrNull;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: BrandColors.momentumBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${question?.question.questionOrder ?? '?'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: BrandColors.momentumBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question?.question.questionText ?? 'Question',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.parsedResponse ?? r.rawResponse ?? '(empty)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: BrandColors.unityBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (detail.responses.isEmpty)
            Text(
              detail.session.status == 'opted_out'
                  ? 'Opted out before answering'
                  : 'No responses yet',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _buildRespondentAvatar(SurveySessionDetail detail) {
  final name = detail.memberName ?? '';
  final url = detail.profilePhotoUrl;
  if (url != null && url.isNotEmpty) {
    return CircleAvatar(
      radius: 20,
      backgroundImage: CachedNetworkImageProvider(url),
      backgroundColor: BrandColors.unityBlue.withOpacity(0.1),
    );
  }
  return CircleAvatar(
    radius: 20,
    backgroundColor: BrandColors.unityBlue.withOpacity(0.1),
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        color: BrandColors.unityBlue,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  );
}

Widget _buildStatusBadge(String status) {
  final color = _statusColor(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      status,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.3,
      ),
    ),
  );
}

Color _statusColor(String status) {
  switch (status) {
    case 'Completed':
      return BrandColors.success;
    case 'In Progress':
      return BrandColors.momentumBlue;
    case 'Opted Out':
      return BrandColors.error;
    case 'No Response':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}
```

**Step 4: Commit**

```bash
git add lib/screens/crm/survey_results_widget.dart
git commit -m "feat: respondent list with member photos, progress bars, and expandable responses"
```

---

### Task 7: Results Widget — New Question Type Visualizations

**Files:**
- Modify: `lib/screens/crm/survey_results_widget.dart`

**Context:** The results widget's `_buildQuestionVisualization` switch currently handles yes_no, rating, multiple_choice, short_answer. We need to add true_false, multi_select, and dynamic rating scale support.

**Step 1: Update `_buildQuestionVisualization` switch**

```dart
Widget _buildQuestionVisualization(QuestionResultSummary qs) {
  switch (qs.question.questionType) {
    case 'yes_no':
      return _buildYesNoBar(qs);
    case 'true_false':
      return _buildTrueFalseBar(qs);
    case 'rating':
      return _buildRatingDisplay(qs);
    case 'multiple_choice':
      return _buildBarChart(qs);
    case 'multi_select':
      return _buildMultiSelectChart(qs);
    case 'short_answer':
      return _buildShortAnswerList(qs);
    default:
      return _buildShortAnswerList(qs);
  }
}
```

**Step 2: Add `_buildTrueFalseBar`**

```dart
Widget _buildTrueFalseBar(QuestionResultSummary qs) {
  final dist = qs.distribution;
  final trueCount = dist['true'] ?? 0;
  final falseCount = dist['false'] ?? 0;
  final total = trueCount + falseCount;
  if (total == 0) {
    return const Text('No responses yet',
        style: TextStyle(color: Colors.grey, fontSize: 13));
  }

  final truePct = trueCount / total;
  final falsePct = falseCount / total;

  return Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 32,
          child: Row(
            children: [
              if (truePct > 0)
                Expanded(
                  flex: (truePct * 100).round(),
                  child: Container(
                    color: BrandColors.momentumBlue,
                    alignment: Alignment.center,
                    child: Text(
                      'True ${(truePct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              if (falsePct > 0)
                Expanded(
                  flex: (falsePct * 100).round(),
                  child: Container(
                    color: BrandColors.slateBlue,
                    alignment: Alignment.center,
                    child: Text(
                      'False ${(falsePct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '$trueCount True, $falseCount False',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
      ),
    ],
  );
}
```

**Step 3: Add `_buildMultiSelectChart`**

```dart
Widget _buildMultiSelectChart(QuestionResultSummary qs) {
  final total = qs.responseCount;
  if (total == 0) {
    return const Text('No responses yet',
        style: TextStyle(color: Colors.grey, fontSize: 13));
  }

  // Multi-select responses are JSON arrays — count each option occurrence
  final optionCounts = <String, int>{};
  for (final r in qs.responses) {
    final parsed = r.parsedResponse ?? '';
    // Try parsing as JSON array
    List<String> selected = [];
    if (parsed.startsWith('[')) {
      try {
        final decoded = (parsed.replaceAll(RegExp(r'[\[\]"]'), '')).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        selected = decoded;
      } catch (_) {
        selected = [parsed];
      }
    } else {
      selected = [parsed];
    }
    for (final opt in selected) {
      optionCounts[opt] = (optionCounts[opt] ?? 0) + 1;
    }
  }

  final entries = optionCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Column(
    children: [
      // "N respondents, multiple selections allowed" header
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.checklist, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              '$total respondents \u00B7 multiple selections',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
      ...entries.map((entry) {
        final pct = entry.value / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  entry.key,
                  style: const TextStyle(fontSize: 13, color: BrandColors.unityBlue),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
                    minHeight: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
                child: Text(
                  '${entry.value} (${(pct * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}
```

**Step 4: Update `_buildRatingDisplay` for dynamic scale**

Replace the rating display to use `question.ratingMax` instead of hardcoded 5:

```dart
Widget _buildRatingDisplay(QuestionResultSummary qs) {
  final avg = qs.averageRating;
  final dist = qs.distribution;
  final total = qs.responseCount;
  final maxRating = qs.question.ratingMax ?? 5;

  return Column(
    children: [
      if (avg != null) ...[
        Row(
          children: [
            Text(
              avg.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: BrandColors.sunriseGold,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(maxRating.clamp(1, 10), (i) {
                    return Icon(
                      i < avg.round() ? Icons.star : Icons.star_border,
                      color: BrandColors.sunriseGold,
                      size: maxRating > 5 ? 16 : 20,
                    );
                  }),
                ),
                Text(
                  '$total responses',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      // Distribution bars — dynamic based on maxRating
      ...List.generate(maxRating, (i) {
        final rating = maxRating - i;
        final count = dist['$rating'] ?? 0;
        final pct = total > 0 ? count / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: maxRating > 5 ? 24 : 16,
                child: Text('$rating',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        const AlwaysStoppedAnimation(BrandColors.sunriseGold),
                    minHeight: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    ],
  );
}
```

**Step 5: Update `averageRating` in QuestionResultSummary to support dynamic scale**

In `lib/models/crm/survey_model.dart`, the `averageRating` getter works for any numeric rating — no change needed since it parses the stored numbers directly. However, we should ensure the `distribution` property handles the full range. No code change required here.

**Step 6: Add short answer respondent identity**

Update `_buildShortAnswerList` to show respondent info when available:

```dart
Widget _buildShortAnswerList(QuestionResultSummary qs) {
  if (qs.responses.isEmpty) {
    return const Text('No responses yet',
        style: TextStyle(color: Colors.grey, fontSize: 13));
  }

  // Try to match responses to session details for identity
  final summary = _summary;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children:
        qs.responses.take(10).map((r) {
          // Find session detail for this response
          SurveySessionDetail? respondent;
          if (summary != null) {
            respondent = summary.sessionDetails
                .where((d) => d.session.id == r.sessionId)
                .firstOrNull;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (respondent != null) ...[
                  _buildMiniAvatar(respondent),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (respondent != null)
                        Text(
                          respondent.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (respondent != null) const SizedBox(height: 3),
                      Text(
                        r.rawResponse ?? r.parsedResponse ?? '(empty)',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
  );
}

Widget _buildMiniAvatar(SurveySessionDetail detail) {
  final name = detail.memberName ?? '';
  final url = detail.profilePhotoUrl;
  if (url != null && url.isNotEmpty) {
    return CircleAvatar(
      radius: 14,
      backgroundImage: CachedNetworkImageProvider(url),
      backgroundColor: BrandColors.unityBlue.withOpacity(0.1),
    );
  }
  return CircleAvatar(
    radius: 14,
    backgroundColor: BrandColors.unityBlue.withOpacity(0.1),
    child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: const TextStyle(
        color: BrandColors.unityBlue,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    ),
  );
}
```

**Step 7: Commit**

```bash
git add lib/screens/crm/survey_results_widget.dart
git commit -m "feat: results visualizations for true/false, multi-select, dynamic rating scale, respondent identity"
```

---

### Dependency Order

```
Task 1 (STOP fix)           — standalone, deploy first
Task 2 (models/repo)        — standalone, data layer
Task 3 (webhook types)      — standalone, deploy after Task 1
Task 4 (builder UI)         — depends on Task 2 (ratingMax on model)
Task 5 (stats Tiers 1-2)    — depends on Task 2 (totalInProgress, totalNoResponse)
Task 6 (respondent list)    — depends on Task 2 (sessionDetails) + Task 5 (placed after)
Task 7 (result viz)         — depends on Task 2 (ratingMax) + Task 6 (mini avatars)
```

Recommended execution order: **1 → 2 → 3 → 4 → 5 → 6 → 7**
