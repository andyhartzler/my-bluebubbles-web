# Survey Feature Overhaul - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Overhaul the survey system with a Slack-style standalone surveys page, redesigned survey builder with intelligent question suggestions and advanced recipient selection, enhanced results with export (Excel/PDF), and event page integration with default post-event survey templates.

**Architecture:** Replace existing `SurveysScreen`, `SurveyBuilderScreen`, and `SurveyResultsWidget` in-place. Add new `SurveyExportService` modeled after `DonorExportService`. Add new `RecipientSelectorWidget` for member filtering/selection. All UI uses `BrandColors` gradient system from `lib/features/committees/theme/brand_colors.dart`. No DB schema changes needed — existing `surveys`, `survey_questions`, `survey_sessions`, `survey_responses` tables are sufficient.

**Tech Stack:** Flutter/Dart, Supabase (PostgREST), `pdf`/`printing` packages for PDF export, `excel` package for Excel export, BrandColors design system, Material Design widgets.

---

## Task 1: Suggested Questions Library

**Files:**
- Create: `lib/models/crm/survey_suggested_questions.dart`

**What:** A static data file containing categorized suggested survey questions with their recommended types. This is a pure data file with no dependencies — everything else builds on it.

**Step 1: Create the suggested questions library**

```dart
/// Suggested survey questions organized by category with intelligent type mapping.
class SuggestedQuestion {
  final String text;
  final String type; // yes_no, rating, multiple_choice, short_answer
  final List<String> options; // for multiple_choice
  final String category;

  const SuggestedQuestion({
    required this.text,
    required this.type,
    this.options = const [],
    required this.category,
  });
}

class SurveyQuestionSuggestions {
  static const List<String> categories = [
    'Post-Event Feedback',
    'Satisfaction',
    'Program Evaluation',
    'Demographics',
    'General Feedback',
    'Engagement',
  ];

  static const List<SuggestedQuestion> all = [
    // ── Post-Event Feedback ──
    SuggestedQuestion(
      text: 'How would you rate the overall event experience?',
      type: 'rating',
      category: 'Post-Event Feedback',
    ),
    SuggestedQuestion(
      text: 'Would you attend a similar event in the future?',
      type: 'yes_no',
      category: 'Post-Event Feedback',
    ),
    SuggestedQuestion(
      text: 'What was your favorite part of the event?',
      type: 'short_answer',
      category: 'Post-Event Feedback',
    ),
    SuggestedQuestion(
      text: 'How did you hear about this event?',
      type: 'multiple_choice',
      options: ['Social media', 'Email', 'Word of mouth', 'Website', 'Other'],
      category: 'Post-Event Feedback',
    ),
    SuggestedQuestion(
      text: 'How would you rate the venue/location?',
      type: 'rating',
      category: 'Post-Event Feedback',
    ),
    SuggestedQuestion(
      text: 'What could we improve for next time?',
      type: 'short_answer',
      category: 'Post-Event Feedback',
    ),

    // ── Satisfaction ──
    SuggestedQuestion(
      text: 'How satisfied are you with your overall experience?',
      type: 'rating',
      category: 'Satisfaction',
    ),
    SuggestedQuestion(
      text: 'Would you recommend us to a friend?',
      type: 'yes_no',
      category: 'Satisfaction',
    ),
    SuggestedQuestion(
      text: 'How likely are you to participate in future activities?',
      type: 'rating',
      category: 'Satisfaction',
    ),
    SuggestedQuestion(
      text: 'How would you rate our communication?',
      type: 'rating',
      category: 'Satisfaction',
    ),

    // ── Program Evaluation ──
    SuggestedQuestion(
      text: 'How useful was this program/workshop?',
      type: 'rating',
      category: 'Program Evaluation',
    ),
    SuggestedQuestion(
      text: 'Did this meet your expectations?',
      type: 'yes_no',
      category: 'Program Evaluation',
    ),
    SuggestedQuestion(
      text: 'What topics would you like covered in the future?',
      type: 'short_answer',
      category: 'Program Evaluation',
    ),
    SuggestedQuestion(
      text: 'How would you rate the speaker/presenter?',
      type: 'rating',
      category: 'Program Evaluation',
    ),

    // ── Demographics ──
    SuggestedQuestion(
      text: 'What is your age range?',
      type: 'multiple_choice',
      options: ['18-24', '25-34', '35-44', '45-54', '55+'],
      category: 'Demographics',
    ),
    SuggestedQuestion(
      text: 'Which county do you live in?',
      type: 'short_answer',
      category: 'Demographics',
    ),
    SuggestedQuestion(
      text: 'Are you a registered voter?',
      type: 'yes_no',
      category: 'Demographics',
    ),

    // ── General Feedback ──
    SuggestedQuestion(
      text: 'Is there anything else you would like to share?',
      type: 'short_answer',
      category: 'General Feedback',
    ),
    SuggestedQuestion(
      text: 'How can we better serve you?',
      type: 'short_answer',
      category: 'General Feedback',
    ),
    SuggestedQuestion(
      text: 'Would you be interested in volunteering?',
      type: 'yes_no',
      category: 'General Feedback',
    ),

    // ── Engagement ──
    SuggestedQuestion(
      text: 'How often do you engage with our organization?',
      type: 'multiple_choice',
      options: ['Weekly', 'Monthly', 'A few times a year', 'This is my first time'],
      category: 'Engagement',
    ),
    SuggestedQuestion(
      text: 'Which committee(s) are you interested in?',
      type: 'short_answer',
      category: 'Engagement',
    ),
    SuggestedQuestion(
      text: 'How many hours per week could you volunteer?',
      type: 'multiple_choice',
      options: ['1-2 hours', '3-5 hours', '5-10 hours', '10+ hours'],
      category: 'Engagement',
    ),
  ];

  /// Default post-event survey questions (subset of all)
  static List<SuggestedQuestion> get defaultPostEventQuestions => all
      .where((q) => q.category == 'Post-Event Feedback')
      .toList();

  /// Get questions by category
  static List<SuggestedQuestion> byCategory(String category) =>
      all.where((q) => q.category == category).toList();

  /// Intelligent type suggestion based on question text patterns
  static String suggestType(String questionText) {
    final lower = questionText.toLowerCase().trim();

    // Rating patterns
    if (lower.contains('how would you rate') ||
        lower.contains('how likely') ||
        lower.contains('how satisfied') ||
        lower.contains('how useful') ||
        lower.contains('on a scale') ||
        lower.contains('how well')) {
      return 'rating';
    }

    // Yes/No patterns
    if (lower.startsWith('do you') ||
        lower.startsWith('did you') ||
        lower.startsWith('are you') ||
        lower.startsWith('is there') ||
        lower.startsWith('have you') ||
        lower.startsWith('would you') ||
        lower.startsWith('will you') ||
        lower.startsWith('can you') ||
        lower.startsWith('should we')) {
      return 'yes_no';
    }

    // Multiple choice patterns
    if (lower.contains('which of') ||
        lower.contains('what is your age') ||
        lower.contains('how often') ||
        lower.contains('how did you hear') ||
        lower.contains('how many hours')) {
      return 'multiple_choice';
    }

    // Default to short answer
    return 'short_answer';
  }
}
```

