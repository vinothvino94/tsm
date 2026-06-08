import 'dart:convert';
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
                          itemCount: _billingList.length,
                          itemBuilder: (context, index) {
                            return _buildBillingCard(_billingList[index]);
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
