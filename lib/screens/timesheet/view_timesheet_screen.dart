import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../models/project.dart';
import '../../services/file_service.dart';
import '../../services/prefrence_helper.dart';
import 'add_timesheet_screen.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ViewTimesheetScreen extends StatefulWidget {
  final String? initialStatusFilter;
  const ViewTimesheetScreen({
    super.key,
    this.initialStatusFilter,
  });

  @override
  State<ViewTimesheetScreen> createState() => _ViewTimesheetScreenState();
}

class _ViewTimesheetScreenState extends State<ViewTimesheetScreen> {
  final FileService _fileService = FileService();
  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  List<TimesheetViewModel> _entries = [];
  Map<int, List<TimesheetViewModel>> _groupedEntries = {};
  late int empCode;
  String? empName;
  String? empDept;
  String? empTL;
  List<int> _allowedAppRejEmpCodes = [];
  bool _isApprover = false;
  String? _statusFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _departmentFilter;
  Map<int, String> _tlMap = {};
  List<Map<String, dynamic>> _allSites = [];
  int? _siteFilter;
  final TextEditingController _siteController = TextEditingController();
  final Map<int, String> _siteNameCache = {};
  String? _tlFilter;
  String? _submittedByFilter;
  Map<int, String> _filteredSubmittedByMap = {};
  Map<int, String> _originalSubmittedByMap = {};
  Map<int, String> _submittedByMap = {};
  final TextEditingController _submittedByController = TextEditingController();
  Map<int, int> _employeeTLMap = {};

