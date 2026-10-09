import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class ReportExportService {
  ReportExportService._();

  // ============================================================
  // EXCEL EXPORT
  // ============================================================

  static Future<void> exportExcel({
    required String fileName,
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final excel = Excel.createExcel();

    final defaultSheet = excel.getDefaultSheet();

    if (defaultSheet != null && defaultSheet != 'Report') {
      excel.rename(defaultSheet, 'Report');
    }

    final sheet = excel['Report'];

    // ----------------------------------------------------------
    // TITLE
    // ----------------------------------------------------------

    sheet.appendRow([TextCellValue(title)]);

    sheet.appendRow([TextCellValue('')]);

    // ----------------------------------------------------------
    // HEADERS
    // ----------------------------------------------------------

    sheet.appendRow(
      headers.map((header) {
        return TextCellValue(header);
      }).toList(),
    );

    // ----------------------------------------------------------
    // DATA
    // ----------------------------------------------------------

    for (final row in rows) {
      sheet.appendRow(
        row.map((value) {
          return TextCellValue(value);
        }).toList(),
      );
    }

    // ----------------------------------------------------------
    // COLUMN WIDTH
    // ----------------------------------------------------------

    for (int i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, _columnWidth(headers[i]));
    }

    // ----------------------------------------------------------
    // GENERATE XLSX
    // ----------------------------------------------------------

    final bytes = excel.encode();

    if (bytes == null) {
      throw Exception('Failed to generate Excel report.');
    }

    // ----------------------------------------------------------
    // SAVE TEMPORARY FILE
    // ----------------------------------------------------------

    final directory = await getTemporaryDirectory();

    final safeFileName = fileName.endsWith('.xlsx')
        ? fileName
        : '$fileName.xlsx';

    final file = File('${directory.path}/$safeFileName');

    await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);

    // ----------------------------------------------------------
    // SHARE EXCEL FILE
    // ----------------------------------------------------------

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: title,
      ),
    );
  }

  // ============================================================
  // PDF EXPORT
  // ============================================================

  static Future<void> exportPdf({
    required String fileName,
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final pdf = pw.Document();

    final tableData = <List<String>>[headers, ...rows];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,

        margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 25),

        header: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.Text(
                  'Page ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          );
        },

        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Vision The Library',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          );
        },

        build: (context) {
          return [
            pw.TableHelper.fromTextArray(
              data: tableData,

              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),

              cellStyle: const pw.TextStyle(fontSize: 7),

              cellPadding: const pw.EdgeInsets.all(4),

              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),

              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headerCount: 1,
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName.endsWith('.pdf') ? fileName : '$fileName.pdf',
    );
  }

  // ============================================================
  // PRINT PDF
  // ============================================================

  static Future<void> printPdf({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final pdf = pw.Document();

    final tableData = <List<String>>[headers, ...rows];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,

        margin: const pw.EdgeInsets.all(20),

        header: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.Text(
                  'Page ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          );
        },

        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'Vision The Library',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          );
        },

        build: (context) {
          return [
            pw.TableHelper.fromTextArray(
              data: tableData,

              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),

              cellStyle: const pw.TextStyle(fontSize: 7),

              cellPadding: const pw.EdgeInsets.all(4),

              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),

              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headerCount: 1,
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        return pdf.save();
      },
    );
  }

  // ============================================================
  // COLUMN WIDTH
  // ============================================================

  static double _columnWidth(String header) {
    final value = header.toLowerCase();

    if (value.contains('name')) {
      return 25;
    }

    if (value.contains('address')) {
      return 35;
    }

    if (value.contains('email')) {
      return 30;
    }

    if (value.contains('entry') || value.contains('exit')) {
      return 18;
    }

    if (value.contains('date')) {
      return 16;
    }

    if (value.contains('status')) {
      return 15;
    }

    if (value.contains('study')) {
      return 16;
    }

    if (value.contains('library')) {
      return 18;
    }

    if (value.contains('student')) {
      return 22;
    }

    if (value.contains('present') || value.contains('absent')) {
      return 14;
    }

    if (value.contains('%') || value.contains('average')) {
      return 16;
    }

    return 18;
  }
}