**Step 2: Commit**

```bash
git add lib/models/crm/survey_suggested_questions.dart
git commit -m "feat: add suggested survey questions library with intelligent type detection"
```

---

## Task 2: Survey Export Service

**Files:**
- Create: `lib/services/crm/survey_export_service.dart`

**What:** PDF and Excel export for survey results, modeled after `DonorExportService` at `lib/services/crm/donor_export_service.dart`. Uses same color scheme and layout patterns.

**Step 1: Create the export service**

```dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';

import 'package:bluebubbles/models/crm/survey_model.dart';

/// Service for generating PDF and Excel exports of survey results.
class SurveyExportService {
  static const _unityBlue = PdfColor.fromInt(0xFF273351);
  static const _momentumBlue = PdfColor.fromInt(0xFF32A6DE);
  static const _lightGray = PdfColor.fromInt(0xFFF5F5F5);
  static const _darkGray = PdfColor.fromInt(0xFF666666);
  static const _grassrootsGreen = PdfColor.fromInt(0xFF43A047);
  static const _actionRed = PdfColor.fromInt(0xFFE63946);
  static const _sunriseGold = PdfColor.fromInt(0xFFFDB813);

  // ── PDF Export ──

  static Future<Uint8List> generatePdf({
    required String surveyTitle,
    required SurveyResultsSummary summary,
    required List<SurveySession> sessions,
  }) async {
    final doc = pw.Document(title: '$surveyTitle — Results', author: 'Missouri Young Democrats');

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/text-logo-1320x440.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Failed to load logo: $e');
    }

    final font = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final now = DateTime.now();
    final dateFmt = DateFormat.yMMMd();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        maxPages: 1000,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(
          context: context,
          logo: logoImage,
          title: '$surveyTitle — Results',
          boldFont: boldFont,
          font: font,
          generatedDate: now,
        ),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
          // Summary metrics
          _buildSummarySection(summary, font, boldFont),
          pw.SizedBox(height: 20),

          // Per-question breakdown
          ...summary.questionSummaries.map(
            (qs) => _buildQuestionSection(qs, font, boldFont),
          ),

          // Individual responses table
          if (sessions.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildSessionsTable(sessions, font, boldFont),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader({
    required pw.Context context,
    required pw.MemoryImage? logo,
    required String title,
    required pw.Font boldFont,
    required pw.Font font,
    required DateTime generatedDate,
  }) {
    final dateFmt = DateFormat.yMMMd();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) pw.Image(logo, width: 200)
            else pw.Text('Missouri Young Democrats', style: pw.TextStyle(font: boldFont, fontSize: 18, color: _unityBlue)),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 18, color: _unityBlue)),
                pw.SizedBox(height: 4),
                pw.Text('Generated: ${dateFmt.format(generatedDate)}', style: pw.TextStyle(font: font, fontSize: 10, color: _darkGray)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 3, decoration: const pw.BoxDecoration(gradient: pw.LinearGradient(colors: [_unityBlue, _momentumBlue]))),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Missouri Young Democrats', style: pw.TextStyle(font: font, fontSize: 9, color: _darkGray)),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 9, color: _darkGray)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummarySection(SurveyResultsSummary s, pw.Font font, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _lightGray,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _momentumBlue, width: 2),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('Sent', '${s.totalSent}', font, boldFont),
          _summaryItem('Responded', '${s.totalResponded}', font, boldFont),
          _summaryItem('Completed', '${s.totalCompleted}', font, boldFont),
          _summaryItem('Response Rate', '${(s.responseRate * 100).toStringAsFixed(0)}%', font, boldFont),
          _summaryItem('Opted Out', '${s.totalOptedOut}', font, boldFont),
        ],
      ),
    );
  }

  static pw.Widget _summaryItem(String label, String value, pw.Font font, pw.Font boldFont) {
    return pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: _darkGray)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(font: boldFont, fontSize: 16, color: _unityBlue)),
      ],
    );
  }

  static pw.Widget _buildQuestionSection(QuestionResultSummary qs, pw.Font font, pw.Font boldFont) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Q${qs.question.questionOrder}: ${qs.question.questionText}',
            style: pw.TextStyle(font: boldFont, fontSize: 11, color: _unityBlue),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${qs.responseCount} responses · Type: ${qs.question.questionType.replaceAll('_', ' ')}',
            style: pw.TextStyle(font: font, fontSize: 9, color: _darkGray),
          ),
          pw.SizedBox(height: 6),
          // Distribution table
          if (qs.distribution.isNotEmpty)
            pw.TableHelper.fromTextArray(
              headers: ['Response', 'Count', 'Percentage'],
              data: qs.distribution.entries.map((e) {
                final pct = qs.responseCount > 0
                    ? '${(e.value / qs.responseCount * 100).toStringAsFixed(1)}%'
                    : '0%';
                return [e.key, '${e.value}', pct];
              }).toList(),
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _unityBlue),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              oddRowDecoration: const pw.BoxDecoration(color: _lightGray),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          if (qs.averageRating != null)
            pw.Text(
              'Average rating: ${qs.averageRating!.toStringAsFixed(1)} / 5',
              style: pw.TextStyle(font: boldFont, fontSize: 10, color: _sunriseGold),
            ),
          pw.SizedBox(height: 8),
        ],
      ),
    );
  }

  static pw.Widget _buildSessionsTable(List<SurveySession> sessions, pw.Font font, pw.Font boldFont) {
    final dateFmt = DateFormat('MM/dd/yy h:mm a');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Individual Sessions', style: pw.TextStyle(font: boldFont, fontSize: 12, color: _unityBlue)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: ['Phone', 'Status', 'Progress', 'Started', 'Completed'],
          data: sessions.map((s) {
            final maskedPhone = s.phoneE164.length > 4
                ? '***${s.phoneE164.substring(s.phoneE164.length - 4)}'
                : s.phoneE164;
            return [
              maskedPhone,
              s.status,
              'Q${s.currentQuestionOrder}',
              s.startedAt != null ? dateFmt.format(s.startedAt!) : '-',
              s.completedAt != null ? dateFmt.format(s.completedAt!) : '-',
            ];
          }).toList(),
          headerStyle: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _unityBlue),
          cellStyle: pw.TextStyle(font: font, fontSize: 7),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          oddRowDecoration: const pw.BoxDecoration(color: _lightGray),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
      ],
    );
  }

  // ── Excel Export ──

  static Future<Uint8List> generateExcel({
    required String surveyTitle,
    required SurveyResultsSummary summary,
    required List<SurveySession> sessions,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#273351'),
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
    );

    // ── Summary Sheet ──
    final summarySheet = excel['Summary'];
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue(surveyTitle)
      ..cellStyle = CellStyle(bold: true, fontSize: 14, fontColorHex: ExcelColor.fromHexString('#273351'));

    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue('Generated: ${DateFormat.yMMMd().format(DateTime.now())}')
      ..cellStyle = CellStyle(italic: true, fontColorHex: ExcelColor.fromHexString('#666666'));

    final metrics = ['Sent', 'Responded', 'Completed', 'Response Rate', 'Opted Out'];
    final values = [
      '${summary.totalSent}',
      '${summary.totalResponded}',
      '${summary.totalCompleted}',
      '${(summary.responseRate * 100).toStringAsFixed(0)}%',
      '${summary.totalOptedOut}',
    ];

    for (var i = 0; i < metrics.length; i++) {
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3 + i))
        ..value = TextCellValue(metrics[i])
        ..cellStyle = CellStyle(bold: true);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3 + i))
        ..value = TextCellValue(values[i]);
    }

    summarySheet.setColumnWidth(0, 20);
    summarySheet.setColumnWidth(1, 15);

    // ── Per-question sheets ──
    for (final qs in summary.questionSummaries) {
      final sheetName = 'Q${qs.question.questionOrder}';
      final sheet = excel[sheetName];

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('Q${qs.question.questionOrder}: ${qs.question.questionText}')
        ..cellStyle = CellStyle(bold: true, fontSize: 12);

      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        ..value = TextCellValue('Type: ${qs.question.questionType.replaceAll('_', ' ')} · ${qs.responseCount} responses');

      if (qs.averageRating != null) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
          ..value = TextCellValue('Average: ${qs.averageRating!.toStringAsFixed(1)} / 5');
      }

      final dataStart = qs.averageRating != null ? 4 : 3;

      // Headers
      for (var i = 0; i < ['Response', 'Count', 'Percentage'].length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: dataStart))
          ..value = TextCellValue(['Response', 'Count', 'Percentage'][i])
          ..cellStyle = headerStyle;
      }

      final sortedEntries = qs.distribution.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      for (var i = 0; i < sortedEntries.length; i++) {
        final entry = sortedEntries[i];
        final pct = qs.responseCount > 0 ? (entry.value / qs.responseCount * 100) : 0.0;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: dataStart + 1 + i))
          ..value = TextCellValue(entry.key);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: dataStart + 1 + i))
          ..value = IntCellValue(entry.value);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: dataStart + 1 + i))
          ..value = TextCellValue('${pct.toStringAsFixed(1)}%');
      }

      // Raw responses for short_answer
      if (qs.question.questionType == 'short_answer' && qs.responses.isNotEmpty) {
        final rawStart = dataStart + 2 + sortedEntries.length;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rawStart))
          ..value = TextCellValue('All Responses')
          ..cellStyle = CellStyle(bold: true);
        for (var i = 0; i < qs.responses.length; i++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rawStart + 1 + i))
            ..value = TextCellValue(qs.responses[i].rawResponse ?? qs.responses[i].parsedResponse ?? '');
        }
      }

      sheet.setColumnWidth(0, 30);
      sheet.setColumnWidth(1, 10);
      sheet.setColumnWidth(2, 12);
    }

    // ── Sessions Sheet ──
    final sessionsSheet = excel['Sessions'];
    final sessHeaders = ['Phone (masked)', 'Status', 'Progress', 'Started', 'Completed'];
    for (var i = 0; i < sessHeaders.length; i++) {
      sessionsSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(sessHeaders[i])
        ..cellStyle = headerStyle;
    }

    final dateFmt = DateFormat('MM/dd/yy h:mm a');
    for (var i = 0; i < sessions.length; i++) {
      final s = sessions[i];
      final masked = s.phoneE164.length > 4 ? '***${s.phoneE164.substring(s.phoneE164.length - 4)}' : s.phoneE164;
      final row = i + 1;
      sessionsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))..value = TextCellValue(masked);
      sessionsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))..value = TextCellValue(s.status);
      sessionsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))..value = TextCellValue('Q${s.currentQuestionOrder}');
      sessionsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))..value = TextCellValue(s.startedAt != null ? dateFmt.format(s.startedAt!) : '-');
      sessionsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))..value = TextCellValue(s.completedAt != null ? dateFmt.format(s.completedAt!) : '-');
    }

    for (var i = 0; i < sessHeaders.length; i++) {
      sessionsSheet.setColumnWidth(i, i == 0 ? 18 : 15);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel file');
    return Uint8List.fromList(bytes);
  }
}
```