  // Add selection variables
  bool _isSelectionMode = false;
  Set<int> _selectedTimesheets = <int>{};
  final Map<int, bool> _timesheetCheckboxStates = {};
  Map<int, String> _tlDetails = {}; // EMPCODE -> EMPNAME
  bool _isLoadingTL = false;
  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  // Update the _isTeamLeadUser method
  bool _isTeamLeadUser() {
    return _tlDetails.containsKey(empCode);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      _statusFilter = widget.initialStatusFilter;
    }
    _loadUserDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedTimesheets.length} selected')
            : const Text(
                'View Time Sheets',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () {
              if (_isSelectionMode) {
                _toggleSelectionMode();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Icon(
                _isSelectionMode ? Icons.close : Icons.arrow_back,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        actions: _buildAppBarActions(),
      ),
      body: _isInitialLoading
          ? _buildInitialLoading()
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: Column(
                children: [
                  if (_isSelectionMode) _buildSelectionHeader(),
                  SizedBox(height: UI.sectionSpacing),
                  // Date Filter
                  if (!_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // From Date
                              Expanded(
                                child: TextField(
                                  controller: _fromDateController,
                                  decoration:
                                      _inputDecoration('From Date').copyWith(
                                    filled: true,
                                    fillColor: Colors.white,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.calendar_today),
                                      onPressed: () => _selectFromDate(context),
                                    ),
                                  ),
                                  readOnly: true,
                                  onTap: () => _selectFromDate(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // To Date
                              Expanded(
                                child: TextField(
                                  controller: _toDateController,
                                  decoration:
                                      _inputDecoration('To Date').copyWith(
                                    filled: true,
                                    fillColor: Colors.white,
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.calendar_today),
                                      onPressed: () => _selectToDate(context),
                                    ),
                                  ),
                                  readOnly: true,
                                  onTap: () => _selectToDate(context),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Clear Date Filter
                              if (_fromDate != null || _toDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: Colors.red),
                                  onPressed: _clearDateFilter,
                                  tooltip: 'Clear date filter',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: UI.sectionSpacing),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.only(right: 8, left: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration:
                          _inputDecoration('Search by Timesheet Number...')
                              .copyWith(
                        hintText: 'Search by Timesheet Number...',
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
                  SizedBox(height: 5),
                  // Site Filter
                  if (_allSites.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, left: 8),
                      child: Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) return _allSites;
                          return _allSites.where((site) =>
                              (site['display']?.toString().toLowerCase() ?? '')
                                  .contains(
                                      textEditingValue.text.toLowerCase()) ||
                              site['code']
                                  .toString()
                                  .contains(textEditingValue.text) ||
                              (site['name']?.toString().toLowerCase() ?? '')
                                  .contains(
                                      textEditingValue.text.toLowerCase()));
                        },
                        displayStringForOption: (site) =>
                            site['display'] ??
                            "${site['code']} - ${site['name']}",
                        fieldViewBuilder: (context, controller, focusNode,
                            onEditingComplete) {
                          if (_siteFilter != null && controller.text.isEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final selected = _allSites.firstWhere(
                                (s) => s['code'] == _siteFilter,
                                orElse: () => {
                                  "code": _siteFilter,
                                  "name": "",
                                  "display": "$_siteFilter - "
                                },
                              );
                              controller.text =
                                  selected['display'] ?? "$_siteFilter - ";
                            });
                          }

                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration:
                                _inputDecoration('Filter by Site (Code - Name)')
                                    .copyWith(
                              filled: true,
                              fillColor: Colors.white,
                              suffixIcon: _siteFilter != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _siteFilter = null;
                                          controller.clear();
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (value) {
                              if (value.isEmpty) {
                                setState(() => _siteFilter = null);
                              }
                            },
                            onEditingComplete: onEditingComplete,
                          );
                        },
                        onSelected: (Map<String, dynamic> selectedSite) {
                          setState(() {
                            _siteFilter = selectedSite['code'];
                          });
                        },
                      ),
                    ),
                  SizedBox(height: 5),
                  if (_isApprover && _tlMap.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, left: 8),
                      child: DropdownButtonFormField<String>(
                        value: _tlFilter,
                        decoration: _inputDecoration('Filter by TL').copyWith(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('All TLs',
                                style: TextStyle(color: Colors.grey[600])),
                          ),
                          ..._tlMap.entries.map((entry) {
                            final code = entry.key.toString();
                            final name =
                                entry.value.isNotEmpty ? entry.value : code;
                            return DropdownMenuItem<String>(
                              value: code,
                              child: Text(name),
                            );
                          }).toList(),
                        ],
                        onChanged: (selected) {
                          _filterEmployeesByTL(selected);
                        },
                      ),
                    ),
                  SizedBox(height: UI.sectionSpacing),
                  // Employee Filter
                  if (_isApprover || _isTeamLeadUser())
                    Padding(
                      padding: const EdgeInsets.only(right: 8, left: 8),
                      child: DropdownButtonFormField<String>(
                        value: _submittedByFilter,
                        decoration:
                            _inputDecoration('Filter by Employee').copyWith(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              _tlFilter != null
                                  ? 'All employees under TL'
                                  : 'All Employees',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                          ..._filteredSubmittedByMap.entries.map((entry) {
                            final empCode = entry.key;
                            final empName = entry.value;

                            return DropdownMenuItem<String>(
                              value: empCode.toString(),
                              child: Text(
                                empName.isNotEmpty
                                    ? empName
                                    : "Employee $empCode",
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (selected) {
                          setState(() {
                            _submittedByFilter = selected;
                          });
                        },
                      ),
                    ),

                  SizedBox(height: UI.sectionSpacing),
                  // Department Filter
                  if (_isApprover && !_isSelectionMode) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8, left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Filter by Department:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              if (_departmentFilter != null) ...[
                                InkWell(
                                  onTap: _clearDepartmentFilter,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Clear',
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(height: UI.sectionSpacing),
                                        Icon(Icons.close,
                                            size: 14, color: Colors.red[700]),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(height: UI.sectionSpacing),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              'All',
                              'DESIGNING',
                              'DRAFTING',
                            ].map((dept) {
                              bool isSelected = _departmentFilter == dept ||
                                  (_departmentFilter == null && dept == 'All');

                              return FilterChip(
                                label: Text(
                                  dept,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                selected: isSelected,
                                backgroundColor: Colors.white,
                                selectedColor: Colors.blue,
                                checkmarkColor: Colors.white,
                                onSelected: (selected) {
                                  if (dept == 'All') {
                                    _clearDepartmentFilter();
                                  } else {
                                    _applyDepartmentFilter(
                                        selected ? dept : null);
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: UI.sectionSpacing),
                  // Status Filter
                  if (!_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Filter
                          if (!_isSelectionMode)
                            Padding(
                              padding: const EdgeInsets.only(right: 8, left: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Filter by Status:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: UI.sectionSpacing),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      'All',
                                      'SUBMITTED',
                                      'APPROVED',
                                      'REJECTED',
                                      'RECHECK',
                                      'FORWARDED',
                                      'REASSIGNED',
                                    ].map((status) {
                                      Color statusColor;
                                      IconData statusIcon;

                                      switch (status) {
                                        case 'APPROVED':
                                          statusColor = Colors.green;
                                          statusIcon = Icons.check_circle;
                                          break;
                                        case 'REJECTED':
                                          statusColor = Colors.red;
                                          statusIcon = Icons.cancel;
                                          break;
                                        case 'RECHECK':
                                          statusColor = Colors.orange;
                                          statusIcon = Icons.sync_alt;
                                          break;
                                        case 'SUBMITTED':
                                          statusColor = Colors.blueGrey;
                                          statusIcon = Icons.pending_actions;
                                          break;
                                        case 'FORWARDED':
                                          statusColor = Colors.purple;
                                          statusIcon = Icons.forward;
                                          break;
                                        case 'REASSIGNED':
                                          statusColor = Colors.teal;
                                          statusIcon = Icons.assignment;
                                          break;
                                        default:
                                          statusColor = Colors.purple;
                                          statusIcon = Icons.filter_list;
                                      }

                                      bool isSelected =
                                          _statusFilter == status ||
                                              (_statusFilter == null &&
                                                  status == 'All');

                                      return ActionChip(
                                        avatar: Icon(statusIcon,
                                            size: 20, color: Colors.white),
                                        label: Text(
                                          status,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        backgroundColor: isSelected
                                            ? statusColor
                                            : Colors.grey.shade400,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          side: const BorderSide(
                                              color: Colors.white),
                                        ),
                                        labelPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12),
                                        onPressed: () =>
                                            _applyStatusFilter(status),
                                      );
                                    }).toList(),
                                  )
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Show loading indicator when refreshing or loading
                  if (_isLoading || _isRefreshing)
                    const LinearProgressIndicator(),

                  Expanded(
                    child: _buildTimesheetList(),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _fromDate = picked;
        _fromDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        _applyDateFilter();
      });
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _toDate = picked;
        _toDateController.text = DateFormat('dd-MM-yyyy').format(picked);
        _applyDateFilter();
      });
    }
  }

  void _applyDateFilter() {
    // This will trigger the list rebuild with date filtering
    setState(() {});
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _fromDateController.clear();
      _toDateController.clear();
    });
  }

  // Selection mode methods
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedTimesheets.clear();
        _timesheetCheckboxStates.clear();
      }
    });
  }

  void _selectAllTimesheets() {
    setState(() {
      final filteredList = _getFilteredGroupedList();
      for (var group in filteredList) {
        _selectedTimesheets.add(group.key);
        _timesheetCheckboxStates[group.key] = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTimesheets.clear();
      _timesheetCheckboxStates.clear();
    });
  }

  void _toggleTimesheetSelection(int tsNo, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedTimesheets.add(tsNo);
        _timesheetCheckboxStates[tsNo] = true;
      } else {
        _selectedTimesheets.remove(tsNo);
        _timesheetCheckboxStates.remove(tsNo);
      }
    });
  }

  bool _isTimesheetSelected(int tsNo) {
    return _selectedTimesheets.contains(tsNo);
  }

  // Get filtered grouped list for selection
  List<MapEntry<int, List<TimesheetViewModel>>> _getFilteredGroupedList() {
    final groupedList = _groupedEntries.entries.toList();

    return groupedList.where((group) {
      final tsNo = group.key;
      final entries = group.value;
      final firstEntry = entries.first;

      // Apply search filter
      if (_searchQuery.isNotEmpty && !tsNo.toString().contains(_searchQuery)) {
        return false;
      }

      // Apply submitted by filter
      if (_submittedByFilter != null) {
        final submittedByCode = int.tryParse(_submittedByFilter!);
        if (submittedByCode != null && firstEntry.addUser != submittedByCode) {
          return false;
        }
      }

      // Apply site filter
      if (_siteFilter != null) {
        final hasSite = entries.any((e) => e.siteCode == _siteFilter);
        if (!hasSite) return false;
      }

      // Apply department filter
      if (_isApprover &&
          _departmentFilter != null &&
          _departmentFilter != 'All') {
        final deptName = _getDepartmentName(firstEntry.deptCode);
        if (deptName != _departmentFilter) return false;
      }

      // Apply TL filter
      if (_isApprover && _tlFilter != null) {
        final tlCode = firstEntry.tlCode?.toString() ?? '';
        if (tlCode != _tlFilter) return false;
      }

      // Apply status filter
      if (_statusFilter != null && _statusFilter != 'All') {
        if (firstEntry.tsStatus?.toUpperCase() != _statusFilter) {
          return false;
        }
      }

      // Apply date filter - NEW
      if (_fromDate != null || _toDate != null) {
        bool hasMatchingDate = entries.any((entry) {
          if (entry.tsDt == null || entry.tsDt!.isEmpty) return false;

          try {
            final entryDate = DateTime.parse(entry.tsDt!);

            bool fromCondition = true;
            bool toCondition = true;

            if (_fromDate != null) {
              fromCondition = entryDate
                  .isAfter(_fromDate!.subtract(const Duration(days: 1)));
            }

            if (_toDate != null) {
              toCondition =
                  entryDate.isBefore(_toDate!.add(const Duration(days: 1)));
            }

            return fromCondition && toCondition;
          } catch (e) {
            debugPrint('Error parsing date: ${entry.tsDt}');
            return false;
          }
        });

        if (!hasMatchingDate) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await _fetchTimesheetEntries();
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _prepareTLMap(List<TimesheetViewModel> entries) {
    if (!_isApprover) return;

    final Map<int, String> map = {};
    for (var e in entries) {
      if (e.tlCode != null && !_tlMap.containsKey(e.tlCode)) {
        // Use API data if available, otherwise use empty string
        map[e.tlCode!] = _tlDetails[e.tlCode!] ?? "";
      }
    }
    _tlMap = map;

    // Only fetch names for TLs not in our API data
    _tlMap.forEach((code, name) async {
      if (name.isEmpty) {
        final fetchedName = await getEmployeeNameWithCode(code);
        setState(() {
          _tlMap[code] = fetchedName;
        });
      }
    });
  }

  void _prepareSubmittedByMap(List<TimesheetViewModel> entries) {
    final Map<int, String> map = {};
    final Map<int, int> employeeTLMap = {};

    for (var e in entries) {
      if (e.addUser != null && !map.containsKey(e.addUser)) {
        map[e.addUser!] = "";
        if (e.tlCode != null) {
          employeeTLMap[e.addUser!] = e.tlCode!;
        }
      }
    }

    setState(() {
      _submittedByMap = map;
      _originalSubmittedByMap = Map.from(map);
      _filteredSubmittedByMap = Map.from(map);
      _employeeTLMap = employeeTLMap;
    });

    _loadEmployeeNames(map);
  }

  void _filterEmployeesByTL(String? selectedTL) {
    setState(() {
      _tlFilter = selectedTL;
      _submittedByFilter = null;

      if (selectedTL == null) {
        _filteredSubmittedByMap = Map.from(_originalSubmittedByMap);
      } else {
        _filteredSubmittedByMap = _getEmployeesByTL(selectedTL);
      }
    });
  }

  Map<int, String> _getEmployeesByTL(String tlCode) {
    final Map<int, String> filteredEmployees = {};
    final int tlCodeInt = int.tryParse(tlCode) ?? 0;

    _originalSubmittedByMap.forEach((empCode, empName) {
      final employeeTL = _employeeTLMap[empCode];
      if (employeeTL == tlCodeInt) {
        filteredEmployees[empCode] = empName;
      }
    });

    return filteredEmployees;
  }

  Future<void> _loadEmployeeNames(Map<int, String> map) async {
    for (final code in map.keys) {
      try {
        final name = await getEmployeeNameWithCode(code);
        if (mounted) {
          setState(() {
            _submittedByMap[code] = name;
            _originalSubmittedByMap[code] = name;
            _filteredSubmittedByMap[code] = name;
          });
        }
      } catch (e) {
        debugPrint('Error loading name for employee $code: $e');
        if (mounted) {
          setState(() {
            _submittedByMap[code] = "Unknown";
            _originalSubmittedByMap[code] = "Unknown";
            _filteredSubmittedByMap[code] = "Unknown";
          });
        }
      }
    }
  }

  void _clearSubmittedByFilter() {
    setState(() {
      _submittedByFilter = null;
      _submittedByController.clear();
    });
  }

  void _clearTLFilter() {
    setState(() {
      _tlFilter = null;
    });
  }

  Future<void> _prepareSiteList(List<TimesheetViewModel> entries) async {
    final siteCodes = <int>{};

    for (var e in entries) {
      if (e.siteCode != null) {
        siteCodes.add(e.siteCode!);
      }
    }

    final List<Map<String, dynamic>> siteList = [];

    for (var code in siteCodes) {
      final siteName = await _fetchSiteName(code.toString());
      siteList.add({
        "code": code,
        "name": siteName,
        "display": "$code - $siteName",
      });
    }

    setState(() {
      _allSites = siteList;
    });
  }

  Future<void> _fetchTLDetails() async {
    if (_isLoadingTL) return;

    setState(() {
      _isLoadingTL = true;
    });

    try {
      final uri = ApiUtils.getUri('TLDetails');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          final List<dynamic> tlList = data['TLDetails'];
          final Map<int, String> tlDetails = {};

          for (var tl in tlList) {
            final code = tl['EMPCODE'] as int;
            final name = tl['EMPNAME'] as String;
            tlDetails[code] = name;
          }

          setState(() {
            _tlDetails = tlDetails;
          });
        } else {
          debugPrint('Failed to fetch TL details: ${data['Message']}');
        }
      } else {
        debugPrint('Server error fetching TL details: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching TL details: $e');
    } finally {
      setState(() {
        _isLoadingTL = false;
      });
    }
  }

  Future<void> _loadUserDetails() async {
    setState(() {
      _isInitialLoading = true;
      _isLoading = true;
    });

    try {
      final prefsHelper = PreferencesHelper();
      empCode = (await prefsHelper.getEmpCode()) ?? 0;
      empName = await prefsHelper.getEmpName();
      empDept = await prefsHelper.getEmpDept();
      empTL = await prefsHelper.getEmpTL();

      // Fetch both allowed approvers and TL details in parallel
      await Future.wait([
        _fetchAllowedApprovers(),
        _fetchTLDetails(),
      ]);
      setState(() {
        _isApprover = _allowedAppRejEmpCodes.contains(empCode);
      });

      await _fetchTimesheetEntries();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading user: $e')));
    } finally {
      setState(() {
        _isLoading = false;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _fetchAllowedApprovers() async {
    try {
      final uri = ApiUtils.getUri('ShowAppRej');
      final response =
          await http.post(uri, headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) _allowedAppRejEmpCodes = data.cast<int>();
      }
    } catch (e) {
      debugPrint('Error fetching approvers: $e');
    }
  }

  Future<void> _fetchTimesheetEntries({int? tsNo}) async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }

    try {
      final uri = ApiUtils.getUri('TSViewList');
      final body = tsNo != null ? jsonEncode({"TSNO": tsNo}) : jsonEncode({});
      final response = await http.post(uri,
          headers: {'Content-Type': 'application/json'}, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          final List<dynamic> tickets = data['Tickets'];
          final allEntries =
              tickets.map((e) => TimesheetViewModel.fromJson(e)).toList();

          await _cacheSiteNames(allEntries);

          List<TimesheetViewModel> filteredEntries = [];

          if (_isApprover) {
            filteredEntries = allEntries;
          } else {
            filteredEntries = allEntries.where((e) {
              final isOwner = e.addUser == empCode;
              final isTL = e.tlCode != null &&
                  e.tlCode.toString().trim() == empCode.toString().trim();
              return isOwner || isTL;
            }).toList();
          }

          _groupEntries(filteredEntries);
          _prepareTLMap(filteredEntries);
          _prepareSubmittedByMap(filteredEntries);
          await _prepareSiteList(filteredEntries);
        } else {
          if (!_isRefreshing) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(data['Message'] ?? 'Failed to load data'),
                  backgroundColor: AppColors.primaryDark),
            );
          }
        }
      } else {
        if (!_isRefreshing) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Server error: ${response.statusCode}'),
                backgroundColor: AppColors.primaryDark),
          );
        }
      }
    } catch (e) {
      if (!_isRefreshing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.primaryDark),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cacheSiteNames(List<TimesheetViewModel> entries) async {
    _siteNameCache.clear();

    final uniqueSiteCodes = entries
        .where((entry) => entry.siteCode != null)
        .map((entry) => entry.siteCode!)
        .toSet();

    for (final siteCode in uniqueSiteCodes) {
      try {
        final siteName = await _fetchSiteName(siteCode.toString());
        _siteNameCache[siteCode] = siteName;
      } catch (e) {
        debugPrint("Error caching site name for $siteCode: $e");
        _siteNameCache[siteCode] = "Site $siteCode";
      }
    }
  }

  void _groupEntries(List<TimesheetViewModel> entries) {
    final Map<int, List<TimesheetViewModel>> grouped = {};

    for (var entry in entries) {
      if (entry.tsNo != null) {
        if (_statusFilter == null || entry.tsStatus == _statusFilter) {
          grouped.putIfAbsent(entry.tsNo!, () => []).add(entry);
        }
      }
    }

    setState(() {
      _entries = entries;
      _groupedEntries = grouped;
    });
  }

  void _applyStatusFilter(String? status) {
    setState(() {
      _statusFilter = status == 'All' ? null : status;

      final Map<int, List<TimesheetViewModel>> grouped = {};

      for (var entry in _entries) {
        if (_statusFilter == null || entry.tsStatus == _statusFilter) {
          grouped.putIfAbsent(entry.tsNo!, () => []).add(entry);
        }
      }

      _groupedEntries = grouped;
    });
  }

  void _applyDepartmentFilter(String? department) {
    setState(() {
      _departmentFilter = department;
    });
  }

  void _clearDepartmentFilter() {
    setState(() {
      _departmentFilter = null;
    });
  }

  List<Widget> _buildAppBarActions() {
    if (_isSelectionMode) {
      return [
        if (_selectedTimesheets.isNotEmpty) ...[
          PopupMenuButton<String>(
            onSelected: (action) {
              switch (action) {
                case 'approve':
                  _bulkUpdateTimesheetStatus('APPROVE');
                  break;
                case 'reject':
                  _bulkUpdateTimesheetStatus('REJECT');
                  break;
                case 'recheck':
                  _bulkUpdateTimesheetStatus('RECHECK');
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'approve',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Approve Selected'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'reject',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Reject Selected'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'recheck',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Recheck Selected'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ];
    } else {
      // Show selection button only when status filter is SUBMITTED and user is approver
      return [
        if (_isApprover || _isTeamLeadUser())
          if (_statusFilter == 'SUBMITTED')
            Row(
              children: [
                Text('Select multiple timesheets'),
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: _toggleSelectionMode,
                  tooltip: 'Select multiple timesheets',
                ),
              ],
            )
      ];
    }
  }

  Widget _buildSelectionHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppColors.primary.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_selectedTimesheets.length} timesheets selected',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          Row(
            children: [
              if (_getFilteredGroupedList().isNotEmpty)
                TextButton(
                  onPressed: _selectedTimesheets.length ==
                          _getFilteredGroupedList().length
                      ? _clearSelection
                      : _selectAllTimesheets,
                  child: Text(
                    _selectedTimesheets.length ==
                            _getFilteredGroupedList().length
                        ? 'Clear All'
                        : 'Select All',
                    style: const TextStyle(color: AppColors.primaryDark),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimesheetList() {
    final groupedList = _getFilteredGroupedList();

    if (_isLoading && !_isRefreshing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading timesheets...',
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
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            SizedBox(height: UI.sectionSpacing),
            Text(
              _getEmptyStateMessage(),
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty ||
                _departmentFilter != null ||
                _tlFilter != null ||
                _siteFilter != null) ...[
              SizedBox(height: UI.sectionSpacing),
              TextButton(
                onPressed: _clearAllFilters,
                child: const Text('Clear All Filters'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedList.length,
      itemBuilder: (context, index) {
        final tsNo = groupedList[index].key;
        final entries = groupedList[index].value;
        return _buildTimesheetCard(tsNo, entries);
      },
    );
    /*return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
            columns: const [
              DataColumn(label: Text('TS No')),
              DataColumn(label: Text('Sl No')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Site')),
              DataColumn(label: Text('Element')),
              DataColumn(label: Text('QTY')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Work Type')),
              DataColumn(label: Text('Time')),
              DataColumn(label: Text('Status')),
            ],
            rows: groupedList.expand((group) {
              final tsNo = group.key;
              final entries = group.value;

              return entries.map((entry) {
                void onRowTap() {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTimesheetScreen(
                        tsNo: tsNo,
                        existingEntries: entries,
                        isEditMode: true,
                        isViewMode: true,
                        timesheetStatus: entry.tsStatus,
                      ),
                    ),
                  ).then((_) => _fetchTimesheetEntries());
                }

                // ✅ FORMAT DATE FUNCTION
                String formatDate(String? date) {
                  if (date == null || date.isEmpty) return '-';
                  try {
                    final parsedDate = DateTime.parse(date);
                    return DateFormat('dd-MM-yyyy').format(parsedDate);
                  } catch (e) {
                    return date.split(' ').first;
                  }
                }

                // ✅ SELECT CORRECT USER ROW BASED ON STATUS
                Widget activityWidget() {
                  switch (entry.tsStatus) {
                    case 'SUBMITTED':
                      return _buildSubmittedByRow(entry, formatDate);
                    case 'APPROVED':
                      return _buildApprovedByRow(entry, formatDate);
                    case 'REJECTED':
                      return _buildRejectedByRow(entry, formatDate);
                    case 'RECHECK':
                      return _buildRecheckByRow(entry, formatDate);
                    default:
                      return const Text('-');
                  }
                }

                return DataRow(
                  cells: [
                    DataCell(Text('$tsNo'), onTap: onRowTap),
                    DataCell(Text('${entry.tsSlNo ?? '-'}'), onTap: onRowTap),
                    DataCell(
                      Text(formatDate(entry.tsDt)),
                      onTap: onRowTap,
                    ),
                    DataCell(
                      SizedBox(
                        width: 250, // prevent overflow
                        child: activityWidget(),
                      ),
                      onTap: onRowTap,
                    ),
                    DataCell(Text('${entry.siteCode ?? '-'}'), onTap: onRowTap),
                    DataCell(Text('${entry.eleId ?? '-'}'), onTap: onRowTap),
                    DataCell(Text('${entry.eleQnty ?? '-'}'), onTap: onRowTap),
                    DataCell(Text('${entry.type ?? '-'}'), onTap: onRowTap),
                    DataCell(Text('${entry.workType ?? '-'}'), onTap: onRowTap),
                    DataCell(Text('${entry.tsUpTime ?? '-'}'), onTap: onRowTap),
                    DataCell(
                      Chip(
                        label: Text(
                          entry.tsStatus ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: _getStatusColor(entry.tsStatus),
                      ),
                      onTap: onRowTap,
                    ),
                  ],
                );
              });
            }).toList(),
          ),
        ),
      ),
    );*/
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'RECHECK':
        return Colors.orange;
      case 'SUBMITTED':
        return Colors.blueGrey;
      case 'FORWARDED':
        return Colors.purple;
      case 'REASSIGNED':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTimesheetCard(int tsNo, List<TimesheetViewModel> entries) {
    final firstEntry = entries.first;
    final status = firstEntry.tsStatus?.toUpperCase() ?? '';

    final bool isOwner = firstEntry.addUser == empCode;
    final bool isTL = firstEntry.tlCode == empCode;
    final bool isApproverUser = _isApprover;
    final bool showActionButtons = _statusFilter != null;
    final List<String> editableStatus = ['SUBMITTED', 'RECHECK', 'REASSIGNED'];
    final List<String> viewableStatus = [
      'APPROVED',
      'REJECTED',
      'RECHECK',
      'SUBMITTED',
      'FORWARDED',
      'REASSIGNED'
    ];

    bool canView = false;
    if (isApproverUser) {
      canView = true;
    } else if (isOwner) {
      canView = true;
    } else if (isTL) {
      canView = true;
    } else if (viewableStatus.contains(status)) {
      canView = true;
    }

    int? reassignedTo;
    String? reassignedToName;

    if ((status == 'FORWARDED' || status == 'REASSIGNED') &&
        firstEntry.reassignData != null &&
        firstEntry.reassignData!.isNotEmpty) {
      try {
        final reassignText = firstEntry.reassignData!;
        final reassignedMatch =
            RegExp(r'Reassign(?:ing)?\s*to:\s*(\d+)').firstMatch(reassignText);
        if (reassignedMatch != null) {
          reassignedTo = int.tryParse(reassignedMatch.group(1)!);
        } else {
          final altReassignedMatch =
              RegExp(r'Reassign\s*To\s*:\s*(\d+)').firstMatch(reassignText);
          if (altReassignedMatch != null) {
            reassignedTo = int.tryParse(altReassignedMatch.group(1)!);
          } else {
            final simpleReassignedMatch =
                RegExp(r'Reassign(?:ing)?\s*to\s*(\d+)')
                    .firstMatch(reassignText);
            if (simpleReassignedMatch != null) {
              reassignedTo = int.tryParse(simpleReassignedMatch.group(1)!);
            }
          }
        }

        final nameMatch =
            RegExp(r'Reassign(?:ing)?\s*to[:\s]*\d+\s*-\s*([^-]+)$')
                .firstMatch(reassignText);
        if (nameMatch != null) {
          reassignedToName = nameMatch.group(1)?.trim();
        }
      } catch (e) {
        debugPrint('Error parsing reassignData: $e');
      }
    }

    final bool isReassignedToCurrentUser = reassignedTo == empCode;

    bool canEditDelete = false;
    if ((isOwner && editableStatus.contains(status)) ||
        (isReassignedToCurrentUser &&
            (status == 'REASSIGNED' || status == 'FORWARDED'))) {
      canEditDelete = true;
    }

    bool canApproveReject = false;
    if (isTL && !isOwner && ['SUBMITTED'].contains(status)) {
      canApproveReject = true;
    } else if (isApproverUser && ['SUBMITTED', 'RECHECK'].contains(status)) {
      canApproveReject = true;
    }

    if (!canView) return const SizedBox();

    String formatDate(String? date) {
      if (date == null || date.isEmpty) return '-';
      try {
        final parsedDate = DateTime.parse(date);
        return DateFormat('dd-MM-yyyy').format(parsedDate);
      } catch (e) {
        return date.split(' ').first;
      }
    }

    int? forwardedBy;
    if ((status == 'FORWARDED' || status == 'REASSIGNED') &&
        firstEntry.reassignData != null &&
        firstEntry.reassignData!.isNotEmpty) {
      try {
        final reassignText = firstEntry.reassignData!;
        final forwardedMatch =
            RegExp(r'Forward(?:ed)?\s*From:\s*(\d+)').firstMatch(reassignText);
        if (forwardedMatch != null) {
          forwardedBy = int.tryParse(forwardedMatch.group(1)!);
        } else {
          final altForwardedMatch =
              RegExp(r'Forward\s*from\s*:\s*(\d+)').firstMatch(reassignText);
          if (altForwardedMatch != null) {
            forwardedBy = int.tryParse(altForwardedMatch.group(1)!);
          }
        }
      } catch (e) {
        debugPrint('Error parsing reassignData for display: $e');
      }
    }

    return GestureDetector(
      onTap: _isSelectionMode
          ? () {
              _toggleTimesheetSelection(tsNo, !_isTimesheetSelected(tsNo));
            }
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTimesheetScreen(
                    tsNo: tsNo,
                    tsSlNo: firstEntry.tsSlNo,
                    existingEntries: entries,
                    isEditMode: true,
                    isViewMode: true,
                    timesheetStatus: status,
                  ),
                ),
              ).then((_) => _fetchTimesheetEntries());
            },
      onLongPress: (_isApprover || _isTeamLeadUser()) &&
              !_isSelectionMode &&
              status == 'SUBMITTED'
          ? () {
              _toggleSelectionMode();
              _toggleTimesheetSelection(tsNo, true);
            }
          : null,
      child: Card(
        color: _isSelectionMode && _isTimesheetSelected(tsNo)
            ? AppColors.primary.withOpacity(0.1)
            : Colors.white,
        elevation: 4,
        margin: EdgeInsets.only(bottom: UI.sectionSpacing),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _isSelectionMode && _isTimesheetSelected(tsNo)
              ? const BorderSide(color: AppColors.primary, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: EdgeInsets.all(UI.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (_isSelectionMode)
                        Checkbox(
                          value: _isTimesheetSelected(tsNo),
                          onChanged: (selected) {
                            _toggleTimesheetSelection(tsNo, selected);
                          },
                        ),
                      Text('Time Sheet No: $tsNo',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  if (!_isSelectionMode)
                    Row(
                      children: [
                        if (canApproveReject &&
                            (status == 'SUBMITTED') &&
                            showActionButtons) ...[
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            tooltip: 'Approve',
                            onPressed: () => _updateTimesheetStatus(
                                tsNo, "APPROVE", entries),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel,
                                color: Colors.redAccent),
                            tooltip: 'Reject',
                            onPressed: () =>
                                _updateTimesheetStatus(tsNo, "REJECT", entries),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.refresh, color: Colors.orange),
                            tooltip: 'Recheck',
                            onPressed: () => _updateTimesheetStatus(
                                tsNo, "RECHECK", entries),
                          ),
                        ],
                        IconButton(
                          icon:
                              const Icon(Icons.visibility, color: Colors.grey),
                          tooltip: 'View',
                          onPressed: () {
                            print(
                                "DEBUG: View clicked - tsNo: $tsNo, entries count: ${entries?.length}");
                            if (entries != null && entries.isNotEmpty) {
                              print(
                                  "DEBUG: First entry totHrs: ${entries.first.totHrs}");
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddTimesheetScreen(
                                  tsNo: tsNo,
                                  existingEntries: entries,
                                  isEditMode: true,
                                  isViewMode: true,
                                  timesheetStatus: status,
                                  currentStatusFilter: _statusFilter,
                                ),
                              ),
                            ).then((_) => _fetchTimesheetEntries());
                          },
                        ),
                        if (canEditDelete) ...[
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: 'Edit',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddTimesheetScreen(
                                    tsNo: tsNo,
                                    existingEntries: entries,
                                    isEditMode: true,
                                    isViewMode: false,
                                    currentStatusFilter: _statusFilter,
                                  ),
                                ),
                              ).then((_) => _fetchTimesheetEntries());
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () => _deleteTimesheet(tsNo),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
              SizedBox(height: UI.sectionSpacing),
              if (isReassignedToCurrentUser && status == 'REASSIGNED') ...[
                Chip(
                  label: const Text(
                    'ASSIGNED TO YOU',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  backgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Colors.white, width: 1),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FutureBuilder<String>(
                      future: getEmployeeNameWithCode(firstEntry.tlCode ?? 0),
                      builder: (context, snapshot) {
                        return Chip(
                          label: Text(
                            'TL :  ${snapshot.data ?? '${firstEntry.tlCode ?? '-'} - -'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          backgroundColor:
                              _getTeamLeadColor(firstEntry.tlCode?.toString()),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side:
                                const BorderSide(color: Colors.grey, width: 1),
                          ),
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        );
                      },
                    ),
                    SizedBox(width: UI.sectionSpacing),
                    Chip(
                      label: Text(
                        '${_getDepartmentName(firstEntry.deptCode)}',
                        style: const TextStyle(color: Colors.black),
                      ),
                      backgroundColor: _getDepartmentColor(firstEntry.deptCode),
                      shape: const StadiumBorder(
                        side: BorderSide(color: AppColors.text, width: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: () {
                  final sortedEntries = List<TimesheetViewModel>.from(entries);
                  sortedEntries
                      .sort((a, b) => (a.tsSlNo ?? 0).compareTo(b.tsSlNo ?? 0));

                  return sortedEntries.map((entry) {
                    final String siteDisplay;
                    if (entry.siteCode != null) {
                      final siteName =
                          _siteNameCache[entry.siteCode] ?? "Loading...";
                      siteDisplay = "${entry.siteCode} - $siteName";
                    } else {
                      siteDisplay = '-';
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.primary),
                                ),
                                child: Text(
                                  '${entry.tsSlNo ?? 'N/A'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('Site: $siteDisplay',
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // ADDED DATE FIELD FOR EACH ENTRY
                          Text(
                            'TS Date: ${formatDate(entry.tsDt)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Element ID: ${entry.eleId ?? '-'} | Type: ${entry.type ?? '-'} | Work Type: ${entry.workType ?? '-'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Work Time: ${entry.tsUpTime ?? '-'} | Entry Dept: ${entry.deptType ?? '-'}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                }(),
              ),
              const SizedBox(height: 10),
              Chip(
                avatar: Icon(
                  status == 'APPROVED'
                      ? Icons.check_circle
                      : status == 'REJECTED'
                          ? Icons.cancel
                          : status == 'RECHECK'
                              ? Icons.sync_alt
                              : status == 'FORWARDED'
                                  ? Icons.forward
                                  : status == 'REASSIGNED'
                                      ? Icons.assignment
                                      : Icons.hourglass_top,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  status,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                backgroundColor: status == 'APPROVED'
                    ? Colors.green
                    : status == 'REJECTED'
                        ? Colors.red
                        : status == 'RECHECK'
                            ? Colors.orange
                            : status == 'FORWARDED'
                                ? Colors.purple
                                : status == 'REASSIGNED'
                                    ? Colors.teal
                                    : Colors.blueGrey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white, width: 1),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              const SizedBox(height: 8),
              if (status == 'SUBMITTED') ...[
                _buildSubmittedByRow(firstEntry, formatDate),
              ] else if (status == 'APPROVED') ...[
                _buildSubmittedByRow(firstEntry, formatDate),
                _buildApprovedByRow(firstEntry, formatDate),
                if (firstEntry.appRemarks?.isNotEmpty ?? false)
                  _buildRemarks(firstEntry.appRemarks!),
              ] else if (status == 'REJECTED') ...[
                _buildSubmittedByRow(firstEntry, formatDate),
                _buildRejectedByRow(firstEntry, formatDate),
                if (firstEntry.appRemarks?.isNotEmpty ?? false)
                  _buildRemarks(firstEntry.appRemarks!),
              ] else if (status == 'RECHECK') ...[
                _buildSubmittedByRow(firstEntry, formatDate),
                _buildRecheckByRow(firstEntry, formatDate),
                if (firstEntry.reChkRemarks?.isNotEmpty ?? false)
                  _buildRemarks(firstEntry.reChkRemarks!),
              ] else if (status == 'FORWARDED' || status == 'REASSIGNED') ...[
                _buildSubmittedByRow(firstEntry, formatDate),
                if (forwardedBy != null)
                  FutureBuilder<String>(
                    future: getEmployeeNameWithCode(forwardedBy),
                    builder: (context, snapshot) {
                      final empLabel = snapshot.data ?? "$forwardedBy - -";
                      return _buildUserRow(
                        icon: Icons.forward,
                        color: Colors.purple,
                        label: "Forwarded from: $empLabel",
                      );
                    },
                  ),
                if (reassignedTo != null)
                  _buildUserRow(
                    icon: status == 'FORWARDED'
                        ? Icons.assignment_ind
                        : Icons.assignment_turned_in,
                    color: Colors.teal,
                    label: status == 'FORWARDED'
                        ? "Reassign to: ${reassignedToName != null ? '$reassignedTo - $reassignedToName' : '$reassignedTo - -'}"
                        : "Reassigned to: ${reassignedToName != null ? '$reassignedTo - $reassignedToName' : '$reassignedTo - -'} (${formatDate(firstEntry.addDate)})",
                  ),
                if (forwardedBy == null &&
                    reassignedTo == null &&
                    firstEntry.reassignData != null)
                  _buildUserRow(
                    icon: Icons.info,
                    color: Colors.orange,
                    label: "Reassignment: ${firstEntry.reassignData}",
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Bulk update method
  Future<void> _bulkUpdateTimesheetStatus(String action) async {
    if (empCode == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not loaded yet. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedTimesheets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one timesheet.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Filter only SUBMITTED timesheets
    final validTimesheets = _selectedTimesheets.where((tsNo) {
      final entries = _groupedEntries[tsNo];
      if (entries == null || entries.isEmpty) return false;
      final status = entries.first.tsStatus?.toUpperCase();
      return status == 'SUBMITTED';
    }).toList();

    if (validTimesheets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected timesheets must be in SUBMITTED status.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final remarksController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            '${action[0].toUpperCase()}${action.substring(1).toLowerCase()} ${validTimesheets.length} Timesheet${validTimesheets.length > 1 ? 's' : ''}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to ${action.toLowerCase()} ${validTimesheets.length} timesheet${validTimesheets.length > 1 ? 's' : ''}.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remarksController,
              maxLines: 2,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
            ),
            child:
                const Text('Confirm', style: TextStyle(color: AppColors.text)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      int successCount = 0;
      int failCount = 0;

      for (int tsNo in validTimesheets) {
        try {
          final uri = ApiUtils.getUri('UpdateTimesheetStatusAll');

          Map<String, dynamic> body = {
            "TSNO": tsNo,
            "TSSTATUS": action.toUpperCase(),
          };

          if (action.toUpperCase() == 'APPROVE' ||
              action.toUpperCase() == 'REJECT') {
            body["APPUSER"] = empCode;
            body["APPREMARKS"] = remarksController.text;
          } else if (action.toUpperCase() == 'RECHECK') {
            body["RECHKUSER"] = empCode;
            body["RECHKREMARKS"] = remarksController.text;

            // Get entries for this timesheet
            final entries = _groupedEntries[tsNo] ?? [];
            List<Map<String, dynamic>> recheckData = entries
                .map((e) => {
                      "TSNO": e.tsNo ?? 0,
                      "TSDT": e.tsDt != null
                          ? DateTime.parse(e.tsDt!).toIso8601String()
                          : DateTime.now().toIso8601String(),
                      "SITECODE": e.siteCode ?? 0,
                      "ELEID": e.eleId ?? '',
                      "TYPE": e.type ?? '',
                      "WORKTYPE": e.workType ?? '',
                      "REMARKS": e.remarks ?? '',
                      "TSDEPTTYPE": e.deptType ?? '',
                      "TSUPTIME": e.tsUpTime ?? '',
                    })
                .toList();

            body["RECHKDATA"] = jsonEncode(recheckData);
          }

          final response = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          );

          final data = jsonDecode(response.body);
          if (response.statusCode == 200 && data['Success'] == true) {
            successCount++;
          } else {
            failCount++;
            debugPrint('Failed to update timesheet $tsNo: ${data['Message']}');
          }
        } catch (e) {
          failCount++;
          debugPrint('Error updating timesheet $tsNo: $e');
        }
      }

      setState(() {
        _isLoading = false;
        _isSelectionMode = false;
        _selectedTimesheets.clear();
        _timesheetCheckboxStates.clear();
      });

      // Show result summary
      String message = '';
      if (successCount > 0 && failCount == 0) {
        message =
            'Successfully $action${action.endsWith('e') ? 'd' : 'ed'} $successCount timesheet${successCount > 1 ? 's' : ''}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (successCount > 0 && failCount > 0) {
        message =
            '$action${action.endsWith('e') ? 'd' : 'ed'} $successCount timesheet${successCount > 1 ? 's' : ''}, failed for $failCount';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        message = 'Failed to $action any timesheets';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
          ),
        );
      }

      // Refresh the data
      await _fetchTimesheetEntries();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during bulk update: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Input Decoration Method
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

  Widget _buildInitialLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading Timesheets...',
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

  String _getEmptyStateMessage() {
    // Check date filter first
    if (_fromDate != null || _toDate != null) {
      final fromText = _fromDate != null
          ? DateFormat('dd-MM-yyyy').format(_fromDate!)
          : 'any date';
      final toText = _toDate != null
          ? DateFormat('dd-MM-yyyy').format(_toDate!)
          : 'any date';

      if (_searchQuery.isNotEmpty &&
          _departmentFilter != null &&
          _siteFilter != null) {
        final siteInfo = _allSites.firstWhere(
          (s) => s['code'] == _siteFilter,
          orElse: () => {
            "code": _siteFilter,
            "name": "Unknown Site",
            "display": "$_siteFilter - Unknown Site"
          },
        );
        return 'No timesheets found for "$_searchQuery" in $_departmentFilter department at site ${siteInfo['display']} between $fromText and $toText';
      } else if (_searchQuery.isNotEmpty && _departmentFilter != null) {
        return 'No timesheets found for "$_searchQuery" in $_departmentFilter department between $fromText and $toText';
      } else if (_searchQuery.isNotEmpty && _siteFilter != null) {
        final siteInfo = _allSites.firstWhere(
          (s) => s['code'] == _siteFilter,
          orElse: () => {
            "code": _siteFilter,
            "name": "Unknown Site",
            "display": "$_siteFilter - Unknown Site"
          },
        );
        return 'No timesheets found for "$_searchQuery" at site ${siteInfo['display']} between $fromText and $toText';
      } else if (_departmentFilter != null && _siteFilter != null) {
        final siteInfo = _allSites.firstWhere(
          (s) => s['code'] == _siteFilter,
          orElse: () => {
            "code": _siteFilter,
            "name": "Unknown Site",
            "display": "$_siteFilter - Unknown Site"
          },
        );
        return 'No timesheets found in $_departmentFilter department at site ${siteInfo['display']} between $fromText and $toText';
      } else if (_searchQuery.isNotEmpty) {
        return 'No timesheets found for "$_searchQuery" between $fromText and $toText';
      } else if (_departmentFilter != null) {
        return 'No timesheets found in $_departmentFilter department between $fromText and $toText';
      } else if (_siteFilter != null) {
        final siteInfo = _allSites.firstWhere(
          (s) => s['code'] == _siteFilter,
          orElse: () => {
            "code": _siteFilter,
            "name": "Unknown Site",
            "display": "$_siteFilter - Unknown Site"
          },
        );
        return 'No timesheets found at site ${siteInfo['display']} between $fromText and $toText';
      } else if (_tlFilter != null) {
        return 'No timesheets found for selected TL between $fromText and $toText';
      } else {
        return 'No timesheets found between $fromText and $toText';
      }
    }

    // Rest of your existing empty state messages...
    if (_searchQuery.isNotEmpty &&
        _departmentFilter != null &&
        _siteFilter != null) {
      final siteInfo = _allSites.firstWhere(
        (s) => s['code'] == _siteFilter,
        orElse: () => {
          "code": _siteFilter,
          "name": "Unknown Site",
          "display": "$_siteFilter - Unknown Site"
        },
      );
      return 'No timesheets found for "$_searchQuery" in $_departmentFilter department at site ${siteInfo['display']}';
    } else if (_searchQuery.isNotEmpty && _departmentFilter != null) {
      return 'No timesheets found for "$_searchQuery" in $_departmentFilter department';
    } else if (_searchQuery.isNotEmpty && _siteFilter != null) {
      final siteInfo = _allSites.firstWhere(
        (s) => s['code'] == _siteFilter,
        orElse: () => {
          "code": _siteFilter,
          "name": "Unknown Site",
          "display": "$_siteFilter - Unknown Site"
        },
      );
      return 'No timesheets found for "$_searchQuery" at site ${siteInfo['display']}';
    } else if (_departmentFilter != null && _siteFilter != null) {
      final siteInfo = _allSites.firstWhere(
        (s) => s['code'] == _siteFilter,
        orElse: () => {
          "code": _siteFilter,
          "name": "Unknown Site",
          "display": "$_siteFilter - Unknown Site"
        },
      );
      return 'No timesheets found in $_departmentFilter department at site ${siteInfo['display']}';
    } else if (_searchQuery.isNotEmpty) {
      return 'No timesheets found for "$_searchQuery"';
    } else if (_departmentFilter != null) {
      return 'No timesheets found in $_departmentFilter department';
    } else if (_siteFilter != null) {
      final siteInfo = _allSites.firstWhere(
        (s) => s['code'] == _siteFilter,
        orElse: () => {
          "code": _siteFilter,
          "name": "Unknown Site",
          "display": "$_siteFilter - Unknown Site"
        },
      );
      return 'No timesheets found at site ${siteInfo['display']}';
    } else if (_tlFilter != null) {
      return 'No timesheets found for selected TL';
    } else {
      return 'No timesheets found';
    }
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _departmentFilter = null;
      _tlFilter = null;
      _siteFilter = null;
      _siteController.clear();
      _fromDate = null;
      _toDate = null;
      _fromDateController.clear();
      _toDateController.clear();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  String _getDepartmentName(dynamic deptCode) {
    final deptString = deptCode?.toString() ?? '';

    switch (deptString) {
      case '1':
      case 'DES':
      case 'DESIGN':
      case 'DESIGNING':
        return 'DESIGNING';
      case '2':
      case 'DRA':
      case 'DRAFT':
      case 'DRAFTING':
        return 'DRAFTING';
      default:
        return deptString.isNotEmpty ? deptString : 'UNKNOWN';
    }
  }

  EdgeInsets _getCardPadding() {
    if (kIsWeb) {
      return const EdgeInsets.all(14);
    }

    try {
      if (Platform.isWindows) {
        return const EdgeInsets.all(16);
      } else {
        return const EdgeInsets.all(10);
      }
    } catch (e) {
      return const EdgeInsets.all(14);
    }
  }

  Widget buildSubmittedByRow(
      TimesheetViewModel entry, String Function(String?) formatDate) {
    return FutureBuilder<String>(
      future: getEmployeeNameWithCode(entry.addUser ?? 0),
      builder: (context, snapshot) {
        final empLabel = snapshot.data ?? "${entry.addUser ?? 0} - -";
        return _buildUserRow(
          icon: Icons.person_add,
          color: Colors.blueGrey,
          label: "Submitted by: $empLabel (${formatDate(entry.addDate)})",
        );
      },
    );
  }

  Widget _buildSubmittedByRow(
      TimesheetViewModel entry, String Function(String?) formatDate) {
    return FutureBuilder<String>(
      future: getEmployeeNameWithCode(entry.addUser ?? 0),
      builder: (context, snapshot) {
        final empLabel = snapshot.data ?? "${entry.addUser ?? 0} - -";
        return _buildUserRow(
          icon: Icons.person_add,
          color: Colors.blueGrey,
          label: "$empLabel",
        );
      },
    );
  }

  Widget buildApprovedByRow(
      TimesheetViewModel entry, String Function(String?) formatDate) {
    return FutureBuilder<String>(
      future: getEmployeeNameWithCode(entry.appUser ?? 0),
      builder: (context, snapshot) {
        final empLabel = snapshot.data ?? "${entry.appUser ?? 0} - -";
        return _buildUserRow(
          icon: Icons.verified,
          color: Colors.green,
          label: "Approved by: $empLabel (${formatDate(entry.appDate)})",
        );
      },
    );
  }

  Widget _buildApprovedByRow(
      TimesheetViewModel entry, String Function(String?) formatDate) {
    return FutureBuilder<String>(
      future: getEmployeeNameWithCode(entry.appUser ?? 0),
      builder: (context, snapshot) {
        final empLabel = snapshot.data ?? "${entry.appUser ?? 0} - -";
        return _buildUserRow(
          icon: Icons.verified,
          color: Colors.green,
          label: "$empLabel",
        );
      },
    );
  }

  Widget buildRejectedByRow(
      TimesheetViewModel entry, String Function(String?) formatDate) {
    return FutureBuilder<String>(
      future: getEmployeeNameWithCode(entry.appUser ?? 0),
      builder: (context, snapshot) {
        final empLabel = snapshot.data ?? "${entry.appUser ?? 0} - -";
        return _buildUserRow(
          icon: Icons.cancel,
          color: Colors.red,
          label: "Rejected by: $empLabel (${formatDate(entry.appDate)})",
        );
      },
    );
  }

  Widget _buildRejectedByRow(
      TimesheetViewModel entry, String Function(String?) formatDate) {
    return FutureBuilder<String>(
      future: getEmployeeNameWithCode(entry.appUser ?? 0),
      builder: (context, snapshot) {
        final empLabel = snapshot.data ?? "${entry.appUser ?? 0} - -";
        return _buildUserRow(
          icon: Icons.cancel,
          color: Colors.red,
          label: "$empLabel",
        );
      },
    );
  }

  Widget buildRecheckByRow(
      TimesheetViewModel entry, String Function(String?) formatDate) {
    return FutureBuilder<String>(
      future: getEmployeeNameWithCode(entry.reChkUser ?? 0),
      builder: (context, snapshot) {
        final empLabel = snapshot.data ?? "${entry.reChkUser ?? 0} - -";
        return _buildUserRow(
          icon: Icons.sync_alt,
          color: Colors.orange,
          label:
              "Marked as Recheck by: $empLabel (${formatDate(entry.reChkDate)})",
        );
      },
    );
  }

  Widget _buildRecheckByRow(
      TimesheetViewModel entry, String Function(String?) formatDate) {
    return FutureBuilder<String>(
      future: getEmployeeNameWithCode(entry.reChkUser ?? 0),
      builder: (context, snapshot) {
        final empLabel = snapshot.data ?? "${entry.reChkUser ?? 0} - -";
        return _buildUserRow(
          icon: Icons.sync_alt,
          color: Colors.orange,
          label: "$empLabel",
        );
      },
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }

  Widget _buildUserRow({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarks(String remarks) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 24),
      child: Text(
        'Remarks: $remarks',
        style: const TextStyle(
          fontSize: 13,
          fontStyle: FontStyle.italic,
          color: Colors.black87,
        ),
      ),
    );
  }

  Color _getDepartmentColor(dynamic deptCode) {
    switch (deptCode?.toString()) {
      case '1':
        return Colors.blue.shade100;
      case '2':
        return Colors.pink.shade100;
      default:
        return Colors.grey.shade300;
    }
  }

  Color _getTeamLeadColor(dynamic tlCode) {
    switch (tlCode?.toString()) {
      case '3234':
        return Colors.indigo.shade400;
      case '5005':
        return Colors.teal.shade400;
      case '5007':
        return Colors.orange.shade400;
      case '5696':
        return Colors.pink.shade400;
      case '8664':
        return Colors.blue.shade400;
      case '13230':
        return Colors.amber.shade500;
      case '13330':
        return Colors.deepPurple.shade400;
      case '3000':
        return Colors.lightGreen.shade400;
      case '8141':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  void _deleteTimesheet(int tsNo) async {
    if (empCode == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not loaded yet. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
            'Are you sure you want to delete all entries for this timesheet?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uri = ApiUtils.getUri('DeleteTimesheetByTSNO');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "TSNO": tsNo,
          "DELUSER": empCode.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['Success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('All entries for this timesheet deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchTimesheetEntries();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: ${result['Message']}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Server error: ${response.statusCode} ${response.reasonPhrase}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting timesheet: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _updateTimesheetStatus(
      int tsNo, String action, List<TimesheetViewModel> entries) async {
    if (empCode == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not loaded yet. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final remarksController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            '${action[0].toUpperCase()}${action.substring(1).toLowerCase()} Timesheet'),
        content: TextField(
          controller: remarksController,
          maxLines: 2,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            labelText: 'Remarks (optional)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
            ),
            child:
                const Text('Confirm', style: TextStyle(color: AppColors.text)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uri = ApiUtils.getUri('UpdateTimesheetStatus');

      Map<String, dynamic> body = {
        "TSNO": tsNo,
        "TSSTATUS": action.toUpperCase(),
      };

      if (action.toUpperCase() == 'APPROVE' ||
          action.toUpperCase() == 'REJECT') {
        body["APPUSER"] = empCode;
        body["APPREMARKS"] = remarksController.text;
      } else if (action.toUpperCase() == 'RECHECK') {
        body["RECHKUSER"] = empCode;
        body["RECHKREMARKS"] = remarksController.text;

        List<Map<String, dynamic>> recheckData = entries
            .map((e) => {
                  "TSNO": e.tsNo ?? 0,
                  "TSDT": e.tsDt != null
                      ? DateTime.parse(e.tsDt!).toIso8601String()
                      : DateTime.now().toIso8601String(),
                  "SITECODE": e.siteCode ?? 0,
                  "ELEID": e.eleId ?? '',
                  "TYPE": e.type ?? '',
                  "WORKTYPE": e.workType ?? '',
                  "REMARKS": e.remarks ?? '',
                  "TSDEPTTYPE": e.deptType ?? '',
                  "TSUPTIME": e.tsUpTime ?? '',
                })
            .toList();

        body["RECHKDATA"] = jsonEncode(recheckData);
        debugPrint('RECHECK Data entries: ${entries.length}');
        debugPrint('RECHECK Data JSON: ${body["RECHKDATA"]}');
      }

      debugPrint('Sending request body: ${jsonEncode(body)}');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      debugPrint('API Response: $data');

      if (response.statusCode == 200 && data['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message'] ?? 'Action completed successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        _handleRefresh();
        //   Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message'] ?? 'Failed to update timesheet'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating timesheet status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String> getEmployeeNameWithCode(int empCode) async {
    try {
      final uri = ApiUtils.getUri("GetEmployeeNames");
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"EMPCODE": empCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true && data['Departments'].isNotEmpty) {
          final emp = data['Departments'][0];
          return "${emp['EMPCODE'] ?? empCode} - ${emp['EMPNAME'] ?? '-'}";
        }
      }
    } catch (e) {
      debugPrint("Error fetching employee name: $e");
    }

    return "$empCode - -";
  }

  Future<String> _fetchSiteName(String siteCode) async {
    try {
      if (siteCode.isEmpty) return "Site $siteCode";
      final siteInfo = await _fileService.loadSiteName(int.parse(siteCode));
      return siteInfo?.first['PROJECTNAME'] ?? "Site $siteCode";
    } catch (e) {
      debugPrint("Error fetching site name: $e");
      return "Site $siteCode";
    }
  }
}

class UI {
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static double get cardPadding => isMobile ? 8.0 : 12.0;
  static double get sectionSpacing => isMobile ? 2.0 : 8.0;
  static double get innerSpacing => isMobile ? 6.0 : 4.0;
  static double get iconSize => isMobile ? 22.0 : 18.0;
  static double get fontSize => isMobile ? 14.0 : 13.0;
}
