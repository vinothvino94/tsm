import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/src/painting/box_border.dart' as box_border;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';

import '../../services/file_service.dart';
import '../../services/pdfgeneratorservice.dart';
import '../../services/prefrence_helper.dart';

import 'package:universal_html/html.dart' as html;
import 'package:path/path.dart' as p;

class TSReportScreen extends StatefulWidget {
  final String? initialStatus;
  const TSReportScreen({
    super.key,
    this.initialStatus,
  });

  @override
  State<TSReportScreen> createState() => TSReportScreenState();
}

class TSReportScreenState extends State<TSReportScreen> {
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final FileService _fileService = FileService();
  String selectedStatus = 'ALL';
  //String currentStatus = 'ALL';
  String? selectedDepartment;
  String? selectedtype;
  String? selectedworktype;
  final List<String> statusOptions = [
    'ALL',
    'SUBMITTED',
    'APPROVED',
    'REJECTED',
    'RECHECK',
    'FORWARDED',
    'REASSIGNED',
    'MAN POWER HOURS',
  ];
  final Map<int, String> deptMap = {
    1: 'DESIGNING',
    2: 'DRAFTING',
  };
  final List<String> typeOptions = [
    'NEW',
    'REWORK',
  ];
  final List<String> worktypeOptions = [
    'DRAWING',
    'CHECKING',
    'CORRECTION',
    'ISSUED'
  ];
  final TextEditingController _fromdateController = TextEditingController();
  final TextEditingController _todateController = TextEditingController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  TextEditingController eleidController = TextEditingController();
  bool _showTable = false;
  bool _isInitializing = true;
  bool _isSiteSelectionEnabled = true;

  List<Project> _projects = [];
  int? _projectId;
  int? _siteCode;
  late int empCode;
  String? _selectedProject;

  String? empPass, empSite, empBran, empName;
  List<Map<String, dynamic>> ticketDetails = [];
  List<dynamic> _departments = [];

  String ecNo = '';
  String eleid = '';
  List<dynamic> _tlList = [];
  String? selectedTL;
  bool isTLFilterApplied = false;
  //List<TimeSheet> _timeSheetList = [];
  bool isLoading = false;
  int? selectedDeptCode;

  String? selectedEmployee = 'ALL';

  List<Map<String, dynamic>> _employeeList = [];
  String? selectedTLCode;

  // Add these with your other state variables
  String? _sortColumn; // No default sorting initially
  bool _sortAscending = true;
  // Add these to your state class
  final Map<String, String> _siteCodeToProjectName = {};
  bool _isProjectMappingLoaded = false;

  // Add these class-level variables
  List<dynamic> _timeSheetTotals = [];
  bool _isLoadingTimeSheet = false;

  // Add this state variable
  bool _showManPowerHoursTable = false;

  List<SummaryReportModel> summaryList = [];
  bool isLoadingSummary = false;