**Step 2: Commit**

```bash
git add lib/services/crm/survey_export_service.dart
git commit -m "feat: add SurveyExportService for PDF and Excel export of survey results"
```

---

## Task 3: Recipient Selector Widget

**Files:**
- Create: `lib/widgets/crm/recipient_selector_widget.dart`

**What:** A reusable widget for selecting survey recipients. Supports individual member search (by name), group filters (all members, by school, county, congressional district, age range), and shows real-time count preview. Queries the `members` table in Supabase.

**Step 1: Create the recipient selector widget**

This widget provides:
- **Mode toggle**: "Individual" vs "Group" selection
- **Individual mode**: Search-as-you-type member list with checkboxes, showing name + phone
- **Group mode**: Dropdown filters for:
  - All active members with phone numbers
  - High school (dropdown of distinct values from members.high_school)
  - College (dropdown of distinct values from members.college)
  - County (dropdown of distinct values from members.county)
  - Congressional District (dropdown of distinct values from members.congressional_district)
  - Age range (min/max based on date_of_birth)
  - Chapter membership status (current_chapter_member = 'Yes')
- **Real-time count**: Shows "X members match" as filters change
- **Output**: `List<String>` of phone_e164 values for selected recipients

Key implementation notes:
- Uses `CRMSupabaseService` for queries
- Filters out `opt_out = true` members
- Only includes members with non-null `phone_e164`
- Fetches distinct filter values once on init
- Group filter builds a composite Supabase query

