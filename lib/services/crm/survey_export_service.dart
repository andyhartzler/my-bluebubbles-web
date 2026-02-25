import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';

import 'package:bluebubbles/models/crm/survey_model.dart';

/// Service for generating PDF and Excel exports of survey results
class SurveyExportService {
  static const _unityBlue = PdfColor.fromInt(0xFF273351);
  static const _momentumBlue = PdfColor.fromInt(0xFF32A6DE);
  static const _lightGray = PdfColor.fromInt(0xFFF5F5F5);
  static const _darkGray = PdfColor.fromInt(0xFF666666);

  /// Generate a PDF document from survey results
  static Future<Uint8List> generatePdf({
    required String surveyTitle,
    required SurveyResultsSummary summary,
    required List<SurveySession> sessions,
  }) async {
    final doc = pw.Document(title: surveyTitle, author: 'Missouri Young Democrats');

    // Load logo from assets
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load(
        'assets/images/text-logo-1320x440.png',
      );
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Failed to load logo: $e');
    }

    // Load fonts
    final font = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    final now = DateTime.now();
    final percentFormat = NumberFormat.percentPattern();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        maxPages: 1000,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader(
          context: context,
          logo: logoImage,
          title: surveyTitle,
          boldFont: boldFont,
          font: font,
          generatedDate: now,
        ),
        footer: (context) => _buildPdfFooter(context, font),
        build: (context) => [
          // Summary section
          _buildPdfSummary(
            summary: summary,
            font: font,
            boldFont: boldFont,
            percentFormat: percentFormat,
          ),
          pw.SizedBox(height: 20),
          // Per-question sections
          ...summary.questionSummaries.map(
            (qs) => _buildQuestionSection(
              questionSummary: qs,
              font: font,
              boldFont: boldFont,
            ),
          ),
          pw.SizedBox(height: 20),
          // Sessions table
          _buildSessionsSection(
            sessions: sessions,
            font: font,
            boldFont: boldFont,
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildPdfHeader({
    required pw.Context context,
    required pw.MemoryImage? logo,
    required String title,
    required pw.Font boldFont,
    required pw.Font font,
    required DateTime generatedDate,
  }) {
    final dateFormat = DateFormat.yMMMd();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo
            if (logo != null)
              pw.Image(logo, width: 200)
            else
              pw.Text(
                'Missouri Young Democrats',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 18,
                  color: _unityBlue,
                ),
              ),
            // Title and date
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 20,
                    color: _unityBlue,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated: ${dateFormat.format(generatedDate)}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: _darkGray,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 3,
          decoration: const pw.BoxDecoration(
            gradient: pw.LinearGradient(colors: [_unityBlue, _momentumBlue]),
          ),
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Missouri Young Democrats',
            style: pw.TextStyle(font: font, fontSize: 9, color: _darkGray),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 9, color: _darkGray),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfSummary({
    required SurveyResultsSummary summary,
    required pw.Font font,
    required pw.Font boldFont,
    required NumberFormat percentFormat,
  }) {
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
          _buildSummaryItem('Sent', summary.totalSent.toString(), font, boldFont),
          _buildSummaryItem('Responded', summary.totalResponded.toString(), font, boldFont),
          _buildSummaryItem('Completed', summary.totalCompleted.toString(), font, boldFont),
          _buildSummaryItem(
            'Response Rate',
            percentFormat.format(summary.responseRate),
            font,
            boldFont,
          ),
          _buildSummaryItem('Opted Out', summary.totalOptedOut.toString(), font, boldFont),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(
    String label,
    String value,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: 10, color: _darkGray),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(font: boldFont, fontSize: 16, color: _unityBlue),
        ),
      ],
    );
  }

  static pw.Widget _buildQuestionSection({
    required QuestionResultSummary questionSummary,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    final question = questionSummary.question;
    final dist = questionSummary.distribution;
    final total = questionSummary.responseCount;

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Question header
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const pw.BoxDecoration(color: _unityBlue),
            child: pw.Text(
              'Q${question.questionOrder}: ${question.questionText}',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 10,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Type: ${_formatQuestionType(question.questionType)}  |  Responses: $total',
            style: pw.TextStyle(font: font, fontSize: 8, color: _darkGray),
          ),
          pw.SizedBox(height: 6),
          // Distribution table
          if (dist.isNotEmpty)
            _buildDistributionTable(dist, total, font, boldFont),
          // Average rating
          if (questionSummary.averageRating != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Average Rating: ${questionSummary.averageRating!.toStringAsFixed(2)}',
              style: pw.TextStyle(font: boldFont, fontSize: 10, color: _unityBlue),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildDistributionTable(
    Map<String, int> distribution,
    int totalResponses,
    pw.Font font,
    pw.Font boldFont,
  ) {
    final headers = ['Response', 'Count', 'Percentage'];
    final data = distribution.entries.map((e) {
      final pct = totalResponses > 0
          ? (e.value / totalResponses * 100).toStringAsFixed(1)
          : '0.0';
      return [e.key, e.value.toString(), '$pct%'];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FixedColumnWidth(60),
        2: const pw.FixedColumnWidth(80),
      },
      headerStyle: pw.TextStyle(
        font: boldFont,
        fontSize: 8,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _unityBlue),
      headerHeight: 20,
      cellStyle: pw.TextStyle(font: font, fontSize: 7.5),
      cellHeight: 18,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
      },
      oddRowDecoration: const pw.BoxDecoration(color: _lightGray),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  static pw.Widget _buildSessionsSection({
    required List<SurveySession> sessions,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    final dateFormat = DateFormat.yMMMd().add_jm();

    final headers = ['Phone', 'Status', 'Progress', 'Started', 'Completed'];
    final data = sessions.map((s) {
      return [
        _maskPhone(s.phoneE164),
        s.status,
        'Q${s.currentQuestionOrder}',
        s.startedAt != null ? dateFormat.format(s.startedAt!) : '-',
        s.completedAt != null ? dateFormat.format(s.completedAt!) : '-',
      ];
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Sessions',
          style: pw.TextStyle(font: boldFont, fontSize: 14, color: _unityBlue),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: data,
          columnWidths: {
            0: const pw.FixedColumnWidth(80),
            1: const pw.FixedColumnWidth(70),
            2: const pw.FixedColumnWidth(60),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
          },
          headerStyle: pw.TextStyle(
            font: boldFont,
            fontSize: 8,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: _unityBlue),
          headerHeight: 20,
          cellStyle: pw.TextStyle(font: font, fontSize: 7.5),
          cellHeight: 18,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.centerLeft,
            4: pw.Alignment.centerLeft,
          },
          oddRowDecoration: const pw.BoxDecoration(color: _lightGray),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
      ],
    );
  }

  /// Generate an Excel document from survey results
  static Future<Uint8List> generateExcel({
    required String surveyTitle,
    required SurveyResultsSummary summary,
    required List<SurveySession> sessions,
  }) async {
    final excel = Excel.createExcel();
    final dateFormat = DateFormat.yMMMd().add_jm();

    // Remove default sheet and create our own
    excel.delete('Sheet1');

    // Define styles
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#273351'),
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    // ── Summary sheet ──────────────────────────────────────────────────────
    final summarySheet = excel['Summary'];

    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue(surveyTitle)
      ..cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: ExcelColor.fromHexString('#273351'),
      );

    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue('Generated: ${DateFormat.yMMMd().format(DateTime.now())}')
      ..cellStyle = CellStyle(
        italic: true,
        fontColorHex: ExcelColor.fromHexString('#666666'),
      );

    final percentFormat = NumberFormat.percentPattern();

    final metricLabels = ['Sent', 'Responded', 'Completed', 'Response Rate', 'Opted Out'];
    final metricValues = [
      summary.totalSent.toString(),
      summary.totalResponded.toString(),
      summary.totalCompleted.toString(),
      percentFormat.format(summary.responseRate),
      summary.totalOptedOut.toString(),
    ];

    // Metric headers at row 3
    for (var i = 0; i < metricLabels.length; i++) {
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3))
        ..value = TextCellValue(metricLabels[i])
        ..cellStyle = headerStyle;
    }
    // Metric values at row 4
    for (var i = 0; i < metricValues.length; i++) {
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4))
        ..value = TextCellValue(metricValues[i])
        ..cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
    }

    // Set summary column widths
    for (var i = 0; i < metricLabels.length; i++) {
      summarySheet.setColumnWidth(i, 18.0);
    }

    // ── Per-question sheets ────────────────────────────────────────────────
    for (var qi = 0; qi < summary.questionSummaries.length; qi++) {
      final qs = summary.questionSummaries[qi];
      final question = qs.question;
      final sheetName = 'Q${qi + 1}';
      final sheet = excel[sheetName];

      int row = 0;

      // Question text
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue('Q${question.questionOrder}: ${question.questionText}')
        ..cellStyle = CellStyle(
          bold: true,
          fontSize: 12,
          fontColorHex: ExcelColor.fromHexString('#273351'),
        );
      row++;

      // Question type
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue('Type: ${_formatQuestionType(question.questionType)}')
        ..cellStyle = CellStyle(
          italic: true,
          fontColorHex: ExcelColor.fromHexString('#666666'),
        );
      row++;

      // Response count
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        ..value = TextCellValue('Responses: ${qs.responseCount}');
      row++;

      // Average rating (if applicable)
      if (qs.averageRating != null) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          ..value = TextCellValue('Average Rating: ${qs.averageRating!.toStringAsFixed(2)}')
          ..cellStyle = CellStyle(bold: true);
        row++;
      }

      row++; // blank row

      // Distribution table
      final dist = qs.distribution;
      if (dist.isNotEmpty) {
        final distHeaders = ['Response', 'Count', 'Percentage'];
        for (var i = 0; i < distHeaders.length; i++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row))
            ..value = TextCellValue(distHeaders[i])
            ..cellStyle = headerStyle;
        }
        row++;

        for (final entry in dist.entries) {
          final pct = qs.responseCount > 0
              ? (entry.value / qs.responseCount * 100).toStringAsFixed(1)
              : '0.0';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            ..value = TextCellValue(entry.key);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            ..value = IntCellValue(entry.value)
            ..cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            ..value = TextCellValue('$pct%')
            ..cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
          row++;
        }
      }

      // Raw responses for short_answer questions
      if (question.questionType == 'short_answer' && qs.responses.isNotEmpty) {
        row++; // blank row
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          ..value = TextCellValue('Raw Responses')
          ..cellStyle = headerStyle;
        row++;

        for (final r in qs.responses) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            ..value = TextCellValue(r.rawResponse ?? r.parsedResponse ?? '');
          row++;
        }
      }

      // Set column widths
      sheet.setColumnWidth(0, 35.0);
      sheet.setColumnWidth(1, 12.0);
      sheet.setColumnWidth(2, 15.0);
    }

    // ── Sessions sheet ─────────────────────────────────────────────────────
    final sessionsSheet = excel['Sessions'];

    final sessionHeaders = ['Phone', 'Status', 'Progress', 'Started', 'Completed'];
    for (var i = 0; i < sessionHeaders.length; i++) {
      sessionsSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
        ..value = TextCellValue(sessionHeaders[i])
        ..cellStyle = headerStyle;
    }

    for (var rowIndex = 0; rowIndex < sessions.length; rowIndex++) {
      final s = sessions[rowIndex];
      final values = [
        _maskPhone(s.phoneE164),
        s.status,
        'Q${s.currentQuestionOrder}',
        s.startedAt != null ? dateFormat.format(s.startedAt!) : '-',
        s.completedAt != null ? dateFormat.format(s.completedAt!) : '-',
      ];

      for (var colIndex = 0; colIndex < values.length; colIndex++) {
        final cell = sessionsSheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: colIndex,
            rowIndex: 1 + rowIndex,
          ),
        );
        cell.value = TextCellValue(values[colIndex]);
        if (colIndex == 1 || colIndex == 2) {
          cell.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
        }
      }
    }

    // Set session column widths
    sessionsSheet.setColumnWidth(0, 15.0);
    sessionsSheet.setColumnWidth(1, 12.0);
    sessionsSheet.setColumnWidth(2, 12.0);
    sessionsSheet.setColumnWidth(3, 22.0);
    sessionsSheet.setColumnWidth(4, 22.0);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file');
    }
    return Uint8List.fromList(bytes);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Mask a phone number showing only last 4 digits: ***1234
  static String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    return '***${phone.substring(phone.length - 4)}';
  }

  /// Pretty-print a question type slug
  static String _formatQuestionType(String type) {
    switch (type) {
      case 'yes_no':
        return 'Yes / No';
      case 'rating':
        return 'Rating (1-5)';
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'short_answer':
        return 'Short Answer';
      default:
        return type;
    }
  }
}