  @override
  void initState() {
    super.initState();
    loadTimeSheetTothrs();
    _fetchTLDetails();
    _loadDepartments();
    _loadUserDetails().then((_) {
      return _initializeData();
    }).then((_) {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }).catchError((error) {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Initialization failed: $error')),
      );
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  /*@override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDeptFilterApplied = selectedDepartment != null;
    final bool isFromNotification = widget.initialStatus != null;
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          'Time Sheet Report',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          IconButton(
              icon: Icon(
                (kIsWeb || Platform.isWindows) ? Icons.download : Icons.share,
              ),
              onPressed: () {
                generateAndShareTSPdf(context);
              }),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: ListView(
            physics: BouncingScrollPhysics(),
            children: [
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fromdateController,
                      readOnly: true,
                      decoration: _inputDecoration('From Date').copyWith(
                        suffixIcon: Icon(Icons.calendar_today,
                            color: AppColors.primary),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Select From date'
                          : null,
                      onTap: _selectFromDate,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _todateController,
                      readOnly: true,
                      decoration: _inputDecoration('To Date').copyWith(
                        suffixIcon: Icon(Icons.calendar_today,
                            color: AppColors.primary),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Select To date' : null,
                      onTap: _selectToDate,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              _buildProjectDropdown(),
              SizedBox(height: 20),
              DropdownButtonFormField<int>(
                value: selectedDeptCode, // int? for Map keys
                decoration: _inputDecoration("Department").copyWith(
                  suffixIcon: selectedDeptCode != null
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              selectedDeptCode = null;
                            });
                          },
                          icon: const Icon(Icons.clear, size: 18),
                        )
                      : null,
                ),
                items: deptMap.entries.map((entry) {
                  return DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedDeptCode = value; // store the key
                  });
                },
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedTL,
                decoration: _inputDecoration("Team Lead").copyWith(
                  suffixIcon: isTLFilterApplied
                      ? IconButton(
                          onPressed: () async {
                            setState(() {
                              selectedTL = null;
                              selectedTLCode = null;
                              isTLFilterApplied = false;
                              _employeeList.clear();
                              selectedEmployee = null;
                              _employeeList.clear();
                              //_employeeController.clear();
                            });
                            await _fetchEmployeesByTL(null);
                            applyFilters();
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          padding: EdgeInsets.zero,
                          tooltip: 'Clear TL filter',
                        )
                      : null,
                ),
                items: _tlList.map<DropdownMenuItem<String>>((tl) {
                  final empName = (tl['EMPNAME'] ?? '').toString();
                  final empCode = (tl['EMPCODE'] ?? '').toString();
                  return DropdownMenuItem<String>(
                    value: empCode, // 👈 Store Team Lead Code
                    child: Text('$empCode - $empName'),
                  );
                }).toList(),
                onChanged: (value) async {
                  setState(() {
                    selectedTL = value;
                    selectedTLCode = value;
                    isTLFilterApplied = true;
                    selectedEmployee = null;
                    _employeeList.clear();
                  });
                  await _fetchEmployeesByTL(selectedTLCode!);
                  applyFilters();
                },
              ),
              SizedBox(height: 20),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _employeeList
                        .map((emp) => '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                        .toList();
                  } else {
                    return _employeeList
                        .where((emp) {
                          final empCode =
                              (emp['EMPCODE'] ?? '').toString().toLowerCase();
                          final empName =
                              (emp['EMPNAME'] ?? '').toString().toLowerCase();
                          final query = textEditingValue.text.toLowerCase();
                          return empCode.contains(query) ||
                              empName.contains(query);
                        })
                        .map((emp) => '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                        .toList();
                  }
                },
                displayStringForOption: (option) => option,
                fieldViewBuilder: (context, textEditingController, focusNode,
                    onFieldSubmitted) {
                  // Sync controller text with selectedEmployee
                  textEditingController.text = selectedEmployee != null
                      ? _employeeList
                              .where(
                                  (emp) => emp['EMPCODE'] == selectedEmployee)
                              .map((emp) =>
                                  '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                              .firstOrNull ??
                          ''
                      : '';

                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: _inputDecoration("Employee").copyWith(
                      // 👇 Show suffix icon only when an employee is selected
                      suffixIcon: (selectedEmployee != null &&
                              selectedEmployee!.isNotEmpty)
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: "Clear Employee",
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                textEditingController.clear();
                                setState(() {
                                  selectedEmployee = null;
                                });
                                applyFilters();
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setState(() {
                          selectedEmployee = null;
                        });
                        applyFilters();
                      }
                    },
                  );
                },
                onSelected: (String selectedOption) {
                  final empCode = selectedOption.split('-').first.trim();
                  setState(() {
                    selectedEmployee =
                        empCode; // 👈 triggers suffix icon to appear
                  });
                  applyFilters();
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: eleidController,
                decoration: _inputDecoration("Element Id").copyWith(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: eleidController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              eleidController.clear();
                              eleid = '';
                            });
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          tooltip: 'Clear Element Id',
                        )
                      : null,
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    eleid = value;
                  });
                },
              ),
              SizedBox(height: 20),
              if (kIsWeb || (Platform.isWindows))
                Row(
                  children: [
                    Expanded(
                        child: DropdownButtonFormField<String>(
                      value: selectedtype,
                      decoration: _inputDecoration("Type").copyWith(
                        suffixIcon: (selectedtype != null)
                            ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedtype = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear type filter',
                              )
                            : null,
                      ),
                      items: typeOptions.map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedtype = value;
                        });
                      },
                    )),
                    SizedBox(width: 16),
                    Expanded(
                        child: DropdownButtonFormField<String>(
                      value: selectedworktype,
                      decoration: _inputDecoration("Work Type").copyWith(
                        suffixIcon: (selectedworktype != null)
                            ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedworktype = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear Work type filter',
                              )
                            : null,
                      ),
                      items: worktypeOptions.map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedworktype = value;
                        });
                      },
                    )),
                  ],
                ),
              if (!kIsWeb && Platform.isAndroid)
                Wrap(
                  spacing: 16,
                  runSpacing: 20,
                  children: [
                    SizedBox(
                        width: 375, // fixed or min width
                        child: DropdownButtonFormField<String>(
                          value: selectedtype,
                          decoration: _inputDecoration("Type").copyWith(
                            suffixIcon: (selectedtype != null)
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        selectedtype = null;
                                      });
                                    },
                                    icon: const Icon(Icons.clear, size: 18),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear type filter',
                                  )
                                : null,
                          ),
                          items: typeOptions.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedtype = value;
                            });
                          },
                        )),
                    SizedBox(
                        width: 375,
                        child: DropdownButtonFormField<String>(
                          value: selectedworktype,
                          decoration: _inputDecoration("Work Type").copyWith(
                            suffixIcon: (selectedworktype != null)
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        selectedworktype = null;
                                      });
                                    },
                                    icon: const Icon(Icons.clear, size: 18),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear Work type filter',
                                  )
                                : null,
                          ),
                          items: worktypeOptions.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedworktype = value;
                            });
                          },
                        )),
                  ],
                ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: _inputDecoration("Status").copyWith(
                  // Add clear icon in suffix when status is selected and not from notification
                  suffixIcon:
                      !isFromNotification && selectedStatus != 'SUBMITTED'
                          ? IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedStatus = 'SUBMITTED';
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear status filter',
                            )
                          : null,
                ),
                items: statusOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedStatus = value!;
                  });
                },
              ),
              SizedBox(height: 36),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 5,
                            offset: Offset(2, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          if (_formKey.currentState!.validate()) {
                            loadTimeSheetList();
                            loadTimeSheetTothrs();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Please select From & To Date')),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Center(
                            child: Text(
                              'Submit',
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
              SizedBox(height: 20),
              if (_showTable) buildFixedHeaderTable(),
            ],
          ),
        ),
      ),
    );
  }*/

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDeptFilterApplied = selectedDepartment != null;
    final bool isFromNotification = widget.initialStatus != null;
    final isManPowerHours = selectedStatus.toUpperCase() == 'MAN POWER HOURS';
    final bool isSummaryReport = widget.initialStatus == "SUMMARY";

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          isSummaryReport
              ? 'Summary Report'
              : (isManPowerHours
                  ? 'Man Power Hours Report'
                  : 'Time Sheet Report'),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          // ✅ Summary Report Download
          if (isSummaryReport && !isLoadingSummary && summaryList.isNotEmpty)
            IconButton(
              icon: Icon(Icons.picture_as_pdf), // better icon for PDF
              onPressed: () {
                PDFGeneratorService.generateAndSharePDF(
                    context,
                    summaryList,
                    _fromdateController.text,
                    _todateController.text,
                    selectedworktype);
                //generateSummaryPdf(); // ✅ your method
              },
            ),
          if (isManPowerHours &&
              !_isLoadingTimeSheet &&
              _timeSheetTotals.isNotEmpty)
            IconButton(
              icon: Icon(Icons.download),
              onPressed: () {
                // Add download functionality for man power hours
                generateAndShareTSHoursReport(context);
              },
            ),
          if (!isManPowerHours && !isSummaryReport)
            IconButton(
                icon: Icon(
                  (kIsWeb || Platform.isWindows) ? Icons.download : Icons.share,
                ),
                onPressed: () {
                  generateAndShareTSPdf(context);
                  generateAndShareTSHoursReport(context);
                }),
        ],
        bottom: _isLoading || (isManPowerHours && _isLoadingTimeSheet)
            ? PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: ListView(
            physics: BouncingScrollPhysics(),
            children: [
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fromdateController,
                      readOnly: true,
                      decoration: _inputDecoration('From Date').copyWith(
                        suffixIcon: Icon(Icons.calendar_today,
                            color: AppColors.primary),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Select From date'
                          : null,
                      onTap: _selectFromDate,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _todateController,
                      readOnly: true,
                      decoration: _inputDecoration('To Date').copyWith(
                        suffixIcon: Icon(Icons.calendar_today,
                            color: AppColors.primary),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Select To date' : null,
                      onTap: _selectToDate,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              _buildProjectDropdown(),
              if (!isSummaryReport) ...[
                SizedBox(height: 20),
                DropdownButtonFormField<int>(
                  value: selectedDeptCode,
                  decoration: _inputDecoration("Department").copyWith(
                    suffixIcon: selectedDeptCode != null
                        ? IconButton(
                            onPressed: () {
                              setState(() {
                                selectedDeptCode = null;
                              });
                            },
                            icon: const Icon(Icons.clear, size: 18),
                          )
                        : null,
                  ),
                  items: deptMap.entries.map((entry) {
                    return DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDeptCode = value;
                    });
                  },
                ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedTL,
                  decoration: _inputDecoration("Team Lead").copyWith(
                    suffixIcon: isTLFilterApplied
                        ? IconButton(
                            onPressed: () async {
                              setState(() {
                                selectedTL = null;
                                selectedTLCode = null;
                                isTLFilterApplied = false;
                                _employeeList.clear();
                                selectedEmployee = null;
                                _employeeList.clear();
                              });
                              await _fetchEmployeesByTL(null);
                              applyFilters();
                            },
                            icon: const Icon(Icons.clear, size: 18),
                            padding: EdgeInsets.zero,
                            tooltip: 'Clear TL filter',
                          )
                        : null,
                  ),
                  items: _tlList.map<DropdownMenuItem<String>>((tl) {
                    final empName = (tl['EMPNAME'] ?? '').toString();
                    final empCode = (tl['EMPCODE'] ?? '').toString();
                    return DropdownMenuItem<String>(
                      value: empCode,
                      child: Text('$empCode - $empName'),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    setState(() {
                      selectedTL = value;
                      selectedTLCode = value;
                      isTLFilterApplied = true;
                      selectedEmployee = null;
                      _employeeList.clear();
                    });
                    await _fetchEmployeesByTL(selectedTLCode!);
                    applyFilters();
                  },
                ),
                SizedBox(height: 20),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _employeeList
                          .map((emp) => '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                          .toList();
                    } else {
                      return _employeeList
                          .where((emp) {
                            final empCode =
                                (emp['EMPCODE'] ?? '').toString().toLowerCase();
                            final empName =
                                (emp['EMPNAME'] ?? '').toString().toLowerCase();
                            final query = textEditingValue.text.toLowerCase();
                            return empCode.contains(query) ||
                                empName.contains(query);
                          })
                          .map((emp) => '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                          .toList();
                    }
                  },
                  displayStringForOption: (option) => option,
                  fieldViewBuilder: (context, textEditingController, focusNode,
                      onFieldSubmitted) {
                    textEditingController.text = selectedEmployee != null
                        ? _employeeList
                                .where(
                                    (emp) => emp['EMPCODE'] == selectedEmployee)
                                .map((emp) =>
                                    '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                                .firstOrNull ??
                            ''
                        : '';

                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: _inputDecoration("Employee").copyWith(
                        suffixIcon: (selectedEmployee != null &&
                                selectedEmployee!.isNotEmpty)
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                tooltip: "Clear Employee",
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  textEditingController.clear();
                                  setState(() {
                                    selectedEmployee = null;
                                  });
                                  applyFilters();
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          setState(() {
                            selectedEmployee = null;
                          });
                          applyFilters();
                        }
                      },
                    );
                  },
                  onSelected: (String selectedOption) {
                    final empCode = selectedOption.split('-').first.trim();
                    setState(() {
                      selectedEmployee = empCode;
                    });
                    applyFilters();
                  },
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: eleidController,
                  decoration: _inputDecoration("Element Id").copyWith(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: eleidController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              setState(() {
                                eleidController.clear();
                                eleid = '';
                              });
                            },
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: 'Clear Element Id',
                          )
                        : null,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      eleid = value;
                    });
                  },
                ),
                SizedBox(height: 20),
                // Inside your widget build method or wherever this code is
                if (kIsWeb || Platform.isWindows)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedtype,
                          decoration: _inputDecoration("Type").copyWith(
                            suffixIcon: (selectedtype != null)
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        selectedtype = null;
                                        selectedworktype =
                                            null; // Clear work type when type is cleared
                                      });
                                    },
                                    icon: const Icon(Icons.clear, size: 18),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear type filter',
                                  )
                                : null,
                          ),
                          items: typeOptions.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedtype = value;
                              selectedworktype =
                                  null; // Reset work type when type changes
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedworktype,
                          decoration: _inputDecoration("Work Type").copyWith(
                            suffixIcon: (selectedworktype != null)
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        selectedworktype = null;
                                      });
                                    },
                                    icon: const Icon(Icons.clear, size: 18),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear Work type filter',
                                  )
                                : null,
                          ),
                          items: getWorkTypeOptions(selectedtype).map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedworktype = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                if (!kIsWeb && Platform.isAndroid)
                  Wrap(
                    spacing: 16,
                    runSpacing: 20,
                    children: [
                      SizedBox(
                        width: 375,
                        child: DropdownButtonFormField<String>(
                          value: selectedtype,
                          decoration: _inputDecoration("Type").copyWith(
                            suffixIcon: (selectedtype != null)
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        selectedtype = null;
                                        selectedworktype =
                                            null; // Clear work type when type is cleared
                                      });
                                    },
                                    icon: const Icon(Icons.clear, size: 18),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear type filter',
                                  )
                                : null,
                          ),
                          items: typeOptions.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedtype = value;
                              selectedworktype =
                                  null; // Reset work type when type changes
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 375,
                        child: DropdownButtonFormField<String>(
                          value: selectedworktype,
                          decoration: _inputDecoration("Work Type").copyWith(
                            suffixIcon: (selectedworktype != null)
                                ? IconButton(
                                    onPressed: () {
                                      setState(() {
                                        selectedworktype = null;
                                      });
                                    },
                                    icon: const Icon(Icons.clear, size: 18),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear Work type filter',
                                  )
                                : null,
                          ),
                          items: getWorkTypeOptions(selectedtype).map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedworktype = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: _inputDecoration("Status").copyWith(
                    suffixIcon:
                        !isFromNotification && selectedStatus != 'SUBMITTED'
                            ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedStatus = 'SUBMITTED';
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear status filter',
                              )
                            : null,
                  ),
                  items: statusOptions.map((status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value!;
                      _showTable =
                          value == 'MAN POWER HOURS' ? false : _showTable;
                      if (value != 'MAN POWER HOURS') {
                        _showManPowerHoursTable = false;
                      }
                    });
                  },
                ),
              ],
              SizedBox(height: 20),

              // ✅ Show Work Type ONLY for Summary Report
              if (isSummaryReport) ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedworktype,
                        decoration: _inputDecoration("Work Type"),
                        items: getWorkTypeOptions(selectedtype).map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedworktype = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 20),

              _isLoading || (isManPowerHours && _isLoadingTimeSheet)
                  ? Center(child: CircularProgressIndicator())
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 5,
                            offset: Offset(2, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          if (isSummaryReport) {
                            // ✅ ONLY summary should run
                            if (_formKey.currentState!.validate()) {
                              loadSummaryReport();
                              setState(() {
                                _showTable = false;
                                _showManPowerHoursTable = false;
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please select From & To Date'),
                                ),
                              );
                            }
                          } else if (isManPowerHours) {
                            // ✅ Man Power Hours
                            loadTimeSheetTothrs();
                            setState(() {
                              _showTable = false;
                              _showManPowerHoursTable = true;
                            });
                          } else {
                            // ✅ Normal Report
                            if (_formKey.currentState!.validate()) {
                              loadTimeSheetList();
                              setState(() {
                                _showTable = true;
                                _showManPowerHoursTable = false;
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please select From & To Date'),
                                ),
                              );
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Center(
                            child: Text(
                              isManPowerHours ? 'Submit' : 'Submit',
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

              SizedBox(height: 36),
              // Show tables based on conditions
              if (isManPowerHours &&
                  _showManPowerHoursTable &&
                  !_isLoadingTimeSheet)
                buildTimeSheetHoursTable(),

              if (!isManPowerHours && _showTable && !_isLoading)
                buildFixedHeaderTable(),

              if (isSummaryReport && !isLoadingSummary) buildSummaryTable(),

              // Your regular timesheet table
            ],
          ),
        ),
      ),
    );
  }

  // Define work type options based on selected type
  List<String> getWorkTypeOptions(String? selectedType) {
    if (selectedType == 'NEW') {
      return ['DRAWING', 'CHECKING', 'CORRECTION', 'ISSUED'];
    } else if (selectedType == 'REWORK') {
      return [
        'REVISION',
        'RECTIFICATION',
        'DRAWING',
        'CHECKING',
        'CORRECTION',
        'ISSUED'
      ];
    }
    return ['DRAWING', 'CHECKING', 'CORRECTION', 'ISSUED']; // Default
  }

  Widget _buildProjectDropdown() {
    final TextEditingController _projectController = TextEditingController();

    try {
      return Autocomplete<Project>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Project>.empty();
          }
          return _projects.where((project) =>
              project.projectName
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase()) ||
              project.projectId.toString().contains(textEditingValue.text));
        },
        displayStringForOption: (project) =>
            '${project.projectId} - ${project.projectName}',
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
          if (textEditingController.text.isEmpty) {
            textEditingController.text = _projectController.text;
          }

          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            decoration: _inputDecoration("Project").copyWith(
              hintText: 'Search by site code or name...',
              suffixIcon: textEditingController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18),
                      onPressed: () {
                        textEditingController.clear();
                        setState(() {
                          _projectId = 0;
                          _selectedProject = '';
                        });
                      },
                    )
                  : null,
            ),
            enabled: _isSiteSelectionEnabled,
          );
        },
        onSelected: (Project selection) async {
          setState(() {
            _selectedProject = selection.projectName;
            _projectController.text =
                '${selection.projectId} - ${selection.projectName}';
          });

          try {
            final id = await _fileService.ProjectId(_selectedProject!);
            setState(() {
              _projectId = id;
              _showTable = false;
            });
          } catch (e) {
            setState(() {
              _projectId = 0;
              _showTable = false;
            });
          }
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Material(
            elevation: 4,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final project = options.elementAt(index);
                return ListTile(
                  title: Text('${project.projectId} - ${project.projectName}'),
                  subtitle: Text('Site Code: ${project.projectId}'),
                  onTap: () => onSelected(project),
                );
              },
            ),
          );
        },
      );
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading projects: $e')),
        );
      });
      return Container();
    }
  }

  // Input Decoration Method
  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        fillColor: Colors.white,
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

  Future<void> _loadUserDetails() async {
    final prefsHelper = PreferencesHelper();
    empCode = (await prefsHelper.getEmpCode()) ?? 0;
    empPass = await prefsHelper.getEmpPass();
    empName = await prefsHelper.getEmpName();
    empSite = (await prefsHelper.getEmpSite())?.toString();
    empBran = (await prefsHelper.getEmpBran())?.toString();

    _siteCode = int.tryParse(empSite ?? '0') ?? 0;

    if (_siteCode != null && _siteCode! > 0) {
      await _loadSiteName(_siteCode!);
    }
    await _loadProjects();

    setState(() {});
  }

  Future<void> _loadDepartments() async {
    try {
      final url = ApiUtils.getUri('GetDepartments');
      final response = await http.post(url);

      if (!mounted) return;
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['Success'] == true) {
          setState(() {
            _departments = json['Departments'] ?? [];
          });
        } else {
          throw Exception(json['Message'] ?? "Failed to load departments");
        }
      } else {
        throw Exception("Failed to load departments: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading departments: ${e.toString()}")),
      );
    }
  }

  Future<void> _fetchTLDetails() async {
    try {
      final url = ApiUtils.getUri('TLDetails');
      debugPrint("🔹 Fetching TL Details from: $url");

      final response = await http.post(url);

      debugPrint("🔹 Response Status Code: ${response.statusCode}");
      debugPrint("🔹 Raw Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['Success'] == true && data['TLDetails'] != null) {
          final List<dynamic> list = data['TLDetails'];

          // ✅ Ensure consistent map structure
          final List<Map<String, dynamic>> formattedList = list
              .map((e) => {
                    'EMPCODE': e['EMPCODE'].toString(),
                    'EMPNAME': e['EMPNAME'].toString(),
                  })
              .toList();

          setState(() {
            _tlList = formattedList;
          });

          debugPrint("✅ TL List Loaded: ${_tlList.length} entries");
        } else {
          debugPrint("❌ API Error: ${data['Message'] ?? 'Unknown error'}");
        }
      } else {
        debugPrint("❌ HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Exception in _fetchTLDetails: $e");
    }
  }

  Future<void> _fetchEmployeesByTL(String? teamLeadCode) async {
    try {
      final url = ApiUtils.getUri('EmployeeListByTeamLead');
      debugPrint("🔹 Fetching Employees for TL: $teamLeadCode from $url");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'HRIACCNO': teamLeadCode}), // ✅ fixed key name
      );

      debugPrint("🔹 Response Status Code: ${response.statusCode}");
      debugPrint("🔹 Raw Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['Success'] == true && data['EmployeeList'] != null) {
          final List<dynamic> list = data['EmployeeList'];

          // ✅ Normalize structure
          final formattedList = list
              .map((e) => {
                    'EMPCODE': e['EMPCODE'].toString(),
                    'EMPNAME': e['EMPNAME'].toString(),
                    'HRIACCNO': e['HRIACCNO'].toString(),
                    'HRIIFSCCODE': e['HRIIFSCCODE'].toString(),
                  })
              .toList();

          setState(() {
            _employeeList = formattedList;
          });

          debugPrint("✅ Employee List Loaded: ${_employeeList.length}");
        } else {
          debugPrint("❌ API Error: ${data['Message'] ?? 'Unknown error'}");
        }
      } else {
        debugPrint("❌ HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Exception in _fetchEmployeesByTL: $e");
    }
  }

  void applyFilters() {
    setState(() {
      isTLFilterApplied = selectedTL != null;
    });
  }

  Future<void> _initializeData() async {
    //print('Loading initial data...');
    try {
      await _loadProjects();

      if (_siteCode != null && _siteCode! > 0) {
        await _loadSiteName(_siteCode!);
      }

      print('Initial data loaded successfully');
    } catch (e) {
      print('Error loading initial data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load initial data: $e')),
      );
    }
  }

  Future<void> _loadProjects() async {
    try {
      setState(() => _isLoading = true);
      final projects = await _fileService.loadProjNames();

      final uniqueProjects = <Project>[];
      final names = <String>{};

      for (final project in projects) {
        _siteCodeToProjectName[project.projectId.toString()] =
            project.projectName;
        if (!names.contains(project.projectName)) {
          uniqueProjects.add(project);
          names.add(project.projectName);
        }
      }

      setState(() {
        _isProjectMappingLoaded = true;
        // Insert "All" option at the top
        _projects = [
          Project(projectId: 0, projectName: 'All'),
          ...uniqueProjects,
        ];

        if (_projects.isNotEmpty && _isSiteSelectionEnabled) {
          _selectedProject = _projects.first.projectName;
          _projectId = _projects.first.projectId;
        }
      });
    } catch (e) {
      print('Error loading projects: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load projects: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSiteName(int projectId) async {
    try {
      setState(() => _isLoading = true);
      final siteInfo = await _fileService.loadSiteName(projectId);

      if (siteInfo != null && siteInfo.isNotEmpty) {
        setState(() {
          _selectedProject = siteInfo.first['PROJECTNAME'] ?? 'Unknown Site';
          _projectId = projectId;
          _isSiteSelectionEnabled = false;
        });
      } else {
        setState(() {
          _selectedProject = null;
          _projectId = null;
          _isSiteSelectionEnabled = true;
        });
      }
    } catch (e) {
      print("Error loading site name: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load site: ${e.toString()}")),
      );
      setState(() {
        _selectedProject = null;
        _projectId = null;
        _isSiteSelectionEnabled = true;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Widget _buildProjectDropdown() {
  //   final TextEditingController _projectController = TextEditingController();
  //
  //   try {
  //     return Autocomplete<Project>(
  //       optionsBuilder: (TextEditingValue textEditingValue) {
  //         if (textEditingValue.text.isEmpty) {
  //           return const Iterable<Project>.empty();
  //         }
  //         return _projects.where((project) =>
  //             project.projectName
  //                 .toLowerCase()
  //                 .contains(textEditingValue.text.toLowerCase()) ||
  //             project.projectId.toString().contains(textEditingValue.text));
  //       },
  //       displayStringForOption: (project) =>
  //           '${project.projectId} - ${project.projectName}',
  //       fieldViewBuilder:
  //           (context, textEditingController, focusNode, onFieldSubmitted) {
  //         if (textEditingController.text.isEmpty) {
  //           textEditingController.text = _projectController.text;
  //         }
  //
  //         return TextFormField(
  //           controller: textEditingController,
  //           focusNode: focusNode,
  //           decoration: InputDecoration(
  //             labelText: 'Project',
  //             hintText: 'Search by site code or name...',
  //             border: OutlineInputBorder(),
  //             suffixIcon: textEditingController.text.isNotEmpty
  //                 ? IconButton(
  //                     icon: Icon(Icons.clear),
  //                     onPressed: () {
  //                       textEditingController.clear();
  //                       setState(() {
  //                         _projectId = 0;
  //                         _selectedProject = '';
  //                       });
  //                     },
  //                   )
  //                 : null,
  //           ),
  //           enabled: _isSiteSelectionEnabled,
  //         );
  //       },
  //       onSelected: (Project selection) async {
  //         setState(() {
  //           _selectedProject = selection.projectName;
  //           _projectController.text =
  //               '${selection.projectId} - ${selection.projectName}';
  //         });
  //
  //         try {
  //           final id = await _fileService.ProjectId(_selectedProject!);
  //           setState(() {
  //             _projectId = id;
  //             _showTable = false;
  //           });
  //         } catch (e) {
  //           setState(() {
  //             _projectId = 0;
  //             _showTable = false;
  //           });
  //         }
  //       },
  //       optionsViewBuilder: (context, onSelected, options) {
  //         return Material(
  //           elevation: 4,
  //           child: ListView.builder(
  //             padding: EdgeInsets.zero,
  //             itemCount: options.length,
  //             itemBuilder: (context, index) {
  //               final project = options.elementAt(index);
  //               return ListTile(
  //                 title: Text('${project.projectId} - ${project.projectName}'),
  //                 subtitle: Text('Site Code: ${project.projectId}'),
  //                 onTap: () => onSelected(project),
  //               );
  //             },
  //           ),
  //         );
  //       },
  //     );
  //   } catch (e) {
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error loading projects: $e')),
  //       );
  //     });
  //     return Container();
  //   }
  // }

  Future<void> _selectFromDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _fromdateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectToDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _todateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  InputDecoration _buildInputDecoration(String label, ColorScheme scheme) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outline),
      ),
    );
  }

  Widget buildFixedHeaderTable() {
    // ... (keep your existing variable declarations and checks)
    final isSubmittedStatus = selectedStatus.toUpperCase() == 'SUBMITTED';
    final isApprovedStatus = selectedStatus.toUpperCase() == 'APPROVED';
    final isRejectedStatus = selectedStatus.toUpperCase() == 'REJECTED';
    final isRecheckStatus = selectedStatus.toUpperCase() == 'RECHECK';
    final isReassignedStatus = selectedStatus.toUpperCase() == 'REASSIGNED';
    final isForwardStatus = selectedStatus.toUpperCase() == 'FORWARDED';
    List<dynamic> sortedTickets = _sortTicketData(ticketDetails);
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: true,
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Column(
                children: [
                  // Add Scrollbar here
                  SizedBox(
                    //height: MediaQuery.of(context).size.height - 470,
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true, // Always show the scrollbar
                      trackVisibility: true, // Show track as well
                      notificationPredicate: (notification) =>
                          notification.depth == 0,
                      thickness: 8, // Adjust thickness as needed
                      radius: Radius.circular(10), // Rounded corners
                      scrollbarOrientation:
                          ScrollbarOrientation.bottom, // Position at bottom
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// 🔷 Header Row
                            Container(
                              color: AppColors.primary,
                              child: Row(
                                children: isSubmittedStatus
                                    ? [
                                        _buildSortableHeaderCell(
                                            "S.No", 'INDEX', 70),
                                        _buildSortableHeaderCell(
                                            "EC No - Name", 'ADDUSER', 160),
                                        _buildSortableHeaderCell(
                                            "Project", 'SITECODE', 180),
                                        _buildSortableHeaderCell(
                                            "Element Id", 'ELEID', 150),
                                        _buildSortableHeaderCell(
                                            "Remarks", 'REMARKS', 150),
                                        _buildSortableHeaderCell(
                                            "Date & Time", 'ADDDATE', 120),
                                        _buildSortableHeaderCell(
                                            "Type", 'TYPE', 80),
                                        _buildSortableHeaderCell(
                                            "Work Type", 'WORKTYPE', 110),
                                        _buildSortableHeaderCell(
                                            "Department", 'DEPTCODE', 120),
                                        _buildSortableHeaderCell(
                                            "Team Lead", 'TLCODE', 160),
                                      ]
                                    : isApprovedStatus
                                        ? [
                                            _buildSortableHeaderCell(
                                                "S.No", 'INDEX', 60),
                                            _buildSortableHeaderCell(
                                                "EC No - Name", 'ADDUSER', 160),
                                            _buildSortableHeaderCell(
                                                "Project", 'SITECODE', 180),
                                            _buildSortableHeaderCell(
                                                "Element Id", 'ELEID', 150),
                                            _buildSortableHeaderCell(
                                                "Remarks", 'REMARKS', 150),
                                            _buildSortableHeaderCell(
                                                "Date & Time", 'ADDDATE', 120),
                                            _buildSortableHeaderCell(
                                                "Type", 'TYPE', 80),
                                            _buildSortableHeaderCell(
                                                "Work Type", 'WORKTYPE', 110),
                                            _buildSortableHeaderCell(
                                                "Department", 'DEPTCODE', 110),
                                            _buildSortableHeaderCell(
                                                "Team Lead", 'TLCODE', 160),
                                            _buildSortableHeaderCell(
                                                "Approved By", 'APPUSER', 160),
                                            _buildSortableHeaderCell(
                                                "App Date & Time",
                                                'APPDATE',
                                                140),
                                            _buildSortableHeaderCell(
                                                "App Remarks",
                                                'APPREMARKS',
                                                160),
                                          ]
                                        : isRejectedStatus
                                            ? [
                                                _buildSortableHeaderCell(
                                                    "S.No", 'INDEX', 60),
                                                _buildSortableHeaderCell(
                                                    "EC No - Name",
                                                    'ADDUSER',
                                                    160),
                                                _buildSortableHeaderCell(
                                                    "Project", 'SITECODE', 180),
                                                _buildSortableHeaderCell(
                                                    "Element Id", 'ELEID', 150),
                                                _buildSortableHeaderCell(
                                                    "Remarks", 'REMARKS', 150),
                                                _buildSortableHeaderCell(
                                                    "Date & Time",
                                                    'ADDDATE',
                                                    110),
                                                _buildSortableHeaderCell(
                                                    "Type", 'TYPE', 80),
                                                _buildSortableHeaderCell(
                                                    "Work Type",
                                                    'WORKTYPE',
                                                    110),
                                                _buildSortableHeaderCell(
                                                    "Department",
                                                    'DEPTCODE',
                                                    110),
                                                _buildSortableHeaderCell(
                                                    "Team Lead", 'TLCODE', 165),
                                                _buildSortableHeaderCell(
                                                    "Rejected By",
                                                    'APPUSER',
                                                    160),
                                                _buildSortableHeaderCell(
                                                    "Rej Date & Time",
                                                    'APPDATE',
                                                    140),
                                                _buildSortableHeaderCell(
                                                    "Rej Remarks",
                                                    'APPREMARKS',
                                                    160),
                                              ]
                                            : isRecheckStatus
                                                ? [
                                                    _buildSortableHeaderCell(
                                                        "S.No", 'INDEX', 60),
                                                    _buildSortableHeaderCell(
                                                        "EC No - Name",
                                                        'ADDUSER',
                                                        160),
                                                    _buildSortableHeaderCell(
                                                        "Project",
                                                        'SITECODE',
                                                        180),
                                                    _buildSortableHeaderCell(
                                                        "Element Id",
                                                        'ELEID',
                                                        150),
                                                    _buildSortableHeaderCell(
                                                        "Remarks",
                                                        'REMARKS',
                                                        150),
                                                    _buildSortableHeaderCell(
                                                        "Date & Time",
                                                        'ADDDATE',
                                                        110),
                                                    _buildSortableHeaderCell(
                                                        "Type", 'TYPE', 80),
                                                    _buildSortableHeaderCell(
                                                        "Work Type",
                                                        'WORKTYPE',
                                                        110),
                                                    _buildSortableHeaderCell(
                                                        "Department",
                                                        'DEPTCODE',
                                                        110),
                                                    _buildSortableHeaderCell(
                                                        "Team Lead",
                                                        'TLCODE',
                                                        165),
                                                    _buildSortableHeaderCell(
                                                        "Recheck By",
                                                        'RECHKUSER',
                                                        160),
                                                    _buildSortableHeaderCell(
                                                        "Rec Date & Time",
                                                        'RECHKDATE',
                                                        140),
                                                    _buildSortableHeaderCell(
                                                        "Rec Remarks",
                                                        'RECHKREMARKS',
                                                        160),
                                                  ]
                                                : isReassignedStatus
                                                    ? [
                                                        _buildSortableHeaderCell(
                                                            "S.No",
                                                            'INDEX',
                                                            60),
                                                        _buildSortableHeaderCell(
                                                            "EC No - Name",
                                                            'ADDUSER',
                                                            160),
                                                        _buildSortableHeaderCell(
                                                            "Project",
                                                            'SITECODE',
                                                            180),
                                                        _buildSortableHeaderCell(
                                                            "Element Id",
                                                            'ELEID',
                                                            150),
                                                        _buildSortableHeaderCell(
                                                            "Remarks",
                                                            'REMARKS',
                                                            150),
                                                        _buildSortableHeaderCell(
                                                            "Date & Time",
                                                            'ADDDATE',
                                                            120),
                                                        _buildSortableHeaderCell(
                                                            "Type", 'TYPE', 80),
                                                        _buildSortableHeaderCell(
                                                            "Work Type",
                                                            'WORKTYPE',
                                                            110),
                                                        _buildSortableHeaderCell(
                                                            "Department",
                                                            'DEPTCODE',
                                                            110),
                                                        _buildSortableHeaderCell(
                                                            "Team Lead",
                                                            'TLCODE',
                                                            160),
                                                        _buildSortableHeaderCell(
                                                            "Reassigned To",
                                                            'REASSIGNDATA',
                                                            160),
                                                      ]
                                                    : isForwardStatus
                                                        ? [
                                                            _buildSortableHeaderCell(
                                                                "S.No",
                                                                'INDEX',
                                                                60),
                                                            _buildSortableHeaderCell(
                                                                "EC No - Name",
                                                                'ADDUSER',
                                                                160),
                                                            _buildSortableHeaderCell(
                                                                "Project",
                                                                'SITECODE',
                                                                180),
                                                            _buildSortableHeaderCell(
                                                                "Element Id",
                                                                'ELEID',
                                                                150),
                                                            _buildSortableHeaderCell(
                                                                "Remarks",
                                                                'REMARKS',
                                                                150),
                                                            _buildSortableHeaderCell(
                                                                "Date & Time",
                                                                'ADDDATE',
                                                                120),
                                                            _buildSortableHeaderCell(
                                                                "Type",
                                                                'TYPE',
                                                                80),
                                                            _buildSortableHeaderCell(
                                                                "Work Type",
                                                                'WORKTYPE',
                                                                110),
                                                            _buildSortableHeaderCell(
                                                                "Department",
                                                                'DEPTCODE',
                                                                110),
                                                            _buildSortableHeaderCell(
                                                                "Team Lead",
                                                                'TLCODE',
                                                                160),
                                                            _buildSortableHeaderCell(
                                                                "Forwarded To",
                                                                'REASSIGNDATA',
                                                                160),
                                                          ]
                                                        : [
                                                            _buildSortableHeaderCell(
                                                                "S.No",
                                                                'INDEX',
                                                                55),
                                                            _buildSortableHeaderCell(
                                                                "EC No - Name",
                                                                'ADDUSER',
                                                                160),
                                                            _buildSortableHeaderCell(
                                                                "Project",
                                                                'SITECODE',
                                                                140),
                                                            _buildSortableHeaderCell(
                                                                "Element Id",
                                                                'ELEID',
                                                                100),
                                                            _buildSortableHeaderCell(
                                                                "Remarks",
                                                                'REMARKS',
                                                                100),
                                                            _buildSortableHeaderCell(
                                                                "Date & Time",
                                                                'ADDDATE',
                                                                160),
                                                            _buildSortableHeaderCell(
                                                                "Type",
                                                                'TYPE',
                                                                80),
                                                            _buildSortableHeaderCell(
                                                                "Work Type",
                                                                'WORKTYPE',
                                                                110),
                                                            _buildSortableHeaderCell(
                                                                "Department",
                                                                'DEPTCODE',
                                                                110),
                                                            _buildSortableHeaderCell(
                                                                "Team Lead",
                                                                'TLCODE',
                                                                160),
                                                            _buildSortableHeaderCell(
                                                                "Approved By",
                                                                'APPUSER',
                                                                160),
                                                            _buildSortableHeaderCell(
                                                                "App Date & Time",
                                                                'APPDATE',
                                                                150),
                                                            _buildSortableHeaderCell(
                                                                "App Remarks",
                                                                'APPREMARKS',
                                                                120),
                                                            _buildSortableHeaderCell(
                                                                "Recheck By",
                                                                'RECHKUSER',
                                                                160),
                                                            _buildSortableHeaderCell(
                                                                "Rec Date & Time",
                                                                'RECHKDATE',
                                                                150),
                                                            _buildSortableHeaderCell(
                                                                "Rec Remarks",
                                                                'RECHKREMARKS',
                                                                120),
                                                            _buildSortableHeaderCell(
                                                                "Status",
                                                                'TSSTATUS',
                                                                120),
                                                          ],
                              ),
                            ),
                            const SizedBox(height: 5),

                            /// 🔷 Data Rows
                            SizedBox(
                              height: MediaQuery.of(context).size.height - 470,
                              child: SingleChildScrollView(
                                child: Column(
                                  children: List.generate(sortedTickets.length,
                                      (index) {
                                    final expense = sortedTickets[index];
                                    return IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: isSubmittedStatus
                                            ? [
                                                buildDataCell(
                                                    '${index + 1}', 70),
                                                Center(
                                                  child: FutureBuilder<String>(
                                                    future: _fileService
                                                        .getEmpNameByCode(
                                                            expense['ADDUSER']
                                                                .toString()),
                                                    builder:
                                                        (context, snapshot) {
                                                      final name =
                                                          snapshot.hasData
                                                              ? snapshot.data!
                                                              : 'Loading...';
                                                      return buildDataCell(
                                                          name, 160);
                                                    },
                                                  ),
                                                ),
                                                Center(
                                                  child: FutureBuilder<String>(
                                                    future: _fetchSiteName(
                                                        expense['SITECODE']
                                                            .toString()),
                                                    builder:
                                                        (context, snapshot) {
                                                      final name = snapshot
                                                              .hasData
                                                          ? snapshot.data!
                                                          : _siteCodeToProjectName[
                                                                  expense['SITECODE']
                                                                      ?.toString()] ??
                                                              'Loading...';
                                                      return buildDataCell(
                                                          name, 180);
                                                    },
                                                  ),
                                                ),
                                                buildDataCell(
                                                    expense['ELEID']
                                                            ?.toString() ??
                                                        '',
                                                    150),
                                                buildDataCell(
                                                    expense['REMARKS']
                                                            ?.toString() ??
                                                        '',
                                                    150),
                                                buildDataCell(
                                                  _formatDate(
                                                      expense['ADDDATE'],
                                                      includeTime: true),
                                                  120,
                                                ),
                                                buildDataCell(
                                                    expense['TYPE']
                                                            ?.toString() ??
                                                        '',
                                                    80),
                                                buildDataCell(
                                                    expense['WORKTYPE']
                                                            ?.toString() ??
                                                        '',
                                                    110),
                                                buildDataCell(
                                                  getDeptName(int.tryParse(
                                                      expense['DEPTCODE']
                                                              ?.toString() ??
                                                          '')),
                                                  120,
                                                ),
                                                Center(
                                                  child: FutureBuilder<String>(
                                                    future: _fileService
                                                        .getEmpNameByCode(expense[
                                                                    'TLCODE']
                                                                ?.toString() ??
                                                            ''),
                                                    builder:
                                                        (context, snapshot) {
                                                      final name = snapshot
                                                              .hasData
                                                          ? snapshot.data!
                                                          : ''; // Return an empty string if TLCODE is null
                                                      return buildDataCell(
                                                          name, 160);
                                                    },
                                                  ),
                                                ),
                                              ]
                                            : isApprovedStatus
                                                ? [
                                                    buildDataCell(
                                                        '${index + 1}', 60),
                                                    Center(
                                                      child:
                                                          FutureBuilder<String>(
                                                        future: _fileService
                                                            .getEmpNameByCode(
                                                                expense['ADDUSER']
                                                                    .toString()),
                                                        builder: (context,
                                                            snapshot) {
                                                          final name = snapshot
                                                                  .hasData
                                                              ? snapshot.data!
                                                              : 'Loading...';
                                                          return buildDataCell(
                                                              name, 160);
                                                        },
                                                      ),
                                                    ),
                                                    Center(
                                                      child:
                                                          FutureBuilder<String>(
                                                        future: _fetchSiteName(
                                                            expense['SITECODE']
                                                                .toString()),
                                                        builder: (context,
                                                            snapshot) {
                                                          final name = snapshot
                                                                  .hasData
                                                              ? snapshot.data!
                                                              : _siteCodeToProjectName[
                                                                      expense['SITECODE']
                                                                          ?.toString()] ??
                                                                  'Loading...';
                                                          return buildDataCell(
                                                              name, 180);
                                                        },
                                                      ),
                                                    ),
                                                    buildDataCell(
                                                        expense['ELEID']
                                                                ?.toString() ??
                                                            '',
                                                        150),
                                                    buildDataCell(
                                                        expense['REMARKS']
                                                                ?.toString() ??
                                                            '',
                                                        150),
                                                    buildDataCell(
                                                      _formatDate(
                                                          expense['ADDDATE'],
                                                          includeTime: true),
                                                      120,
                                                    ),
                                                    buildDataCell(
                                                        expense['TYPE']
                                                                ?.toString() ??
                                                            '',
                                                        80),
                                                    buildDataCell(
                                                        expense['WORKTYPE']
                                                                ?.toString() ??
                                                            '',
                                                        110),
                                                    buildDataCell(
                                                      getDeptName(int.tryParse(
                                                          expense['DEPTCODE']
                                                                  ?.toString() ??
                                                              '')),
                                                      110,
                                                    ),
                                                    Center(
                                                      child:
                                                          FutureBuilder<String>(
                                                        future: _fileService
                                                            .getEmpNameByCode(
                                                                expense['TLCODE']
                                                                        ?.toString() ??
                                                                    ''),
                                                        builder: (context,
                                                            snapshot) {
                                                          final name = snapshot
                                                                  .hasData
                                                              ? snapshot.data!
                                                              : ''; // Return an empty string if TLCODE is null
                                                          return buildDataCell(
                                                              name, 160);
                                                        },
                                                      ),
                                                    ),
                                                    Center(
                                                      child:
                                                          FutureBuilder<String>(
                                                        future: _fileService
                                                            .getEmpNameByCode(
                                                                expense['APPUSER']
                                                                    .toString()),
                                                        builder: (context,
                                                            snapshot) {
                                                          final name = snapshot
                                                                  .hasData
                                                              ? snapshot.data!
                                                              : 'Loading...';
                                                          return buildDataCell(
                                                              name, 160);
                                                        },
                                                      ),
                                                    ),
                                                    buildDataCell(
                                                      _formatDate(
                                                          expense['APPDATE'],
                                                          includeTime: true),
                                                      140,
                                                    ),
                                                    buildDataCell(
                                                        expense['APPREMARKS']
                                                                ?.toString() ??
                                                            '',
                                                        160),
                                                  ]
                                                : isRejectedStatus
                                                    ? [
                                                        buildDataCell(
                                                            '${index + 1}', 60),
                                                        Center(
                                                          child: FutureBuilder<
                                                              String>(
                                                            future: _fileService
                                                                .getEmpNameByCode(
                                                                    expense['ADDUSER']
                                                                        .toString()),
                                                            builder: (context,
                                                                snapshot) {
                                                              final name = snapshot
                                                                      .hasData
                                                                  ? snapshot
                                                                      .data!
                                                                  : 'Loading...';
                                                              return buildDataCell(
                                                                  name, 160);
                                                            },
                                                          ),
                                                        ),
                                                        Center(
                                                          child: FutureBuilder<
                                                              String>(
                                                            future: _fetchSiteName(
                                                                expense['SITECODE']
                                                                    .toString()),
                                                            builder: (context,
                                                                snapshot) {
                                                              final name = snapshot
                                                                      .hasData
                                                                  ? snapshot
                                                                      .data!
                                                                  : _siteCodeToProjectName[
                                                                          expense['SITECODE']
                                                                              ?.toString()] ??
                                                                      'Loading...';
                                                              return buildDataCell(
                                                                  name, 180);
                                                            },
                                                          ),
                                                        ),
                                                        buildDataCell(
                                                            expense['ELEID']
                                                                    ?.toString() ??
                                                                '',
                                                            150),
                                                        buildDataCell(
                                                            expense['REMARKS']
                                                                    ?.toString() ??
                                                                '',
                                                            150),
                                                        buildDataCell(
                                                          _formatDate(
                                                              expense[
                                                                  'ADDDATE'],
                                                              includeTime:
                                                                  true),
                                                          110,
                                                        ),
                                                        buildDataCell(
                                                            expense['TYPE']
                                                                    ?.toString() ??
                                                                '',
                                                            80),
                                                        buildDataCell(
                                                            expense['WORKTYPE']
                                                                    ?.toString() ??
                                                                '',
                                                            110),
                                                        buildDataCell(
                                                          getDeptName(int.tryParse(
                                                              expense['DEPTCODE']
                                                                      ?.toString() ??
                                                                  '')),
                                                          110,
                                                        ),
                                                        Center(
                                                          child: FutureBuilder<
                                                              String>(
                                                            future: _fileService
                                                                .getEmpNameByCode(
                                                                    expense['TLCODE']
                                                                            ?.toString() ??
                                                                        ''),
                                                            builder: (context,
                                                                snapshot) {
                                                              final name = snapshot
                                                                      .hasData
                                                                  ? snapshot
                                                                      .data!
                                                                  : ''; // Return an empty string if TLCODE is null
                                                              return buildDataCell(
                                                                  name, 160);
                                                            },
                                                          ),
                                                        ),
                                                        Center(
                                                          child: FutureBuilder<
                                                              String>(
                                                            future: _fileService
                                                                .getEmpNameByCode(
                                                                    expense['APPUSER']
                                                                        .toString()),
                                                            builder: (context,
                                                                snapshot) {
                                                              final name = snapshot
                                                                      .hasData
                                                                  ? snapshot
                                                                      .data!
                                                                  : 'Loading...';
                                                              return buildDataCell(
                                                                  name, 160);
                                                            },
                                                          ),
                                                        ),
                                                        buildDataCell(
                                                          _formatDate(
                                                              expense[
                                                                  'APPDATE'],
                                                              includeTime:
                                                                  true),
                                                          140,
                                                        ),
                                                        buildDataCell(
                                                            expense['APPREMARKS']
                                                                    ?.toString() ??
                                                                '',
                                                            160),
                                                      ]
                                                    : isRecheckStatus
                                                        ? [
                                                            buildDataCell(
                                                                '${index + 1}',
                                                                60),
                                                            Center(
                                                              child:
                                                                  FutureBuilder<
                                                                      String>(
                                                                future: _fileService
                                                                    .getEmpNameByCode(
                                                                        expense['ADDUSER']
                                                                            .toString()),
                                                                builder: (context,
                                                                    snapshot) {
                                                                  final name = snapshot
                                                                          .hasData
                                                                      ? snapshot
                                                                          .data!
                                                                      : 'Loading...';
                                                                  return buildDataCell(
                                                                      name,
                                                                      160);
                                                                },
                                                              ),
                                                            ),
                                                            Center(
                                                              child:
                                                                  FutureBuilder<
                                                                      String>(
                                                                future: _fetchSiteName(
                                                                    expense['SITECODE']
                                                                        .toString()),
                                                                builder: (context,
                                                                    snapshot) {
                                                                  final name = snapshot.hasData
                                                                      ? snapshot
                                                                          .data!
                                                                      : _siteCodeToProjectName[
                                                                              expense['SITECODE']?.toString()] ??
                                                                          'Loading...';
                                                                  return buildDataCell(
                                                                      name,
                                                                      180);
                                                                },
                                                              ),
                                                            ),
                                                            buildDataCell(
                                                                expense['ELEID']
                                                                        ?.toString() ??
                                                                    '',
                                                                150),
                                                            buildDataCell(
                                                                expense['REMARKS']
                                                                        ?.toString() ??
                                                                    '',
                                                                150),
                                                            buildDataCell(
                                                              _formatDate(
                                                                  expense[
                                                                      'ADDDATE'],
                                                                  includeTime:
                                                                      true),
                                                              110,
                                                            ),
                                                            buildDataCell(
                                                                expense['TYPE']
                                                                        ?.toString() ??
                                                                    '',
                                                                80),
                                                            buildDataCell(
                                                                expense['WORKTYPE']
                                                                        ?.toString() ??
                                                                    '',
                                                                110),
                                                            buildDataCell(
                                                              getDeptName(int.tryParse(
                                                                  expense['DEPTCODE']
                                                                          ?.toString() ??
                                                                      '')),
                                                              110,
                                                            ),
                                                            Center(
                                                              child:
                                                                  FutureBuilder<
                                                                      String>(
                                                                future: _fileService
                                                                    .getEmpNameByCode(
                                                                        expense['TLCODE']?.toString() ??
                                                                            ''),
                                                                builder: (context,
                                                                    snapshot) {
                                                                  final name = snapshot
                                                                          .hasData
                                                                      ? snapshot
                                                                          .data!
                                                                      : ''; // Return an empty string if TLCODE is null
                                                                  return buildDataCell(
                                                                      name,
                                                                      160);
                                                                },
                                                              ),
                                                            ),
                                                            Center(
                                                              child:
                                                                  FutureBuilder<
                                                                      String>(
                                                                future: _fileService
                                                                    .getEmpNameByCode(
                                                                        expense['RECHKUSER']?.toString() ??
                                                                            ''),
                                                                builder: (context,
                                                                    snapshot) {
                                                                  final name = snapshot
                                                                          .hasData
                                                                      ? snapshot
                                                                          .data!
                                                                      : ''; // Return an empty string if TLCODE is null
                                                                  return buildDataCell(
                                                                      name,
                                                                      160);
                                                                },
                                                              ),
                                                            ),
                                                            buildDataCell(
                                                              _formatDate(
                                                                  expense[
                                                                      'RECHKDATE'],
                                                                  includeTime:
                                                                      true),
                                                              140,
                                                            ),
                                                            buildDataCell(
                                                                expense['RECHKREMARKS']
                                                                        ?.toString() ??
                                                                    '',
                                                                160),
                                                          ]
                                                        : isReassignedStatus
                                                            ? [
                                                                buildDataCell(
                                                                    '${index + 1}',
                                                                    60),
                                                                Center(
                                                                  child:
                                                                      FutureBuilder<
                                                                          String>(
                                                                    future: _fileService
                                                                        .getEmpNameByCode(
                                                                            expense['ADDUSER'].toString()),
                                                                    builder:
                                                                        (context,
                                                                            snapshot) {
                                                                      final name = snapshot
                                                                              .hasData
                                                                          ? snapshot
                                                                              .data!
                                                                          : 'Loading...';
                                                                      return buildDataCell(
                                                                          name,
                                                                          160);
                                                                    },
                                                                  ),
                                                                ),
                                                                Center(
                                                                  child:
                                                                      FutureBuilder<
                                                                          String>(
                                                                    future: _fetchSiteName(
                                                                        expense['SITECODE']
                                                                            .toString()),
                                                                    builder:
                                                                        (context,
                                                                            snapshot) {
                                                                      final name = snapshot.hasData
                                                                          ? snapshot
                                                                              .data!
                                                                          : _siteCodeToProjectName[expense['SITECODE']?.toString()] ??
                                                                              'Loading...';
                                                                      return buildDataCell(
                                                                          name,
                                                                          180);
                                                                    },
                                                                  ),
                                                                ),
                                                                buildDataCell(
                                                                    expense['ELEID']
                                                                            ?.toString() ??
                                                                        '',
                                                                    150),
                                                                buildDataCell(
                                                                    expense['REMARKS']
                                                                            ?.toString() ??
                                                                        '',
                                                                    150),
                                                                buildDataCell(
                                                                  _formatDate(
                                                                      expense[
                                                                          'ADDDATE'],
                                                                      includeTime:
                                                                          true),
                                                                  120,
                                                                ),
                                                                buildDataCell(
                                                                    expense['TYPE']
                                                                            ?.toString() ??
                                                                        '',
                                                                    80),
                                                                buildDataCell(
                                                                    expense['WORKTYPE']
                                                                            ?.toString() ??
                                                                        '',
                                                                    110),
                                                                buildDataCell(
                                                                  getDeptName(int
                                                                      .tryParse(
                                                                          expense['DEPTCODE']?.toString() ??
                                                                              '')),
                                                                  110,
                                                                ),
                                                                Center(
                                                                  child:
                                                                      FutureBuilder<
                                                                          String>(
                                                                    future: _fileService.getEmpNameByCode(
                                                                        expense['TLCODE']?.toString() ??
                                                                            ''),
                                                                    builder:
                                                                        (context,
                                                                            snapshot) {
                                                                      final name = snapshot
                                                                              .hasData
                                                                          ? snapshot
                                                                              .data!
                                                                          : ''; // Return an empty string if TLCODE is null
                                                                      return buildDataCell(
                                                                          name,
                                                                          160);
                                                                    },
                                                                  ),
                                                                ),
                                                                buildDataCell(
                                                                    expense['REASSIGNDATA']
                                                                            ?.toString() ??
                                                                        '',
                                                                    160),
                                                              ]
                                                            : isForwardStatus
                                                                ? [
                                                                    buildDataCell(
                                                                        '${index + 1}',
                                                                        60),
                                                                    Center(
                                                                      child: FutureBuilder<
                                                                          String>(
                                                                        future:
                                                                            _fileService.getEmpNameByCode(expense['ADDUSER'].toString()),
                                                                        builder:
                                                                            (context,
                                                                                snapshot) {
                                                                          final name = snapshot.hasData
                                                                              ? snapshot.data!
                                                                              : 'Loading...';
                                                                          return buildDataCell(
                                                                              name,
                                                                              160);
                                                                        },
                                                                      ),
                                                                    ),
                                                                    Center(
                                                                      child: FutureBuilder<
                                                                          String>(
                                                                        future:
                                                                            _fetchSiteName(expense['SITECODE'].toString()),
                                                                        builder:
                                                                            (context,
                                                                                snapshot) {
                                                                          final name = snapshot.hasData
                                                                              ? snapshot.data!
                                                                              : _siteCodeToProjectName[expense['SITECODE']?.toString()] ?? 'Loading...';
                                                                          return buildDataCell(
                                                                              name,
                                                                              180);
                                                                        },
                                                                      ),
                                                                    ),
                                                                    buildDataCell(
                                                                        expense['ELEID']?.toString() ??
                                                                            '',
                                                                        150),
                                                                    buildDataCell(
                                                                        expense['REMARKS']?.toString() ??
                                                                            '',
                                                                        150),
                                                                    buildDataCell(
                                                                      _formatDate(
                                                                          expense[
                                                                              'ADDDATE'],
                                                                          includeTime:
                                                                              true),
                                                                      120,
                                                                    ),
                                                                    buildDataCell(
                                                                        expense['TYPE']?.toString() ??
                                                                            '',
                                                                        80),
                                                                    buildDataCell(
                                                                        expense['WORKTYPE']?.toString() ??
                                                                            '',
                                                                        110),
                                                                    buildDataCell(
                                                                      getDeptName(int.tryParse(
                                                                          expense['DEPTCODE']?.toString() ??
                                                                              '')),
                                                                      110,
                                                                    ),
                                                                    Center(
                                                                      child: FutureBuilder<
                                                                          String>(
                                                                        future: _fileService.getEmpNameByCode(expense['TLCODE']?.toString() ??
                                                                            ''),
                                                                        builder:
                                                                            (context,
                                                                                snapshot) {
                                                                          final name = snapshot.hasData
                                                                              ? snapshot.data!
                                                                              : ''; // Return an empty string if TLCODE is null
                                                                          return buildDataCell(
                                                                              name,
                                                                              160);
                                                                        },
                                                                      ),
                                                                    ),
                                                                    buildDataCell(
                                                                        expense['REASSIGNDATA']?.toString() ??
                                                                            '',
                                                                        160),
                                                                  ]
                                                                : [
                                                                    buildDataCell(
                                                                        '${index + 1}',
                                                                        55),
                                                                    FutureBuilder<
                                                                        String>(
                                                                      future: _fileService
                                                                          .getEmpNameByCode(
                                                                              expense['ADDUSER'].toString()),
                                                                      builder:
                                                                          (context,
                                                                              snapshot) {
                                                                        final name = snapshot.hasData
                                                                            ? snapshot.data!
                                                                            : 'Loading...';
                                                                        return buildDataCell(
                                                                            name,
                                                                            160);
                                                                      },
                                                                    ),
                                                                    Center(
                                                                      child: FutureBuilder<
                                                                          String>(
                                                                        future:
                                                                            _fetchSiteName(expense['SITECODE'].toString()),
                                                                        builder:
                                                                            (context,
                                                                                snapshot) {
                                                                          final name = snapshot.hasData
                                                                              ? snapshot.data!
                                                                              : _siteCodeToProjectName[expense['SITECODE']?.toString()] ?? 'Loading...';
                                                                          return buildDataCell(
                                                                              name,
                                                                              140);
                                                                        },
                                                                      ),
                                                                    ),
                                                                    buildDataCell(
                                                                        expense['ELEID']?.toString() ??
                                                                            '',
                                                                        100),
                                                                    buildDataCell(
                                                                        expense['REMARKS']?.toString() ??
                                                                            '',
                                                                        100),
                                                                    buildDataCell(
                                                                      _formatDate(expense['ADDDATE'],
                                                                              includeTime:
                                                                                  true)
                                                                          .replaceFirst(
                                                                              ' ',
                                                                              '\n'),
                                                                      160,
                                                                    ),
                                                                    buildDataCell(
                                                                        expense['TYPE']?.toString() ??
                                                                            '',
                                                                        80),
                                                                    buildDataCell(
                                                                        expense['WORKTYPE']?.toString() ??
                                                                            '',
                                                                        110),
                                                                    buildDataCell(
                                                                      getDeptName(int.tryParse(
                                                                          expense['DEPTCODE']?.toString() ??
                                                                              '')),
                                                                      110,
                                                                    ),
                                                                    Center(
                                                                      child: FutureBuilder<
                                                                          String>(
                                                                        future: _fileService.getEmpNameByCode(expense['TLCODE']?.toString() ??
                                                                            ''),
                                                                        builder:
                                                                            (context,
                                                                                snapshot) {
                                                                          final name = snapshot.hasData
                                                                              ? snapshot.data!
                                                                              : ''; // Return an empty string if TLCODE is null
                                                                          return buildDataCell(
                                                                              name,
                                                                              160);
                                                                        },
                                                                      ),
                                                                    ),
                                                                    Center(
                                                                      child: FutureBuilder<
                                                                          String>(
                                                                        future: _fileService.getEmpNameByCode(expense['APPUSER']?.toString() ??
                                                                            ''),
                                                                        builder:
                                                                            (context,
                                                                                snapshot) {
                                                                          final name = snapshot.hasData
                                                                              ? snapshot.data!
                                                                              : ''; // Return an empty string if TLCODE is null
                                                                          return buildDataCell(
                                                                              name,
                                                                              160);
                                                                        },
                                                                      ),
                                                                    ),
                                                                    buildDataCell(
                                                                      _formatDate(expense['APPDATE'],
                                                                              includeTime:
                                                                                  true)
                                                                          .replaceFirst(
                                                                              ' ',
                                                                              '\n'),
                                                                      150,
                                                                    ),
                                                                    buildDataCell(
                                                                        expense['APPREMARKS']?.toString() ??
                                                                            '',
                                                                        120),
                                                                    Center(
                                                                      child: FutureBuilder<
                                                                          String>(
                                                                        future: _fileService.getEmpNameByCode(expense['RECHKUSER']?.toString() ??
                                                                            ''),
                                                                        builder:
                                                                            (context,
                                                                                snapshot) {
                                                                          final name = snapshot.hasData
                                                                              ? snapshot.data!
                                                                              : ''; // Return an empty string if TLCODE is null
                                                                          return buildDataCell(
                                                                              name,
                                                                              160);
                                                                        },
                                                                      ),
                                                                    ),
                                                                    buildDataCell(
                                                                      _formatDate(expense['RECHKDATE'],
                                                                              includeTime:
                                                                                  true)
                                                                          .replaceFirst(
                                                                              ' ',
                                                                              '\n'),
                                                                      150,
                                                                    ),
                                                                    buildDataCell(
                                                                        expense['RECHKREMARKS']?.toString() ??
                                                                            '',
                                                                        120),
                                                                    buildDataCell(
                                                                      (expense['TSSTATUS'] != null && expense['TSSTATUS'].toString().isNotEmpty)
                                                                          ? expense['TSSTATUS'].toString()[0].toUpperCase() +
                                                                              expense['TSSTATUS'].toString().substring(1).toLowerCase()
                                                                          : '',
                                                                      120,
                                                                    ),
                                                                  ],
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Sorting method
  List<dynamic> _sortTicketData(List<dynamic> tickets) {
    if (tickets.isEmpty || _sortColumn == null) return tickets;

    List<dynamic> sortedList = List.from(tickets);

    sortedList.sort((a, b) {
      var aValue = _getSortValue(a, _sortColumn!);
      var bValue = _getSortValue(b, _sortColumn!);

      // Handle null values
      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return _sortAscending ? -1 : 1;
      if (bValue == null) return _sortAscending ? 1 : -1;

      int result;

      if (aValue is String && bValue is String) {
        result = aValue.toLowerCase().compareTo(bValue.toLowerCase());
      } else if (aValue is DateTime && bValue is DateTime) {
        result = aValue.compareTo(bValue);
      } else if (aValue is num && bValue is num) {
        result = aValue.compareTo(bValue);
      } else {
        result = aValue.toString().compareTo(bValue.toString());
      }

      return _sortAscending ? result : -result;
    });

    return sortedList;
  }

  // Helper method to get sort value based on column key
  dynamic _getSortValue(Map<String, dynamic> item, String columnKey) {
    switch (columnKey) {
      case 'INDEX':
        return item['index'] ?? 0;
      case 'ADDDATE':
      case 'APPDATE':
      case 'RECHKDATE':
        return _parseDate(item[columnKey]?.toString());
      case 'DEPTCODE':
        return getDeptName(int.tryParse(item[columnKey]?.toString() ?? ''));
      case 'SITECODE': // For Project column sorting
        final siteCode = item['SITECODE']?.toString() ?? '';
        // Get project name from cache, or use site code as fallback
        final projectName = _siteCodeToProjectName[siteCode] ?? siteCode;
        // Return first letter for sorting, or empty string if no name
        return projectName.isNotEmpty ? projectName[0].toUpperCase() : '';
      case 'TSSTATUS':
        final status = item[columnKey]?.toString() ?? '';
        return status.isNotEmpty
            ? status[0].toUpperCase() + status.substring(1).toLowerCase()
            : '';
      case 'ADDUSER':
      case 'APPUSER':
      case 'RECHKUSER':
      case 'TLCODE':
      case 'ELEID':
      case 'REMARKS':
      case 'TYPE':
      case 'WORKTYPE':
      case 'APPREMARKS':
      case 'RECHKREMARKS':
      case 'REASSIGNDATA':
      default:
        return item[columnKey]?.toString() ?? '';
    }
  }

  // Date parsing helper
  DateTime? _parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.tryParse(dateString);
    } catch (e) {
      return null;
    }
  }

  // Sortable header cell widget
  Widget _buildSortableHeaderCell(
      String title, String columnKey, double width) {
    final isSorted = _sortColumn == columnKey;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_sortColumn == columnKey) {
            _sortAscending = !_sortAscending;
          } else {
            _sortColumn = columnKey;
            _sortAscending = true;
          }
        });
      },
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary,
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.background,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSorted)
              Icon(
                _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                color: AppColors.background,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateValue,
      {bool useShortFormat = false, bool includeTime = true}) {
    try {
      if (dateValue == null) return '';
      DateTime parsedDate;

      // 🧩 Parse from either String or timestamp
      if (dateValue is String) {
        parsedDate = DateTime.parse(dateValue);
      } else if (dateValue is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else {
        return '';
      }

      // 🧭 Select format
      String dateFormat = useShortFormat
          ? 'dd/MMM/yy'
          : 'dd/MM/yyyy'; // e.g. 11/Oct/25 or 11/10/2025
      String timeFormat = 'hh:mm a'; // e.g. 05:00 PM

      // 🧮 Combine date + time if required
      if (includeTime) {
        return '${DateFormat('$dateFormat $timeFormat').format(parsedDate)}';
      } else {
        return DateFormat(dateFormat).format(parsedDate);
      }
    } catch (_) {
      return '';
    }
  }

  String getFileSafeDateTimeFormatted() {
    final now = DateTime.now();
    return DateFormat('dd-MM-yyyy_hh-mm_a').format(now);
    // ✅ Output: 18-07-2025_04-35_PM
  }

  String getCurrentDateTimeFormatted() {
    final now = DateTime.now();
    return DateFormat('dd/MM/yyyy hh:mm a')
        .format(now); // e.g. 11/07/2025 04:12 PM
  }

  Future<String?> getUniqueFilePath(String fileName) async {
    final downloadsDir = await getDownloadsFolder();
    if (downloadsDir == null) return null;

    final ncrDir = Directory(p.join(downloadsDir.path, "Time Sheet Report"));
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

  Future<String> _fetchSiteName(String siteCode) async {
    try {
      if (siteCode.isEmpty) return "Site $siteCode";

      final siteInfo = await _fileService.loadSiteName(int.parse(siteCode));
      return siteInfo?.first['PROJECTNAME'] ?? "Site $siteCode";
    } catch (e) {
      print("Error fetching site name: $e");
      return "Site $siteCode";
    }
  }

  Widget buildHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        border: box_border.Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.background,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildDataCell(String text, double width, {TextStyle? style}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: box_border.Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: style ?? const TextStyle(color: AppColors.textPrimary),
      ),
    );
  }

  String getDeptName(int? deptCode) {
    switch (deptCode) {
      case 1:
        return 'DESIGN';
      case 2:
        return 'DRAFTING';
      default:
        return 'UNKNOWN';
    }
  }

  Future<void> loadTimeSheetList() async {
    setState(() {
      isLoading = true;
      _showTable = false;
    });
    if (!_isProjectMappingLoaded) {
      await _loadProjects();
    }
    // ✅ Ensure only From Date & To Date are mandatory
    if (_fromdateController.text.isEmpty || _todateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select both From Date and To Date"),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => isLoading = false);
      return;
    }

    final url = ApiUtils.getUri('TSViewList');
    print("🔹 Fetching Timesheet List from URL: $url");

    try {
      final response = await http.post(url);
      print("🔹 Response Status Code: ${response.statusCode}");
      print("🔹 Raw Response Body: ${response.body}");

      final Map<String, dynamic> json = jsonDecode(response.body);

      if (json['Success'] == true) {
        final List<dynamic> tickets = json['Tickets'] ?? [];

        final List<Map<String, dynamic>> allTickets =
            tickets.map((e) => Map<String, dynamic>.from(e)).toList();

        print("📦 Total Tickets From API: ${allTickets.length}");

        // ✅ Sort by TSNO, then ELEID
        allTickets.sort((a, b) {
          final intA = int.tryParse(a['TSNO']?.toString() ?? '') ?? 0;
          final intB = int.tryParse(b['TSNO']?.toString() ?? '') ?? 0;
          final eleA = a['ELEID']?.toString() ?? '';
          final eleB = b['ELEID']?.toString() ?? '';
          if (intA != intB) return intA.compareTo(intB);
          return eleA.compareTo(eleB);
        });

        // ✅ Parse date filters
        final DateTime? fromDate = DateTime.tryParse(_fromdateController.text);
        final DateTime? toDate = DateTime.tryParse(_todateController.text);

        final filtered = allTickets.where((ticket) {
          final status = (ticket['TSSTATUS'] ?? '').toString().toUpperCase();
          final statusMatch = selectedStatus == null ||
              selectedStatus!.isEmpty ||
              selectedStatus == 'ALL' ||
              status == selectedStatus!.toUpperCase();

          final addDateString = ticket['ADDDATE'] ?? '';
          final ticketDate = DateTime.tryParse(addDateString);

          final dateMatch = (fromDate == null ||
                  (ticketDate != null &&
                      ticketDate
                          .isAfter(fromDate.subtract(Duration(days: 1))))) &&
              (toDate == null ||
                  (ticketDate != null &&
                      ticketDate.isBefore(toDate.add(Duration(days: 1)))));

          final projectId = int.tryParse(ticket['SITECODE']?.toString() ?? '');
          final projectMatch = (_projectId == null || _projectId == 0)
              ? true
              : projectId == _projectId;

          final deptCode = int.tryParse(ticket['DEPTCODE']?.toString() ?? '');
          final deptMatch = (selectedDeptCode == null || selectedDeptCode == 0)
              ? true
              : deptCode == selectedDeptCode;

          // ✅ Team Lead filter is OPTIONAL now
          final tlCode = ticket['TLCODE']?.toString() ?? '';
          final teamLeadMatch = selectedTL == null ||
              selectedTL!.isEmpty ||
              selectedTL == 'ALL' ||
              tlCode == selectedTL;

          // ✅ Employee filter (by ADDUSER)
          final addUser = ticket['ADDUSER']?.toString() ?? '';
          final employeeMatch = selectedEmployee == null ||
              selectedEmployee!.isEmpty ||
              selectedEmployee == 'ALL' ||
              addUser == selectedEmployee;

          final type = (ticket['TYPE'] ?? '').toString().toUpperCase();
          final typeMatch = selectedtype == null ||
              selectedtype!.isEmpty ||
              selectedtype == 'SELECT TYPE' ||
              type == selectedtype!.toUpperCase();

          final workType = (ticket['WORKTYPE'] ?? '').toString().toUpperCase();
          final workTypeMatch = selectedworktype == null ||
              selectedworktype!.isEmpty ||
              selectedworktype == 'SELECT WORK TYPE' ||
              workType == selectedworktype!.toUpperCase();

          final eleIdValue = (ticket['ELEID'] ?? '').toString().toUpperCase();
          final eleIdFilter = eleid == null ||
              eleid!.isEmpty ||
              eleIdValue.contains(eleid!.toUpperCase());

          final ecNoValue = (ticket['ADDUSER'] ?? '').toString();
          final ecNoFilter =
              ecNo == null || ecNo!.isEmpty || ecNoValue.contains(ecNo!.trim());

          return statusMatch &&
              dateMatch &&
              projectMatch &&
              deptMatch &&
              teamLeadMatch &&
              employeeMatch &&
              typeMatch &&
              workTypeMatch &&
              eleIdFilter &&
              ecNoFilter;
        }).toList();

        print("✅ Filtered Tickets Count: ${filtered.length}");

        setState(() {
          ticketDetails = filtered;
          _showTable = ticketDetails.isNotEmpty;
        });

        if (ticketDetails.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No Data Found"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        throw Exception(json['Message'] ?? 'Failed to load timesheet list');
      }
    } catch (e) {
      setState(() => _showTable = false);
      print("❌ Error loading timesheet list: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // API call method
  Future<void> loadTimeSheetTothrs() async {
    setState(() {
      _isLoadingTimeSheet = true;
      _timeSheetTotals = [];
    });

    final request = {
      "SITECODE": _projectId,
      "ADDUSER": selectedEmployee,
    };

    try {
      final response = await http.post(
        ApiUtils.getUri('TSTOTHRS'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(request),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['Success'] == true) {
          final List<dynamic>? apiData = data['Tickets'];

          if (apiData != null && apiData.isNotEmpty) {
            // Apply department filter
            List<dynamic> filteredData = apiData.where((ticket) {
              final deptCode =
                  int.tryParse(ticket['DEPTCODE']?.toString() ?? '');
              final deptMatch =
                  (selectedDeptCode == null || selectedDeptCode == 0)
                      ? true
                      : deptCode == selectedDeptCode;
              // Apply Date filter
              final addDateString = ticket['ADDDATE'] ?? '';
              final ticketDate = DateTime.tryParse(addDateString);
              final DateTime? fromDate =
                  DateTime.tryParse(_fromdateController.text);
              final DateTime? toDate =
                  DateTime.tryParse(_todateController.text);
              final dateMatch = (fromDate == null ||
                      (ticketDate != null &&
                          ticketDate.isAfter(
                              fromDate.subtract(Duration(days: 1))))) &&
                  (toDate == null ||
                      (ticketDate != null &&
                          ticketDate.isBefore(toDate.add(Duration(days: 1)))));

              // Apply TLCODE filter:
              final tlMatch = (selectedTLCode == null || selectedTLCode == '')
                  ? true
                  : ticket['TLCODE']?.toString() == selectedTLCode;
              return deptMatch && tlMatch && dateMatch;
            }).toList();

            setState(() {
              _timeSheetTotals = filteredData;
              _isLoadingTimeSheet = false;
            });

            // Log each item
            for (var i = 0; i < _timeSheetTotals.length; i++) {
              //print('📊 Item $i: ${_timeSheetTotals[i]}');
            }

            // Show message if no data after filtering
            if (filteredData.isEmpty && apiData.isNotEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No data found for the selected filter'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          } else {
            setState(() {
              _timeSheetTotals = [];
              _isLoadingTimeSheet = false;
            });

            // Show user-friendly message
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'No timesheet hours found for the selected criteria'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          setState(() {
            _isLoadingTimeSheet = false;
          });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['Message'] ?? 'No data available'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        setState(() {
          _isLoadingTimeSheet = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server error: ${response.statusCode}'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoadingTimeSheet = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Table widget for timesheet total hours
  /*Widget buildTimeSheetHoursTable() {
    if (_isLoadingTimeSheet) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_timeSheetTotals.isEmpty) {
      return const Center(
        child: Text('No timesheet data found', style: TextStyle(fontSize: 16)),
      );
    }

    double totalHoursSum = 0;
    for (var item in _timeSheetTotals) {
      totalHoursSum += (item['TotalHours'] ?? 0).toDouble();
    }

// Convert to proper time format
    String formatTotalHours(double decimalHours) {
      int hours = decimalHours.floor();
      double decimalPart = decimalHours - hours;
      int minutes = (decimalPart * 60).round();

      // Handle overflow when minutes >= 60
      if (minutes >= 60) {
        hours += minutes ~/ 60;
        minutes = minutes % 60;
      }

      return '${hours}h ${minutes}m';
      // Or return '${hours}:${minutes.toString().padLeft(2, '0')}';
    }

    String formattedTime = formatTotalHours(totalHoursSum);
// For 3.90 hours, this returns "4h 30m" or "4:30"

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: true,
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Column(
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '$_selectedProject - Total Hours - ${totalHoursSum.toStringAsFixed(2)} - hrs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),

                  // Add Scrollbar for horizontal scrolling
                  SizedBox(
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      notificationPredicate: (notification) =>
                          notification.depth == 0,
                      thickness: 8,
                      radius: const Radius.circular(10),
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// 🔷 Header Row
                            Container(
                              color: AppColors.primary,
                              child: Row(
                                children: [
                                  _buildSimpleHeaderCell("S.No", 60),
                                  _buildSimpleHeaderCell("EC No - Name", 250),
                                  _buildSimpleHeaderCell("Project", 180),
                                  _buildSimpleHeaderCell("Department", 120),
                                  _buildSimpleHeaderCell("Team Lead", 250),
                                  _buildSimpleHeaderCell("Total Hours", 120),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),

                            /// 🔷 Data Rows
                            SizedBox(
                              height: MediaQuery.of(context).size.height - 500,
                              child: SingleChildScrollView(
                                child: Column(
                                  children: List.generate(
                                      _timeSheetTotals.length, (index) {
                                    final item = _timeSheetTotals[index];
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: index.isEven
                                            ? Colors.white
                                            : Colors.grey.shade50,
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            // S.No
                                            buildDataCell('${index + 1}', 60),

                                            // EC No - Name
                                            Center(
                                              child: FutureBuilder<String>(
                                                future: _fileService
                                                    .getEmpNameByCode(
                                                        item['ADDUSER']
                                                            .toString()),
                                                builder: (context, snapshot) {
                                                  final name = snapshot.hasData
                                                      ? snapshot.data!
                                                      : 'Loading...';
                                                  return buildDataCell(
                                                      name, 250);
                                                },
                                              ),
                                            ),

                                            // Project
                                            Center(
                                              child: FutureBuilder<String>(
                                                future: _fetchSiteName(
                                                  item['SITECODE']
                                                          ?.toString() ??
                                                      '',
                                                ),
                                                builder: (context, snapshot) {
                                                  final projectName = snapshot
                                                          .hasData
                                                      ? snapshot.data!
                                                      : _siteCodeToProjectName[
                                                              item['SITECODE']
                                                                  ?.toString()] ??
                                                          '${item['SITECODE']}';
                                                  return buildDataCell(
                                                      projectName, 180);
                                                },
                                              ),
                                            ),

                                            // Department
                                            buildDataCell(
                                              getDeptName(int.tryParse(
                                                  item['DEPTCODE']
                                                          ?.toString() ??
                                                      '')),
                                              120,
                                            ),

                                            // Team Lead
                                            Center(
                                              child: FutureBuilder<String>(
                                                future: _fileService
                                                    .getEmpNameByCode(
                                                        item['TLCODE']
                                                                ?.toString() ??
                                                            ''),
                                                builder: (context, snapshot) {
                                                  final name = snapshot.hasData
                                                      ? snapshot.data!
                                                      : ''; // Return an empty string if TLCODE is null
                                                  return buildDataCell(
                                                      name, 250);
                                                },
                                              ),
                                            ),

                                            // Total Hours
                                            buildDataCell(
                                              '${(item['TotalHours'] ?? 0).toStringAsFixed(2)} hrs',
                                              120,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),

                            /// 🔷 Summary Row
                            Container(
                              color: AppColors.primary,
                              child: Row(
                                children: [
                                  buildSummaryCell('Total:', 850,
                                      textColor: AppColors.text,
                                      alignment: Alignment.centerRight),
                                  buildSummaryCell(
                                    '${totalHoursSum.toStringAsFixed(2)} hrs',
                                    120,
                                    isBold: true,
                                    textColor: AppColors.text,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }*/

  Widget buildTimeSheetHoursTable() {
    if (_isLoadingTimeSheet) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_timeSheetTotals.isEmpty) {
      return const Center(
        child: Text('No timesheet data found', style: TextStyle(fontSize: 16)),
      );
    }

    // Calculate total sum in decimal - USE TotalHoursDecimal
    double totalHoursSum = 0;
    for (var item in _timeSheetTotals) {
      totalHoursSum += (item['TotalHoursDecimal'] ?? 0).toDouble();
    }

    // Convert total to HH:MM
    String totalHoursFormatted = convertDecimalHoursToHHMM(totalHoursSum);

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: true,
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Column(
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '$_selectedProject - Total Hours: $totalHoursFormatted ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),

                  // Add Scrollbar for horizontal scrolling
                  SizedBox(
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      notificationPredicate: (notification) =>
                          notification.depth == 0,
                      thickness: 8,
                      radius: const Radius.circular(10),
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// 🔷 Header Row
                            Container(
                              color: AppColors.primary,
                              child: Row(
                                children: [
                                  _buildSimpleHeaderCell("S.No", 60),
                                  _buildSimpleHeaderCell("EC No - Name", 250),
                                  _buildSimpleHeaderCell("Project", 180),
                                  _buildSimpleHeaderCell("Department", 120),
                                  _buildSimpleHeaderCell("Team Lead", 250),
                                  _buildSimpleHeaderCell("Total Hours", 120),
                                ],
                              ),
                            ),
                            const SizedBox(height: 5),

                            /// 🔷 Data Rows
                            SizedBox(
                              height: MediaQuery.of(context).size.height - 500,
                              child: SingleChildScrollView(
                                child: Column(
                                  children: List.generate(
                                      _timeSheetTotals.length, (index) {
                                    final item = _timeSheetTotals[index];
                                    // USE TotalHoursDecimal instead of TotalHours
                                    final decimalHours =
                                        (item['TotalHoursDecimal'] ?? 0)
                                            .toDouble();
                                    // OR use TotalHoursFormatted directly if you want
                                    final formattedHours = item[
                                            'TotalHoursFormatted'] ??
                                        convertDecimalHoursToHHMM(decimalHours);

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: index.isEven
                                            ? Colors.white
                                            : Colors.grey.shade50,
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            // S.No
                                            buildDataCell('${index + 1}', 60),

                                            // EC No - Name
                                            Center(
                                              child: FutureBuilder<String>(
                                                future: _fileService
                                                    .getEmpNameByCode(
                                                        item['ADDUSER']
                                                            .toString()),
                                                builder: (context, snapshot) {
                                                  final name = snapshot.hasData
                                                      ? snapshot.data!
                                                      : 'Loading...';
                                                  return buildDataCell(
                                                      name, 250);
                                                },
                                              ),
                                            ),

                                            // Project
                                            Center(
                                              child: FutureBuilder<String>(
                                                future: _fetchSiteName(
                                                  item['SITECODE']
                                                          ?.toString() ??
                                                      '',
                                                ),
                                                builder: (context, snapshot) {
                                                  final projectName = snapshot
                                                          .hasData
                                                      ? snapshot.data!
                                                      : _siteCodeToProjectName[
                                                              item['SITECODE']
                                                                  ?.toString()] ??
                                                          '${item['SITECODE']}';
                                                  return buildDataCell(
                                                      projectName, 180);
                                                },
                                              ),
                                            ),

                                            // Department
                                            buildDataCell(
                                              getDeptName(int.tryParse(
                                                  item['DEPTCODE']
                                                          ?.toString() ??
                                                      '')),
                                              120,
                                            ),

                                            // Team Lead
                                            Center(
                                              child: FutureBuilder<String>(
                                                future: _fileService
                                                    .getEmpNameByCode(
                                                        item['TLCODE']
                                                                ?.toString() ??
                                                            ''),
                                                builder: (context, snapshot) {
                                                  final name = snapshot.hasData
                                                      ? snapshot.data!
                                                      : '';
                                                  return buildDataCell(
                                                      name, 250);
                                                },
                                              ),
                                            ),

                                            // Total Hours - Use formatted value directly or convert
                                            buildDataCell(
                                              formattedHours,
                                              120,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),

                            /// 🔷 Summary Row
                            Container(
                              color: AppColors.primary,
                              child: Row(
                                children: [
                                  buildSummaryCell(
                                    'Total:',
                                    850,
                                    textColor: AppColors.text,
                                    alignment: Alignment.centerRight,
                                  ),
                                  buildSummaryCell(
                                    '$totalHoursFormatted hrs',
                                    120,
                                    isBold: true,
                                    textColor: AppColors.text,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper function to convert decimal hours to HH:MM format
  String convertDecimalHoursToHHMM(double decimalHours) {
    if (decimalHours <= 0) return '0:00';

    // Get whole hours
    int hours = decimalHours.floor();

    // Get decimal part and convert to minutes
    double decimalPart = decimalHours - hours;
    int minutes = (decimalPart * 60).round();

    // Handle rounding edge cases
    if (minutes >= 60) {
      hours += 1;
      minutes = 0;
    }

    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }

  // Helper method for simple header cells (non-sortable)
  Widget _buildSimpleHeaderCell(String text, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.3))),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Helper method for data cells
  Widget buildSimpleDataCell(String text, double width,
      {TextAlign alignment = TextAlign.center}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
        textAlign: alignment,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // Helper method for summary cells
  Widget buildSummaryCell(
    String text,
    double width, {
    Alignment alignment = Alignment.centerLeft,
    bool isBold = false,
    Color textColor = Colors.black,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          top: BorderSide(color: Colors.grey.shade400, width: 1),
        ),
      ),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Future<void> generateAndShareTSPdf(BuildContext context) async {
    if (ticketDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No Time Sheet Data Available!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ByteData bytes =
        await rootBundle.load('assets/images/Approved Logo.png');
    final pdf = pw.Document();

    String formattedStatus = selectedStatus
        .toLowerCase()
        .split(' ')
        .map((word) =>
            word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
        .join(' ');

    final String reportTitle = "$formattedStatus Time Sheet Report";
    final String formattedDate = getFileSafeDateTimeFormatted();
    final String fileName = selectedStatus.toLowerCase().replaceAll(' ', '_') +
        "_ts_report_$formattedDate.pdf";

    // Determine flags
    final isSubmitted = selectedStatus.toUpperCase() == "SUBMITTED";
    final isApproved = selectedStatus.toUpperCase() == "APPROVED";
    final isRejected = selectedStatus.toUpperCase() == "REJECTED";
    final isRecheck = selectedStatus.toUpperCase() == "RECHECK";
    final isReassigned = selectedStatus.toUpperCase() == "REASSIGNED";
    final isForwarded = selectedStatus.toUpperCase() == "FORWARDED";
    final isAll = selectedStatus.toUpperCase() == "ALL";

    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final pw.MemoryImage logo = pw.MemoryImage(logoBytes);

    // === 1. Build Headers ===
    final List<String> headers = [
      "S.No",
      "EC No - Name",
      "Project",
      "Element Id",
      "Remarks",
      "Date & Time",
      "Type",
      "Work Type",
      "Department",
      "Team Lead",
    ];

    if (isApproved) {
      headers.addAll(["App By", "App Date & Time", "App Remarks"]);
    }

    if (isRejected) {
      headers.addAll(["Rej By", "Rej Date & Time", "Rej Des"]);
    }

    if (isRecheck) {
      headers.addAll(["Rec By", "Rec Date & Time", "Rec Des"]);
    }

    if (isReassigned) {
      headers.addAll(["Reassigned To"]);
    }

    if (isForwarded) {
      headers.addAll(["Forward From"]);
    }

    if (isAll) {
      headers.addAll([
        "App / Rej By",
        "App / Rej Date & Time",
        "App / Rej Remarks",
        "Recheck By",
        "Recheck Date & Time",
        "Recheck Remarks",
        "Status"
      ]);
    }

    // === 2. Build Data Rows ===
    List<List<String>> tableData = [];
    for (int index = 0; index < ticketDetails.length; index++) {
      final item = ticketDetails[index];
      final addUserCode = item['ADDUSER']?.toString() ?? '';
      final addUserName = await _fileService.getEmpNameByCode(addUserCode);
      final UserCode = item['TLCODE']?.toString() ?? '';
      final UserName = await _fileService.getEmpNameByCode(UserCode);
      final siteCode = item['SITECODE']?.toString() ?? '';
      final projectName = await _fetchSiteName(siteCode);
      final approvedusercode = item['APPUSER']?.toString() ?? '';
      final approvedusername =
          await _fileService.getEmpNameByCode(approvedusercode);
      final recheckusercode = item['RECHKUSER']?.toString() ?? '';
      final recheckusername =
          await _fileService.getEmpNameByCode(recheckusercode);

      final row = [
        '${index + 1}',
        addUserName.toString() == '0' ? '' : addUserName,
        projectName,
        item['ELEID']?.toString().toUpperCase() ?? '',
        item['REMARKS']?.toString().toUpperCase() ?? '',
        _formatDate(item['ADDDATE'], includeTime: true),
        item['TYPE']?.toString().toUpperCase() ?? '',
        item['WORKTYPE']?.toString().toUpperCase() ?? '',
        getDeptName(int.tryParse(item['DEPTCODE']?.toString() ?? '')),
        UserName
      ];

      if (isApproved || isRejected) {
        row.addAll([
          approvedusername,
          _formatDate(item['APPDATE'], includeTime: true),
          item['APPREMARKS']?.toString().toUpperCase() ?? '',
        ]);
      }

      if (isRecheck) {
        row.addAll([
          recheckusername,
          _formatDate(item['RECHKDATE'], includeTime: true),
          item['RECHKREMARKS']?.toString().toUpperCase() ?? '',
        ]);
      }
      /*if (isReassigned) {
        // Extract the necessary data from REASSIGNDATA
        final reassignData = item['REASSIGNDATA']?.toString() ?? '';
        final reassignParts = reassignData.split(' - ');

        // Check if the data contains the required parts (Forwarded From and Reassigning to)
        String forwardFrom = '';

        // Loop through the parts and capture the relevant section
        for (int i = 0; i < reassignParts.length; i++) {
          if (reassignParts[i].startsWith('Forwarded From:')) {
            // Extract the ID and Name after 'Forwarded From:'
            forwardFrom =
                reassignParts[i].replaceFirst('Forwarded From: ', '').trim();
            break;
          }
        }

        // Add the extracted data to the row
        if (isReassigned) {
          row.addAll([forwardFrom]);
        }
      }*/
      if (isReassigned) {
        // Extract the necessary data from REASSIGNDATA
        final reassignData = item['REASSIGNDATA']?.toString() ?? '';

        // Use a regular expression to extract the portion between 'Forwarded From:' and 'Reassigning to:'
        final regex = RegExp(r'Forwarded From: (.*?) Reassigning to:');
        final match = regex.firstMatch(reassignData);

        // Check if a match was found and extract the desired part
        String forwardFrom = '';
        if (match != null) {
          forwardFrom = match.group(1)?.trim() ?? '';
        }

        // Add the extracted data to the row
        if (isReassigned) {
          row.addAll([forwardFrom]);
        }
      }

      if (isForwarded) {
        row.addAll([
          item['REASSIGNDATA']?.toString().toUpperCase() ?? '',
        ]);
      }

      if (isAll) {
        final tsStatus = item['TSSTATUS']?.toString()?.toUpperCase() ?? '';

        // Approved / Rejected common fields
        String appOrRejBy = '';
        String appOrRejDate = '';
        String appOrRejRemarks = '';

        // Recheck fields
        String recheckBy = '';
        String recheckDate = '';
        String recheckRemarks = '';

        if (tsStatus == "APPROVED") {
          appOrRejBy = approvedusername;
          appOrRejDate = _formatDate(item['APPDATE'], includeTime: true);
          appOrRejRemarks = item['APPREMARKS']?.toString().toUpperCase() ?? '';
        } else if (tsStatus == "REJECTED") {
          appOrRejBy = recheckusername;
          appOrRejDate = _formatDate(item['RECHKDATE'], includeTime: true);
          appOrRejRemarks =
              item['RECHKREMARKS']?.toString().toUpperCase() ?? '';
        } else if (tsStatus == "RECHECK") {
          recheckBy = recheckusername;
          recheckDate = _formatDate(item['RECHKDATE'], includeTime: true);
          recheckRemarks = item['RECHKREMARKS']?.toString().toUpperCase() ?? '';
        }

        // Add all columns in exact header order
        row.addAll([
          appOrRejBy,
          appOrRejDate,
          appOrRejRemarks,
          recheckBy,
          recheckDate,
          recheckRemarks,
          tsStatus,
        ]);
      }

      tableData.add(row.map((e) => e.toString()).toList());
    }

    // === 3. Column Widths ===
    final columnWidths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth((isApproved ||
              isReassigned ||
              isForwarded ||
              isRejected ||
              isRecheck ||
              isAll)
          ? 40
          : 34), // S.No
      1: pw.FixedColumnWidth(
          (isSubmitted || isReassigned || isForwarded || isAll)
              ? 89
              : 85), // EC No - Name
      2: pw.FixedColumnWidth(130), // Project
      3: pw.FixedColumnWidth((isApproved) ? 70 : 80), // Element Id
      4: pw.FixedColumnWidth((isApproved) ? 95 : 100), // Remarks
      5: pw.FixedColumnWidth(
          (isSubmitted || isApproved || isRejected || isRecheck || isAll)
              ? 90
              : 120), // Date & Time
      6: pw.FixedColumnWidth(70), // Type
      7: pw.FixedColumnWidth((isApproved || isAll) ? 90 : 75), // Work Type
      8: pw.FixedColumnWidth((isReassigned ||
              isForwarded ||
              isApproved ||
              isRejected ||
              isRecheck ||
              isAll)
          ? 77
          : 70), // Department
      9: pw.FixedColumnWidth((isSubmitted) ? 89 : 85), // Team Lead
      if (isApproved || isRejected || isRecheck) ...{
        10: pw.FixedColumnWidth(85), // Approved By
        11: pw.FixedColumnWidth(90), // Approved Date & Time
        12: pw.FixedColumnWidth(100), // Approved Remarks
      },
      if (isAll) ...{
        13: pw.FixedColumnWidth(80), // App/Rej By
        14: pw.FixedColumnWidth(80), // App/Rej Date & Time
        15: pw.FixedColumnWidth(100), // App/Rej Remarks
        16: pw.FixedColumnWidth(85), // Recheck By
        17: pw.FixedColumnWidth((isAll) ? 90 : 120), // Recheck Date & Time
        18: pw.FixedColumnWidth(100), // Recheck Remarks
        19: pw.FixedColumnWidth(70), // Status
      },
      if (isReassigned || isForwarded) ...{
        20: pw.FixedColumnWidth(30), // Reassigned To
        21: pw.FixedColumnWidth(30), // Forwarded To
      },
    };

    // === 4. Generate PDF ===
    pdf.addPage(
      pw.MultiPage(
        pageFormat:
            isAll ? PdfPageFormat.a3.landscape : PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(8),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 5),
          child: pw.Text(
            'Page No: ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
            ),
            padding: const pw.EdgeInsets.all(2),
            height: 75,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  padding: pw.EdgeInsets.all(20),
                  width: 70,
                  height: 70,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Image(logo,
                      width: 70, height: 70, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        "Jata Techno Wheels LLP - $reportTitle",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        "From: ${_formatDate(_fromdateController.text, includeTime: false)} To: ${_formatDate(_todateController.text, includeTime: false)}",
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        "Generated On: ${getCurrentDateTimeFormatted()}",
                        style: pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: tableData,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle:
                pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            headerAlignment: pw.Alignment.center,
            cellStyle: pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.center,
            border: pw.TableBorder.all(color: PdfColors.grey),
            columnWidths: columnWidths,
          ),
        ],
      ),
    );

    // === 5. Save & Share ===
    final pdfBytes = await pdf.save();

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
          SnackBar(content: Text("❌ Could not access Downloads folder")),
        );
      }
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: reportTitle);
    }
  }

  Future<void> generateAndShareTSHoursReport(BuildContext context) async {
    if (_timeSheetTotals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No Time Sheet Hours Data Available!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ByteData bytes =
        await rootBundle.load('assets/images/Approved Logo.png');
    final Uint8List logoBytes = bytes.buffer.asUint8List();
    final pw.MemoryImage logo = pw.MemoryImage(logoBytes);

    final String formattedDate = getFileSafeDateTimeFormatted();
    final String fileName =
        (_selectedProject?.toLowerCase() ?? 'untitled').replaceAll(' ', '_') +
            "_ts_hours_report_$formattedDate.pdf";

    final pdf = pw.Document();

    // === 1. Build Headers ===
    final List<String> headers = [
      "S.No",
      "EC No - Name",
      "Project",
      "Department",
      "Team Lead",
      "Total Hours",
    ];

    // === 2. Build Data Rows ===
    List<List<String>> tableData = [];
    double totalHoursSum = 0;

    for (int index = 0; index < _timeSheetTotals.length; index++) {
      final item = _timeSheetTotals[index];

      // Fetch employee name
      final addUserCode = item['ADDUSER']?.toString() ?? '';
      final addUserName = await _fileService.getEmpNameByCode(addUserCode);

      // Fetch team lead name
      final tlCode = item['TLCODE']?.toString() ?? '';
      final tlName = await _fileService.getEmpNameByCode(tlCode);

      // Fetch project name
      final siteCode = item['SITECODE']?.toString() ?? '';
      final projectName = await _fetchSiteName(siteCode);

      // Get department name
      final deptCode = int.tryParse(item['DEPTCODE']?.toString() ?? '');
      final deptName = getDeptName(deptCode);

      // Get total hours - Use the same logic as UI table
      // First try to get TotalHoursDecimal (numeric value)
      double itemHours = 0;

      if (item.containsKey('TotalHoursDecimal')) {
        itemHours = (item['TotalHoursDecimal'] ?? 0).toDouble();
      } else if (item.containsKey('TOTHRS')) {
        itemHours = (item['TOTHRS'] ?? 0).toDouble();
      } else if (item.containsKey('totalHours')) {
        itemHours = (item['totalHours'] ?? 0).toDouble();
      } else if (item.containsKey('TotalHours')) {
        itemHours = (item['TotalHours'] ?? 0).toDouble();
      } else if (item.containsKey('TOTALHRS')) {
        itemHours = (item['TOTALHRS'] ?? 0).toDouble();
      } else if (item.containsKey('TOT_HRS')) {
        itemHours = (item['TOT_HRS'] ?? 0).toDouble();
      }

      // Add to total sum
      totalHoursSum += itemHours;

      // Get formatted hours - same as UI
      String formattedHours;
      if (item.containsKey('TotalHoursFormatted') &&
          item['TotalHoursFormatted'] != null &&
          item['TotalHoursFormatted'].toString().isNotEmpty) {
        formattedHours = item['TotalHoursFormatted'].toString();
      } else {
        formattedHours = convertDecimalHoursToHHMM(itemHours);
      }

      final row = [
        '${index + 1}',
        addUserName.toString() == '0' ? '' : addUserName,
        projectName,
        deptName,
        tlName,
        formattedHours, // Use formatted hours instead of decimal
      ];
      tableData.add(row.map((e) => e.toString()).toList());
    }

    // Convert total sum to formatted string (same as UI)
    String totalHoursFormatted = convertDecimalHoursToHHMM(totalHoursSum);

    // === 4. Column Widths ===
    final columnWidths = <int, pw.TableColumnWidth>{
      0: pw.FixedColumnWidth(40), // S.No
      1: pw.FixedColumnWidth(120), // EC No - Name
      2: pw.FixedColumnWidth(150), // Project
      3: pw.FixedColumnWidth(100), // Department
      4: pw.FixedColumnWidth(120), // Team Lead
      5: pw.FixedColumnWidth(80), // Total Hours
    };

    // === 5. Generate PDF ===
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(8),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 5),
          child: pw.Text(
            'Page No: ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
            ),
            padding: const pw.EdgeInsets.all(2),
            height: 75,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  padding: pw.EdgeInsets.all(20),
                  width: 70,
                  height: 70,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Image(logo,
                      width: 70, height: 70, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        "Jata Techno Wheels LLP - $_selectedProject - Hours Report",
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        "Generated On: ${getCurrentDateTimeFormatted()}",
                        style: pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: tableData,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle:
                pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            headerAlignment: pw.Alignment.center,
            cellStyle: pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.center,
            border: pw.TableBorder.all(color: PdfColors.grey),
            columnWidths: columnWidths,
          ),

          // Summary Row - Use the same formatted total as UI
          pw.SizedBox(height: 10),
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            padding: pw.EdgeInsets.all(10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Grand Total:',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '$totalHoursFormatted hours', // Use formatted total
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // === 6. Save & Share ===
    final pdfBytes = await pdf.save();

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
          SnackBar(content: Text("❌ Could not access Downloads folder")),
        );
      }
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(file.path)], text: _selectedProject);
    }
  }

  Future<void> loadSummaryReport() async {
    setState(() {
      isLoadingSummary = true;
    });

    // Validate dates
    if (_fromdateController.text.isEmpty || _todateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select both From Date and To Date"),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => isLoadingSummary = false);
      return;
    }

    try {
      final url = ApiUtils.getUri('GetPieceDrawingElementCounts');

      final response = await http.post(url);

      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        print("RAW FIRST ITEM 👉 ${_selectedProject}");

        // Convert to model
        List<SummaryReportModel> allData =
            data.map((e) => SummaryReportModel.fromJson(e)).toList();

        // Parse date filters
        final DateTime? fromDate = DateTime.tryParse(_fromdateController.text);
        final DateTime? toDate = DateTime.tryParse(_todateController.text);

        // Apply filters (DATE + PROJECT ONLY)
        final filtered = allData.where((item) {
          final itemDate = DateTime.tryParse(item.tsdt);

          final dateMatch = (fromDate == null ||
                  (itemDate != null &&
                      itemDate
                          .isAfter(fromDate.subtract(Duration(days: 1))))) &&
              (toDate == null ||
                  (itemDate != null &&
                      itemDate.isBefore(toDate.add(Duration(days: 1)))));

          final projectMatch = (_projectId == null || _projectId == 0)
              ? true
              : item.projectName == _selectedProject;

          // ✅ NEW: Work Type filter
          final workTypeMatch =
              (selectedworktype == null || selectedworktype!.isEmpty)
                  ? true
                  : (item.workType.isNotEmpty &&
                      item.workType.toLowerCase().trim() ==
                          selectedworktype!.toLowerCase().trim());

          return dateMatch && projectMatch && workTypeMatch;
        }).toList();

        setState(() {
          summaryList = filtered;
        });

        if (summaryList.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No Data Found"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        throw Exception("Failed to load data");
      }
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() {
        isLoadingSummary = false;
      });
    }
  }

  Widget buildSummaryTable() {
    if (isLoadingSummary) {
      return const Center(child: CircularProgressIndicator());
    }

    if (summaryList.isEmpty) {
      return const Center(child: Text("No Data Found"));
    }

    // Group data by project only (no week grouping)
    final groupedByProject = _groupDataByProject(summaryList);

    // Get all unique project names
    final allProjects = summaryList
        .map((e) => e.projectName)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    // Get all unique elements
    final allElements = summaryList
        .map((e) => e.eleName)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var project in allProjects) ...[
            _buildProjectTable(
              project,
              groupedByProject[project] ?? {},
              allElements,
            ),
            const SizedBox(height: 30),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectTable(
    String projectName,
    Map<String, Map<String, dynamic>> data,
    List<String> elements,
  ) {
    // Get all dates for this project
    final dates = data.keys.toList()..sort();

    // Calculate column widths
    final slNoWidth = 60.0;
    final elementWidth = 150.0;
    final dwgQtyWidth = 70.0;

    // Filter elements that have at least one non-zero value
    final filteredElements = <String>[];
    for (var element in elements) {
      bool hasData = false;
      for (var date in dates) {
        final dwg = int.tryParse(_getValue(data[date]?[element], "dwg")) ?? 0;
        final qnty = int.tryParse(_getValue(data[date]?[element], "qnty")) ?? 0;
        if (dwg > 0 || qnty > 0) {
          hasData = true;
          break;
        }
      }
      if (hasData) {
        filteredElements.add(element);
      }
    }

    // If no elements have data, return empty container
    if (filteredElements.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate row-wise totals for each element
    Map<String, Map<String, int>> rowTotals = {};
    for (var element in filteredElements) {
      int totalDwg = 0;
      int totalQnty = 0;
      for (var date in dates) {
        totalDwg += int.tryParse(_getValue(data[date]?[element], "dwg")) ?? 0;
        totalQnty += int.tryParse(_getValue(data[date]?[element], "qnty")) ?? 0;
      }
      rowTotals[element] = {"dwg": totalDwg, "qnty": totalQnty};
    }

    // Calculate column-wise totals
    Map<String, Map<String, int>> columnTotals = {};
    for (var date in dates) {
      columnTotals[date] = {
        "dwg": _calculateDailyTotal(data[date], "dwg"),
        "qnty": _calculateDailyTotal(data[date], "qnty"),
      };
    }

    // Calculate grand totals
    final grandTotalDwg = columnTotals.values
        .fold<int>(0, (sum, totals) => sum + (totals["dwg"] ?? 0));
    final grandTotalQnty = columnTotals.values
        .fold<int>(0, (sum, totals) => sum + (totals["qnty"] ?? 0));

    // Calculate total width for the table
    final totalWidth = slNoWidth +
        elementWidth +
        (dates.length * dwgQtyWidth * 2) +
        (dwgQtyWidth * 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Project title
        /*Container(
          width: double.infinity, // 👈 ensures full width
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          color: Colors.blue[50],
          alignment: Alignment.center, // 👈 centers child
          child: Text(
            projectName.toUpperCase(),
            textAlign: TextAlign.center, // 👈 centers text
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),*/
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          color: Colors.blue[50],
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // 👈 center everything
            children: [
              // ✅ Project Name
              Text(
                projectName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                overflow: TextOverflow.ellipsis,
              ),

              // ✅ Space between texts
              if (selectedworktype != null && selectedworktype!.isNotEmpty)
                const SizedBox(width: 8),

              // ✅ WorkType - REPORT
              if (selectedworktype != null && selectedworktype!.isNotEmpty)
                Text(
                  "- (${selectedworktype!.toUpperCase()}  REPORT)",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Use ScrollConfiguration to allow both horizontal and vertical scrolling
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ✅ S.NO merged (spans both rows)
                          Container(
                            width: slNoWidth,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Text(
                              "S.NO",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),

                          // ✅ Rest of header
                          Column(
                            children: [
                              // 🔹 TOP HEADER (DATE + DATES + TOTAL)
                              Row(
                                children: [
                                  Container(
                                    width: elementWidth,
                                    height: 50,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: const Text(
                                      "DATE",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  for (var date in dates)
                                    Container(
                                      width: dwgQtyWidth * 2,
                                      height: 50,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: Text(
                                        formatDate(date),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  Container(
                                    width: dwgQtyWidth * 2,
                                    height: 50,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: const Text(
                                      "TOTAL",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),

                              // 🔹 SECOND HEADER (ELEMENT + DWG/QTY)
                              Row(
                                children: [
                                  Container(
                                    width: elementWidth,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: const Text(
                                      "ELEMENT",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  for (var date in dates) ...[
                                    Container(
                                      width: dwgQtyWidth,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: const Text("DWG"),
                                    ),
                                    Container(
                                      width: dwgQtyWidth,
                                      height: 40,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        border: Border.all(color: Colors.grey),
                                      ),
                                      child: const Text("QTY"),
                                    ),
                                  ],
                                  Container(
                                    width: dwgQtyWidth,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: const Text("DWG"),
                                  ),
                                  Container(
                                    width: dwgQtyWidth,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: const Text("QTY"),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Data rows for each filtered element with row totals
                    for (int i = 0; i < filteredElements.length; i++)
                      Row(
                        children: [
                          // SL NO
                          Container(
                            width: slNoWidth,
                            height: 45,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                            ),
                            child: Text(
                              (i + 1).toString(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Element Name
                          Container(
                            width: elementWidth,
                            height: 45,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                            ),
                            child: Text(
                              filteredElements[i],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // DWG and QTY values for each date
                          for (var date in dates) ...[
                            Container(
                              width: dwgQtyWidth,
                              height: 45,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Text(
                                _getValue(
                                    data[date]?[filteredElements[i]], "dwg"),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Container(
                              width: dwgQtyWidth,
                              height: 45,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                              ),
                              child: Text(
                                _getValue(
                                    data[date]?[filteredElements[i]], "qnty"),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          // Row Total (DWG and QTY)
                          Container(
                            width: dwgQtyWidth,
                            height: 45,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              border: Border.all(color: Colors.grey),
                            ),
                            child: Text(
                              rowTotals[filteredElements[i]]?["dwg"]
                                      .toString() ??
                                  "0",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Container(
                            width: dwgQtyWidth,
                            height: 45,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              border: Border.all(color: Colors.grey),
                            ),
                            child: Text(
                              rowTotals[filteredElements[i]]?["qnty"]
                                      .toString() ??
                                  "0",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),

                    // Column Total row (at the bottom)
                    Row(
                      children: [
                        // Total Bottom Header
                        Container(
                          width: elementWidth + slNoWidth,
                          height: 45,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            border: Border.all(color: Colors.grey),
                          ),
                          child: const Text(
                            "TOTAL",
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Column totals for each date
                        for (var date in dates) ...[
                          Container(
                            width: dwgQtyWidth,
                            height: 45,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              border: Border.all(color: Colors.grey),
                            ),
                            child: Text(
                              columnTotals[date]?["dwg"].toString() ?? "0",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Container(
                            width: dwgQtyWidth,
                            height: 45,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              border: Border.all(color: Colors.grey),
                            ),
                            child: Text(
                              columnTotals[date]?["qnty"].toString() ?? "0",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        // Grand Total
                        Container(
                          width: dwgQtyWidth,
                          height: 45,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Text(
                            grandTotalDwg.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Container(
                          width: dwgQtyWidth,
                          height: 45,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            border: Border.all(color: Colors.grey),
                          ),
                          child: Text(
                            grandTotalQnty.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Map<String, Map<String, Map<String, dynamic>>> _groupDataByProject(
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

  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day}-${date.month.toString().padLeft(2, '0')}-${date.year}";
    } catch (e) {
      return dateStr;
    }
  }

  int _calculateDailyTotal(Map<String, dynamic>? dayData, String field) {
    if (dayData == null) return 0;
    return dayData.values.fold<int>(
      0,
      (sum, element) =>
          sum + ((element as Map<String, dynamic>)[field] as int? ?? 0),
    );
  }

  String _getValue(Map<String, dynamic>? elementData, String field) {
    if (elementData == null) return " ";
    final value = elementData[field];
    if (value == null || value == 0) return "-";
    return value.toString();
  }
}
