import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';
import 'design_entry_screen.dart';
import 'dart:typed_data';

class ViewDesignScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const ViewDesignScreen({
    super.key,
    this.isSuperAdmin = false,
  });

  @override
  State<ViewDesignScreen> createState() => _ViewDesignScreenState();
}

class _ViewDesignScreenState extends State<ViewDesignScreen> {
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
  List<SalesDesignModel> _desingingList = [];
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
        title: const Text('View Designing List'),
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
                          itemCount: _desingingList.length,
                          itemBuilder: (context, index) {
                            return _buildDesingningCard(_desingingList[index]);
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

  Widget _buildDesingningCard(SalesDesignModel entry) {
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
              builder: (context) => DesignEntryScreen(
                designData: entry,
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
                      'Entry No - Dt: ${entry.sdno ?? 'N/A'} - ${_formatDate(entry.sddt)}',
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
                              builder: (context) => DesignEntryScreen(
                                designData: entry,
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
                              builder: (context) => DesignEntryScreen(
                                designData: entry,
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
                            _showDeleteConfirmationDialog(entry.sdno);
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

                      // ✅ Download Icon - Downloads BOTH Sales and Design files
                      IconButton(
                        onPressed: () async {
                          // ✅ Download both Sales and Design files
                          await DesigningDownloadService.downloadDesignFiles(
                            context: context,
                            sdNo: entry.sdno ?? 0,
                            salesFiles: entry.sfname, // Sales files
                            designFiles: entry.dfname, // Design files
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
                      'Entered By: ${getEmployeeName(entry.adduser)}',
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
                      'Entry Date: ${formatDate(entry.adddate)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

              /// Edited By
              if (entry.edituser != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 14, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Edited By: ${getEmployeeName(entry.edituser)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              /// Edit Date
              if (entry.editdate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Edit Date: ${formatDate(entry.editdate)}',
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

  Future<void> _showDeleteConfirmationDialog(int? sdno) async {
    if (sdno == null) return;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Billing Entry'),
          content: Text('Are you sure you want to delete Bill #$sdno?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteDesigning(sdno);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchDesigningEntries() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }

    try {
      final uri = ApiUtils.getUri('ViewSalesDesinginglist');

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
                .map(
                    (e) => SalesDesignModel.fromJson(e as Map<String, dynamic>))
                .toList();

            // ✅ GROUP BY SDNO - Combine all entries into one with comma-separated values
            final Map<int, SalesDesignModel> groupedEntries = {};

            for (var entry in entries) {
              final sdno = entry.sdno ?? 0;

              if (!groupedEntries.containsKey(sdno)) {
                // First entry for this SDNO - copy all data
                groupedEntries[sdno] = SalesDesignModel(
                  sdno: entry.sdno,
                  cusid: entry.cusid,
                  projid: entry.projid,
                  sddt: entry.sddt,
                  selename: entry.selename ?? '',
                  seleunit: entry.seleunit ?? '',
                  seletot: entry.seletot ?? '',
                  selesno: entry.selesno,
                  sfname: entry.sfname,
                  sftype: entry.sftype,
                  sfcount: entry.sfcount,
                  dfname: entry.dfname,
                  dftype: entry.dftype,
                  dfcount: entry.dfcount,
                  deleqnty: entry.deleqnty,
                  deletot: entry.deletot,
                  deleremks: entry.deleremks,
                  adduser: entry.adduser,
                  adddate: entry.adddate,
                  edituser: entry.edituser,
                  editdate: entry.editdate,
                );
              } else {
                // ✅ Combine data with existing entry (append to comma-separated lists)
                final existing = groupedEntries[sdno]!;

                // Combine SELENAME, SELEUNIT, SELETOT
                if (entry.selename != null && entry.selename!.isNotEmpty) {
                  if (existing.selename == null || existing.selename!.isEmpty) {
                    existing.selename = entry.selename;
                  } else {
                    existing.selename =
                        '${existing.selename},${entry.selename}';
                  }
                }
                if (entry.seleunit != null && entry.seleunit!.isNotEmpty) {
                  if (existing.seleunit == null || existing.seleunit!.isEmpty) {
                    existing.seleunit = entry.seleunit;
                  } else {
                    existing.seleunit =
                        '${existing.seleunit},${entry.seleunit}';
                  }
                }
                if (entry.seletot != null && entry.seletot!.isNotEmpty) {
                  if (existing.seletot == null || existing.seletot!.isEmpty) {
                    existing.seletot = entry.seletot;
                  } else {
                    existing.seletot = '${existing.seletot},${entry.seletot}';
                  }
                }

                // Combine file names (if different files)
                if (entry.sfname != null && entry.sfname!.isNotEmpty) {
                  if (existing.sfname == null || existing.sfname!.isEmpty) {
                    existing.sfname = entry.sfname;
                    existing.sftype = entry.sftype;
                    existing.sfcount = entry.sfcount;
                  } else if (!existing.sfname!.contains(entry.sfname!)) {
                    existing.sfname = '${existing.sfname},${entry.sfname}';
                  }
                }

                // ✅ Combine Design file names
                if (entry.dfname != null && entry.dfname!.isNotEmpty) {
                  if (existing.dfname == null || existing.dfname!.isEmpty) {
                    existing.dfname = entry.dfname;
                    existing.dftype = entry.dftype;
                    existing.dfcount = entry.dfcount;
                  } else if (!existing.dfname!.contains(entry.dfname!)) {
                    existing.dfname = '${existing.dfname},${entry.dfname}';
                  }
                }

                // Update SELESNO (total count of entries)
                existing.selesno = (existing.selesno ?? 0) + 1;
              }
            }

            // Convert grouped map back to list
            final groupedList = groupedEntries.values.toList();

            // Sort by SDNO descending (latest first)
            groupedList.sort((a, b) {
              final aSdno = a.sdno ?? 0;
              final bSdno = b.sdno ?? 0;
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
                  'SDNO: ${entry.sdno}, SELENAME: ${entry.selename}, SFNAME: ${entry.sfname}');
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

  Future<void> _deleteDesigning(int sdno) async {
    setState(() => _isLoading = true);

    try {
      final requestBody = {
        "SDNO": sdno,
        "DELUSER": empCode,
      };

      final response = await http.post(
        ApiUtils.getUri('DeleteSalesdesigninglist'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      final data = jsonDecode(response.body);

      if (data['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Designing entry deleted successfully'),
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
}

class DesigningDownloadService {
  static Future<Map<String, dynamic>?> _getDesigningFiles({
    required int sdNo,
  }) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('GetDesigningFiles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"SDNO": sdNo}),
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

  static Future<void> downloadDesignFiles({
    required BuildContext context,
    required int sdNo,
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
      final filesData = await _getDesigningFiles(sdNo: sdNo);

      if (filesData == null) {
        _showNoFilesDialog(context, sdNo);
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
        _showNoFilesDialog(context, sdNo);
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
        await _downloadFile(fileName, sdNo);
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
        ApiUtils.getUri('DownloaddesignFile'),
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
