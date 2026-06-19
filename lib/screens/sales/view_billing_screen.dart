/*import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';
import 'billing_entry_screen.dart';

import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

class ViewBillingScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const ViewBillingScreen({
    super.key,
    this.isSuperAdmin = false,
  });

  @override
  State<ViewBillingScreen> createState() => _ViewBillingScreenState();
}

class _ViewBillingScreenState extends State<ViewBillingScreen> {
  bool _isRefreshing = false;
  bool _isLoading = false;
  bool _hasGenerated = false;
  String _searchQuery = '';
  List<SalesBillingModel> _billingList = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController customerController = TextEditingController();
  final TextEditingController siteController = TextEditingController();
  int empCode = 0;
  String empName = '';

  List<ChecklistCustomer> customerList = [];
  List<Project> projectList = [];
  List<SalesEmployeeModel> salesEmployees = [];

  Map<int, String> _employeeNameMap = {};

  int? selectedCustomerId;
  int? selectedProjectId;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    loadCustomers();
    _loadEmployees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Billing List'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
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
                      customerController.text =
                          "${selection.customerId} - ${selection.companyName}";

                      setState(() {
                        selectedCustomerId = selection.customerId;
                        selectedProjectId = null;
                        siteController.clear();
                        projectList.clear();
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
                                    customerController.clear();
                                    setState(() {
                                      selectedCustomerId = null;
                                      selectedProjectId = null;
                                      siteController.clear();
                                      projectList.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      siteController.text =
                          "${selection.projectId} - ${selection.projectName}";
                      setState(() {
                        selectedProjectId = selection.projectId;
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
                                    siteController.clear();
                                    setState(() {
                                      selectedProjectId = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      onTap: _isLoading ? null : _onGeneratePressed,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: Text(
                            'Generate',
                            style: const TextStyle(
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

            ///Search bar + List (only after generate)
            if (_hasGenerated) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: TextField(
                  controller: _searchController,
                  decoration:
                      _inputDecoration('Search by Bill No / SBNO...').copyWith(
                    hintText: 'Search by Bill No / SBNO...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 5),
              if (_isLoading || _isRefreshing) const LinearProgressIndicator(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: _billingList.isEmpty && !_isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text('No billing entries found',
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredBillingList
                              .length, // ✅ Use filtered list
                          itemBuilder: (context, index) {
                            return _buildBillingCard(_filteredBillingList[
                                index]); // ✅ Use filtered list
                          },
                        ),
                ),
              ),
            ] else
              Expanded(
                child: Center(
                  child: Text(
                    'Select Customer & Project, then tap Generate',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<SalesBillingModel> get _filteredBillingList {
    if (_searchQuery.isEmpty) {
      return _billingList;
    }
    return _billingList.where((bill) {
      final searchLower = _searchQuery.toLowerCase();
      return (bill.billno?.toLowerCase().contains(searchLower) ?? false) ||
          (bill.billdesc?.toLowerCase().contains(searchLower) ?? false);
    }).toList();
  }

  void _onGeneratePressed() {
    if (selectedCustomerId == null || selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please Select Customer Name & Project Name"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _hasGenerated = true;
    });
    _fetchBillingEntries();
  }

  Future<void> _loadUserDetails() async {
    final prefsHelper = PreferencesHelper();
    empCode = (await prefsHelper.getEmpCode()) ?? 0;
    empName = (await prefsHelper.getEmpName()) ?? '';
    setState(() {});
  }

  Future<void> _loadEmployees() async {
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

            // Create a map for O(1) lookup by empCode
            _employeeNameMap = {
              for (var emp in salesEmployees) emp.empCode: emp.empName
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading employees: $e');
    }
  }

  String getEmployeeName(int? empCodeValue) {
    if (empCodeValue == null) return '-';

    // Try to get name from map
    final employeeName = _employeeNameMap[empCodeValue];

    if (employeeName != null && employeeName.isNotEmpty) {
      return '$empCodeValue - $employeeName';
    }

    return empCodeValue.toString();
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

  Future<void> loadProjects(int customerId) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('ProjectDetails'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "CUSTOMERID": customerId,
        }),
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

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await _fetchBillingEntries();
    } finally {
      setState(() => _isRefreshing = false);
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
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
      );

  Future<void> _fetchBillingEntries() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }

    try {
      final uri = ApiUtils.getUri('ViewSalesBillinglist');

      final requestBody = <String, dynamic>{};
      if (selectedCustomerId != null) {
        requestBody['CUSID'] = selectedCustomerId;
      }
      if (selectedProjectId != null) {
        requestBody['PROJID'] = selectedProjectId;
      }

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true) {
          final List<dynamic> list = data['BillingList'] ?? [];

          final entries =
              list.map((e) => SalesBillingModel.fromJson(e)).toList();

          // Sort by SBNO descending (latest first)
          entries.sort((a, b) => (b.sbno ?? 0).compareTo(a.sbno ?? 0));

          setState(() {
            _billingList = entries;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Widget _buildBillingCard(SalesBillingModel entry) {
    String formatDate(DateTime? date) {
      if (date == null) return '-';
      return DateFormat('dd-MM-yyyy').format(date);
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to view mode when tapping on card
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BillingEntryScreen(
                billingData: entry,
                isReadOnly: true,
                isSuperAdmin: widget.isSuperAdmin,
                onDataSaved: () {
                  _fetchBillingEntries();
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Header with Icons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Bill No: ${entry.billno ?? '-'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // View Icon
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BillingEntryScreen(
                                billingData: entry,
                                isReadOnly: true,
                                onDataSaved: () {
                                  _fetchBillingEntries();
                                },
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BillingEntryScreen(
                                billingData: entry,
                                isReadOnly: false,
                                onDataSaved: () {
                                  _fetchBillingEntries();
                                },
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
                      if (widget.isSuperAdmin)
                        IconButton(
                          onPressed: () {
                            _showDeleteConfirmationDialog(entry.sbno);
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

                      if (widget.isSuperAdmin) const SizedBox(width: 8),

                      // Download Icon
                      IconButton(
                        onPressed: () async {
                          await BillingDownloadService.downloadBillingFiles(
                            context: context,
                            sbNo: entry.sbno,
                            sbfname: entry.sbfname,
                          );
                        },
                        icon: const Icon(
                          Icons.download,
                          size: 20,
                          color: Colors.purpleAccent,
                        ),
                        tooltip: 'Download Attachments',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              /// Bill Date
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bill Date : ${formatDate(entry.billdate)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              /// Bill Description
              if (entry.billdesc != null && entry.billdesc!.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.description, size: 18, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bill Description : ${entry.billdesc!}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              /// Added By - Shows in "EMPCODE - EMPNAME" format
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Entered By : ${getEmployeeName(entry.adduser)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              /// Added Date
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Entry Date : ${formatDate(entry.adddate)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              /// Edited By
              if (entry.edituser != null)
                Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Edit By : ${getEmployeeName(entry.edituser)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              /// Edit Date
              if (entry.editdate != null)
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 18, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Edit Date : ${formatDate(entry.editdate)}',
                        style: const TextStyle(fontSize: 13),
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

  Future<void> _showDeleteConfirmationDialog(int sbno) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Billing Entry'),
          content: Text('Are you sure you want to delete Bill #$sbno?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteBilling(sbno);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBilling(int sbno) async {
    setState(() => _isLoading = true);

    try {
      final requestBody = {
        "SBNO": sbno,
        "DELUSER": empCode,
      };

      final response = await http.post(
        ApiUtils.getUri('DeleteSalesbillinglist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final data = jsonDecode(response.body);

      if (data['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Billing entry deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchBillingEntries();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message'] ?? 'Failed to delete'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
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

    // ✅ Calculate total Billed amount (Bill Amount + GST)
    final totalBilled = totalBillAmount + totalGST;
    // ✅ Calculate Net Receivable (Billed - Total Deductions)
    final totalNetReceivable = totalBilled - totalAllDeductions;

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
                    // Amount (Sum of all bill amounts)
                    _totalNumCell(indianFormat.format(totalBillAmount)),
                    // GST (Sum of all GST)
                    _totalNumCell(indianFormat.format(totalGST)),
                    // ✅ Total Value (Amount + GST) - FIXED
                    _totalNumCell(indianFormat.format(totalBilled),
                        color: Colors.blue.shade800),
                    // IT
                    _totalNumCell(indianFormat.format(totalIT)),
                    // Retention
                    _totalNumCell(indianFormat.format(totalRetn)),
                    // Other Deduction
                    _totalNumCell(indianFormat.format(totalDed)),
                    // Total Deduction
                    _totalNumCell(indianFormat.format(totalAllDeductions),
                        color: Colors.red.shade700),
                    // ✅ Net Receivable (Total Billed - Total Deductions) - FIXED
                    _totalNumCell(indianFormat.format(totalNetReceivable)),
                    // Received
                    _totalNumCell(indianFormat.format(item.recamnt ?? 0),
                        color: Colors.green.shade800),
                    // Empty (Date column)
                    _emptyCell(),
                    // Outstanding
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
}*/

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';
import 'billing_entry_screen.dart';