The widget should be a StatefulWidget that accepts a callback `onRecipientsChanged(List<String> phones)` and displays the filter UI. Use BrandColors for styling. The widget body is ~400-500 lines — gradient header, tab toggle for Individual/Group, respective filter UIs, count preview bar at bottom.

**Step 2: Commit**

```bash
git add lib/widgets/crm/recipient_selector_widget.dart
git commit -m "feat: add RecipientSelectorWidget with individual/group member filtering"
```

---

## Task 4: Redesigned Survey Builder Screen

**Files:**
- Modify: `lib/screens/crm/survey_builder_screen.dart` (full rewrite, 649 lines → ~800 lines)

**What:** Replace the existing basic form with a polished step-based wizard using BrandColors gradient styling (matching Slack page design). Features:

1. **Step indicator** at top showing progress through 3 steps
2. **Step 1 - Survey Details**: Title, description, type toggle (standalone vs event-linked)
3. **Step 2 - Questions**:
   - Suggested questions dropdown (from `SurveyQuestionSuggestions`)
   - Category filter chips
   - "Add from suggestions" button that opens a bottom sheet of suggested questions
   - Text field with intelligent type auto-detection (`suggestType()`)
   - Drag-to-reorder (existing)
   - iMessage preview (existing, enhanced styling)
