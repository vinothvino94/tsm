// pdf_generator_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../../api/api_utils.dart';
import '../../models/project.dart';

class PDFGeneratorService {
  static Future<void> generateAndSharePDF(
    BuildContext context,
    List<SummaryReportModel> summaryList,
    String fromDate,
    String toDate,
    String? selectedworktype,
  ) async {
    if (summaryList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No Summary Data Available!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Generating PDF..."),
                ],
              ),
            ),
          ),
        ),
      );

      // Load logo
      final ByteData bytes =
          await rootBundle.load('assets/images/Approved Logo.png');
      final Uint8List logoBytes = bytes.buffer.asUint8List();

      final PdfDocument document = PdfDocument();

      // Set page size to A3 Landscape
      //document.pageSettings.size = const Size(1190, 842); // A3 Landscape
      //document.pageSettings.margins = PdfMargins()
      document.pageSettings.size = PdfPageSize.a3;
      document.pageSettings.orientation = PdfPageOrientation.landscape;
      document.pageSettings.margins = PdfMargins()
        ..left = 20
        ..right = 20
        ..top = 20
        ..bottom = 20;

      // Group data by project
      final groupedByProject = _groupDataByProject(summaryList);
      final allProjects = summaryList
          .map((e) => e.projectName)
          .where((name) => name != null && name.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      final allElements = summaryList
          .map((e) => e.eleName)
          .where((name) => name != null && name.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList()
        ..sort();

      // Add pages for each project
      for (int i = 0; i < allProjects.length; i++) {
        final project = allProjects[i];
        final page = document.pages.add();

        double y = 20;

        // Draw Header with Logo
        y = _drawHeader(page, logoBytes, y, fromDate, toDate);
        y += 10;

        // Draw Project Table
        y = _drawProjectTable(
          page,
          project,
          groupedByProject[project] ?? {},
          allElements,
          y,
          selectedworktype,
        );

        // Add page break if not last page
        if (i < allProjects.length - 1 && y > 700) {
          page.graphics.drawString(
            "--- Continued on next page ---",
            PdfStandardFont(PdfFontFamily.helvetica, 8),
            bounds: Rect.fromLTWH(0, y + 10, 1150, 20),
            brush: PdfSolidBrush(PdfColor(128, 128, 128)),
          );
        }
      }

      // Save PDF
      final List<int> bytesList = await document.save();
      document.dispose();

      final String formattedDate = getFileSafeDateTimeFormatted();
      final String fileName = "summary_report_$formattedDate.pdf";

      // Close loading dialog
      Navigator.pop(context);

      // Save PDF based on platform
      await _savePdf(context, bytesList, fileName);
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error generating PDF: $e")),
      );
      print("Error generating PDF: $e");
    }
  }

  static double _drawHeader(
    PdfPage page,
    Uint8List logoBytes,
    double startY,
    String fromDate,
    String toDate,
  ) {
    final graphics = page.graphics;
    final pageWidth = page.getClientSize().width;

    // Draw border
    final rect = Rect.fromLTWH(0, startY, pageWidth, 70);
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(240, 240, 240)),
      bounds: rect,
    );
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(200, 200, 200)),
      bounds: rect,
    );

    // Draw logo
    final logoImage = PdfBitmap(logoBytes);
    graphics.drawImage(
      logoImage,
      Rect.fromLTWH(10, startY + 5, 60, 60),
    );

    // Draw title
    final titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold);
    final title = "Jata Techno Wheels LLP - Drawing Summary Report";
    final titleSize = titleFont.measureString(title);
    graphics.drawString(
      title,
      titleFont,
      bounds: Rect.fromLTWH(
        (pageWidth - titleSize.width) / 2,
        startY + 15,
        titleSize.width,
        20,
      ),
    );

    // Draw date range
    final dateFont =
        PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final dateRange =
        "From: ${_formatDate(fromDate, includeTime: false)} To: ${_formatDate(toDate, includeTime: false)}";
    final dateSize = dateFont.measureString(dateRange);
    graphics.drawString(
      dateRange,
      dateFont,
      bounds: Rect.fromLTWH(
        (pageWidth - dateSize.width) / 2,
        startY + 38,
        dateSize.width,
        15,
      ),
    );

    // Draw generation time
    final timeFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final genTime = "Generated On: ${getCurrentDateTimeFormatted()}";
    final timeSize = timeFont.measureString(genTime);
    graphics.drawString(
      genTime,
      timeFont,
      bounds: Rect.fromLTWH(
        (pageWidth - timeSize.width) / 2,
        startY + 55,
        timeSize.width,
        12,
      ),
    );

    return startY + 75;
  }

  static double _drawProjectTable(
    PdfPage page,
    String projectName,
    Map<String, Map<String, dynamic>> data,
    List<String> elements,
    double startY,
    String? selectedworktype,
  ) {
    final graphics = page.graphics;
    final dates = data.keys.toList()..sort();

    // Filter elements with data
    final filteredElements = elements.where((element) {
      return dates.any((date) {
        final dwg = int.tryParse(_getValue(data[date]?[element], "dwg")) ?? 0;
        final qty = int.tryParse(_getValue(data[date]?[element], "qnty")) ?? 0;
        return dwg > 0 || qty > 0;
      });
    }).toList();

    if (filteredElements.isEmpty) return startY;

    // Calculate totals
    final rowTotals = _calculateRowTotals(data, dates, filteredElements);
    final columnTotals = _calculateColumnTotals(data, dates);
    final grandTotalDwg =
        columnTotals.values.fold(0, (sum, e) => sum + (e["dwg"] ?? 0));
    final grandTotalQty =
        columnTotals.values.fold(0, (sum, e) => sum + (e["qnty"] ?? 0));

    // Draw project title
    final titleFont =
        PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold);
    final titleText = selectedworktype != null && selectedworktype!.isNotEmpty
        ? "${projectName.toUpperCase()} (${selectedworktype!.toUpperCase()} - REPORT)"
        : projectName.toUpperCase();
    graphics.drawString(
      //projectName.toUpperCase(),
      titleText,
      titleFont,
      bounds: Rect.fromLTWH(0, startY, 1150, 20),
      brush: PdfSolidBrush(PdfColor(0, 0, 128)),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center, // ✅ CENTER ALIGN
      ),
    );
    startY += 25;

    // Create grid
    final int columnCount = 2 + (dates.length * 2) + 2;
    final grid = PdfGrid();
    grid.columns.add(count: columnCount);
    grid.columns[0].width = 40;
    grid.columns[1].width = 100;
    grid.style.cellPadding = PdfPaddings(left: 2, right: 2, top: 2, bottom: 2);
    grid.style.font = PdfStandardFont(PdfFontFamily.helvetica, 7);

    // Add header rows
    grid.headers.add(2);
    final headerRow1 = grid.headers[0];
    final headerRow2 = grid.headers[1];

    // First column (S.NO)
    _setCenterCell(headerRow1.cells[0], "S.NO");
    headerRow1.cells[0].rowSpan = 2;
    _styleHeaderCell(headerRow1.cells[0]);

    // Second column (DATE/ELEMENT)
    _setCenterCell(headerRow1.cells[1], "DATE");
    _setCenterCell(headerRow2.cells[1], "ELEMENT");
    _styleHeaderCell(headerRow1.cells[1]);
    _styleHeaderCell(headerRow2.cells[1]);

    // Date columns
    int col = 2;
    for (var date in dates) {
      _setCenterCell(
          headerRow1.cells[col], _formatDate(date, includeTime: false));
      headerRow1.cells[col].columnSpan = 2;
      _styleHeaderCell(headerRow1.cells[col]);

      _setCenterCell(headerRow2.cells[col], "DWG");
      _setCenterCell(headerRow2.cells[col + 1], "QTY");
      _styleSubHeaderCell(headerRow2.cells[col]);
      _styleSubHeaderCell(headerRow2.cells[col + 1]);

      col += 2;
    }

    // Total columns
    _setCenterCell(headerRow1.cells[col], "TOTAL");
    headerRow1.cells[col].columnSpan = 2;
    _styleHeaderCell(headerRow1.cells[col]);

    _setCenterCell(headerRow2.cells[col], "DWG");
    _setCenterCell(headerRow2.cells[col + 1], "QTY");
    _styleSubHeaderCell(headerRow2.cells[col]);
    _styleSubHeaderCell(headerRow2.cells[col + 1]);

    // Add data rows
    for (int i = 0; i < filteredElements.length; i++) {
      final element = filteredElements[i];
      final row = grid.rows.add();

      int c = 0;
      _setCenterCell(row.cells[c++], (i + 1).toString());
      _setCenterCell(row.cells[c++], element);

      for (var date in dates) {
        _setCenterCell(row.cells[c++], _getValue(data[date]?[element], "dwg"));
        _setCenterCell(row.cells[c++], _getValue(data[date]?[element], "qnty"));
      }

      _setCenterCell(
        row.cells[c++],
        rowTotals[element]?["dwg"].toString() ?? "0",
      );

      _setCenterCell(
        row.cells[c++],
        rowTotals[element]?["qnty"].toString() ?? "0",
      );

      // Style data cells
      for (int j = 0; j < row.cells.count; j++) {
        row.cells[j].style.font = PdfStandardFont(PdfFontFamily.helvetica, 7);
        row.cells[j].style.cellPadding =
            PdfPaddings(left: 2, right: 2, top: 2, bottom: 2);
      }
    }

    // Add total row
    final totalRow = grid.rows.add();
    totalRow.style.backgroundBrush = PdfSolidBrush(PdfColor(220, 255, 220));

    int tc = 0;
    _setCenterCell(totalRow.cells[tc], "TOTAL");
    totalRow.cells[tc].columnSpan = 2;
    tc += 2;

    for (var date in dates) {
      _setCenterCell(
          totalRow.cells[tc++], columnTotals[date]?["dwg"].toString() ?? "0");

      _setCenterCell(
          totalRow.cells[tc++], columnTotals[date]?["qnty"].toString() ?? "0");
    }

    _setCenterCell(totalRow.cells[tc++], grandTotalDwg.toString());
    _setCenterCell(totalRow.cells[tc++], grandTotalQty.toString());

    // Style total row
    for (int j = 0; j < totalRow.cells.count; j++) {
      totalRow.cells[j].style.font =
          PdfStandardFont(PdfFontFamily.helvetica, 7, style: PdfFontStyle.bold);
      totalRow.cells[j].style.backgroundBrush =
          PdfSolidBrush(PdfColor(255, 255, 200));
    }

    // Draw grid
    final result = grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, startY, 0, 0),
    );

    return result!.bounds.bottom + 20;
  }

  static void _styleHeaderCell(PdfGridCell cell) {
    cell.style.font =
        PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold);
    cell.style.backgroundBrush = PdfSolidBrush(PdfColor(220, 220, 220));
    cell.style.cellPadding = PdfPaddings(left: 4, right: 4, top: 4, bottom: 4);
  }

  static void _styleSubHeaderCell(PdfGridCell cell) {
    cell.style.font = PdfStandardFont(PdfFontFamily.helvetica, 7);
    cell.style.backgroundBrush = PdfSolidBrush(PdfColor(240, 240, 240));
    cell.style.cellPadding = PdfPaddings(left: 2, right: 2, top: 2, bottom: 2);
  }

  static void setCenterCell(PdfGridCell cell, String value) {
    cell.value = value;
    final style = PdfGridCellStyle();
    style.stringFormat = PdfStringFormat(
      alignment: PdfTextAlignment.center,
      lineAlignment: PdfVerticalAlignment.middle,
    );
    cell.style = style;
  }

  static void _setCenterCell(PdfGridCell cell, String value) {
    cell.value = value;

    final style = cell.style ?? PdfGridCellStyle();

    style.stringFormat = PdfStringFormat(
      alignment: PdfTextAlignment.center,
      lineAlignment: PdfVerticalAlignment.middle,
    );

    cell.style = style;
  }

  static Map<String, Map<String, int>> _calculateRowTotals(
    Map<String, Map<String, dynamic>> data,
    List<String> dates,
    List<String> elements,
  ) {
    final Map<String, Map<String, int>> rowTotals = {};
    for (var element in elements) {
      int totalDwg = 0;
      int totalQty = 0;
      for (var date in dates) {
        totalDwg += int.tryParse(_getValue(data[date]?[element], "dwg")) ?? 0;
        totalQty += int.tryParse(_getValue(data[date]?[element], "qnty")) ?? 0;
      }
      rowTotals[element] = {"dwg": totalDwg, "qnty": totalQty};
    }
    return rowTotals;
  }

  static Map<String, Map<String, int>> _calculateColumnTotals(
    Map<String, Map<String, dynamic>> data,
    List<String> dates,
  ) {
    final Map<String, Map<String, int>> columnTotals = {};
    for (var date in dates) {
      columnTotals[date] = {
        "dwg": _calculateDailyTotal(data[date], "dwg"),
        "qnty": _calculateDailyTotal(data[date], "qnty"),
      };
    }
    return columnTotals;
  }

  static String _getValue(dynamic data, String key) {
    if (data == null) return " ";
    return data[key]?.toString() ?? " ";
  }

  static int _calculateDailyTotal(Map<String, dynamic>? data, String key) {
    if (data == null) return 0;
    int total = 0;
    data.forEach((_, value) {
      total += int.tryParse(value[key].toString()) ?? 0;
    });
    return total;
  }

  static String _formatDate(String date, {bool includeTime = true}) {
    if (date.isEmpty) return date;
    try {
      final d = DateTime.tryParse(date);
      if (d == null) return date;
      if (includeTime) {
        return "${d.day.toString().padLeft(2, '0')}-"
            "${d.month.toString().padLeft(2, '0')}-"
            "${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
      } else {
        return "${d.day.toString().padLeft(2, '0')}-"
            "${d.month.toString().padLeft(2, '0')}-"
            "${d.year}";
      }
    } catch (e) {
      return date;
    }
  }

  static Map<String, Map<String, Map<String, dynamic>>> _groupDataByProject(
    List<SummaryReportModel> summaryList,
  ) {
    final result = <String, Map<String, Map<String, dynamic>>>{};
    for (var item in summaryList) {
      final dateStr = item.tsdt.split("T").first;
      final projectName = item.projectName ?? "Unknown Project";
      final element = item.eleName ?? "Other";
      final dwg = (item.dwg ?? 0).toInt();
      final qnty = (item.qnty ?? 0).toInt();
      result.putIfAbsent(projectName, () => {});
      result[projectName]!.putIfAbsent(dateStr, () => {});
      result[projectName]![dateStr]![element] = {
        "dwg": dwg,
        "qnty": qnty,
      };
    }
    return result;
  }

  static Future<void> _savePdf(
    BuildContext context,
    List<int> bytesList,
    String fileName,
  ) async {
    try {
      if (Platform.isAndroid) {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytesList);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ PDF saved to:\n${file.path}")),
          );
          await Share.shareXFiles(
            [XFile(file.path)],
            text: "Drawing Summary Report",
          );
        } else {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(bytesList);
          await Share.shareXFiles(
            [XFile(file.path)],
            text: "Drawing Summary Report",
          );
        }
      } else if (Platform.isWindows) {
        final downloadsPath =
            '${Platform.environment['USERPROFILE']}\\Downloads';
        final downloadsDir = Directory(downloadsPath);

        if (await downloadsDir.exists()) {
          String filePath = '$downloadsPath\\$fileName';
          int counter = 1;
          while (File(filePath).existsSync()) {
            final nameWithoutExt =
                fileName.substring(0, fileName.lastIndexOf('.'));
            final ext = fileName.substring(fileName.lastIndexOf('.'));
            filePath = '$downloadsPath\\${nameWithoutExt}_$counter$ext';
            counter++;
          }

          final file = File(filePath);
          await file.writeAsBytes(bytesList);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ PDF saved to:\n$filePath")),
          );
        } else {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(bytesList);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ PDF saved to:\n${file.path}")),
          );
        }
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytesList);
        await Share.shareXFiles(
          [XFile(file.path)],
          text: "Drawing Summary Report",
        );
      }
    } catch (e) {
      print("❌ Error saving PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error saving PDF: $e")),
      );
    }
  }
}

String getFileSafeDateTimeFormatted() {
  final now = DateTime.now();
  return "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
}

String getCurrentDateTimeFormatted() {
  final now = DateTime.now();
  return "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
}
