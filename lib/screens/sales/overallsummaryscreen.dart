import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import '../../services/pdfgeneratorservice.dart';
import 'package:path/path.dart' as p;

class OverAllSummaryScreen extends StatefulWidget {
  const OverAllSummaryScreen({super.key});

  @override
  State<OverAllSummaryScreen> createState() => _OverAllSummaryScreenState();
}

class _OverAllSummaryScreenState extends State<OverAllSummaryScreen> {
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  TextEditingController customerController = TextEditingController();
  TextEditingController siteController = TextEditingController();
  TextEditingController _customerInternalController = TextEditingController();
  TextEditingController _siteInternalController = TextEditingController();
  List<ChecklistCustomer> customerList = [];
  List<Project> projectList = [];
  List<SalesBillingSummaryModel> summaryList = [];
  List<SalesBillingSummaryModel> allDataList = [];

  String? selectedCustomerId;
  String? selectedProjectId;
  bool isLoading = false;
  bool hasGenerated = false;
  bool _customerControllerInitialized = false;
  bool _siteControllerInitialized = false;
  bool _isDownloadingAll = false;

  @override
  void initState() {
    super.initState();
    loadCustomers();
    customerController.text = 'ALL';
    siteController.text = 'ALL';
    _customerInternalController.addListener(() => setState(() {}));
    _siteInternalController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    customerController.dispose();
    siteController.dispose();
    _customerInternalController.dispose();
    _siteInternalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indianFormat = NumberFormat('#,##,##0', 'en_IN');
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Over All Summary'),
        actions: [
          // ✅ Show download button only when data is generated
          if (hasGenerated && summaryList.isNotEmpty)
            _isDownloadingAll
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Download All Projects',
                    onPressed: _downloadAllProjects,
                  ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ///Customer Name & Project Name
              Row(
                children: [
                  Expanded(
                    child: Autocomplete<ChecklistCustomer>(
                      displayStringForOption: (option) =>
                          "${option.customerId} - ${option.companyName}",
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return customerList;
                        }
                        return customerList.where((customer) {
                          return customer.companyName.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              customer.customerId
                                  .toString()
                                  .contains(textEditingValue.text);
                        });
                      },
                      onSelected: (ChecklistCustomer selection) {
                        final text =
                            "${selection.customerId} - ${selection.companyName}";
                        customerController.text = text;
                        _customerInternalController.text = text; // ← add this

                        setState(() {
                          selectedCustomerId = selection.customerId.toString();
                          selectedProjectId = null;
                          siteController.text = 'ALL';
                          _siteInternalController.text = 'ALL'; // ← add this
                          projectList.clear();
                          hasGenerated = false;
                          summaryList.clear();
                          allDataList.clear();
                        });

                        loadProjects(selection.customerId);
                      },
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        // Set only on first build
                        if (!_customerControllerInitialized) {
                          _customerControllerInitialized = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            controller.text = customerController.text;
                            _customerInternalController.text =
                                customerController.text;
                          });
                        }

                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: "Customer Name",
                            hintText: "Search Customer",
                            border: const OutlineInputBorder(),
                            suffixIcon: _customerInternalController
                                    .text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      _customerInternalController.clear();
                                      customerController.text = 'ALL';
                                      _customerControllerInitialized =
                                          false; // ← reset flag
                                      setState(() {
                                        selectedCustomerId = null;
                                        selectedProjectId = null;
                                        siteController.text = 'ALL';
                                        _siteInternalController.text = 'ALL';
                                        _siteControllerInitialized =
                                            false; // ← reset flag
                                        projectList.clear();
                                        hasGenerated = false;
                                        summaryList.clear();
                                        allDataList.clear();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (value) {
                            _customerInternalController.text = value;
                          },
                          style: const TextStyle(
                            fontSize: 14,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Autocomplete<Project>(
                      displayStringForOption: (option) =>
                          "${option.projectId} - ${option.projectName}",
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return projectList;
                        }
                        return projectList.where((project) {
                          return project.projectName.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              project.projectId
                                  .toString()
                                  .contains(textEditingValue.text);
                        });
                      },
                      onSelected: (Project selection) {
                        final text =
                            "${selection.projectId} - ${selection.projectName}";
                        siteController.text = text;
                        _siteInternalController.text = text; // ← add this

                        setState(() {
                          selectedProjectId = selection.projectId.toString();
                        });
                      },
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        // Set only on first build
                        if (!_siteControllerInitialized) {
                          _siteControllerInitialized = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            controller.text = siteController.text;
                            _siteInternalController.text = siteController.text;
                          });
                        }

                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: "Site Name",
                            hintText: "Search Site",
                            border: const OutlineInputBorder(),
                            suffixIcon: _siteInternalController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      _siteInternalController.text = 'ALL';
                                      siteController.text = 'ALL';
                                      _siteControllerInitialized =
                                          false; // ← reset flag
                                      setState(() {
                                        selectedProjectId = null;
                                        if (hasGenerated &&
                                            allDataList.isNotEmpty) {
                                          summaryList = List.from(allDataList);
                                        }
                                      });
                                    },
                                  )
                                : null,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (value) {
                            _siteInternalController.text = value;
                          },
                          style: const TextStyle(
                            fontSize: 14,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: null,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ///Generate Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 5,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: isLoading
                            ? null
                            : () async {
                                await getSalesBillingSummary();
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Center(
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    'Generate',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ///Summary Table - Only show if Generate was clicked
              if (hasGenerated && summaryList.isNotEmpty)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: isAndroid
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildSummaryDataTable(indianFormat),
                          )
                        : _buildSummaryDataTable(indianFormat),
                  ),
                )
              else if (hasGenerated &&
                  !isLoading &&
                  summaryList.isEmpty &&
                  allDataList.isNotEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No data found for the selected project',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryDataTable(NumberFormat indianFormat) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(
        AppColors.primary.withOpacity(0.1),
      ),
      columns: const [
        DataColumn(
            label: Text('S.No', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Project Name',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Total value',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label:
                Text('Billed', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Net amount received',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Outstanding',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label:
                Text('Print', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: summaryList.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return DataRow(
          cells: [
            DataCell(Text('${index + 1}')),
            DataCell(
              _ProjectNameCell(
                projectName: item.projectName ?? '',
                onTap: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                  try {
                    final bills = await _fetchBillsForProject(item.projectId!);
                    await _showProjectDetailsDialog(item, indianFormat, bills);
                  } catch (e) {
                    debugPrint('Error: $e');
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            DataCell(Text(indianFormat.format(item.woValueInclGst ?? 0))),
            DataCell(Text(indianFormat.format(item.billed ?? 0))),
            DataCell(Text(indianFormat.format(item.recamnt ?? 0))),
            DataCell(Text(indianFormat.format(item.balanceAmnt ?? 0))),
            DataCell(
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () async {
                  final bills = await _fetchBillsForProject(item.projectId!);
                  await _printSingleRow(item, indianFormat, bills);
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String? extractProjectIdFromProjectName(String projectName) {
    if (projectName.isEmpty) return null;
    // Extract first number from the beginning of the string
    RegExp regex = RegExp(r'^(\d+)');
    Match? match = regex.firstMatch(projectName);
    return match?.group(1);
  }

  Future<void> loadProjects(int customerId) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('ProjectDetails'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"CUSTOMERID": customerId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          final List list = data['ProjectDetails'];
          setState(() {
            projectList = list.map((e) => Project.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> loadCustomers() async {
    try {
      final response =
          await http.post(ApiUtils.getUri('ExistingChecklistCustomers'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          final List list = data['CustomerDetails'];
          setState(() {
            customerList =
                list.map((e) => ChecklistCustomer.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> getSalesBillingSummary() async {
    setState(() {
      isLoading = true;
      summaryList.clear();
    });

    try {
      final response = await http.post(
        ApiUtils.getUri('GetSalesBillingSummary'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ Debug: Print the first item from API response
        if (data['Success'] == true &&
            data['Data'] != null &&
            data['Data'].isNotEmpty) {
          debugPrint('===== First API Response Item =====');
          debugPrint('${data['Data'][0]}');
          debugPrint(
              'PROJECTCODE in first item: ${data['Data'][0]['PROJECTCODE']}');
        }

        if (data['Success'] == true) {
          List<SalesBillingSummaryModel> allData =
              (data['Data'] as List).map((e) {
            // ✅ Debug each item as it's being parsed
            debugPrint(
                'Parsing item: ${e['PROJECTNAME']} - Code: ${e['PROJECTCODE']}');
            return SalesBillingSummaryModel.fromJson(e);
          }).toList();

          debugPrint('Total records received from API: ${allData.length}');

          // ✅ Check if project codes are populated
          for (int i = 0; i < allData.length && i < 3; i++) {
            debugPrint(
                'Project ${i + 1}: ${allData[i].projectName} - Code: ${allData[i].projectCode}');
          }

          setState(() {
            allDataList = allData;
            if (selectedProjectId != null && selectedProjectId != 'ALL') {
              List<SalesBillingSummaryModel> filtered = allData.where((item) {
                String? itemProjectId =
                    extractProjectIdFromProjectName(item.projectName);
                return itemProjectId == selectedProjectId;
              }).toList();
              summaryList = filtered;
            } else {
              summaryList = List.from(allData);
            }
            hasGenerated = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _printSingleRow(
    SalesBillingSummaryModel item,
    NumberFormat indianFormat,
    List<SalesBillingModel> billRows,
  ) async {
    debugPrint('===== _printSingleRow START =====');
    debugPrint('Project ID: ${item.projectId}');
    debugPrint('Project Name: ${item.projectName}');
    debugPrint('Project Code: ${item.projectCode}');
    debugPrint('Customer ID: ${item.customerId}');
    debugPrint('Bill Rows count: ${billRows.length}');

    if (item.projectId == null) {
      debugPrint('ERROR: Project ID is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final pdf = pw.Document();

    final String formattedDate = getFileSafeDateTimeFormatted();
    final String fileName =
        "${item.projectName?.replaceAll(' ', '_') ?? 'project'}_summary_$formattedDate.pdf";
    debugPrint('Generated fileName: $fileName');

    String customerName = '';
    debugPrint('Resolving customer name...');

    if (billRows.isNotEmpty && billRows.first.cusid != null) {
      debugPrint(
          'Getting customer from billRows first item, cusid: ${billRows.first.cusid}');
      final matchedCustomer = customerList.firstWhere(
        (c) => c.customerId == billRows.first.cusid,
        orElse: () {
          debugPrint('Customer not found in customerList, returning default');
          return ChecklistCustomer(customerId: 0, companyName: '');
        },
      );
      customerName = matchedCustomer.companyName;
      debugPrint('Customer name from billRows: $customerName');
    }

    if (customerName.isEmpty && item.customerId != null) {
      debugPrint('Getting customer from item.customerId: ${item.customerId}');
      final matchedCustomer = customerList.firstWhere(
        (c) => c.customerId == item.customerId,
        orElse: () {
          debugPrint('Customer not found in customerList, returning default');
          return ChecklistCustomer(customerId: 0, companyName: '');
        },
      );
      customerName = matchedCustomer.companyName;
      debugPrint('Customer name from item: $customerName');
    }

    if (customerName.isEmpty &&
        customerController.text.isNotEmpty &&
        customerController.text.toUpperCase() != 'ALL') {
      debugPrint(
          'Getting customer from customerController.text: ${customerController.text}');
      final parts = customerController.text.split(' - ');
      customerName = parts.length > 1
          ? parts.sublist(1).join(' - ')
          : customerController.text;
      debugPrint('Customer name from controller: $customerName');
    }

    debugPrint('Final customerName: $customerName');

    final headers = [
      'Bill No',
      'Date',
      'Description',
      'Amount',
      'GST',
      'Total Bill Amt',
      'IT',
      'Retn',
      'Other Ded/Mat',
      'Total Ded',
      'Net Rec.',
      'Net Amt Rec.',
      'Date',
      'Outstanding',
    ];

    final List<List<String>> data = [];
    debugPrint('Building data rows for ${billRows.length} bills...');

    for (int i = 0; i < billRows.length; i++) {
      final bill = billRows[i];
      debugPrint(
          'Processing bill ${i + 1}/${billRows.length}: Bill No: ${bill.billno}');

      final totalDeduction = (bill.itamnt ?? 0) +
          (bill.retnamnt ?? 0) +
          (bill.whamnt ?? 0) +
          (bill.dedamnt ?? 0);
      final netReceivable = (bill.billtotamnt ?? 0) - totalDeduction;
      final outstanding = netReceivable - (bill.recamnt ?? 0);

      data.add([
        bill.billno ?? '',
        bill.billdate != null
            ? _formatDate(bill.billdate, includeTime: false)
            : '',
        bill.billdesc ?? '',
        indianFormat.format(bill.billamnt ?? 0),
        indianFormat.format(bill.gstamnt ?? 0),
        indianFormat.format(bill.billtotamnt ?? 0),
        indianFormat.format(bill.itamnt ?? 0),
        indianFormat.format(bill.retnamnt ?? 0),
        indianFormat.format(bill.dedamnt ?? 0),
        indianFormat.format(totalDeduction),
        indianFormat.format(netReceivable),
        indianFormat.format(bill.recamnt ?? 0),
        bill.recdate != null
            ? _formatDate(bill.recdate, includeTime: false)
            : '',
        indianFormat.format(outstanding),
      ]);
    }

    // Totals row
    debugPrint('Adding totals row...');
    final totalBillAmount = billRows.fold(0.0, (s, b) => s + (b.billamnt ?? 0));
    final totalGST = billRows.fold(0.0, (s, b) => s + (b.gstamnt ?? 0));
    final totalIT = billRows.fold(0.0, (s, b) => s + (b.itamnt ?? 0));
    final totalRetn = billRows.fold(0.0, (s, b) => s + (b.retnamnt ?? 0));
    final totalDed = billRows.fold(0.0, (s, b) => s + (b.dedamnt ?? 0));
    final totalAllDeductions = billRows.fold(
        0.0,
        (s, b) =>
            s +
            (b.itamnt ?? 0) +
            (b.retnamnt ?? 0) +
            (b.whamnt ?? 0) +
            (b.dedamnt ?? 0));

    final List<String> totalRow = [
      '',
      '',
      'Total',
      indianFormat.format(totalBillAmount),
      indianFormat.format(totalGST),
      indianFormat.format(item.billed),
      indianFormat.format(totalIT),
      indianFormat.format(totalRetn),
      indianFormat.format(totalDed),
      indianFormat.format(totalAllDeductions),
      indianFormat.format(item.billed - totalAllDeductions),
      indianFormat.format(item.recamnt ?? 0),
      '',
      indianFormat.format(item.balanceAmnt),
    ];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(8),
        build: (context) {
          // Build table rows with custom styling for total row
          final tableRows = <pw.TableRow>[];

          // Add header row
          tableRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green200),
              children: headers.map((header) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    header,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                );
              }).toList(),
            ),
          );

          // Add data rows
          for (var row in data) {
            tableRows.add(
              pw.TableRow(
                children: [
                  // Bill No
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[0],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center),
                  ),
                  // Date
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[1],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center),
                  ),
                  // Description
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[2],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.left),
                  ),
                  // Amount
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[3],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right),
                  ),
                  // GST
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[4],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right),
                  ),
                  // Total Bill Amt
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[5],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right),
                  ),
                  // IT
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[6],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right),
                  ),
                  // Retn
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[7],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right),
                  ),
                  // Other Ded/Mat
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[8],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right),
                  ),
                  // Total Ded
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[9],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right),
                  ),
                  // Net Rec.
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[10],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right),
                  ),
                  // Net Amt Rec.
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[11],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right),
                  ),
                  // Date
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[12],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center),
                  ),
                  // Outstanding
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[13],
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
            );
          }

          // Add total row with background color
          tableRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(
                  color: PdfColors.green100), // Light green background
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[0],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[1],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[2],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.left),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[3],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[4],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[5],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[6],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[7],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[8],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[9],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[10],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[11],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[12],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalRow[13],
                      style: pw.TextStyle(
                          fontSize: 8, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right),
                ),
              ],
            ),
          );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300)),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Project Name and Project Code on the SAME ROW
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: 90,
                          child: pw.Text('Project',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        pw.Expanded(
                          child: pw.Text(item.projectName ?? '-',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        pw.Text('Proj.Code: ',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(item.projectCode ?? '-',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: 90,
                          child: pw.Text('Customer',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                              customerName.isNotEmpty ? customerName : '-',
                              style: const pw.TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 90,
                          child: pw.Text('Value',
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(
                              indianFormat.format(item.woValueInclGst / 1.18),
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Text('Exclusive of GST 18%',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.SizedBox(width: 90),
                        pw.SizedBox(
                          width: 100,
                          child: pw.Text(
                              indianFormat.format(item.woValueInclGst),
                              style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Text('Inclusive of GST 18%',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey),
                children: tableRows,
              ),
            ],
          );
        },
      ),
    );

    debugPrint('Saving PDF...');
    final pdfBytes = await pdf.save();
    debugPrint('PDF saved, size: ${pdfBytes.length} bytes');

    if (kIsWeb) {
      debugPrint('Platform: Web - downloading PDF');
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ PDF saved to:\n$fileName")),
      );
      debugPrint('PDF download triggered for web');
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint(
          'Platform: Desktop (${Platform.operatingSystem}) - saving to downloads');
      final uniquePath = await getUniqueFilePath(fileName);
      if (uniquePath != null) {
        final file = File(uniquePath);
        await file.writeAsBytes(pdfBytes);
        debugPrint('PDF saved to: ${file.path}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ PDF saved to:\n${file.path}")),
        );
      } else {
        debugPrint('ERROR: Could not access Downloads folder');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Could not access Downloads folder")),
        );
      }
    } else {
      debugPrint(
          'Platform: Mobile (${Platform.operatingSystem}) - sharing PDF');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      debugPrint('PDF saved temporarily at: ${file.path}');
      await Share.shareXFiles([XFile(file.path)],
          text: "Project Summary Report");
      debugPrint('Share dialog opened');
    }

    debugPrint('===== _printSingleRow END =====');
  }

  Future<String?> getUniqueFilePath(String fileName) async {
    final downloadsDir = await getDownloadsFolder();
    if (downloadsDir == null) return null;

    final ncrDir =
        Directory(p.join(downloadsDir.path, "Over all summary report"));
    if (!(await ncrDir.exists())) {
      await ncrDir.create(recursive: true);
    }

    final nameWithoutExt = fileName.replaceAll(RegExp(r'\.pdf$'), '');
    String fullPath = p.join(ncrDir.path, fileName);
    int counter = 1;

    while (await File(fullPath).exists()) {
      fullPath = p.join(ncrDir.path, '${nameWithoutExt}($counter).pdf');
      counter++;
    }

    return fullPath;
  }

  Future<Directory?> getDownloadsFolder() async {
    if (Platform.isWindows) {
      // Windows default Downloads
      final userProfile = Platform.environment['USERPROFILE'];
      return Directory('$userProfile\\Downloads');
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      return Directory('$home/Downloads');
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Use the downloads_path_provider_28 plugin here
      //return await DownloadsPathProvider.downloadsDirectory;
    }
    return null;
  }

  Future<List<SalesBillingModel>> _fetchBillsForProject(int projectId) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('GetSalesBillingByProject'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "PROJID": projectId,
          "CUSTOMERID": selectedCustomerId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          final List list = data['Data'];
          return list.map((e) => SalesBillingModel.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching bills: $e');
      return [];
    }
  }

  String _formatDate(dynamic date, {bool includeTime = false}) {
    if (date == null) return '';
    DateTime? dt;
    if (date is DateTime) {
      dt = date;
    } else {
      dt = DateTime.tryParse(date.toString());
    }
    if (dt == null) return '';
    return includeTime
        ? DateFormat('dd/MM/yyyy hh:mm a').format(dt)
        : DateFormat('dd/MM/yyyy').format(dt);
  }

  Future<void> _downloadAllProjects() async {
    setState(() => _isDownloadingAll = true);

    try {
      final indianFormat = NumberFormat('#,##,##0', 'en_IN');
      final pdf = pw.Document();

      // Create table data without Print column
      final headers = [
        'S.No',
        'Project Name',
        'Total Bill Amount',
        'Billed',
        'Net Amount Received',
        'Outstanding',
      ];

      final List<List<String>> data = [];

      for (int i = 0; i < summaryList.length; i++) {
        final item = summaryList[i];
        data.add([
          (i + 1).toString(),
          item.projectName ?? '',
          indianFormat.format(item.woValueInclGst ?? 0),
          indianFormat.format(item.billed ?? 0),
          indianFormat.format(item.recamnt ?? 0),
          indianFormat.format(item.balanceAmnt ?? 0),
        ]);
      }

      // Calculate totals
      final totalBillAmount = summaryList.fold(
          0.0, (sum, item) => sum + (item.woValueInclGst ?? 0));
      final totalBilled =
          summaryList.fold(0.0, (sum, item) => sum + (item.billed ?? 0));
      final totalReceived =
          summaryList.fold(0.0, (sum, item) => sum + (item.recamnt ?? 0));
      final totalOutstanding =
          summaryList.fold(0.0, (sum, item) => sum + (item.balanceAmnt ?? 0));

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (context) {
            // Build table rows with custom styling
            final tableRows = <pw.TableRow>[];

            // Add header row
            tableRows.add(
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green200),
                children: headers.map((header) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      header,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
            );

            // Add data rows
            for (var row in data) {
              tableRows.add(
                pw.TableRow(
                  children: [
                    // S.No
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(row[0],
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.center),
                    ),
                    // Project Name
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(row[1],
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.left),
                    ),
                    // Total Bill Amount
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(row[2],
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right),
                    ),
                    // Billed
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(row[3],
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right),
                    ),
                    // Net Amount Received
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(row[4],
                          style: const pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right),
                    ),
                    // Outstanding
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(row[5],
                          style: pw.TextStyle(fontSize: 9),
                          textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              );
            }

            // Add Total row with same header background color
            tableRows.add(
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                    color: PdfColors.green200), // ✅ Same as header
                children: [
                  // S.No - empty
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('',
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.center),
                  ),
                  // Total label
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  // Total Bill Amount
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      indianFormat.format(totalBillAmount),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  // Total Billed
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      indianFormat.format(totalBilled),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  // Total Received
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      indianFormat.format(totalReceived),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  // Total Outstanding
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      indianFormat.format(totalOutstanding),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            );

            return pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Main content that will be pushed up
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.all(12),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            'Overall Summary Report',
                            style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Generated on: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                            style: pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey600),
                          ),
                          pw.SizedBox(height: 4),
                          if (selectedCustomerId != null &&
                              selectedCustomerId != 'ALL')
                            pw.Text(
                              'Customer: ${customerController.text}',
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          if (selectedProjectId != null &&
                              selectedProjectId != 'ALL')
                            pw.Text(
                              'Project: ${siteController.text}',
                              style: pw.TextStyle(fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),

                    // Table
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey),
                      children: tableRows,
                    ),

                    pw.SizedBox(height: 20),
                  ],
                ),

                // Spacer to push footer to bottom of page
                pw.Expanded(child: pw.SizedBox.shrink()),

                // Footer with Page Number at bottom of page
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Page ${context.pageNumber} of ${context.pagesCount}',
                      style:
                          pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final String formattedDate =
          DateFormat('dd-MM-yyyy_HH-mm-ss').format(DateTime.now());
      final String fileName = 'Overall_Summary_Report_$formattedDate.pdf';

      // Save and share based on platform
      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ PDF saved: $fileName")),
          );
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final uniquePath = await getUniqueFilePath(fileName);
        if (uniquePath != null) {
          final file = File(uniquePath);
          await file.writeAsBytes(pdfBytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("✅ PDF saved to:\n${file.path}")),
            );
          }
        } else {
          if (mounted) {
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
        if (mounted) {
          await Share.shareXFiles([XFile(file.path)],
              text: "Overall Summary Report");
        }
      }

      debugPrint(
          '✅ Successfully downloaded summary report with ${summaryList.length} projects');
    } catch (e) {
      debugPrint('Error downloading summary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingAll = false);
    }
  }

  Future<void> _showProjectDetailsDialog(
    SalesBillingSummaryModel item,
    NumberFormat indianFormat,
    List<SalesBillingModel> billRows,
  ) async {
    if (!mounted) return;
    Navigator.pop(context);

    String customerName = '';
    if (billRows.isNotEmpty && billRows.first.cusid != null) {
      final matchedCustomer = customerList.firstWhere(
        (c) => c.customerId == billRows.first.cusid,
        orElse: () => ChecklistCustomer(customerId: 0, companyName: ''),
      );
      customerName = matchedCustomer.companyName;
    }
    if (customerName.isEmpty && item.customerId != null) {
      final matchedCustomer = customerList.firstWhere(
        (c) => c.customerId == item.customerId,
        orElse: () => ChecklistCustomer(customerId: 0, companyName: ''),
      );
      customerName = matchedCustomer.companyName;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Enhanced Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Project icon badge
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.folder_open_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.projectName ?? 'Project Details',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.business,
                                      color: Colors.white60, size: 14),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      customerName.isNotEmpty
                                          ? customerName
                                          : 'N/A',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.projectCode != null) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.tag,
                                        color: Colors.white54, size: 13),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.projectCode!,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Close Button
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70, size: 22),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Stats + PDF button row
                    Row(
                      children: [
                        // Total chip
                        Expanded(
                          child: _headerStatChip(
                            icon: Icons.receipt_long_rounded,
                            label: 'Total Value',
                            value:
                                indianFormat.format(item.woValueInclGst ?? 0),
                            valueColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Outstanding chip
                        Expanded(
                          child: _headerStatChip(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Outstanding',
                            value: indianFormat.format(item.balanceAmnt ?? 0),
                            valueColor: (item.balanceAmnt ?? 0) > 0
                                ? Colors.orange.shade200
                                : Colors.green.shade300,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // PDF Button
                        ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _printSingleRow(item, indianFormat, billRows);
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded,
                              size: 18),
                          label: const Text(
                            'PDF',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Table ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child:
                      _buildProjectDetailsTable(item, indianFormat, billRows),
                ),
              ),

              // ── Footer ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt,
                            size: 15, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          '${billRows.length} Bills',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Generated ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white60, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
                Text(value,
                    style: TextStyle(
                        color: valueColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDetailsTable(
    SalesBillingSummaryModel item,
    NumberFormat indianFormat,
    List<SalesBillingModel> billRows,
  ) {
    final headers = [
      'Bill No',
      'Date',
      'Description',
      'Amount',
      'GST',
      'Total Value',
      'IT',
      'Retention',
      'Other Deduction/Material',
      'Total Deduction',
      'Net Receivable',
      'Net Amount Received',
      'Date',
      'Outstanding',
    ];

    final totalBillAmount = billRows.fold(0.0, (s, b) => s + (b.billamnt ?? 0));
    final totalGST = billRows.fold(0.0, (s, b) => s + (b.gstamnt ?? 0));
    final totalIT = billRows.fold(0.0, (s, b) => s + (b.itamnt ?? 0));
    final totalRetn = billRows.fold(0.0, (s, b) => s + (b.retnamnt ?? 0));
    final totalDed = billRows.fold(0.0, (s, b) => s + (b.dedamnt ?? 0));
    final totalAllDeductions = billRows.fold(
      0.0,
      (s, b) =>
          s +
          (b.itamnt ?? 0) +
          (b.retnamnt ?? 0) +
          (b.whamnt ?? 0) +
          (b.dedamnt ?? 0),
    );

    // ── font sizes ──
    const double headerFs = 12.5;
    const double cellFs = 12.0;
    const double totalFs = 13.0;

    DataCell _numCell(String text, {Color? color, bool bold = false}) =>
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: cellFs,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        );

    DataCell _totalNumCell(String text, {Color? color}) => DataCell(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              text,
              style: TextStyle(
                fontSize: totalFs,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.blueGrey.shade800,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        );

    DataCell _emptyCell() => DataCell(
          const SizedBox.shrink(),
        );

    return Card(
      margin: const EdgeInsets.all(6),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppColors.primary.withOpacity(0.10),
              ),
              headingRowHeight: 48,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 52,
              columnSpacing: 18,
              horizontalMargin: 12,
              dividerThickness: 0.6,
              border: TableBorder(
                horizontalInside:
                    BorderSide(color: Colors.grey.shade200, width: 0.8),
                verticalInside:
                    BorderSide(color: Colors.grey.shade200, width: 0.6),
                top: BorderSide(color: Colors.grey.shade300, width: 1),
                bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                left: BorderSide(color: Colors.grey.shade300, width: 1),
                right: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              columns: headers
                  .map((h) => DataColumn(
                        label: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 2),
                          child: Text(
                            h,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: headerFs,
                              color: AppColors.primary,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ))
                  .toList(),
              rows: [
                // ── Data rows ──
                ...billRows.asMap().entries.map((entry) {
                  final index = entry.key;
                  final bill = entry.value;

                  final totalDeduction = (bill.itamnt ?? 0) +
                      (bill.retnamnt ?? 0) +
                      (bill.whamnt ?? 0) +
                      (bill.dedamnt ?? 0);
                  final netReceivable =
                      (bill.billtotamnt ?? 0) - totalDeduction;
                  final outstanding = netReceivable - (bill.recamnt ?? 0);

                  return DataRow(
                    color: WidgetStateProperty.all(
                      index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFF),
                    ),
                    cells: [
                      // Bill No
                      DataCell(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(bill.billno ?? '',
                            style: TextStyle(
                                fontSize: cellFs,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      )),
                      // Date
                      DataCell(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          bill.billdate != null
                              ? _formatDate(bill.billdate, includeTime: false)
                              : '—',
                          style: TextStyle(
                              fontSize: cellFs, color: Colors.grey.shade700),
                        ),
                      )),
                      // Description
                      DataCell(Container(
                        constraints: const BoxConstraints(maxWidth: 180),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(bill.billdesc ?? '',
                            style: TextStyle(fontSize: cellFs),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      )),
                      _numCell(indianFormat.format(bill.billamnt ?? 0),
                          bold: true),
                      _numCell(indianFormat.format(bill.gstamnt ?? 0)),
                      _numCell(indianFormat.format(bill.billtotamnt ?? 0),
                          color: Colors.blueGrey.shade700, bold: true),
                      _numCell(indianFormat.format(bill.itamnt ?? 0)),
                      _numCell(indianFormat.format(bill.retnamnt ?? 0)),
                      _numCell(indianFormat.format(bill.dedamnt ?? 0)),
                      _numCell(indianFormat.format(totalDeduction),
                          color: Colors.red.shade600, bold: true),
                      _numCell(indianFormat.format(netReceivable), bold: true),
                      _numCell(indianFormat.format(bill.recamnt ?? 0),
                          color: Colors.green.shade700, bold: true),
                      // Receipt date
                      DataCell(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          bill.recdate != null
                              ? _formatDate(bill.recdate, includeTime: false)
                              : '—',
                          style: TextStyle(
                              fontSize: cellFs, color: Colors.grey.shade700),
                        ),
                      )),
                      // Outstanding
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 6),
                        decoration: outstanding > 0
                            ? BoxDecoration(
                                color: Colors.deepOrange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              )
                            : null,
                        child: Text(
                          indianFormat.format(outstanding),
                          style: TextStyle(
                            fontSize: cellFs,
                            fontWeight: FontWeight.w700,
                            color: outstanding > 0
                                ? Colors.deepOrange.shade700
                                : Colors.green.shade700,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      )),
                    ],
                  );
                }),

                // ── Totals row ──
                DataRow(
                  color: WidgetStateProperty.all(Colors.indigo.shade50),
                  cells: [
                    _emptyCell(),
                    _emptyCell(),
                    // TOTAL label
                    DataCell(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.functions_rounded,
                                size: 16, color: Colors.indigo.shade700),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.indigo.shade800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    )),
                    _totalNumCell(indianFormat.format(totalBillAmount)),
                    _totalNumCell(indianFormat.format(totalGST)),
                    _totalNumCell(indianFormat.format(item.billed ?? 0),
                        color: Colors.blue.shade800),
                    _totalNumCell(indianFormat.format(totalIT)),
                    _totalNumCell(indianFormat.format(totalRetn)),
                    _totalNumCell(indianFormat.format(totalDed)),
                    _totalNumCell(indianFormat.format(totalAllDeductions),
                        color: Colors.red.shade700),
                    _totalNumCell(indianFormat
                        .format((item.billed ?? 0) - totalAllDeductions)),
                    _totalNumCell(indianFormat.format(item.recamnt ?? 0),
                        color: Colors.green.shade800),
                    _emptyCell(),
                    _totalNumCell(indianFormat.format(item.balanceAmnt ?? 0),
                        color: (item.balanceAmnt ?? 0) > 0
                            ? Colors.deepOrange.shade700
                            : Colors.green.shade700),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectNameCell extends StatefulWidget {
  final String projectName;
  final VoidCallback onTap;

  const _ProjectNameCell({
    required this.projectName,
    required this.onTap,
  });

  @override
  State<_ProjectNameCell> createState() => _ProjectNameCellState();
}

class _ProjectNameCellState extends State<_ProjectNameCell>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _hovering
                ? AppColors.primary.withOpacity(0.08)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _hovering ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Folder icon that "opens" on hover
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  _hovering ? Icons.folder_open_rounded : Icons.folder_rounded,
                  key: ValueKey(_hovering),
                  size: 16,
                  color: _hovering
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 6),
              // Name with animated underline + color shift
              Flexible(
                child: Text(
                  widget.projectName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        _hovering ? AppColors.primaryDark : AppColors.primary,
                    fontWeight: _hovering ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.5,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Arrow that slides in on hover instead of a static underline
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _hovering ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 150),
                  offset: _hovering ? Offset.zero : const Offset(-0.3, 0),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/*import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import '../../services/pdfgeneratorservice.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncPdf; // Added prefix

class OverAllSummaryScreen extends StatefulWidget {
  const OverAllSummaryScreen({super.key});

  @override
  State<OverAllSummaryScreen> createState() => _OverAllSummaryScreenState();
}

class _OverAllSummaryScreenState extends State<OverAllSummaryScreen> {
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  TextEditingController customerController = TextEditingController();
  TextEditingController siteController = TextEditingController();
  TextEditingController _customerInternalController = TextEditingController();
  TextEditingController _siteInternalController = TextEditingController();
  List<ChecklistCustomer> customerList = [];
  List<Project> projectList = [];
  List<SalesBillingSummaryModel> summaryList = [];
  List<SalesBillingSummaryModel> allDataList = [];

  String? selectedCustomerId;
  String? selectedProjectId;
  bool isLoading = false;
  bool hasGenerated = false;
  bool _customerControllerInitialized = false;
  bool _siteControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    loadCustomers();
    customerController.text = 'ALL';
    siteController.text = 'ALL';
    _customerInternalController.addListener(() => setState(() {}));
    _siteInternalController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    customerController.dispose();
    siteController.dispose();
    _customerInternalController.dispose();
    _siteInternalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indianFormat = NumberFormat('#,##,##0', 'en_IN');
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Over All Summary'),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ///Customer Name & Project Name
              Row(
                children: [
                  Expanded(
                    child: Autocomplete<ChecklistCustomer>(
                      displayStringForOption: (option) =>
                          "${option.customerId} - ${option.companyName}",
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return customerList;
                        }
                        return customerList.where((customer) {
                          return customer.companyName.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              customer.customerId
                                  .toString()
                                  .contains(textEditingValue.text);
                        });
                      },
                      onSelected: (ChecklistCustomer selection) {
                        final text =
                            "${selection.customerId} - ${selection.companyName}";
                        customerController.text = text;
                        _customerInternalController.text = text;

                        setState(() {
                          selectedCustomerId = selection.customerId.toString();
                          selectedProjectId = null;
                          siteController.text = 'ALL';
                          _siteInternalController.text = 'ALL';
                          projectList.clear();
                          hasGenerated = false;
                          summaryList.clear();
                          allDataList.clear();
                        });

                        loadProjects(selection.customerId);
                      },
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        if (!_customerControllerInitialized) {
                          _customerControllerInitialized = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            controller.text = customerController.text;
                            _customerInternalController.text =
                                customerController.text;
                          });
                        }

                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: "Customer Name",
                            hintText: "Search Customer",
                            border: const OutlineInputBorder(),
                            suffixIcon: _customerInternalController
                                    .text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      _customerInternalController.clear();
                                      customerController.text = 'ALL';
                                      _customerControllerInitialized = false;
                                      setState(() {
                                        selectedCustomerId = null;
                                        selectedProjectId = null;
                                        siteController.text = 'ALL';
                                        _siteInternalController.text = 'ALL';
                                        _siteControllerInitialized = false;
                                        projectList.clear();
                                        hasGenerated = false;
                                        summaryList.clear();
                                        allDataList.clear();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (value) {
                            _customerInternalController.text = value;
                          },
                          style: const TextStyle(
                            fontSize: 14,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Autocomplete<Project>(
                      displayStringForOption: (option) =>
                          "${option.projectId} - ${option.projectName}",
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return projectList;
                        }
                        return projectList.where((project) {
                          return project.projectName.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              project.projectId
                                  .toString()
                                  .contains(textEditingValue.text);
                        });
                      },
                      onSelected: (Project selection) {
                        final text =
                            "${selection.projectId} - ${selection.projectName}";
                        siteController.text = text;
                        _siteInternalController.text = text;

                        setState(() {
                          selectedProjectId = selection.projectId.toString();
                        });
                      },
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        if (!_siteControllerInitialized) {
                          _siteControllerInitialized = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            controller.text = siteController.text;
                            _siteInternalController.text = siteController.text;
                          });
                        }

                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: "Site Name",
                            hintText: "Search Site",
                            border: const OutlineInputBorder(),
                            suffixIcon: _siteInternalController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      _siteInternalController.text = 'ALL';
                                      siteController.text = 'ALL';
                                      _siteControllerInitialized = false;
                                      setState(() {
                                        selectedProjectId = null;
                                        if (hasGenerated &&
                                            allDataList.isNotEmpty) {
                                          summaryList = List.from(allDataList);
                                        }
                                      });
                                    },
                                  )
                                : null,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (value) {
                            _siteInternalController.text = value;
                          },
                          style: const TextStyle(
                            fontSize: 14,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: null,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ///Generate Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 5,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: isLoading
                            ? null
                            : () async {
                                await getSalesBillingSummary();
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Center(
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    'Generate',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ///Summary Table - Only show if Generate was clicked
              if (hasGenerated && summaryList.isNotEmpty)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: isAndroid
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildSummaryDataTable(indianFormat),
                          )
                        : _buildSummaryDataTable(indianFormat),
                  ),
                )
              else if (hasGenerated &&
                  !isLoading &&
                  summaryList.isEmpty &&
                  allDataList.isNotEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No data found for the selected project',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryDataTable(NumberFormat indianFormat) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(
        AppColors.primary.withOpacity(0.1),
      ),
      columns: const [
        DataColumn(
            label: Text('S.No', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Project Name',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Total bill amount',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label:
                Text('Billed', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Net amount received',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Outstanding',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label:
                Text('Print', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: summaryList.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return DataRow(
          cells: [
            DataCell(Text('${index + 1}')),
            DataCell(Text(item.projectName ?? '')),
            DataCell(Text(indianFormat.format(item.woValueInclGst ?? 0))),
            DataCell(Text(indianFormat.format(item.billed ?? 0))),
            DataCell(Text(indianFormat.format(item.recamnt ?? 0))),
            DataCell(Text(indianFormat.format(item.balanceAmnt ?? 0))),
            DataCell(
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () async {
                  final bills = await _fetchBillsForProject(item.projectId!);
                  await _printSingleRow(item, indianFormat, bills);
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String? extractProjectIdFromProjectName(String projectName) {
    if (projectName.isEmpty) return null;
    RegExp regex = RegExp(r'^(\d+)');
    Match? match = regex.firstMatch(projectName);
    return match?.group(1);
  }

  Future<void> loadProjects(int customerId) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('ProjectDetails'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"CUSTOMERID": customerId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          final List list = data['ProjectDetails'];
          setState(() {
            projectList = list.map((e) => Project.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> loadCustomers() async {
    try {
      final response =
          await http.post(ApiUtils.getUri('ExistingChecklistCustomers'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          final List list = data['CustomerDetails'];
          setState(() {
            customerList =
                list.map((e) => ChecklistCustomer.fromJson(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> getSalesBillingSummary() async {
    setState(() {
      isLoading = true;
      summaryList.clear();
    });

    try {
      final response = await http.post(
        ApiUtils.getUri('GetSalesBillingSummary'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true) {
          List<SalesBillingSummaryModel> allData = (data['Data'] as List)
              .map((e) => SalesBillingSummaryModel.fromJson(e))
              .toList();

          debugPrint('Total records received from API: ${allData.length}');

          for (int i = 0; i < allData.length && i < 3; i++) {
            debugPrint('Project ${i + 1}: ${allData[i].projectName}');
          }

          setState(() {
            allDataList = allData;
            if (selectedProjectId != null && selectedProjectId != 'ALL') {
              List<SalesBillingSummaryModel> filtered = allData.where((item) {
                String? itemProjectId =
                    extractProjectIdFromProjectName(item.projectName ?? '');
                return itemProjectId == selectedProjectId;
              }).toList();
              summaryList = filtered;
            } else {
              summaryList = List.from(allData);
            }
            hasGenerated = true;
          });

          if (summaryList.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No data found for the selected filters'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${data['Message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _printSingleRow(
    SalesBillingSummaryModel item,
    NumberFormat indianFormat,
    List<SalesBillingModel> billRows,
  ) async {
    if (item.projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String formattedDate = getFileSafeDateTimeFormatted();
    final String fileName =
        "${item.projectName.replaceAll(' ', '_')}_summary_$formattedDate.pdf";

    String customerName = '';
    if (billRows.isNotEmpty && billRows.first.cusid != null) {
      final matchedCustomer = customerList.firstWhere(
        (c) => c.customerId == billRows.first.cusid,
        orElse: () => ChecklistCustomer(customerId: 0, companyName: ''),
      );
      customerName = matchedCustomer.companyName;
    }
    if (customerName.isEmpty && item.customerId != null) {
      final matchedCustomer = customerList.firstWhere(
        (c) => c.customerId == item.customerId,
        orElse: () => ChecklistCustomer(customerId: 0, companyName: ''),
      );
      customerName = matchedCustomer.companyName;
    }
    if (customerName.isEmpty &&
        customerController.text.isNotEmpty &&
        customerController.text.toUpperCase() != 'ALL') {
      final parts = customerController.text.split(' - ');
      customerName = parts.length > 1
          ? parts.sublist(1).join(' - ')
          : customerController.text;
    }

    final headers = [
      'Bill No',
      'Date',
      'Description',
      'Amount',
      'GST',
      'Total Bill Amt',
      'IT',
      'Retn',
      'Other Ded/Mat',
      'Total Ded',
      'Net Rec.',
      'Net Amt Rec.',
      'Date',
      'Outstanding',
    ];

    final List<List<String>> rows = [];

    for (final bill in billRows) {
      final totalDeduction = (bill.itamnt ?? 0) +
          (bill.retnamnt ?? 0) +
          (bill.whamnt ?? 0) +
          (bill.dedamnt ?? 0);
      final netReceivable = (bill.billtotamnt ?? 0) - totalDeduction;
      final outstanding = netReceivable - (bill.recamnt ?? 0);

      rows.add([
        bill.billno ?? '',
        bill.billdate != null
            ? _formatDate(bill.billdate, includeTime: false)
            : '',
        bill.billdesc ?? '',
        indianFormat.format(bill.billamnt ?? 0),
        indianFormat.format(bill.gstamnt ?? 0),
        indianFormat.format(bill.billtotamnt ?? 0),
        indianFormat.format(bill.itamnt ?? 0),
        indianFormat.format(bill.retnamnt ?? 0),
        indianFormat.format(bill.dedamnt ?? 0),
        indianFormat.format(totalDeduction),
        indianFormat.format(netReceivable),
        indianFormat.format(bill.recamnt ?? 0),
        bill.recdate != null
            ? _formatDate(bill.recdate, includeTime: false)
            : '',
        indianFormat.format(outstanding),
      ]);
    }

    final totalsRow = [
      indianFormat.format(billRows.fold(0.0, (s, b) => s + (b.billamnt ?? 0))),
      indianFormat.format(billRows.fold(0.0, (s, b) => s + (b.gstamnt ?? 0))),
      indianFormat.format(item.billed),
      indianFormat.format(billRows.fold(0.0, (s, b) => s + (b.itamnt ?? 0))),
      indianFormat.format(billRows.fold(0.0, (s, b) => s + (b.retnamnt ?? 0))),
      indianFormat.format(billRows.fold(0.0, (s, b) => s + (b.dedamnt ?? 0))),
      indianFormat.format(billRows.fold(
          0.0,
          (s, b) =>
              s +
              (b.itamnt ?? 0) +
              (b.retnamnt ?? 0) +
              (b.whamnt ?? 0) +
              (b.dedamnt ?? 0))),
      indianFormat.format(item.billed -
          billRows.fold(
              0.0,
              (s, b) =>
                  s +
                  (b.itamnt ?? 0) +
                  (b.retnamnt ?? 0) +
                  (b.whamnt ?? 0) +
                  (b.dedamnt ?? 0))),
      indianFormat.format(item.recamnt ?? 0),
      indianFormat.format(item.balanceAmnt),
    ];

    // Create PDF document using Syncfusion
    final document = syncPdf.PdfDocument();
    document.pageSettings.orientation = syncPdf.PdfPageOrientation.landscape;
    document.pageSettings.size = syncPdf.PdfPageSize.a4;

    final page = document.pages.add();
    final pageSize = page.getClientSize();

    final headerFont = syncPdf.PdfStandardFont(
        syncPdf.PdfFontFamily.helvetica, 9,
        style: syncPdf.PdfFontStyle.bold);
    final normalFont =
        syncPdf.PdfStandardFont(syncPdf.PdfFontFamily.helvetica, 8);
    final boldFont = syncPdf.PdfStandardFont(
        syncPdf.PdfFontFamily.helvetica, 12,
        style: syncPdf.PdfFontStyle.bold);
    final smallFont =
        syncPdf.PdfStandardFont(syncPdf.PdfFontFamily.helvetica, 10);

    double y = 0;

    // Project
    page.graphics
        .drawString('Project', boldFont, bounds: Rect.fromLTWH(0, y, 80, 18));
    page.graphics.drawString(item.projectName, boldFont,
        bounds: Rect.fromLTWH(85, y, pageSize.width - 85, 18));
    y += 20;

    // Customer
    page.graphics
        .drawString('Customer', boldFont, bounds: Rect.fromLTWH(0, y, 80, 18));
    page.graphics.drawString(
        customerName.isNotEmpty ? customerName : '-', smallFont,
        bounds: Rect.fromLTWH(85, y, pageSize.width - 85, 18));
    y += 20;

    // Value (Excl GST)
    page.graphics
        .drawString('Value', smallFont, bounds: Rect.fromLTWH(0, y, 80, 16));

    final exclGstValue = indianFormat.format(item.woValueInclGst / 1.18);
    page.graphics.drawString(exclGstValue, smallFont,
        bounds: Rect.fromLTWH(85, y, 100, 16));
    page.graphics.drawString('Exclusive of GST 18%', smallFont,
        bounds: Rect.fromLTWH(190, y, 200, 16));
    y += 16;

    // Value (Incl GST)
    final inclGstValue = indianFormat.format(item.woValueInclGst);
    page.graphics.drawString(inclGstValue, smallFont,
        bounds: Rect.fromLTWH(85, y, 100, 16));
    page.graphics.drawString('Inclusive of GST 18%', smallFont,
        bounds: Rect.fromLTWH(190, y, 200, 16));
    y += 24;

    // Build grid
    final grid = syncPdf.PdfGrid();
    grid.columns.add(count: headers.length);
    grid.headers.add(1);

    // Grey background for header (RGB: 211, 211, 211)
    final greyColor = syncPdf.PdfColor(211, 211, 211);

    final headerRow = grid.headers[0];
    for (int i = 0; i < headers.length; i++) {
      headerRow.cells[i].value = headers[i];
    }

    final headerStyle = syncPdf.PdfGridCellStyle(
      backgroundBrush: syncPdf.PdfSolidBrush(greyColor),
      font: headerFont,
      cellPadding: syncPdf.PdfPaddings(left: 2, right: 2, top: 2, bottom: 2),
      textBrush: syncPdf.PdfSolidBrush(syncPdf.PdfColor(0, 0, 0)),
    );

    for (int i = 0; i < headers.length; i++) {
      headerRow.cells[i].style = headerStyle;
    }

    // Add data rows
    for (final r in rows) {
      final gridRow = grid.rows.add();
      for (int i = 0; i < r.length; i++) {
        gridRow.cells[i].value = r[i];
        gridRow.cells[i].style = syncPdf.PdfGridCellStyle(
          font: normalFont,
          cellPadding:
              syncPdf.PdfPaddings(left: 2, right: 2, top: 2, bottom: 2),
        );
      }
    }

    // Totals row - merged "Total" label across first 3 columns
    final totalRow = grid.rows.add();
    totalRow.cells[0].value = 'Total';
    totalRow.cells[0].columnSpan = 3;
    totalRow.cells[0].style = syncPdf.PdfGridCellStyle(
      font: headerFont,
      backgroundBrush: syncPdf.PdfSolidBrush(greyColor),
      cellPadding: syncPdf.PdfPaddings(left: 2, right: 2, top: 2, bottom: 2),
    );

    for (int i = 0; i < totalsRow.length; i++) {
      final colIndex = i + 3;
      totalRow.cells[colIndex].value = totalsRow[i];
      totalRow.cells[colIndex].style = syncPdf.PdfGridCellStyle(
        font: headerFont,
        backgroundBrush: syncPdf.PdfSolidBrush(greyColor),
        cellPadding: syncPdf.PdfPaddings(left: 2, right: 2, top: 2, bottom: 2),
      );
    }

    grid.style = syncPdf.PdfGridStyle(
      cellPadding: syncPdf.PdfPaddings(left: 2, right: 2, top: 2, bottom: 2),
    );

    // Draw grid - full width
    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageSize.width, pageSize.height - y),
    );

    final List<int> bytes = await document.save();
    document.dispose();
    final Uint8List pdfBytes = Uint8List.fromList(bytes);

    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ PDF saved to:\n$fileName")),
      );
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final uniquePath = await getUniqueFilePath(fileName);
      if (uniquePath != null) {
        final file = File(uniquePath);
        await file.writeAsBytes(pdfBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ PDF saved to:\n${file.path}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Could not access Downloads folder")),
        );
      }
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)],
          text: "Project Summary Report");
    }
  }

  Future<String?> getUniqueFilePath(String fileName) async {
    final downloadsDir = await getDownloadsFolder();
    if (downloadsDir == null) return null;

    final ncrDir =
        Directory(p.join(downloadsDir.path, "Over all summary report"));
    if (!(await ncrDir.exists())) {
      await ncrDir.create(recursive: true);
    }

    final nameWithoutExt = fileName.replaceAll(RegExp(r'\.pdf$'), '');
    String fullPath = p.join(ncrDir.path, fileName);
    int counter = 1;

    while (await File(fullPath).exists()) {
      fullPath = p.join(ncrDir.path, '${nameWithoutExt}($counter).pdf');
      counter++;
    }

    return fullPath;
  }

  Future<Directory?> getDownloadsFolder() async {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      return Directory('$userProfile\\Downloads');
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      return Directory('$home/Downloads');
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Use the downloads_path_provider_28 plugin here
      //return await DownloadsPathProvider.downloadsDirectory;
    }
    return null;
  }

  Future<List<SalesBillingModel>> _fetchBillsForProject(int projectId) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('GetSalesBillingByProject'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "PROJID": projectId,
          "CUSTOMERID": selectedCustomerId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          final List list = data['Data'];
          return list.map((e) => SalesBillingModel.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching bills: $e');
      return [];
    }
  }

  String _formatDate(dynamic date, {bool includeTime = false}) {
    if (date == null) return '';
    DateTime? dt;
    if (date is DateTime) {
      dt = date;
    } else {
      dt = DateTime.tryParse(date.toString());
    }
    if (dt == null) return '';
    return includeTime
        ? DateFormat('dd/MM/yyyy hh:mm a').format(dt)
        : DateFormat('dd/MM/yyyy').format(dt);
  }
}

String getFileSafeDateTimeFormatted() {
  final now = DateTime.now();
  return DateFormat('yyyyMMdd_HHmmss').format(now);
}*/
/*@override
  Widget _build(BuildContext context) {
    final indianFormat = NumberFormat('#,##,##0', 'en_IN');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Over All Summary'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final minWidth =
              constraints.maxWidth < 600 ? 600.0 : constraints.maxWidth;

          return SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Container(
                width: minWidth,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ///Customer Name & Project Name
                      Row(
                        children: [
                          Expanded(
                            child: Autocomplete<ChecklistCustomer>(
                              displayStringForOption: (option) =>
                                  "${option.customerId} - ${option.companyName}",
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return customerList;
                                }
                                return customerList.where((customer) {
                                  return customer.companyName
                                          .toLowerCase()
                                          .contains(textEditingValue.text
                                              .toLowerCase()) ||
                                      customer.customerId
                                          .toString()
                                          .contains(textEditingValue.text);
                                });
                              },
                              onSelected: (ChecklistCustomer selection) {
                                debugPrint(
                                    'Selected Customer: ${selection.companyName}, ID: ${selection.customerId}');

                                customerController.text =
                                    "${selection.customerId} - ${selection.companyName}";

                                setState(() {
                                  selectedCustomerId =
                                      selection.customerId.toString();
                                  selectedProjectId = null;
                                  siteController.clear();
                                  siteController.text = 'ALL';
                                  projectList.clear();
                                  hasGenerated = false;
                                  summaryList.clear();
                                  allDataList.clear();
                                });

                                loadProjects(selection.customerId);
                              },
                              fieldViewBuilder: (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                controller.text = customerController.text;
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: "Customer Name",
                                    hintText: "Search Customer",
                                    border: const OutlineInputBorder(),
                                    suffixIcon: controller.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              controller.clear();
                                              customerController.text = 'ALL';
                                              setState(() {
                                                selectedCustomerId = null;
                                                selectedProjectId = null;
                                                siteController.clear();
                                                siteController.text = 'ALL';
                                                projectList.clear();
                                                hasGenerated = false;
                                                summaryList.clear();
                                                allDataList.clear();
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Autocomplete<Project>(
                              displayStringForOption: (option) =>
                                  "${option.projectId} - ${option.projectName}",
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return projectList;
                                }
                                return projectList.where((project) {
                                  return project.projectName
                                          .toLowerCase()
                                          .contains(textEditingValue.text
                                              .toLowerCase()) ||
                                      project.projectId
                                          .toString()
                                          .contains(textEditingValue.text);
                                });
                              },
                              onSelected: (Project selection) {
                                siteController.text =
                                    "${selection.projectId} - ${selection.projectName}";
                                setState(() {
                                  selectedProjectId =
                                      selection.projectId.toString();
                                });
                              },
                              fieldViewBuilder: (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                controller.text = siteController.text;
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: "Site Name",
                                    hintText: "Search Site",
                                    border: const OutlineInputBorder(),
                                    suffixIcon: controller.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              controller.clear();
                                              siteController.text = 'ALL';
                                              setState(() {
                                                selectedProjectId = null;
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Generate Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryDark
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 5,
                                    offset: const Offset(2, 4),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: isLoading
                                    ? null
                                    : () async {
                                        await getSalesBillingSummary();
                                      },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  child: Center(
                                    child: isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text(
                                            'Generate',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Summary Table - Only show if Generate was clicked
                      if (hasGenerated && summaryList.isNotEmpty)
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 20),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  AppColors.primary.withOpacity(0.1),
                                ),
                                columns: const [
                                  DataColumn(
                                      label: Text('S.No',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Project Name',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Total Value',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Billed',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Balance',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                ],
                                rows: summaryList.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text('${index + 1}')),
                                      DataCell(Text(item.projectName ?? '')),
                                      DataCell(Text(indianFormat
                                          .format(item.woValueInclGst ?? 0))),
                                      DataCell(Text(indianFormat
                                          .format(item.billed ?? 0))),
                                      DataCell(Text(indianFormat
                                          .format(item.balanceAmnt ?? 0))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        )
                      else if (hasGenerated &&
                          !isLoading &&
                          summaryList.isEmpty &&
                          allDataList.isNotEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              'No data found for the selected project',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }*/