4. **Step 3 - Recipients & Send**:
   - `RecipientSelectorWidget` embedded
   - OR event attendee mode if eventId is set
   - Schedule/send controls
   - Preview count

Key styling changes:
- Gradient header matching Slack: `BrandColors.tileGradient`
- Step indicator with `_momentumBlue` active, white completed, grey pending
- Cards with 16px border radius
- White text on gradient backgrounds where appropriate
- Import `BrandColors` from `lib/features/committees/theme/brand_colors.dart`

**Step 2: Commit**

```bash
git add lib/screens/crm/survey_builder_screen.dart
git commit -m "feat: redesign survey builder with step wizard, suggestions, and recipient selector"
```

---

## Task 5: Redesigned Surveys Screen (Standalone Page)

**Files:**
- Modify: `lib/screens/crm/surveys_screen.dart` (full rewrite, 413 lines → ~550 lines)

**What:** Transform from basic list view to a Slack-style tabbed interface with gradient header and enhanced survey cards.

New structure:
1. **Gradient header** (BrandColors.tileGradient) with:
   - Icon badge (circular, semi-transparent white background)
   - Title "Surveys" + subtitle with total count
   - "Create Survey" elevated button (sunriseGold)
2. **TabBar** with 4 tabs: All / Active / Drafts / Completed
   - Gold indicator, white labels, white70 unselected
