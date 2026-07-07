import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';
import '../timesheet/view_timesheet_screen.dart';
import 'entry_checklist_screen.dart';

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ViewChecklistScreen extends StatefulWidget {
  const ViewChecklistScreen({super.key});

  @override
  State<ViewChecklistScreen> createState() => _ViewChecklistScreenState();
}

class _ViewChecklistScreenState extends State<ViewChecklistScreen> {
  List<SalesEmployeeModel> salesEmployees = [];
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isLoading = false;
  String _searchQuery = '';
  Map<int, List<SalesChecklistModel>> _groupedEntries = {};
  final TextEditingController _searchController = TextEditingController();
  int empCode = 0;
  String empName = '';

  String _selectedStatusFilter = 'All'; // 'All', 'Approved', 'Pending'

  final List<String> _statusFilterOptions = ['All', 'Approved', 'Pending'];

  @override
  void initState() {
    super.initState();
    loadSalesEmployees();
    _loadUserDetails();
    _fetchSaleschecklistEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('View Check List'),
      ),
      body: _isInitialLoading
          ? _buildInitialLoading()
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: Column(
                children: [
                  SizedBox(height: 15),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.only(right: 8, left: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration:
                          _inputDecoration('Search by Checklist Number...')
                              .copyWith(
                        hintText: 'Search by Checklist Number...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearSearch,
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 10),

                  // Status Filter Dropdown
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatusFilter,
                      decoration: _inputDecoration('Filter by Status').copyWith(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      items: _statusFilterOptions
                          .map((status) => DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedStatusFilter = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: 5),

                  // Show loading indicator when refreshing or loading
                  if (_isLoading || _isRefreshing)
                    const LinearProgressIndicator(),

                  Expanded(
                    child: _buildCheckList(),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _loadUserDetails() async {
    final prefsHelper = PreferencesHelper();
    empCode = (await prefsHelper.getEmpCode()) ?? 0;
    empName = (await prefsHelper.getEmpName())!;
    setState(() {});
  }

  Widget _buildInitialLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Sales Check Lists...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we load your data',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _fetchSaleschecklistEntries();
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 15,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
      );

  Future<void> _fetchSaleschecklistEntries({int? chklNo}) async {
    print("========== FETCH SALES CHECKLIST START ==========");

    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }

    try {
      final uri = ApiUtils.getUri('ViewSalesCheckList');

      print("API URL : $uri");

      final body =
          chklNo != null ? jsonEncode({"CHKLNO": chklNo}) : jsonEncode({});

      print("REQUEST BODY : $body");

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print("STATUS CODE : ${response.statusCode}");
      print("RAW RESPONSE : ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        print("DECODED RESPONSE : $data");

        if (data['Success'] == true) {
          final List<dynamic> tickets = data['CheckList'] ?? [];

          print("TOTAL CHECKLIST COUNT : ${tickets.length}");

          final allEntries =
              tickets.map((e) => SalesChecklistModel.fromJson(e)).toList();

          print("MODEL COUNT : ${allEntries.length}");

          /// GROUP DATA
          final Map<int, List<SalesChecklistModel>> grouped = {};

          for (var entry in allEntries) {
            final key = entry.chklno ?? 0;

            if (!grouped.containsKey(key)) {
              grouped[key] = [];
            }

            grouped[key]!.add(entry);
          }

          print("GROUPED COUNT : ${grouped.length}");
          print("GROUPED KEYS : ${grouped.keys.toList()}");

          setState(() {
            _groupedEntries = grouped;
          });

          print("API SUCCESS");
        } else {
          print("API FAILED : ${data['Message']}");
        }
      } else {
        print("SERVER ERROR : ${response.statusCode}");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e, stackTrace) {
      print("EXCEPTION ERROR : $e");
      print("STACK TRACE : $stackTrace");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } finally {
      print("LOADING COMPLETED");

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _isInitialLoading = false;
      });

      print("========== FETCH SALES CHECKLIST END ==========");
    }
  }

  Widget _buildCheckList() {
    final groupedList = _getFilteredGroupedList();

    if (_isLoading && !_isRefreshing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading checklist...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (groupedList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedList.length,
      itemBuilder: (context, index) {
        final chklNo = groupedList[index].key;
        final entries = groupedList[index].value;

        return _buildChecklistCard(chklNo, entries);
      },
    );
  }

  List<MapEntry<int, List<SalesChecklistModel>>> _getFilteredGroupedList() {
    var entries = _groupedEntries.entries.toList();

    // Existing search filter (by CHKLNO) — keep whatever you already have here
    if (_searchQuery.isNotEmpty) {
      entries = entries
          .where((e) => e.key.toString().contains(_searchQuery))
          .toList();
    }

    // New: status filter by CHKAPPSTATUS
    if (_selectedStatusFilter != 'All') {
      entries = entries.where((e) {
        final status = e.value.isNotEmpty ? e.value.first.chkappstatus : null;
        if (_selectedStatusFilter == 'Approved') {
          return status == 'Y';
        } else {
          // Pending = anything not 'Y' (covers null, 'N', etc.)
          return status != 'Y';
        }
      }).toList();
    }

    return entries;
  }

  Widget _buildChecklistCard(
    int chklNo,
    List<SalesChecklistModel> entries,
  ) {
    final firstEntry = entries.first;

    String formatDate(DateTime? date) {
      if (date == null) return '-';
      return DateFormat('dd-MM-yyyy').format(date);
    }

    return GestureDetector(
      onTap: () {
        // Navigate to EntryChecklistScreen with the data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EntryChecklistScreen(
              checklistData: firstEntry,
              isReadOnly: true,
            ),
          ),
        );
      },
      child: Card(
        elevation: 4,
        margin: EdgeInsets.only(bottom: UI.sectionSpacing),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(UI.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header with Icons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'ListNo: $chklNo',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  // Action Icons Row
                  Row(
                    children: [
                      // Approve Icon
                      if (firstEntry.chkappstatus != 'Y')
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              tooltip: 'Approve',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  _showApproveConfirmationDialog(chklNo),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),

                      // View Icon
                      IconButton(
                        onPressed: () {
                          // View action - just show details
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EntryChecklistScreen(
                                checklistData: firstEntry,
                                isReadOnly:
                                    true, // You'll need to add this parameter
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.visibility,
                          size: 20,
                          color: Colors.blue,
                        ),
                        tooltip: 'View',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),

                      // Edit Icon
                      IconButton(
                        onPressed: () {
                          // Edit action
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EntryChecklistScreen(
                                checklistData: firstEntry,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.edit,
                          size: 20,
                          color: Colors.orange,
                        ),
                        tooltip: 'Edit',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),

                      // Delete Icon
                      IconButton(
                        onPressed: () {
                          _showDeleteConfirmationDialog(chklNo);
                        },
                        icon: const Icon(
                          Icons.delete,
                          size: 20,
                          color: Colors.red,
                        ),
                        tooltip: 'Delete',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),

                      // Print Icon
                      IconButton(
                        onPressed: () async {
                          if (firstEntry != null && firstEntry.chklno != null) {
                            final entries = _groupedEntries[firstEntry.chklno];

                            if (entries != null && entries.isNotEmpty) {
                              await QuotationAgreementPdfService
                                  .generateAndShareChecklistPdf(
                                context: context,
                                checklistEntries: entries,
                                chklNo: firstEntry.chklno!,
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('No data found for this checklist'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(
                          Icons.print,
                          size: 20,
                          color: Colors.green,
                        ),
                        tooltip: 'Download PDF',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),

                      // Download Icon
                      IconButton(
                        onPressed: () async {
                          await ChecklistDownloadService.downloadChecklistFiles(
                            context: context,
                            chklNo: chklNo,
                            chkfname: firstEntry.chkfname,
                          );
                        },
                        icon: const Icon(Icons.download,
                            size: 20, color: Colors.purpleAccent),
                        tooltip: 'Download Attachments',
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// Client Name
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.business,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Client Name : ${firstEntry.clientname ?? '-'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              /// Enquiry Name
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_city,
                    size: 18,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enquiry Name : ${firstEntry.enqidname ?? '-'}',
                      style: const TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              /// Added User & Date
              Row(
                children: [
                  const Icon(
                    Icons.person,
                    size: 18,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Entered By : ${getEmployeeName(firstEntry.adduser)}',
                      style: const TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Entry Date : ${formatDate(firstEntry.adddate)}',
                      style: const TextStyle(
                        fontSize: 13,
                      ),
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

  Future<void> _showDeleteConfirmationDialog(int chklNo) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Checklist'),
          content: Text('Are you sure you want to delete Checklist #$chklNo?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteChecklist(chklNo);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteChecklist(int chklNo) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final requestBody = {
        "CHKLNO": chklNo,
        "DELUSER": empCode, // Add the DELUSER field with current user's empCode
      };

      print("DELETE API URL : ${ApiUtils.getUri('DeleteSalesChecklist')}");
      print("DELETE REQUEST BODY : ${jsonEncode(requestBody)}");

      final response = await http.post(
        ApiUtils.getUri('DeleteSalesChecklist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print("DELETE STATUS CODE : ${response.statusCode}");
      print("DELETE RESPONSE BODY : ${response.body}");

      final data = jsonDecode(response.body);

      if (data['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checklist deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the list
        await _fetchSaleschecklistEntries();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message'] ?? 'Failed to delete checklist'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("DELETE EXCEPTION ERROR : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting checklist: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> loadSalesEmployees() async {
    try {
      final response = await http.post(
        ApiUtils.getUri('SalesEMPCode'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          final List list = data['SalesDetails'];
          setState(() {
            salesEmployees =
                list.map((e) => SalesEmployeeModel.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading employees: $e');
    }
  }

  String getEmployeeName(int? empCode) {
    if (empCode == null) return '-';

    final employee = salesEmployees.firstWhere(
      (emp) => emp.empCode == empCode,
      orElse: () {
        return SalesEmployeeModel(empCode: empCode, empName: '');
      },
    );

    return employee.empName.isNotEmpty
        ? '$empCode - ${employee.empName}'
        : empCode.toString();
  }

  Future<void> _approveChecklist(int chklNo) async {
    try {
      final requestBody = {
        "CHKLNO": chklNo,
        "CHKAPPSTATUS": "Approved",
        "CHKAPPUSER": empCode,
        "CHKAPPDATE": DateTime.now().toIso8601String(),
      };

      print("APPROVE API URL : ${ApiUtils.getUri('ApproveSalesChecklist')}");
      print("APPROVE REQUEST BODY : ${jsonEncode(requestBody)}");

      final response = await http.post(
        ApiUtils.getUri('ApproveSalesChecklist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print("APPROVE STATUS CODE : ${response.statusCode}");
      print("APPROVE RESPONSE BODY : ${response.body}");

      final data = jsonDecode(response.body);

      if (data['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checklist #$chklNo approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchSaleschecklistEntries(); // Refresh list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message'] ?? 'Failed to approve checklist'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("APPROVE EXCEPTION ERROR : $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving checklist: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showApproveConfirmationDialog(int chklNo) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Approve Checklist'),
            ],
          ),
          content: Text(
              'Are you sure you want to approve Checklist #$chklNo?\n\nThis action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _approveChecklist(chklNo);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );
  }
}

class QuotationAgreementPdfService {
  static Future<void> generateAndShareChecklistPdf({
    required BuildContext context,
    required List<SalesChecklistModel> checklistEntries,
    required int chklNo,
  }) async {
    if (checklistEntries.isEmpty) {
      _showError(context, 'No checklist data available!');
      return;
    }

    // Get header data from first entry
    final firstEntry = checklistEntries.first;
    final clientName = firstEntry.clientname ?? 'Not specified';
    final projectName = firstEntry.enqidname ?? 'Not specified';
    final verifiedBy = firstEntry.verifiedby ?? 'Not specified';
    final reviewedBy = firstEntry.reviewedby ?? 'Not specified';

    // Create remarks map from the first entry
    final remarksMap = _createRemarksMap(firstEntry);

    final String formattedDate = _getFileSafeDateTimeFormatted();
    final String fileName =
        "${projectName.toLowerCase().replaceAll(' ', '_')}_quotation_checklist_$formattedDate.pdf";

    final pdf = pw.Document();

    final checklistItems = _getChecklistItems();

    // Build table rows manually to handle section headers properly
    final tableRows = <pw.TableRow>[];

    // Add header row
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _buildCell('S.No', isHeader: true, alignment: pw.Alignment.center),
          _buildCell('Checklist for contract signing',
              isHeader: true, alignment: pw.Alignment.center),
          _buildCell('Remarks', isHeader: true, alignment: pw.Alignment.center),
        ],
      ),
    );

    // Add data rows with section headers
    int serialNo = 1;
    for (int index = 0; index < checklistItems.length; index++) {
      final item = checklistItems[index];
      final remark = remarksMap[item] ?? '';

      // Check if this is a section header (starts with '---')
      if (item.startsWith('---')) {
        final sectionName = item.replaceAll('---', '').trim();

        // Add section header row (spans across columns)
        tableRows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.grey100),
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                alignment: pw.Alignment.center,
                child: pw.Text(''),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  sectionName,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(''),
              ),
            ],
          ),
        );
      } else {
        // Add normal row with serial number
        tableRows.add(
          pw.TableRow(
            children: [
              _buildCell('${serialNo++}', alignment: pw.Alignment.center),
              _buildCell(item),
              _buildCell(remark.isEmpty ? '' : remark),
            ],
          ),
        );
      }
    }

    // Column widths
    final columnWidths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(45), // S.No
      1: pw.FlexColumnWidth(3), // Checklist Item
      2: pw.FixedColumnWidth(200), // Remarks
    };

    // Add page to PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(15),
        footer: (pw.Context context) => _buildFooter(
          verifiedBy: verifiedBy,
          reviewedBy: reviewedBy,
          chklNo: chklNo,
          context: context,
        ),
        build: (pw.Context context) => [
          _buildTitle(),
          pw.SizedBox(height: 15),
          _buildClientInfoTable(
            clientName: clientName,
            projectName: projectName,
            verifiedBy: verifiedBy,
            reviewedBy: reviewedBy,
            chklNo: chklNo,
          ),
          pw.SizedBox(height: 15),
          pw.Table(
            columnWidths: columnWidths,
            border: pw.TableBorder.all(color: PdfColors.grey),
            children: tableRows,
          ),
        ],
      ),
    );

    // === Save & Share Logic ===
    final pdfBytes = await pdf.save();

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final uniquePath = await _getUniqueFilePath(fileName);
      if (uniquePath != null) {
        final file = File(uniquePath);
        await file.writeAsBytes(pdfBytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ PDF saved to:\n${file.path}")),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("❌ Could not access Downloads folder")),
          );
        }
      }
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      if (context.mounted) {
        await Share.shareXFiles([XFile(file.path)], text: projectName);
      }
    }
  }

  // Helper method to build a cell
  static pw.Widget _buildCell(
    String text, {
    bool isHeader = false,
    pw.Alignment alignment = pw.Alignment.centerLeft,
  }) {
    // Check if text contains new lines
    if (text.contains('\n')) {
      final lines = text.split('\n');
      final List<pw.Widget> columnChildren = [];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.isNotEmpty) {
          // Check if line contains bold markers
          if (line.contains('**')) {
            final parts = line.split('**');
            final List<pw.TextSpan> spans = [];

            for (int j = 0; j < parts.length; j++) {
              if (parts[j].isNotEmpty) {
                spans.add(
                  pw.TextSpan(
                    text: parts[j],
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: j % 2 == 1
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                );
              }
            }

            columnChildren.add(
              pw.Container(
                width: double.infinity,
                child: pw.RichText(
                  text: pw.TextSpan(children: spans),
                ),
              ),
            );
          } else {
            columnChildren.add(
              pw.Container(
                width: double.infinity,
                child: pw.Text(
                  line,
                  style: const pw.TextStyle(fontSize: 9),
                  softWrap: true,
                ),
              ),
            );
          }
        }
        // Add spacing between lines
        if (i < lines.length - 1) {
          columnChildren.add(pw.SizedBox(height: 4));
        }
      }

      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        alignment: alignment,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: columnChildren,
        ),
      );
    }

    // Check if text contains bold markers **text** (single line)
    if (text.contains('**')) {
      final parts = text.split('**');
      final List<pw.TextSpan> spans = [];

      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          spans.add(
            pw.TextSpan(
              text: parts[i],
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    i % 2 == 1 ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          );
        }
      }

      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        alignment: alignment,
        child: pw.RichText(
          text: pw.TextSpan(children: spans),
        ),
      );
    }

    // Normal text
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: alignment,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        softWrap: true,
      ),
    );
  }

  static Map<String, String> _createRemarksMap(SalesChecklistModel entry) {
    return {
      // ========== GENERIC DETAILS ==========
      '---Generic Details---': '',
      'Site address and billing address with pincodes':
          '**Site:** ${entry.siteaddress ?? ""} \n**Billing:** ${entry.billingaddress ?? ""}',
      'Client GST no.':
          '**Site:** ${entry.sitegstno ?? ""} \n**Bill:** ${entry.billinggstno ?? ""}',
      'Effective date of agreement': entry.effectivedate != null
          ? DateFormat('dd-MM-yyyy').format(entry.effectivedate!)
          : '',
      'Work order value including GST': entry.wovalueinclgst != null
          ? 'INR ${NumberFormat('#,##,##,##0', 'en_IN').format(entry.wovalueinclgst!)}'
          : '',
      'Tenure of the project': entry.projecttenure ?? '',
      'Defect liability period': entry.defliabperiod ?? '',

      // ========== BILLING DETAILS ==========
      '---Billing Details---': '',
      'Type of contract - BOQ or Lumpsum': entry.contracttype ?? '',
      'Method of billing - M3/Sqft/ no. of elements': entry.billingmethod ?? '',
      'Billing frequency and payment terms': entry.paymentterms ?? '',
      'Milestones': entry.milestones ?? '',
      'Retention': entry.retention ?? '',
      'Bank guarantee requirements': entry.bgreq ?? '',
      'Escalation and basic details': entry.escdetails ?? '',
      'Tax structure changes': entry.taxstrchanges ?? '',

      // ========== SCOPE CLEARANCE ==========
      '---Scope Clearance---': '',
      'Scope of works duly signed': entry.scopeofworksigned ?? '',
      'Waterproofing Methodology': entry.wpmethodology ?? '',
      'Anti termite work': entry.antitermitework ?? '',
      'Site access and local site issues': entry.siteaccessissues ?? '',
      'Dewatering': entry.dewatering ?? '',
      'Electricity and water': entry.electricitywater ?? '',
      'Steel and Cement brands': entry.steelcementbrands ?? '',
      'Non tendered items plus % margin': entry.nontenitemsmar ?? '',
      'Soil excavation, storage and backfilling including royalties, hardrock and soft rock issues, sheet piling - as per site condition':
          entry.soilexcdetails ?? '',
      'All statutory approvals for building': entry.buildingapp ?? '',
      'Soil investigation / survey': entry.soilinv ?? '',
      'Barrication': entry.barrication ?? '',
      'Tree cutting/ Demolition / Debris removal / EB & Utility line shifting/Open well closing':
          entry.treecuttingdem ?? '',
      'Labour accommodation': entry.labouraccom ?? '',
      'Brick work internal and external': entry.brickwork ?? '',
      'Site security': entry.sitesecurity ?? '',
      'Lighting arrangements': entry.lightingarr ?? '',

      // ========== LEGAL ASPECTS ==========
      '---Legal Aspects---': '',
      'Force majeure conditions': entry.forcemajeurecon ?? '',
      'Arbitration clause': entry.arbitrationclause ?? '',
      'Labour compliance including insurance': entry.labcomins ?? '',
      'Liquidated damages': entry.liquidateddamages ?? '',
      'Stability certificate clause': entry.stabilitycertclause ?? '',

      // ========== OTHER REMARKS ==========
      '---Other Remarks---': '',
      'Grout - Teemax approval': entry.groutteemaxapp ?? '',
      'Expansion joint requirements': entry.exjointreq ?? '',
      'Idle charges': entry.idlecharges ?? '',
      'Third party tests': entry.thirdpartytests ?? '',
    };
  }

  static pw.Widget _buildTitle() {
    return pw.Container(
      alignment: pw.Alignment.center,
      child: pw.Text(
        'QUOTATION / AGREEMENT CHECKLIST',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildClientInfoTable({
    required String clientName,
    required String projectName,
    required String verifiedBy,
    required String reviewedBy,
    required int chklNo,
  }) {
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          /*_infoRow('Checklist No:', chklNo.toString()),
          pw.SizedBox(height: 6),*/
          _infoRow('Client Name:', clientName),
          pw.SizedBox(height: 6),
          _infoRow('Project Name:', projectName),
          pw.SizedBox(height: 6),
          _infoRow('Verified By (EC No):', verifiedBy),
          pw.SizedBox(height: 6),
          _infoRow('Reviewed By (EC No):', reviewedBy),
          pw.SizedBox(height: 6),
          /*_infoRow('Date:', currentDate),*/
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 140,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value.isNotEmpty ? value : '_________________',
            style: pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter({
    required String verifiedBy,
    required String reviewedBy,
    required int chklNo,
    required pw.Context context,
  }) {
    final currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey400, width: 1),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Verified by: $verifiedBy  |  Date: $currentDate',
                style: pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Reviewed by: $reviewedBy  |  Date: $currentDate',
                style: pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<String?> _getUniqueFilePath(String fileName) async {
    try {
      final directory = await getDownloadsDirectory();
      if (directory == null) return null;

      String filePath = '${directory.path}/$fileName';
      File file = File(filePath);
      int counter = 1;

      while (await file.exists()) {
        final String nameWithoutExtension =
            fileName.substring(0, fileName.lastIndexOf('.'));
        final String extension = fileName.substring(fileName.lastIndexOf('.'));
        filePath =
            '${directory.path}/${nameWithoutExtension}_$counter$extension';
        file = File(filePath);
        counter++;
      }

      return filePath;
    } catch (e) {
      return null;
    }
  }

  static List<String> _getChecklistItems() {
    return [
      // ========== GENERIC DETAILS ==========
      '---Generic Details---',
      'Site address and billing address with pincodes',
      'Client GST no.',
      'Effective date of agreement',
      'Work order value including GST',
      'Tenure of the project',
      'Defect liability period',

      // ========== BILLING DETAILS ==========
      '---Billing Details---',
      'Type of contract - BOQ or Lumpsum',
      'Method of billing - M3/Sqft/ no. of elements',
      'Billing frequency and payment terms',
      'Milestones',
      'Retention',
      'Bank guarantee requirements',
      'Escalation and basic details',
      'Tax structure changes',

      // ========== SCOPE CLEARANCE ==========
      '---Scope Clearance---',
      'Scope of works duly signed',
      'Waterproofing Methodology',
      'Anti termite work',
      'Site access and local site issues',
      'Dewatering',
      'Electricity and water',
      'Steel and Cement brands',
      'Non tendered items plus % margin',
      'Soil excavation, storage and backfilling including royalties, hardrock and soft rock issues, sheet piling - as per site condition',
      'All statutory approvals for building',
      'Soil investigation / survey',
      'Barrication',
      'Tree cutting/ Demolition / Debris removal / EB & Utility line shifting/Open well closing',
      'Labour accommodation',
      'Brick work internal and external',
      'Site security',
      'Lighting arrangements',

      // ========== LEGAL ASPECTS ==========
      '---Legal Aspects---',
      'Force majeure conditions',
      'Arbitration clause',
      'Labour compliance including insurance',
      'Liquidated damages',
      'Stability certificate clause',

      // ========== OTHER REMARKS ==========
      '---Other Remarks---',
      'Grout - Teemax approval',
      'Expansion joint requirements',
      'Idle charges',
      'Third party tests',
    ];
  }

  static String _getFileSafeDateTimeFormatted() {
    final now = DateTime.now();
    return DateFormat('yyyyMMdd_HHmmss').format(now);
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class ChecklistDownloadService {
  // Method to get file names from your API
  static Future<Map<String, dynamic>?> _getChecklistFiles({
    required int chklNo,
  }) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('GetChecklistFiles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"CHKLNO": chklNo}),
      );

      print('GetChecklistFiles Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          return data['Data'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching files: $e');
      return null;
    }
  }

  // Main method to download files
  static Future<void> downloadChecklistFiles({
    required BuildContext context,
    required int chklNo,
    String? chkfname,
  }) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting file information...'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 1),
      ),
    );

    // Get file names if not provided
    String? fileNamesString = chkfname;

    if (fileNamesString == null || fileNamesString.trim().isEmpty) {
      final filesData = await _getChecklistFiles(chklNo: chklNo);

      if (filesData == null) {
        _showNoFilesDialog(context, chklNo);
        return;
      }

      fileNamesString = filesData['CHKFNAME'];

      if (fileNamesString == null ||
          fileNamesString.toString().trim().isEmpty) {
        _showNoFilesDialog(context, chklNo);
        return;
      }
    }

    final List<String> fileNames =
        fileNamesString.split(',').map((e) => e.trim()).toList();

    // Request storage permission for Android
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission denied'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Show download progress
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${fileNames.length} file(s)...'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );

    final List<String> success = [];
    final List<String> failed = [];

    // Download each file
    for (final fileName in fileNames) {
      try {
        await _downloadFile(fileName, chklNo);
        success.add(fileName);
        print('✓ Downloaded: $fileName');
      } catch (e) {
        failed.add(fileName);
        print('✗ Failed: $fileName - $e');
      }
    }

    // Show result
    _showDownloadResult(context, success, failed);
  }

  // Download single file using your API
  static Future<void> _downloadFile(String fileName, int chklNo) async {
    try {
      print('Original filename from DB: "$fileName"');

      final response = await http.post(
        ApiUtils.getUri('DownloadFile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"fileName": fileName}),
      );

      print('Download API Request: fileName = "$fileName"');
      print('Download API Response Status: ${response.statusCode}');
      print('Download API Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (data['Success'] == true) {
        // Get the file bytes from Base64
        String base64String = data['FileBytes'];
        Uint8List fileBytes = base64Decode(base64String);

        // Save the file
        String savePath = await _getSavePath(fileName);
        File file = File(savePath);
        await file.writeAsBytes(fileBytes);

        print('File saved to: $savePath');
      } else {
        throw Exception(data['Message'] ?? 'Download failed');
      }
    } catch (e) {
      throw Exception('Failed to download $fileName: $e');
    }
  }

  // Get save path for different platforms
  static Future<String> _getSavePath(String fileName) async {
    if (Platform.isAndroid) {
      // Android: Save to Downloads folder
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '${directory.path}/$fileName';
    } else if (Platform.isIOS) {
      // iOS: Save to Documents directory
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$fileName';
    } else if (Platform.isWindows) {
      // Windows: Save to Downloads folder
      final downloadsPath = '${Platform.environment['USERPROFILE']}\\Downloads';
      final directory = Directory(downloadsPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '$downloadsPath\\$fileName';
    } else if (Platform.isMacOS) {
      // MacOS: Save to Downloads folder
      final downloadsPath = '${Platform.environment['HOME']}/Downloads';
      final directory = Directory(downloadsPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '$downloadsPath/$fileName';
    } else {
      // Linux or other: Save to current directory
      final directory = Directory('./downloads');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '${directory.path}/$fileName';
    }
  }

  // Show dialog when no files exist
  static void _showNoFilesDialog(BuildContext context, int chklNo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('No Attachments'),
          ],
        ),
        content: Text(
          'Checklist #$chklNo has no attached files.\n\n'
          'To add files, edit the checklist and upload attachments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show download result
  static void _showDownloadResult(
    BuildContext context,
    List<String> success,
    List<String> failed,
  ) {
    if (success.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No files were downloaded'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } else if (failed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${success.length} file(s) downloaded successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OPEN FOLDER',
            onPressed: () async {
              String folderPath;
              if (Platform.isWindows) {
                folderPath =
                    '${Platform.environment['USERPROFILE']}\\Downloads';
              } else if (Platform.isAndroid) {
                folderPath = '/storage/emulated/0/Download';
              } else if (Platform.isIOS) {
                final directory = await getApplicationDocumentsDirectory();
                folderPath = directory.path;
              } else if (Platform.isMacOS) {
                folderPath = '${Platform.environment['HOME']}/Downloads';
              } else {
                folderPath = './downloads';
              }

              // Open the folder
              await OpenFile.open(folderPath);
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ ${success.length} downloaded, ${failed.length} failed: ${failed.join(", ")}',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
