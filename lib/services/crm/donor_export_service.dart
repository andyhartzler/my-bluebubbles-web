import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';

import 'package:bluebubbles/models/crm/donor_export_config.dart';

/// Service for generating PDF and Excel exports of donation data
class DonorExportService {
  static const _unityBlue = PdfColor.fromInt(0xFF273351);
  static const _momentumBlue = PdfColor.fromInt(0xFF32A6DE);
  static const _lightGray = PdfColor.fromInt(0xFFF5F5F5);
  static const _darkGray = PdfColor.fromInt(0xFF666666);

  /// Generate a PDF document from donation data
  static Future<Uint8List> generatePdf({
    required List<DonationExportRow> donations,
    required DonorExportFields fields,
    required String title,
    String? filterSummary,
  }) async {
    final doc = pw.Document(title: title, author: 'Missouri Young Democrats');

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

    // Calculate summary statistics
    final totalAmount = donations.fold<double>(
      0,
      (sum, d) => sum + (d.amount ?? 0),
    );
    final double avgAmount = donations.isEmpty ? 0.0 : totalAmount / donations.length;
    final dateFormat = DateFormat.yMMMd();
    final now = DateTime.now();

    // Get headers for table
    final headers = fields.selectedFieldNames;

    // Build table data
    final tableData = donations.map((d) => d.getValues(fields)).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter.landscape,
        maxPages: 1000,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader(
          context: context,
          logo: logoImage,
          title: title,
          boldFont: boldFont,
          font: font,
          generatedDate: now,
          filterSummary: filterSummary,
        ),
        footer: (context) => _buildPdfFooter(context, font),
        build: (context) => [
          // Donations table
          _buildPdfTable(headers, tableData, font, boldFont),
          pw.SizedBox(height: 20),
          // Summary section
          _buildPdfSummary(
            donationCount: donations.length,
            totalAmount: totalAmount,
            avgAmount: avgAmount,
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
    String? filterSummary,
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
        if (filterSummary != null &&
            filterSummary.isNotEmpty &&
            filterSummary != 'No filters') ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Filters: $filterSummary',
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: _darkGray,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
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

  static pw.Widget _buildPdfTable(
    List<String> headers,
    List<List<String>> data,
    pw.Font font,
    pw.Font boldFont,
  ) {
    final columnCount = headers.length;

    // Calculate column widths based on content type
    // Page width in landscape is ~720 points (792 - 72 margins)
    final columnWidths = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < headers.length; i++) {
      final header = headers[i];
      double width;
      switch (header) {
        case 'Amount':
          width = 55;
          break;
        case 'Date':
          width = 65;
          break;
        case 'Check #':
          width = 45;
          break;
        case 'Thank You Sent':
        case 'Recurring':
          width = 35;
          break;
        case 'State':
          width = 30;
          break;
        case 'ZIP Code':
          width = 45;
          break;
        case 'Phone':
          width = 75;
          break;
        case 'Email':
          width = 120;
          break;
        case 'Donor Name':
          width = 90;
          break;
        case 'Address':
          width = 100;
          break;
        case 'City':
        case 'County':
          width = 60;
          break;
        case 'Employer':
        case 'Occupation':
          width = 80;
          break;
        case 'Congressional District':
          width = 40;
          break;
        case 'Payment Method':
          width = 60;
          break;
        case 'Event':
          width = 80;
          break;
        case 'Notes':
          width = 100;
          break;
        default:
          width = 60;
      }
      columnWidths[i] = pw.FixedColumnWidth(width);
    }

    // Adjust font size based on number of columns
    final double headerFontSize;
    final double cellFontSize;
    final double cellHeight;
    if (columnCount <= 6) {
      headerFontSize = 9;
      cellFontSize = 8;
      cellHeight = 22;
    } else if (columnCount <= 10) {
      headerFontSize = 7;
      cellFontSize = 6.5;
      cellHeight = 18;
    } else {
      headerFontSize = 6;
      cellFontSize = 5.5;
      cellHeight = 16;
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      columnWidths: columnWidths,
      headerStyle: pw.TextStyle(
        font: boldFont,
        fontSize: headerFontSize,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _unityBlue),
      headerHeight: cellHeight + 4,
      cellStyle: pw.TextStyle(font: font, fontSize: cellFontSize),
      cellHeight: cellHeight,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      cellAlignments: Map.fromIterables(
        List.generate(columnCount, (i) => i),
        headers.map((h) {
          // Right-align Amount column
          if (h == 'Amount') return pw.Alignment.centerRight;
          // Center-align short columns
          if (h == 'Thank You Sent' || h == 'Recurring' || h == 'State') {
            return pw.Alignment.center;
          }
          return pw.Alignment.centerLeft;
        }),
      ),
      oddRowDecoration: const pw.BoxDecoration(color: _lightGray),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  static pw.Widget _buildPdfSummary({
    required int donationCount,
    required double totalAmount,
    required double avgAmount,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

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
          _buildSummaryItem(
            'Total Donations',
            donationCount.toString(),
            font,
            boldFont,
          ),
          _buildSummaryItem(
            'Total Amount',
            currencyFormat.format(totalAmount),
            font,
            boldFont,
          ),
          _buildSummaryItem(
            'Average Gift',
            currencyFormat.format(avgAmount),
            font,
            boldFont,
          ),
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

  /// Generate an Excel document from donation data
  static Future<Uint8List> generateExcel({
    required List<DonationExportRow> donations,
    required DonorExportFields fields,
    required String title,
    String? filterSummary,
  }) async {
    final excel = Excel.createExcel();

    // Remove default sheet and create our own
    excel.delete('Sheet1');
    final sheet = excel['Donations'];

    // Define styles
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#273351'),
      fontColorHex: ExcelColor.white,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final currencyStyle = CellStyle(horizontalAlign: HorizontalAlign.Right);

    final dateStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);

    // Get headers
    final headers = fields.selectedFieldNames;

    // Add title row
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue(title)
      ..cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: ExcelColor.fromHexString('#273351'),
      );

    // Add filter summary if present
    int dataStartRow = 2;
    if (filterSummary != null &&
        filterSummary.isNotEmpty &&
        filterSummary != 'No filters') {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        ..value = TextCellValue('Filters: $filterSummary')
        ..cellStyle = CellStyle(
          italic: true,
          fontColorHex: ExcelColor.fromHexString('#666666'),
        );
      dataStartRow = 3;
    }

    // Add header row
    for (var i = 0; i < headers.length; i++) {
      sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: dataStartRow),
        )
        ..value = TextCellValue(headers[i])
        ..cellStyle = headerStyle;
    }

    // Add data rows
    for (var rowIndex = 0; rowIndex < donations.length; rowIndex++) {
      final donation = donations[rowIndex];
      final values = donation.getValues(fields);

      for (var colIndex = 0; colIndex < values.length; colIndex++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: colIndex,
            rowIndex: dataStartRow + 1 + rowIndex,
          ),
        );

        final value = values[colIndex];
        final header = headers[colIndex];

        // Set appropriate cell value and style based on column type
        if (header == 'Amount' && value.startsWith('\$')) {
          // Parse amount and set as number
          final amount = double.tryParse(
            value.replaceAll('\$', '').replaceAll(',', ''),
          );
          if (amount != null) {
            cell.value = DoubleCellValue(amount);
            cell.cellStyle = currencyStyle;
          } else {
            cell.value = TextCellValue(value);
          }
        } else if (header == 'Date') {
          cell.value = TextCellValue(value);
          cell.cellStyle = dateStyle;
        } else {
          cell.value = TextCellValue(value);
        }
      }
    }

    // Add summary row
    final summaryRowIndex = dataStartRow + 1 + donations.length + 1;
    final totalAmount = donations.fold<double>(
      0,
      (sum, d) => sum + (d.amount ?? 0),
    );

    sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRowIndex),
      )
      ..value = TextCellValue('Summary')
      ..cellStyle = CellStyle(bold: true);

    sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRowIndex + 1),
    )..value = TextCellValue('Total Donations: ${donations.length}');

    sheet.cell(
        CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: summaryRowIndex + 2,
        ),
      )
      ..value = TextCellValue(
        'Total Amount: \$${totalAmount.toStringAsFixed(2)}',
      );

    if (donations.isNotEmpty) {
      final avgAmount = totalAmount / donations.length;
      sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: summaryRowIndex + 3,
          ),
        )
        ..value = TextCellValue(
          'Average Gift: \$${avgAmount.toStringAsFixed(2)}',
        );
    }

    // Set column widths
    for (var i = 0; i < headers.length; i++) {
      final header = headers[i];
      double width = 15.0;
      if (header == 'Email') width = 25.0;
      if (header == 'Donor Name') width = 20.0;
      if (header == 'Address') width = 30.0;
      if (header == 'Notes') width = 35.0;
      if (header == 'Amount') width = 12.0;
      if (header == 'Date') width = 12.0;
      sheet.setColumnWidth(i, width);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel file');
    }
    return Uint8List.fromList(bytes);
  }
}
