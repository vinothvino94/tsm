import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tsm/screens/sales/projectcontrol_entry_screen.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/pdfgeneratorservice.dart';
import '../../services/prefrence_helper.dart';
import 'design_entry_screen.dart';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';
import 'package:universal_html/html.dart' as html;

class ViewProjectControlScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const ViewProjectControlScreen({
    super.key,
    this.isSuperAdmin = false,
  });

  @override
  State<ViewProjectControlScreen> createState() =>
      _ViewProjectControlScreenState();
}

class _ViewProjectControlScreenState extends State<ViewProjectControlScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController customerController = TextEditingController();
  final TextEditingController siteController = TextEditingController();

  List<ChecklistCustomer> customerList = [];
  List<Project> projectList = [];
  List<SalesEmployeeModel> salesEmployees = [];
  Map<int, String> _employeeNameMap = {};
  int? selectedCustomerId;
  int? selectedProjectId;
  bool _isLoading = false;
  bool _hasGenerated = false;
  String _searchQuery = '';
  bool _isRefreshing = false;
  List<ProjectcontrolModel> _desingingList = [];
  int empCode = 0;
  String empName = '';

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
        title: const Text('View ProjectControl List'),
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
                  decoration: _inputDecoration('Search by Entry No').copyWith(
                    hintText: 'Search by Entry No',
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
                  child: _desingingList.isEmpty && !_isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text('No designing entries found',
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredDesigningList
                              .length, // ✅ Use filtered list
                          itemBuilder: (context, index) {
                            return _buildDesingningCard(_filteredDesigningList[
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

  List<ProjectcontrolModel> get _filteredDesigningList {
    if (_searchQuery.isEmpty) {
      return _desingingList;
    }
    return _desingingList.where((design) {
      final searchLower = _searchQuery.toLowerCase();
      return (design.SPCNO?.toString().contains(_searchQuery) ?? false) ||
          (design.SPCNAME?.toLowerCase().contains(searchLower) ?? false) ||
          (design.SPCTOT?.toString().contains(_searchQuery) ?? false) ||
          (design.SPCSNO?.toString().contains(_searchQuery) ?? false) ||
          (design.PCTOT?.toString().contains(_searchQuery) ?? false) ||
          (design.PCREMKS?.toLowerCase().contains(searchLower) ?? false) ||
          (design.SFNAME?.toLowerCase().contains(searchLower) ?? false) ||
          (design.PCFNAME?.toLowerCase().contains(searchLower) ?? false);
    }).toList();
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
    _fetchDesigningEntries();
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

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      await _fetchDesigningEntries();
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Widget _buildDesingningCard(ProjectcontrolModel entry) {
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectcontrolEntryScreen(
                pcData: entry,
                isReadOnly: true,
                isSuperAdmin: widget.isSuperAdmin,
                onDataSaved: () {
                  _fetchDesigningEntries();
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
                      'Entry No - Dt: ${entry.SPCNO ?? 'N/A'} - ${_formatDate(entry.SPCDT)}',
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
                              builder: (context) => ProjectcontrolEntryScreen(
                                pcData: entry,
                                isReadOnly: true,
                                onDataSaved: () {
                                  _fetchDesigningEntries();
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
                              builder: (context) => ProjectcontrolEntryScreen(
                                pcData: entry,
                                isReadOnly: false,
                                onDataSaved: () {
                                  _fetchDesigningEntries();
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
                            _showDeleteConfirmationDialog(entry.SPCNO);
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
                      const SizedBox(width: 8),

                      // Print Icon
                      IconButton(
                        onPressed: () {
                          _generateSalesEntriesPDF(
                              entry); // ✅ Pass _salesEntries
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

                      // ✅ Download Icon - Downloads BOTH Sales and Design files
                      IconButton(
                        onPressed: () async {
                          // ✅ Download both Sales and Design files
                          await PCDownloadService.downloadPCFiles(
                            context: context,
                            spcNo: entry.SPCNO ?? 0,
                            salesFiles: entry.SFNAME, // Sales files
                            designFiles: entry.PCFNAME, // Design files
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

              /// Divider
              const Divider(),
              const SizedBox(height: 4),

              /// Added By
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Entered By: ${getEmployeeName(entry.ADDUSER)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              /// Added Date
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.purple),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Entry Date: ${formatDate(entry.ADDDATE)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

              /// Edited By
              if (entry.EDITUSER != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 14, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Edited By: ${getEmployeeName(entry.EDITUSER)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              /// Edit Date
              if (entry.EDITDATE != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Edit Date: ${formatDate(entry.EDITDATE)}',
                          style: const TextStyle(fontSize: 12),
                        ),
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

  Future<void> _fetchDesigningEntries() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }

    try {
      final uri = ApiUtils.getUri('ViewProjectControllist');

      final requestBody = <String, dynamic>{};
      if (selectedCustomerId != null) {
        requestBody['CUSID'] = selectedCustomerId;
      }
      if (selectedProjectId != null) {
        requestBody['PROJID'] = selectedProjectId;
      }

      debugPrint('Request URL: $uri');
      debugPrint('Request Body: $requestBody');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Parsed Data Keys: ${data.keys}');

        if (data['Success'] == true) {
          final List<dynamic> list = data['DesigningList'] ?? [];

          debugPrint('Found ${list.length} items in DesigningList');

          if (list.isNotEmpty) {
            final entries = list
                .map((e) =>
                    ProjectcontrolModel.fromJson(e as Map<String, dynamic>))
                .toList();

            // ✅ GROUP BY SDNO - Combine all entries into one with comma-separated values
            final Map<int, ProjectcontrolModel> groupedEntries = {};

            for (var entry in entries) {
              final SPCNO = entry.SPCNO ?? 0;

              if (!groupedEntries.containsKey(SPCNO)) {
                // First entry for this SDNO - copy all data
                groupedEntries[SPCNO] = ProjectcontrolModel(
                  SPCNO: entry.SPCNO,
                  SPCDT: entry.SPCDT,
                  CUSID: entry.CUSID,
                  PROJID: entry.PROJID,
                  SPCTOT: entry.SPCTOT,
                  SPCNAME: entry.SPCNAME ?? '',
                  SPCSNO: entry.SPCSNO,
                  SFNAME: entry.SFNAME,
                  SFTYPE: entry.SFTYPE,
                  SFCOUNT: entry.SFCOUNT,
                  PCFNAME: entry.PCFNAME,
                  PCFTYPE: entry.PCFTYPE,
                  PCFCOUNT: entry.PCFCOUNT,
                  PCTOT: entry.PCTOT,
                  PCREMKS: entry.PCREMKS,
                  ADDUSER: entry.ADDUSER,
                  ADDDATE: entry.ADDDATE,
                  EDITUSER: entry.EDITUSER,
                  EDITDATE: entry.EDITDATE,
                );
              } else {
                // ✅ Combine data with existing entry (append to comma-separated lists)
                final existing = groupedEntries[SPCNO]!;

                // Combine SELENAME, SELEUNIT, SELETOT
                if (entry.SPCNAME != null && entry.SPCNAME!.isNotEmpty) {
                  if (existing.SPCNAME == null || existing.SPCNAME!.isEmpty) {
                    existing.SPCNAME = entry.SPCNAME;
                  } else {
                    existing.SPCNAME = '${existing.SPCNAME},${entry.SPCNAME}';
                  }
                }

                if (entry.SPCTOT != null && entry.SPCTOT!.isNotEmpty) {
                  if (existing.SPCTOT == null || existing.SPCTOT!.isEmpty) {
                    existing.SPCTOT = entry.SPCTOT;
                  } else {
                    existing.SPCTOT = '${existing.SPCTOT},${entry.SPCTOT}';
                  }
                }

                // Combine file names (if different files)
                if (entry.SFNAME != null && entry.SFNAME!.isNotEmpty) {
                  if (existing.SFNAME == null || existing.SFNAME!.isEmpty) {
                    existing.SFNAME = entry.SFNAME;
                    existing.SFTYPE = entry.SFTYPE;
                    existing.SFCOUNT = entry.SFCOUNT;
                  } else if (!existing.SFNAME!.contains(entry.SFNAME!)) {
                    existing.SFNAME = '${existing.SFNAME},${entry.SFNAME}';
                  }
                }

                // ✅ Combine Design file names
                if (entry.PCFNAME != null && entry.PCFNAME!.isNotEmpty) {
                  if (existing.PCFNAME == null || existing.PCFNAME!.isEmpty) {
                    existing.PCFNAME = entry.PCFNAME;
                    existing.PCFTYPE = entry.PCFTYPE;
                    existing.PCFCOUNT = entry.PCFCOUNT;
                  } else if (!existing.PCFNAME!.contains(entry.PCFNAME!)) {
                    existing.PCFNAME = '${existing.PCFNAME},${entry.PCFNAME}';
                  }
                }

                // Update SELESNO (total count of entries)
                existing.SPCSNO = (existing.SPCSNO ?? 0) + 1;
              }
            }

            // Convert grouped map back to list
            final groupedList = groupedEntries.values.toList();

            // Sort by SDNO descending (latest first)
            groupedList.sort((a, b) {
              final aSdno = a.SPCNO ?? 0;
              final bSdno = b.SPCNO ?? 0;
              return bSdno.compareTo(aSdno);
            });

            setState(() {
              _desingingList = groupedList;
            });

            debugPrint(
                'Grouped into ${groupedList.length} unique design entries');

            // ✅ Debug: Print the combined values
            for (var entry in groupedList) {
              debugPrint(
                  'SDNO: ${entry.SPCNO}, SELENAME: ${entry.SPCNAME}, SFNAME: ${entry.SFNAME}');
            }
          } else {
            debugPrint('DesigningList is empty');
            setState(() {
              _desingingList = [];
            });
          }
        } else {
          debugPrint('API returned Success=false. Message: ${data['Message']}');
          setState(() {
            _desingingList = [];
          });
        }
      } else {
        debugPrint('Server error: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
        setState(() {
          _desingingList = [];
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching design entries: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _desingingList = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.primaryDark,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
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

  Future<void> _deleteDesigning(int spcNo) async {
    setState(() => _isLoading = true);

    try {
      final requestBody = {
        "SPCNO": spcNo,
        "DELUSER": empCode,
      };

      debugPrint('Soft deleting all entries for SPCNO: $spcNo');

      final response = await http.post(
        ApiUtils.getUri('DeletePClist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final data = jsonDecode(response.body);
      debugPrint('Delete response: $data');

      if (data['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message'] ?? 'Entry deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the list after deletion
        await _fetchDesigningEntries();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message'] ?? 'Failed to delete'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting: $e');
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

  Future<void> _showDeleteConfirmationDialog(int? spcNo) async {
    if (spcNo == null) return;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Project Control Entry'),
          content: Text('Are you sure you want to delete entry #$spcNo ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteDesigning(spcNo);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';

    try {
      // Parse the date string
      DateTime dateTime = DateTime.parse(dateString);
      // Format as DD/MM/YYYY
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      // If parsing fails, return original string or empty
      return dateString;
    }
  }

  Future<void> _generateSalesEntriesPDF(ProjectcontrolModel entry) async {
    // ✅ Parse sales entries from the entry data
    final List<ProjectcontrolModel> pcEntries = [];

    final elementNames = entry.SPCNAME
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    final elementTotals = entry.SPCTOT
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    final designTotals = entry.PCTOT
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    final remarks = entry.PCREMKS
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    for (int i = 0; i < elementNames.length; i++) {
      pcEntries.add(ProjectcontrolModel(
        SPCNAME: elementNames[i],
        SPCTOT: i < elementTotals.length ? elementTotals[i] : '0',
        PCTOT: i < designTotals.length ? designTotals[i] : '0',
        PCREMKS: i < remarks.length ? remarks[i] : '',
      ));
    }

    debugPrint('Parsed ${pcEntries.length} sales entries');

    if (pcEntries.isEmpty) {
      debugPrint('No sales entries found');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No sales entries to generate PDF'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pdf = pw.Document();

    final String formattedDate = getFileSafeDateTimeFormatted();
    final String fileName = "PC_Entry_${entry.SPCNO}_$formattedDate.pdf";
    debugPrint('Generated fileName: $fileName');

    // Format date
    String formatDate(DateTime? date) {
      if (date == null) return '-';
      return DateFormat('dd-MM-yyyy').format(date);
    }

    // Get customer and project names
    String customerName = '';
    String projectName = '';

    if (entry.CUSID != null) {
      final matchedCustomer = customerList.firstWhere(
        (c) => c.customerId == entry.CUSID,
        orElse: () {
          debugPrint('Customer not found in customerList, returning default');
          return ChecklistCustomer(customerId: 0, companyName: '');
        },
      );
      customerName = matchedCustomer.companyName;
      debugPrint('Customer name: $customerName');
    }

    if (entry.PROJID != null) {
      final matchedProject = projectList.firstWhere(
        (p) => p.projectId == entry.PROJID,
        orElse: () {
          debugPrint('Project not found in projectList, returning default');
          return Project(projectId: 0, projectName: '');
        },
      );
      projectName = matchedProject.projectName;
      debugPrint('Project name: $projectName');
    }

    // Calculate totals
    double totalSales = 0;
    double totalDesign = 0;
    for (var item in pcEntries) {
      totalSales +=
          double.tryParse(item.SPCTOT?.replaceAll(',', '') ?? '0') ?? 0;
      totalDesign +=
          double.tryParse(item.PCTOT?.replaceAll(',', '') ?? '0') ?? 0;
    }

    final headers = [
      'S.No',
      'Element Name',
      'Sales Qnty',
      'PC Qnty',
      'Remarks',
    ];

    final List<List<String>> data = [];
    debugPrint('Building data rows for ${pcEntries.length} entries...');

    for (int i = 0; i < pcEntries.length; i++) {
      final item = pcEntries[i];
      debugPrint(
          'Processing entry ${i + 1}/${pcEntries.length}: ${item.SPCNAME}');

      data.add([
        '${i + 1}',
        item.SPCNAME ?? '',
        item.SPCTOT ?? '',
        item.PCTOT ?? '',
        item.PCREMKS ?? '',
      ]);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.portrait,
        margin: const pw.EdgeInsets.all(8),
        build: (context) {
          // Build table rows with custom styling for total row
          final tableRows = <pw.TableRow>[];

          // Add header row - Increased font size to 10
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

          // Add data rows - CORRECTED INDEXES
          for (var row in data) {
            tableRows.add(
              pw.TableRow(
                children: [
                  // S.No (index 0)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[0],
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.center),
                  ),
                  // Element Name (index 1)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[1],
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.left),
                  ),
                  // Sales Qnty (index 2)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[2],
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.center),
                  ),
                  // PC Qnty (index 3)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[3],
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.center),
                  ),
                  // Remarks (index 4)
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(row[4],
                        style: const pw.TextStyle(fontSize: 9),
                        textAlign: pw.TextAlign.left),
                  ),
                ],
              ),
            );
          }

          // Add total row with background color
          tableRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('TOTAL',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.left),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalSales.toStringAsFixed(0),
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(totalDesign.toStringAsFixed(0),
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text('',
                      style: pw.TextStyle(
                          fontSize: 10, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.left),
                ),
              ],
            ),
          );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Main content - Expanded to push footer to bottom
              pw.Expanded(
                child: pw.Column(
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
                          // Entry No and Date on the SAME ROW
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(
                                width: 90,
                                child: pw.Text('Entry No',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 12)),
                              ),
                              pw.Expanded(
                                child: pw.Text(entry.SPCNO?.toString() ?? '-',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 12)),
                              ),
                              pw.Text('Date: ',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10)),
                              pw.Text(
                                  formatDate(entry.SPCDT != null
                                      ? DateTime.tryParse(entry.SPCDT!)
                                      : null),
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10)),
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
                                    customerName.isNotEmpty
                                        ? customerName
                                        : '-',
                                    style: const pw.TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),
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
                                child: pw.Text(
                                    projectName.isNotEmpty ? projectName : '-',
                                    style: const pw.TextStyle(fontSize: 12)),
                              ),
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
                ),
              ),
              // Footer at the bottom of the page
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 10),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        'Generated on: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        'Page ${context.pageNumber} of ${context.pagesCount}',
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    // ✅ Save/Download PDF
    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ PDF downloaded successfully!")),
      );
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final downloadsPath = await getDownloadsDirectory();
      if (downloadsPath != null) {
        final file = File('${downloadsPath.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ PDF saved to:\n${file.path}")),
        );
        await OpenFile.open(file.path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Could not access Downloads folder")),
        );
      }
    } else {
      // Mobile (Android/iOS)
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: "Design Entry Report - SDNO: ${entry.SPCNO}",
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF saved at: ${file.path}")),
        );
      }
    }
  }
}

class PCDownloadService {
  static Future<Map<String, dynamic>?> _getPCFiles({
    required int spcNo,
  }) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('GetPROJCTRLFiles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"SPCNO": spcNo}),
      );

      print('GetDesigningFiles Response: ${response.body}');

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

  static Future<void> downloadPCFiles({
    required BuildContext context,
    required int spcNo,
    String? salesFiles,
    String? designFiles,
  }) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting file information...'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 1),
      ),
    );

    // Get Sales files
    List<String> salesFileList = [];
    if (salesFiles != null && salesFiles.trim().isNotEmpty) {
      salesFileList = salesFiles.split(',').map((e) => e.trim()).toList();
    }

    // Get Design files
    List<String> designFileList = [];
    if (designFiles != null && designFiles.trim().isNotEmpty) {
      designFileList = designFiles.split(',').map((e) => e.trim()).toList();
    }

    // If no files provided, try to fetch from API
    if (salesFileList.isEmpty && designFileList.isEmpty) {
      final filesData = await _getPCFiles(spcNo: spcNo);

      if (filesData == null) {
        _showNoFilesDialog(context, spcNo);
        return;
      }

      // Get Sales files
      if (filesData['SDFNAME'] != null) {
        salesFileList = filesData['SDFNAME']
            .toString()
            .split(',')
            .map((e) => e.trim())
            .toList();
      }

      // Get Design files
      if (filesData['DDFNAME'] != null) {
        designFileList = filesData['DDFNAME']
            .toString()
            .split(',')
            .map((e) => e.trim())
            .toList();
      }

      if (salesFileList.isEmpty && designFileList.isEmpty) {
        _showNoFilesDialog(context, spcNo);
        return;
      }
    }

    // Combine all files for download
    final allFiles = [...salesFileList, ...designFileList];

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${allFiles.length} file(s)...'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );

    final List<String> success = [];
    final List<String> failed = [];

    for (final fileName in allFiles) {
      try {
        await _downloadFile(fileName, spcNo);
        success.add(fileName);
        print('✓ Downloaded: $fileName');
      } catch (e) {
        failed.add(fileName);
        print('✗ Failed: $fileName - $e');
      }
    }

    _showDownloadResult(context, success, failed);
  }

  static Future<void> _downloadFile(String fileName, int sdNo) async {
    try {
      print('Original filename from DB: "$fileName"');

      final response = await http.post(
        ApiUtils.getUri('DownloadPCFile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"fileName": fileName}),
      );

      print('Download API Request: fileName = "$fileName"');
      print('Download API Response Status: ${response.statusCode}');
      print('Download API Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (data['Success'] == true) {
        String base64String = data['FileBytes'];
        Uint8List fileBytes = base64Decode(base64String);

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

  static Future<String> _getSavePath(String fileName) async {
    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '${directory.path}/$fileName';
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$fileName';
    } else if (Platform.isWindows) {
      final downloadsPath = '${Platform.environment['USERPROFILE']}\\Downloads';
      final directory = Directory(downloadsPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '$downloadsPath\\$fileName';
    } else if (Platform.isMacOS) {
      final downloadsPath = '${Platform.environment['HOME']}/Downloads';
      final directory = Directory(downloadsPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '$downloadsPath/$fileName';
    } else {
      final directory = Directory('./downloads');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '${directory.path}/$fileName';
    }
  }

  static void _showNoFilesDialog(BuildContext context, int sdNo) {
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
          'Billing #$sdNo has no attached files.\n\n'
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