import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

class ViewBillingScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const ViewBillingScreen({
    super.key,
    this.isSuperAdmin = false,
  });

  @override
  State<ViewBillingScreen> createState() => _ViewBillingScreenState();
}

class _ViewBillingScreenState extends State<ViewBillingScreen> {
  bool _isRefreshing = false;
  bool _isLoading = false;
  bool _hasGenerated = false;
  String _searchQuery = '';
  List<SalesBillingModel> _billingList = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController customerController = TextEditingController();
  final TextEditingController siteController = TextEditingController();
  int empCode = 0;
  String empName = '';

  List<ChecklistCustomer> customerList = [];
  List<Project> projectList = [];
  List<SalesEmployeeModel> salesEmployees = [];

  Map<int, String> _employeeNameMap = {};

  int? selectedCustomerId;
  int? selectedProjectId;

  Map<int, List<SalesBillingModel>> _groupedBillingList = {};

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    loadCustomers();
    _loadEmployees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Billing List'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
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
                      customerController.text =
                          "${selection.customerId} - ${selection.companyName}";

                      setState(() {
                        selectedCustomerId = selection.customerId;
                        selectedProjectId = null;
                        siteController.clear();
                        projectList.clear();
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
                                    customerController.clear();
                                    setState(() {
                                      selectedCustomerId = null;
                                      selectedProjectId = null;
                                      siteController.clear();
                                      projectList.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      siteController.text =
                          "${selection.projectId} - ${selection.projectName}";
                      setState(() {
                        selectedProjectId = selection.projectId;
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
                                    siteController.clear();
                                    setState(() {
                                      selectedProjectId = null;
                                    });
                                  },
                                )
                              : null,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      onTap: _isLoading ? null : _onGeneratePressed,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: Text(
                            'Generate',
                            style: const TextStyle(
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

            ///List (only after generate)
            if (_isLoading || _isRefreshing) const LinearProgressIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: _groupedBillingList.isEmpty && !_isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('No billing entries found',
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _groupedBillingList.keys.length,
                        itemBuilder: (context, index) {
                          final projectId =
                              _groupedBillingList.keys.elementAt(index);
                          final billRows = _groupedBillingList[projectId]!;

                          // Get project name from the first bill or from projectList
                          String projectName = '';
                          if (billRows.isNotEmpty &&
                              billRows.first.projid != null) {
                            final project = projectList.firstWhere(
                              (p) => p.projectId == billRows.first.projid,
                              orElse: () =>
                                  Project(projectId: 0, projectName: ''),
                            );
                            projectName = project.projectName;
                          }

                          // Create a summary model for this project
                          final summaryModel = SalesBillingSummaryModel(
                            projectId: projectId,
                            projectName: projectName,
                            billed: billRows.fold(
                                0.0, (sum, b) => sum! + (b.billtotamnt ?? 0)),
                            recamnt: billRows.fold(
                                0.0, (sum, b) => sum! + (b.recamnt ?? 0)),
                            balanceAmnt: billRows.fold(
                                0.0,
                                (sum, b) =>
                                    sum! +
                                    ((b.billtotamnt ?? 0) - (b.recamnt ?? 0))),
                            woValueInclGst: billRows.fold(
                                0.0, (sum, b) => sum! + (b.billtotamnt ?? 0)),
                          );

                          return Center(
                            child: _buildProjectDetailsTable(
                              summaryModel,
                              NumberFormat.currency(
                                  locale: 'en_IN',
                                  symbol: '₹',
                                  decimalDigits: 0),
                              billRows,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onGeneratePressed() {
    if (selectedCustomerId == null || selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please Select Customer Name & Project Name"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _hasGenerated = true;
    });
    _fetchBillingEntries();
  }

  Future<void> _loadUserDetails() async {
    final prefsHelper = PreferencesHelper();
    empCode = (await prefsHelper.getEmpCode()) ?? 0;
    empName = (await prefsHelper.getEmpName()) ?? '';
    setState(() {});
  }

  Future<void> _loadEmployees() async {
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

            _employeeNameMap = {
              for (var emp in salesEmployees) emp.empCode: emp.empName
            };
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading employees: $e');
    }
  }

  String getEmployeeName(int? empCodeValue) {
    if (empCodeValue == null) return '-';

    final employeeName = _employeeNameMap[empCodeValue];

    if (employeeName != null && employeeName.isNotEmpty) {
      return '$empCodeValue - $employeeName';
    }

    return empCodeValue.toString();
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

  Future<void> loadProjects(int customerId) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('ProjectDetails'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "CUSTOMERID": customerId,
        }),
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

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await _fetchBillingEntries();
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _fetchBillingEntries() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }

    try {
      final uri = ApiUtils.getUri('ViewSalesBillinglist');

      final requestBody = <String, dynamic>{};
      if (selectedCustomerId != null) {
        requestBody['CUSID'] = selectedCustomerId;
      }
      if (selectedProjectId != null) {
        requestBody['PROJID'] = selectedProjectId;
      }

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true) {
          final List<dynamic> list = data['BillingList'] ?? [];

          final entries =
              list.map((e) => SalesBillingModel.fromJson(e)).toList();

          entries.sort((a, b) => (b.sbno ?? 0).compareTo(a.sbno ?? 0));

          // ✅ Group by Project ID
          final Map<int, List<SalesBillingModel>> grouped = {};
          for (var entry in entries) {
            final projId = entry.projid ?? 0;
            if (!grouped.containsKey(projId)) {
              grouped[projId] = [];
            }
            grouped[projId]!.add(entry);
          }

          setState(() {
            _billingList = entries;
            _groupedBillingList = grouped;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
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
      'IT', // ✅ This header will be centered
      'Retention',
      'Other Ded/Mat',
      'Total Deduction',
      'Net Receivable',
      'Net Amount Received',
      'Date',
      'Outstanding',
      'Actions',
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

    // Calculate total Billed amount (Bill Amount + GST)
    final totalBilled = totalBillAmount + totalGST;
    // Calculate Net Receivable (Billed - Total Deductions)
    final totalNetReceivable = totalBilled - totalAllDeductions;

    // ── font sizes ──
    const double headerFs = 13.5;
    const double cellFs = 13.0;
    const double totalFs = 14.0;

    // ✅ Data cell with right-aligned text
    DataCell _numCell(String text, {Color? color, bool bold = false}) =>
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.centerRight, // ✅ Align to right end
            child: Text(
              text,
              style: TextStyle(
                fontSize: cellFs,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: color,
              ),
              textAlign: TextAlign.right, // ✅ Right aligned
            ),
          ),
        );

    // ✅ Total cell with right-aligned text
    DataCell _totalNumCell(String text, {Color? color}) => DataCell(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.centerRight, // ✅ Align to right end
            child: Text(
              text,
              style: TextStyle(
                fontSize: totalFs,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.blueGrey.shade800,
              ),
              textAlign: TextAlign.right, // ✅ Right aligned
            ),
          ),
        );

    DataCell _emptyCell() => const DataCell(
          SizedBox.shrink(),
        );

    // ✅ Action buttons widget
    NumberFormat indianFormat =
        NumberFormat('#,##0', 'en_IN'); // ✅ Removes ₹ symbol
    return Card(
      margin: const EdgeInsets.all(8),
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
              headingRowHeight: 50,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 54,
              columnSpacing: 18,
              horizontalMargin: 14,
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
              columns: headers.map((h) {
                // ✅ Check if it's Actions or IT column
                final isActions = h == 'Actions';
                final isIT = h == 'IT'; // ✅ Add this line for IT column
                return DataColumn(
                  label: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: SizedBox(
                      width: isActions ? 120 : null,
                      child: Center(
                        child: Text(
                          h,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: headerFs,
                            color: AppColors.primary,
                            letterSpacing: 0.2,
                          ),
                          textAlign: isIT || isActions
                              ? TextAlign.center
                              : TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
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
                      // Bill No - Clickable to show popup
                      DataCell(
                        InkWell(
                          onTap: () {
                            _showBillingDetailsPopup(bill);
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 4),
                            child: Text(
                              bill.billno ?? '',
                              style: TextStyle(
                                fontSize: cellFs,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Date - Left aligned
                      DataCell(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          bill.billdate != null
                              ? _formatDateToString(bill.billdate)
                              : '—',
                          style: TextStyle(
                              fontSize: cellFs, color: Colors.grey.shade700),
                        ),
                      )),
                      // Description - Left aligned
                      DataCell(Container(
                        constraints: const BoxConstraints(maxWidth: 180),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(bill.billdesc ?? '',
                            style: TextStyle(fontSize: cellFs),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      )),
                      // Amount - Right aligned
                      _numCell(indianFormat.format(bill.billamnt ?? 0),
                          bold: true),
                      // GST - Right aligned
                      _numCell(indianFormat.format(bill.gstamnt ?? 0)),
                      // Total Value - Right aligned
                      _numCell(indianFormat.format(bill.billtotamnt ?? 0),
                          color: Colors.blueGrey.shade700, bold: true),
                      // IT - Right aligned (centered header)
                      _numCell(indianFormat.format(bill.itamnt ?? 0)),
                      // Retention - Right aligned
                      _numCell(indianFormat.format(bill.retnamnt ?? 0)),
                      // Other Deduction - Right aligned
                      _numCell(indianFormat.format(bill.dedamnt ?? 0)),
                      // Total Deduction - Right aligned
                      _numCell(indianFormat.format(totalDeduction),
                          color: Colors.red.shade600, bold: true),
                      // Net Receivable - Right aligned
                      _numCell(indianFormat.format(netReceivable), bold: true),
                      // Net Amount Received - Right aligned
                      _numCell(indianFormat.format(bill.recamnt ?? 0),
                          color: Colors.green.shade700, bold: true),
                      // Receipt date - Left aligned
                      DataCell(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          bill.recdate != null
                              ? _formatDateToString(bill.recdate)
                              : '—',
                          style: TextStyle(
                              fontSize: cellFs, color: Colors.grey.shade700),
                        ),
                      )),
                      // Outstanding - Right aligned
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 6),
                        alignment: Alignment.centerRight, // ✅ Right aligned
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
                      // Actions column - centered
                      DataCell(
                        Center(
                          child: _buildActionButtons(bill),
                        ),
                      ),
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
                                size: 18, color: Colors.indigo.shade700),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.indigo.shade800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    )),
                    // Amount (Sum of all bill amounts)
                    _totalNumCell(indianFormat.format(totalBillAmount)),
                    // GST (Sum of all GST)
                    _totalNumCell(indianFormat.format(totalGST)),
                    // Total Value (Amount + GST)
                    _totalNumCell(indianFormat.format(totalBilled),
                        color: Colors.blue.shade800),
                    // IT
                    _totalNumCell(indianFormat.format(totalIT)),
                    // Retention
                    _totalNumCell(indianFormat.format(totalRetn)),
                    // Other Deduction
                    _totalNumCell(indianFormat.format(totalDed)),
                    // Total Deduction
                    _totalNumCell(indianFormat.format(totalAllDeductions),
                        color: Colors.red.shade700),
                    // Net Receivable (Total Billed - Total Deductions)
                    _totalNumCell(indianFormat.format(totalNetReceivable)),
                    // Received
                    _totalNumCell(indianFormat.format(item.recamnt ?? 0),
                        color: Colors.green.shade800),
                    // Empty (Date column)
                    _emptyCell(),
                    // Outstanding
                    _totalNumCell(indianFormat.format(item.balanceAmnt ?? 0),
                        color: (item.balanceAmnt ?? 0) > 0
                            ? Colors.deepOrange.shade700
                            : Colors.green.shade700),
                    // Empty Actions cell for totals row
                    _emptyCell(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(SalesBillingModel bill) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // View Icon
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BillingEntryScreen(
                  billingData: bill,
                  isReadOnly: true,
                  isSuperAdmin: widget.isSuperAdmin,
                  onDataSaved: () {
                    _fetchBillingEntries();
                  },
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            child: const Icon(
              Icons.visibility,
              size: 22,
              color: Colors.blue,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Edit Icon
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BillingEntryScreen(
                  billingData: bill,
                  isReadOnly: false,
                  onDataSaved: () {
                    _fetchBillingEntries();
                  },
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            child: const Icon(
              Icons.edit,
              size: 22,
              color: Colors.orange,
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Delete Icon
        if (widget.isSuperAdmin)
          InkWell(
            onTap: () {
              _showDeleteConfirmationDialog(bill.sbno ?? 0);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              child: const Icon(
                Icons.delete,
                size: 22,
                color: Colors.red,
              ),
            ),
          ),
        if (widget.isSuperAdmin) const SizedBox(width: 6),
        // Download Icon
        InkWell(
          onTap: () async {
            await BillingDownloadService.downloadBillingFiles(
              context: context,
              sbNo: bill.sbno,
              sbfname: bill.sbfname,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            child: const Icon(
              Icons.download,
              size: 22,
              color: Colors.purpleAccent,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateToString(DateTime? date) {
    if (date == null) return '—';
    return DateFormat('dd-MM-yyyy').format(date);
  }

  Future<void> _showDeleteConfirmationDialog(int sbno) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Billing Entry'),
          content: Text('Are you sure you want to delete Bill #$sbno?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteBilling(sbno);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBilling(int sbno) async {
    setState(() => _isLoading = true);

    try {
      final requestBody = {
        "SBNO": sbno,
        "DELUSER": empCode,
      };

      final response = await http.post(
        ApiUtils.getUri('DeleteSalesbillinglist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final data = jsonDecode(response.body);

      if (data['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Billing entry deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _fetchBillingEntries();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message'] ?? 'Failed to delete'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showBillingDetailsPopup(SalesBillingModel bill) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bill Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                // Use the existing _buildBillingCard but wrapped differently
                _buildBillingCardPopup(bill),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBillingCardPopup(SalesBillingModel entry) {
    String formatDate(DateTime? date) {
      if (date == null) return '-';
      return DateFormat('dd-MM-yyyy').format(date);
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Bill No: ${entry.billno ?? '-'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            /// Bill Date
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 18, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bill Date : ${formatDate(entry.billdate)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            /// Bill Description
            if (entry.billdesc != null && entry.billdesc!.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.description, size: 18, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bill Description : ${entry.billdesc!}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),

            /// Added By
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Entered By : ${getEmployeeName(entry.adduser)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            /// Added Date
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 18, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Entry Date : ${formatDate(entry.adddate)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            /// Edited By
            if (entry.edituser != null)
              Row(
                children: [
                  const Icon(Icons.person, size: 18, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit By : ${getEmployeeName(entry.edituser)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),

            /// Edit Date
            if (entry.editdate != null)
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Date : ${formatDate(entry.editdate)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class BillingDownloadService {
  // Method to get file names from your API
  static Future<Map<String, dynamic>?> _getBillingFiles({
    required int sbNo,
  }) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('GetBillingFiles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"SBNO": sbNo}),
      );

      print('GetBillingFiles Response: ${response.body}');

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
  static Future<void> downloadBillingFiles({
    required BuildContext context,
    required int sbNo,
    String? sbfname,
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
    String? fileNamesString = sbfname;

    if (fileNamesString == null || fileNamesString.trim().isEmpty) {
      final filesData = await _getBillingFiles(sbNo: sbNo);

      if (filesData == null) {
        _showNoFilesDialog(context, sbNo);
        return;
      }

      fileNamesString = filesData['SBFNAME'];

      if (fileNamesString == null ||
          fileNamesString.toString().trim().isEmpty) {
        _showNoFilesDialog(context, sbNo);
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
        await _downloadFile(fileName, sbNo);
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
  static Future<void> _downloadFile(String fileName, int sbNo) async {
    try {
      print('Original filename from DB: "$fileName"');

      final response = await http.post(
        ApiUtils.getUri('DownloadbillFile'),
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
  static void _showNoFilesDialog(BuildContext context, int sbNo) {
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
          'Billing #$sbNo has no attached files.\n\n'
          'To add files, edit the billing entry and upload attachments.',
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
