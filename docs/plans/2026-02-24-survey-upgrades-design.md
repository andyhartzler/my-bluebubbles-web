# Survey System Upgrades Design

## Goal
Upgrade the survey system with new question types, redesigned stats dashboard, member identity on results, partial completion tracking, and correct STOP behavior (survey-only opt-out).

## Architecture
Five independent workstreams touching the survey builder (Flutter), results widget (Flutter), survey models/repository (Flutter), and webhook edge function (Supabase/Deno). All changes are additive except the STOP message fix.

## Tech Stack
Flutter/Dart frontend, Supabase edge functions (Deno/TypeScript), Supabase Postgres

---

## 1. New Question Types + Rating Scale Customization

### New types
- **`true_false`**: Binary True/False. Parsed like yes_no but with True/False labels. Webhook accepts "true", "t", "false", "f" and common synonyms.
- **`multi_select`**: Like multiple_choice but allows multiple selections. User replies with comma-separated numbers (e.g., "1,3,4"). Parsed response stored as JSON array string. Webhook validates each number is in range.

### Rating scale customization
- When question type is `rating`, `options` JSONB stores scale config: `{"min": 1, "max": N}` where N can be 3, 5, 7, or 10.
- Default remains 1-5 if options is null/empty.
- Builder UI shows a scale selector (dropdown: 1-3, 1-5, 1-7, 1-10).
- Webhook `parseResponse` reads scale from question options.
- Results widget dynamically renders the correct number of bars/stars.

### Builder UI additions
- Dropdown gets 2 new entries: "True / False" and "Multi-Select"
- True/False: no extra config needed (like yes_no)
- Multi-Select: reuses the same option list UI as multiple_choice, with a note "Recipients can select multiple"
- Rating: adds a "Scale" dropdown below the type selector (1-3, 1-5, 1-7, 1-10)

### Results widget additions
- `true_false`: Same stacked bar as yes_no but with True/False labels
- `multi_select`: Horizontal bar chart like multiple_choice (each option shows count of sessions that selected it)
- `rating`: Dynamic bar count based on scale max

---

## 2. STOP = Survey Opt-Out Only

### Current state
The webhook sets `survey_sessions.status = 'opted_out'` which is already per-survey. No global opt-out flag is set. The behavior is correct but the confirmation message implies a global opt-out.

### Changes
- Update STOP confirmation message to: "You've opted out of this survey. You'll still receive future surveys."
- No database schema changes needed.

---

## 3. Redesigned Stats Dashboard

### Current problems
- 5 gradient tiles in a Wrap with no width constraints — uneven sizing
- No partial completion data
- No "in progress" or "no response" breakdown

### New 3-tier layout

**Tier 1 — Hero metrics**: 3 equal-width cards in a Row(children: [Expanded...])
- **Sent**: Big number + send icon
- **Response Rate**: Circular progress ring with percentage in center (responded/sent)
- **Completion Rate**: Circular progress ring with percentage in center (completed/sent)

Each card is a white Container with subtle shadow, 16px border radius.

**Tier 2 — Breakdown chips**: 4 equal mini-stat containers in a Row
- Completed (green dot + count)
- In Progress (blue dot + count) — sessions with status=active AND >= 1 response
- Opted Out (red dot + count)
- No Response (grey dot + count) — sessions with status=active AND 0 responses

**Tier 3 — Respondent list**: Scrollable list of every survey recipient showing:
- Profile photo CircleAvatar (or initials fallback)
- Name + phone
- Linear progress bar (questionsAnswered / totalQuestions)
- Status badge chip
- Expandable tile showing per-question responses

---

## 4. Member Identity on Results

### Data model changes

New class `SurveySessionDetail`:
```dart
class SurveySessionDetail {
  final SurveySession session;
  final String? memberName;
  final String? memberPhone;
  final String? profilePhotoUrl;
  final int questionsAnswered;
  final int totalQuestions;
  final List<SurveyResponse> responses;
}
```

### Repository changes
- `fetchResultsSummary` joins `survey_sessions` with `members` (on member_id) to get name + profile_pictures
- Also fetches response count per session
- Returns new `List<SurveySessionDetail>` in `SurveyResultsSummary`

### Display
- Respondent list (Tier 3) shows full member cards
- Short answer question results show respondent avatar + name next to each answer
- Question result cards show small avatar row of respondents

---

## 5. Partial Completion Tracking

### Computation
For each session:
- `questionsAnswered` = count of survey_responses for that session_id
- `totalQuestions` = count of survey_questions for the survey

### "In Progress" definition
- Session status = 'active' AND questionsAnswered >= 1

### "No Response" definition
- Session status = 'active' AND questionsAnswered == 0

### Display
- Linear progress bar on each respondent card: filled portion = questionsAnswered/totalQuestions
- Text label: "3/5 questions"
- Color: green if complete, momentumBlue if in progress, grey if 0