3. **TabBarView** content:
   - Each tab shows filtered survey list
   - Survey cards redesigned with gradient side bar, progress indicator, enhanced metadata
   - Empty states with large icons and descriptive text (matching Slack pattern)
4. **Pull-to-refresh** on each tab
5. **Search bar** below tabs for filtering by title

Key patterns from Slack to replicate:
- `Container` with `LinearGradient(colors: BrandColors.tileGradient)` for header
- `TabBar(labelColor: Colors.white, indicatorColor: BrandColors.sunriseGold, indicatorWeight: 3)`
- Cards with `BoxDecoration(gradient: ..., borderRadius: BorderRadius.circular(16), boxShadow: [...])`
- Material + InkWell for ripple effects on gradient cards
- Loading/Empty/Error state patterns

**Step 2: Commit**

```bash
git add lib/screens/crm/surveys_screen.dart
git commit -m "feat: redesign surveys screen with Slack-style tabbed interface and gradient cards"
```

---

## Task 6: Enhanced Survey Results Widget with Export

**Files:**
- Modify: `lib/screens/crm/survey_results_widget.dart` (474 lines → ~600 lines)

**What:** Enhance the results display with BrandColors gradient styling and add export buttons (PDF/Excel). Changes:

1. **Gradient summary cards** replacing plain Cards:
   - Each summary card gets a gradient background
   - Larger, more prominent stats
2. **Export action row** below summary:
   - "Export PDF" and "Export Excel" buttons
   - Uses `SurveyExportService`
   - Downloads via `Printing.sharePdf()` for PDF and file save for Excel
   - Uses `FileSaver` or `download` package for web
3. **Enhanced question visualizations**:
   - Yes/No bars with BrandColors green/red
   - Rating display unchanged (already good)
   - Multiple choice bars with gradient fill
   - Short answer responses in styled cards
4. **Individual responses drill-down**:
   - New expandable section showing per-session responses
   - Member name lookup (if member_id exists)

Integration in export:
```dart
// In the export button handler:
final summary = _summary!;
final sessions = await _repo.fetchSessions(widget.surveyId);

// For PDF:
final pdfBytes = await SurveyExportService.generatePdf(
  surveyTitle: widget.surveyTitle,
  summary: summary,
  sessions: sessions,
);
await Printing.sharePdf(bytes: pdfBytes, filename: '${widget.surveyTitle}-results.pdf');

// For Excel:
final excelBytes = await SurveyExportService.generateExcel(
  surveyTitle: widget.surveyTitle,
  summary: summary,
  sessions: sessions,
);
// Use universal_html or file_saver for download
```

**Step 2: Commit**

```bash
git add lib/screens/crm/survey_results_widget.dart
git commit -m "feat: enhance survey results with gradient styling and PDF/Excel export"
```

---

## Task 7: Event Detail Page — Default Post-Event Survey Integration

**Files:**
- Modify: `lib/screens/crm/event_detail_screen.dart` (lines ~3513-3700, the `_buildSurveysTab` method)

**What:** Add a "Quick Survey" button that creates a pre-populated survey using the default post-event questions from `SurveyQuestionSuggestions.defaultPostEventQuestions`. Changes to the surveys tab:

1. **Replace the basic "Create Survey" button** with a split button:
   - Primary: "Create Survey" (opens empty builder as before)
   - Secondary dropdown: "Use Post-Event Template"
2. **"Use Post-Event Template" action**:
   - Creates a Survey object with `eventId` pre-filled and title "Post-Event Feedback: {event.title}"
   - Pre-populates with the 6 default post-event questions
   - Opens `SurveyBuilderScreen` with this pre-populated survey for review/edit
3. **Enhanced survey cards** in the tab (matching the new gradient styling from Task 5)

Key code change in `_buildSurveysTab()`:
```dart
// Replace the existing ElevatedButton with:
Row(
  children: [
    ElevatedButton.icon(
      onPressed: () => _openSurveyBuilder(),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Create Survey'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _momentumBlue,
        foregroundColor: Colors.white,
      ),
    ),
    const SizedBox(width: 8),
    OutlinedButton.icon(
      onPressed: () => _createFromTemplate(),
      icon: const Icon(Icons.flash_on, size: 18),
      label: const Text('Post-Event Template'),
    ),
  ],
)
```

The `_createFromTemplate` method:
```dart
void _createFromTemplate() async {
  final defaultQs = SurveyQuestionSuggestions.defaultPostEventQuestions;
  final preSurvey = Survey(
    eventId: _currentEvent.id,
    title: 'Post-Event Feedback: ${_currentEvent.title ?? 'Event'}',
    description: 'Automated post-event survey',
    targetAudience: 'all_attendees',
    questions: defaultQs.asMap().entries.map((e) => SurveyQuestion(
      questionText: e.value.text,
      questionType: e.value.type,
      options: e.value.options,
      questionOrder: e.key + 1,
    )).toList(),
  );

  final result = await Navigator.of(context).push<Survey>(
    MaterialPageRoute(
      builder: (_) => SurveyBuilderScreen(
        existingSurvey: preSurvey,
        eventId: _currentEvent.id,
      ),
    ),
  );
  if (result != null) _loadSurveys();
}
```

**Step 2: Commit**

```bash
git add lib/screens/crm/event_detail_screen.dart
git commit -m "feat: add post-event survey template to event detail page"
```

---

## Task Dependencies

```
Task 1 (Suggested Questions) ──┐
                                ├── Task 4 (Survey Builder) ──── Task 7 (Event Detail)
Task 3 (Recipient Selector) ───┘
Task 2 (Export Service) ──────────── Task 6 (Results + Export)
Task 5 (Surveys Screen) ─── independent (can run in parallel with Tasks 4, 6)
```

**Recommended execution order:**
1. Tasks 1, 2, 3 in parallel (no dependencies)
2. Tasks 4, 5, 6 in parallel (depend on 1-3 respectively)
3. Task 7 last (depends on Task 1 and 4)

---

## Key Reference Files

| Purpose | Path |
|---------|------|
| BrandColors theme | `lib/features/committees/theme/brand_colors.dart` |
| Slack page (design reference) | `lib/features/slack/screens/slack_management_screen.dart` |
| Slack widgets (design reference) | `lib/features/slack/widgets/` |
| Donor export (export pattern) | `lib/services/crm/donor_export_service.dart` |
| Donor export config (row model) | `lib/models/crm/donor_export_config.dart` |
| Survey models | `lib/models/crm/survey_model.dart` |
| Survey repository | `lib/services/crm/survey_repository.dart` |
| Supabase service | `lib/services/crm/supabase_service.dart` |
| Main navigation | `lib/main.dart` (lines 1290-1350 for Outreach dropdown) |
| Event detail | `lib/screens/crm/event_detail_screen.dart` (line 3513+ for surveys tab) |
| send-survey edge function | `supabase/functions/send-survey/index.ts` |
| survey-webhook edge function | `supabase/functions/survey-webhook/index.ts` |
