import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/file_service.dart';
import '../../services/prefrence_helper.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:collection/collection.dart';

class AddTimesheetScreen extends StatefulWidget {
  final int? tsNo;
  final int? tsSlNo;
  final List<TimesheetViewModel>? existingEntries;
  final bool isEditMode;
  final bool isViewMode;
  final String? timesheetStatus;
  final String? currentStatusFilter;

  const AddTimesheetScreen({
    super.key,
    this.tsNo,
    this.tsSlNo,
    this.existingEntries,
    this.isEditMode = false,
    this.isViewMode = false,
    this.timesheetStatus,
    this.currentStatusFilter,
  });

  @override
  State<AddTimesheetScreen> createState() => _AddTimesheetScreenState();
}

class _AddTimesheetScreenState extends State<AddTimesheetScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FileService _fileService = FileService();
  bool? canEdit; // null = not yet checked

  bool _isLoading = false;
  List<Project> _projects = [];
  List<int> _allowedAppRejEmpCodes = []; // Store allowed approver emp codes

  int empCode = 0;
  String? empName;
  String? empDept;
  String? empTL;

  late List<TimesheetEntry> _entries;
  final List<String> _types = ['New', 'Rework'];
  bool _selectAll = false;
  String? _statusFilter;
  Map<int, List<TimesheetViewModel>> _groupedEntries = {};
  bool get _isUserTL {
    final isTL = _teamLeadEmpCodes.contains(empCode);
    debugPrint('Checking if user is TL - empCode: $empCode, isTL: $isTL');
    return isTL;
  }

  // Track if timesheet is approved or rejected
  bool get _isTimesheetLocked =>
      widget.timesheetStatus == 'APPROVED' ||
      widget.timesheetStatus == 'REJECTED' ||
      widget.timesheetStatus == 'FORWARDED';

// Check if current user can approve/reject
  bool get _canApproveReject {
    debugPrint('empCode: $empCode');
    debugPrint('isUserTL: $_isUserTL');
    debugPrint('allowedAppRejEmpCodes: $_allowedAppRejEmpCodes');
    debugPrint('timesheetStatus: ${widget.timesheetStatus}');
    debugPrint('contains empCode: ${_allowedAppRejEmpCodes.contains(empCode)}');

    return (_isUserTL || _allowedAppRejEmpCodes.contains(empCode)) &&
        (widget.timesheetStatus == 'SUBMITTED');
  }

// Check if timesheet is submitted and user can approve/reject
  bool get _showApproveRejectOptions {
    debugPrint('isViewMode: ${widget.isViewMode}');
    debugPrint('timesheetStatus: ${widget.timesheetStatus}');
    debugPrint('canApproveReject: $_canApproveReject');

    final shouldShow = widget.isViewMode && _canApproveReject;

    debugPrint('showApproveRejectOptions: $shouldShow');
    return shouldShow;
  }

  List<int> _teamLeadEmpCodes = []; // Store team lead emp codes

  final Map<int, TextEditingController> _elementControllers = {};
  Timer? _elementIdDebounce;
  List<String> _designingElementIds = [];
  List<String> _draftingElementIds = [];
  final Map<int, TextEditingController> _dateControllers =
      {}; // 🔥 CHANGE TO MAP

  // Add this method for date validation
  bool _isDateWithinAllowedRange(DateTime date) {
    final now = DateTime.now();
    /*final twoDaysAgo = DateTime(now.year, now.month, now.day - 2);
    return date.isAfter(twoDaysAgo) || _isSameDay(date, twoDaysAgo);*/
    return date.isBefore(now) || date.isAtSameMomentAs(now);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String? totalHours; // example: "1.05"

  List<String> elementIdList = [];
  Map<int, TextEditingController> _qtyControllers = {};
  Map<int, TextEditingController> _elenameControllers = {};
  List<String> _elementNames = [];

  bool isViewMode = true;
  Set<int> _selectedTimesheets = <int>{};

  @override
  void initState() {
    super.initState();

    // If in edit mode, the date will be loaded from existing entries in _loadEditEntries()
    _loadDesigningElementIds();
    _loadDraftingElementIds();
    _loadElementNames();
    _entries = [];
    for (var entry in _entries) {
      checkElementIssuedForEntry(entry); // updates entry.canEdit individually
    }
    if (widget.isEditMode && widget.existingEntries != null) {
      _loadEditEntries();
    } else {
      _addNewEntry();
    }
    _loadUserAndProjects();
    _fetchAllowedApprovers(); // Fetch allowed approvers list
    _fetchTeamLeads();
  }

  void _initControllers(int index) {
    // Only initialize if controller doesn't exist
    if (_elementControllers[index] == null) {
      _elementControllers[index] = TextEditingController();
    }
    if (_qtyControllers[index] == null) {
      _qtyControllers[index] = TextEditingController();
    }
    if (_elenameControllers[index] == null) {
      _elenameControllers[index] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _elementControllers.values) {
      controller.dispose();
    }
    for (final controller in _dateControllers.values) {
      // 🔥 DISPOSE DATE CONTROLLERS
      controller.dispose();
    }
    _elementIdDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('=== BUILD CALLED ===');
    debugPrint('_showApproveRejectOptions: $_showApproveRejectOptions');
    if (_isLoading || (widget.isViewMode && _teamLeadEmpCodes.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.isViewMode ? 'View' : (widget.isEditMode ? 'Edit' : 'Add')} Timesheet'
          '${widget.tsNo != null ? ' #${widget.tsNo}' : ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
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
        // Only show action buttons if all conditions are met
        actions: _showApproveRejectOptions
            ? [
                IconButton(
                  tooltip: 'Approve All Selected',
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () {
                    final selected = _selectedEntries();
                    final tsSlNos = selected
                        .map((e) => e.tsSlNo)
                        .where((e) => e != null)
                        .cast<int>()
                        .toList();

                    if (selected.isNotEmpty) {
                      _updateTimesheetStatus(
                        widget.tsNo!,
                        'Approve',
                        selected,
                        tsSlNos,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please select at least one entry for Timesheet #${widget.tsNo ?? '-'}',
                          ),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Reject All Selected',
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () {
                    final selected = _selectedEntries();
                    final tsSlNos = selected.map((e) => e.tsSlNo).toList();
                    if (selected.isNotEmpty) {
                      _updateTimesheetStatus(
                          widget.tsNo!, 'Reject', selected, tsSlNos);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one entry'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Recheck All Selected',
                  icon: const Icon(Icons.refresh, color: Colors.orange),
                  onPressed: () {
                    final selected = _selectedEntries();
                    final tsSlNos = selected.map((e) => e.tsSlNo).toList();
                    if (selected.isNotEmpty) {
                      _updateTimesheetStatus(
                          widget.tsNo!, 'Recheck', selected, tsSlNos);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one entry'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    }
                  },
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Show status banner if timesheet is locked or has special status
                    if (_isTimesheetLocked || widget.timesheetStatus != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.1),
                          border: Border.all(color: _getStatusColor()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(_getStatusIcon(), color: _getStatusColor()),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getStatusText(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(),
                                ),
                              ),
                            ),
                            // Show approver info if user can approve/reject
                            if (_canApproveReject && _isUserTL)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Approver Access',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    Expanded(child: _buildEntriesList()),
                    const SizedBox(height: 10),
                    // Only show action buttons if timesheet is NOT locked and NOT in view mode
                    if (!widget.isViewMode && !_isTimesheetLocked)
                      _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _selectDate(BuildContext context, int index) async {
    final currentDate = _entries[index].entryDate ?? DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(1000), // Allow dates from the year 2000
      lastDate: DateTime.now(), // Don't allow future dates
      selectableDayPredicate: (DateTime day) {
        // Ensure all past dates are selectable
        return day.isBefore(DateTime.now()) ||
            day.isAtSameMomentAs(DateTime.now());
      },
    );

    if (picked != null && picked != currentDate) {
      setState(() {
        _entries[index].entryDate = picked;
        _entries[index].isModified = true;

        // Update the controller text
        if (_dateControllers.containsKey(index)) {
          _dateControllers[index]!.text =
              DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  Future<void> _loadDesigningElementIds() async {
    try {
      final elementIds = await fetchDesigningElementIds();
      debugPrint('✅ Designing Element IDs loaded: $elementIds');
      setState(() {
        _designingElementIds = elementIds;
      });
    } catch (e) {
      debugPrint('❌ Failed to load Designing Element IDs: $e');
    }
  }

  Future<void> _loadDraftingElementIds() async {
    try {
      final elementIds = await fetchDraftingElementIds();
      debugPrint('✅ Designing Element IDs loaded: $elementIds');
      setState(() {
        _draftingElementIds = elementIds;
      });
    } catch (e) {
      debugPrint('❌ Failed to load Designing Element IDs: $e');
    }
  }

  Future<void> _loadElementNames() async {
    try {
      final elementNames = await fetchElementNames();
      debugPrint('✅ Piece Drawing Element is: $elementNames');
      setState(() {
        _elementNames = elementNames;
      });
    } catch (e) {
      debugPrint('❌ Failed to load Designing Element IDs: $e');
    }
  }

  Future<List<String>> fetchDesigningElementIds() async {
    final url = ApiUtils.getUri('GetDesigningElementIds');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({}), // empty body for now
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['Success'] == true) {
        return List<String>.from(data['Elements']);
      }
    }

    return [];
  }

  Future<List<String>> fetchDraftingElementIds() async {
    final url = ApiUtils.getUri('GetDraftingElementIds');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({}), // empty body for now
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['Success'] == true) {
        return List<String>.from(data['Elements']);
      }
    }

    return [];
  }

  Future<List<String>> fetchElementNames() async {
    final url = ApiUtils.getUri('GetPieceDrawingElementNames');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({}), // empty body for now
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['Success'] == true) {
        return List<String>.from(data['Elements']);
      }
    }

    return [];
  }

  Future<void> _fetchAllowedApprovers() async {
    try {
      debugPrint('Fetching allowed approvers...');
      final uri = ApiUtils.getUri('ShowAppRej');
      final response =
          await http.post(uri, headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Approvers API response: $data');
        if (data is List) {
          _allowedAppRejEmpCodes = data.cast<int>();
          debugPrint('Loaded approvers: $_allowedAppRejEmpCodes');
        } else {
          debugPrint('Unexpected API response format: $data');
        }
      } else {
        debugPrint('API call failed with status: ${response.statusCode}');
      }
      setState(() {}); // Force rebuild after loading approvers
    } catch (e) {
      debugPrint('Error fetching approvers: $e');
    }
  }

  Future<void> _fetchTeamLeads() async {
    try {
      debugPrint('Fetching team leads...');
      final uri =
          ApiUtils.getUri('TeamLead'); // ✅ FIXED: Add correct endpoint path
      final response =
          await http.post(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('TeamLeads API response: $data');

        if (data is List) {
          _teamLeadEmpCodes = data.cast<int>();
          debugPrint('Loaded team leads: $_teamLeadEmpCodes');
        } else {
          debugPrint('Unexpected TeamLeads API response format: $data');
        }
      } else {
        debugPrint(
            'TeamLeads API call failed with status: ${response.statusCode}');
      }
      setState(() {}); // Force rebuild after loading team leads
    } catch (e) {
      debugPrint('Error fetching team leads: $e');
    }
  }

  Future<void> loadEditEntries() async {
    List<TimesheetEntry> tempEntries = [];

    final sortedExistingEntries =
        List<TimesheetViewModel>.from(widget.existingEntries!);
    sortedExistingEntries
        .sort((a, b) => (a.tsSlNo ?? 0).compareTo(b.tsSlNo ?? 0));

    debugPrint('📥 Loading ${sortedExistingEntries.length} existing entries');

    for (var e in sortedExistingEntries) {
      DateTime? entryDate;

      // 🔥 LOAD DATE FOR EACH INDIVIDUAL ENTRY
      if (e.tsDt != null) {
        try {
          entryDate = DateTime.parse(e.tsDt!);
        } catch (e) {
          debugPrint('❌ Error parsing date for entry: $e');
          entryDate = DateTime.now();
        }
      } else {
        entryDate = DateTime.now();
      }

      String? projectName;
      if (e.siteCode != null) {
        try {
          final sites = await _fileService.loadSiteName(e.siteCode!);
          if (sites.isNotEmpty)
            projectName = sites.first['PROJECTNAME'] as String?;
        } catch (_) {
          projectName = null;
        }
      }

      String? parsedWorkTime = _parseTsuptime(e.tsUpTime);

      // Use the updated parseTotHrs function
      final parsedTime = parseTotHrs(e.totHrs);

      // Debug logging
      debugPrint('''
    🗂️ Loading entry:
      ELEID: ${e.eleId}
      Backend totHrs: ${e.totHrs}
      Parsed totHrs: $parsedTime
      Type: ${e.type}
      WorkType: ${e.workType}
      Status: ${e.tsStatus}
    ''');

      tempEntries.add(TimesheetEntry(
        elementId: e.eleId ?? '',
        type: e.type ?? '',
        workType: e.workType ?? '',
        remarks: e.remarks ?? '',
        projectId: e.siteCode,
        projectName: projectName,
        designingDrafting: e.deptType,
        deptType: e.deptType,
        tsuptime: parsedWorkTime,
        isExisting: true,
        status: e.tsStatus ?? '',
        tsSlNo: e.tsSlNo ?? 0,
        entryDate: entryDate,
        // Use the PARSED time, not the raw backend value
        totHrs: parsedTime,
      ));
    }

    // Debug all loaded entries
    _debugLoadedEntries(tempEntries);

    setState(() => _entries = tempEntries);
  }

  Future<void> _loadEditEntries() async {
    List<TimesheetEntry> tempEntries = [];

    final sortedExistingEntries =
        List<TimesheetViewModel>.from(widget.existingEntries!);

    sortedExistingEntries
        .sort((a, b) => (a.tsSlNo ?? 0).compareTo(b.tsSlNo ?? 0));

    debugPrint('📥 Loading ${sortedExistingEntries.length} existing entries');

    for (var e in sortedExistingEntries) {
      DateTime? entryDate;

      // ✅ DATE
      if (e.tsDt != null) {
        try {
          entryDate = DateTime.parse(e.tsDt!);
        } catch (err) {
          debugPrint('❌ Date parse error: $err');
          entryDate = DateTime.now();
        }
      } else {
        entryDate = DateTime.now();
      }

      // ✅ PROJECT NAME
      String? projectName;
      if (e.siteCode != null) {
        try {
          final sites = await _fileService.loadSiteName(e.siteCode!);
          if (sites.isNotEmpty) {
            projectName = sites.first['PROJECTNAME'] as String?;
          }
        } catch (_) {}
      }

      final parsedWorkTime = _parseTsuptime(e.tsUpTime);
      final parsedTime = parseTotHrs(e.totHrs);

      // 🔥 BUILD ELEMENT ITEMS (IMPORTANT)
      List<Map<String, dynamic>> elementItems = [];

      if (e.draftingType == 'Piece Drawing') {
        if ((e.eleName ?? '').isNotEmpty &&
            (e.eleId ?? '').isNotEmpty &&
            (e.eleQnty ?? 0) > 0) {
          elementItems.add({
            'elementName': e.eleName!,
            'elementId': e.eleId!,
            'qty': e.eleQnty!,
          });
        }
      }

      debugPrint('''
🗂️ Loading entry:
  ELEID: ${e.eleId}
  ELENAME: ${e.eleName}
  ELEQNTY: ${e.eleQnty}
  DraftingType: ${e.draftingType}
''');

      final entry = TimesheetEntry(
        elementId: e.eleId ?? '',
        type: e.type ?? '',
        workType: e.workType ?? '',
        remarks: e.remarks ?? '',
        projectId: e.siteCode,
        projectName: projectName,
        designingDrafting: e.deptType,
        deptType: e.deptType,
        tsuptime: parsedWorkTime,
        isExisting: true,
        status: e.tsStatus ?? '',
        tsSlNo: e.tsSlNo ?? 0,
        entryDate: entryDate,
        totHrs: parsedTime,

        // ✅ IMPORTANT
        draftingType: e.draftingType,
        elementItems: elementItems,
      );

      tempEntries.add(entry);
    }

    setState(() {
      _entries = tempEntries;
    });

    // 🔥 INIT CONTROLLERS AFTER SET
    for (int i = 0; i < _entries.length; i++) {
      final entry = _entries[i];

      // ELEMENT ID
      _elementControllers.putIfAbsent(
          i, () => TextEditingController(text: entry.elementId));

      // ELEMENT NAME
      _elenameControllers.putIfAbsent(
          i,
          () => TextEditingController(
              text: entry.elementItems.isNotEmpty
                  ? entry.elementItems.first['elementName']
                  : ''));

      // QTY
      _qtyControllers.putIfAbsent(
          i,
          () => TextEditingController(
              text: entry.elementItems.isNotEmpty
                  ? entry.elementItems.first['qty'].toString()
                  : ''));

      // DATE
      _dateControllers.putIfAbsent(
          i,
          () => TextEditingController(
              text: DateFormat('yyyy-MM-dd').format(entry.entryDate!)));
    }

    debugPrint('✅ Loaded entries with elementItems: ${_entries.length}');
  }

  void _debugLoadedEntries(List<TimesheetEntry> entries) {
    debugPrint('\n📊 LOADED ENTRIES SUMMARY:');
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      debugPrint('''
      Entry ${i + 1}:
      ELEID: ${entry.elementId}
      totHrs (stored): ${entry.totHrs}
      Hours (getter): ${entry.hours}
      Minutes (getter): ${entry.minutes}
      Status: ${entry.status}
    ''');
    }
    debugPrint('=' * 50);
  }

  String parseTotHrs(String? backendValue) {
    if (backendValue == null || backendValue.isEmpty) {
      return "0:00";
    }

    try {
      // Case 1: Already in HH:MM format (e.g., "2:15")
      if (backendValue.contains(':') && backendValue.split(':').length == 2) {
        return backendValue;
      }

      // Case 2: HH:MM:SS format (e.g., "02:15:00")
      if (backendValue.contains(':') && backendValue.split(':').length == 3) {
        final parts = backendValue.split(':');
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;

        // Remove leading zeros and format as "H:MM"
        return "$hours:${minutes.toString().padLeft(2, '0')}";
      }

      // Case 3: Decimal format (e.g., "2.25", "2.15")
      if (backendValue.contains('.')) {
        return _convertBackendDecimalToTime(backendValue);
      }

      // Case 4: Plain number (e.g., "2")
      final hours = int.tryParse(backendValue) ?? 0;
      return "$hours:00";
    } catch (e) {
      debugPrint('❌ Error parsing totHrs: $backendValue, error: $e');
      return "0:00";
    }
  }

  String _convertBackendDecimalToTime(String backendValue) {
    try {
      debugPrint('🔄 Converting backend decimal to time: $backendValue');

      // Convert string to double
      final decimalValue = double.tryParse(backendValue) ?? 0.0;

      // Now use your existing logic
      // Backend sends special format where:
      // 1.65 = 1 hour 39 minutes (but displays as 2:05 in your special system)
      // 2.75 = 2 hours 45 minutes (but displays as 3:15 in your special system)

      // First, convert to actual hours and minutes
      final hours = decimalValue.floor();
      final decimalPart = decimalValue - hours;

      // Convert decimal part to actual minutes (standard 60 minutes/hour)
      final actualMinutes = (decimalPart * 60).round();

      debugPrint(
          '   Hours: $hours, Decimal: $decimalPart, Actual minutes: $actualMinutes');

      // Now convert to your display format (100 minutes/hour)
      final totalActualMinutes = (hours * 60) + actualMinutes;
      final displayTotal =
          totalActualMinutes * (100 / 60); // Convert to 100-min system

      final displayHours = displayTotal ~/ 100;
      final displayMinutes = (displayTotal % 100).round();

      final result =
          "$displayHours:${displayMinutes.toString().padLeft(2, '0')}";
      debugPrint('   Display: $result ($displayHours:$displayMinutes)');

      return result;
    } catch (e) {
      debugPrint('❌ Error converting decimal to time: $e');
      return "0:00";
    }
  }

  // Add this helper method to parse TSUPTIME value
  String _parseTsuptime(String? tsuptime) {
    if (tsuptime == null || tsuptime.isEmpty) return '';

    // If it contains a pipe (|), extract the FN/AN part
    if (tsuptime.contains('|')) {
      final parts = tsuptime.split('|');
      if (parts.length >= 2) {
        return parts[1]; // Return FN or AN
      }
    }

    // If it's just FN or AN, return as is
    if (tsuptime == 'FN' || tsuptime == 'AN') {
      return tsuptime;
    }

    return '';
  }

  void _addNewEntry() {
    final newEntry = TimesheetEntry(
      elementId: '',
      elementItems: [],
      type: '',
      workType: '',
      remarks: '',
      isExisting: false,
      tsSlNo: 0,
      entryDate: DateTime.now(), // Set default date
    );

    _entries.add(newEntry);

    // Initialize date controller for new entry
    final index = _entries.length - 1;
    _dateControllers.putIfAbsent(
      index,
      () => TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(newEntry.entryDate!),
      ),
    );

    setState(() {});
  }

  Future<void> _loadUserAndProjects() async {
    setState(() => _isLoading = true);
    try {
      final prefsHelper = PreferencesHelper();
      empCode = (await prefsHelper.getEmpCode()) ?? 0;
      empName = await prefsHelper.getEmpName();
      empDept = await prefsHelper.getEmpDept();
      empTL = await prefsHelper.getEmpTL();

      debugPrint('Loaded user - empCode: $empCode, name: $empName');

      final projects = await _fileService.loadProjNames();
      setState(() => _projects = projects);
    } catch (e) {
      debugPrint('Error loading user and projects: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading projects: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor() {
    switch (widget.timesheetStatus?.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'SUBMITTED':
        return Colors.orange;
      case 'RECHECK':
        return Colors.blue;
      case 'FORWARDED':
        return Colors.purple;
      case 'REASSIGNED':
        return Colors.teal; // Add color for RECHECK status
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.timesheetStatus?.toUpperCase()) {
      case 'APPROVED':
        return Icons.check_circle;
      case 'REJECTED':
        return Icons.cancel;
      case 'SUBMITTED':
        return Icons.pending_actions;
      case 'RECHECK':
        return Icons.refresh;
      case 'FORWARDED':
        return Icons.forward;
      case 'REASSIGNED':
        return Icons.assignment; // Add icon for RECHECK status
      default:
        return Icons.info;
    }
  }

  String _getStatusText() {
    final status = widget.timesheetStatus?.toUpperCase() ?? 'DRAFT';
    switch (status) {
      case 'APPROVED':
        return 'Timesheet Approved - Read only mode';
      case 'REJECTED':
        return 'Timesheet Rejected - Read only mode';
      case 'FORWARDED': // ✅ Add FORWARDED message
        return 'Timesheet Forwarded - Read only mode';
      case 'SUBMITTED':
        return 'Timesheet Submitted - Waiting for approval';
      case 'RECHECK':
        return 'Timesheet Needs Recheck - Waiting for correction'; // Add text for RECHECK
      default:
        return 'Timesheet Draft';
    }
  }

  Future<void> _validateElementForEntry(TimesheetEntry entry) async {
    final eleId = entry.elementId.trim();
    final int? siteCode = entry.projectId;
    final String? workType = entry.workType;

    if (eleId.isEmpty || siteCode == null || siteCode == 0) return;

    try {
      debugPrint(
          '🔍 Revalidating Element $eleId for Site $siteCode, WorkType $workType');

      final assignmentResult =
          await checkElementAssignment(eleId, siteCode, empCode);
      final usageResult = await checkElementUsage(eleId, siteCode, empCode);

      bool allowDueToReassignment = false;

      // ✅ Check assignment and reassignment
      if (assignmentResult['Success'] == true) {
        final bool isAssigned = assignmentResult['IsAssigned'] ?? false;
        final bool assignedToCurrentUser =
            assignmentResult['AssignedToCurrentUser'] ?? false;
        final latestAssignment = assignmentResult['LatestAssignment'];
        final assignType =
            latestAssignment?['AssignType']?.toString().toUpperCase();

        if (isAssigned && assignedToCurrentUser && assignType == 'REASSIGN') {
          allowDueToReassignment = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Element reassigned to you. You can use it."),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      // ✅ Usage check
      if (usageResult['Success'] == true) {
        final bool isUsed = usageResult['IsUsed'] ?? false;
        final bool usedByCurrentUser =
            usageResult['UsedByCurrentUser'] ?? false;

        if (isUsed && !usedByCurrentUser && !allowDueToReassignment) {
          final dataList = usageResult['Data'] as List?;
          final data = dataList?.isNotEmpty == true ? dataList!.first : null;
          final addUser = data?['ADDUSER']?.toString();

          String submittedBy = addUser ?? 'another user';

          // 🧩 Fetch employee name with code (async)
          if (addUser != null) {
            try {
              final nameWithCode = await getEmployeeNameWithCode(addUser);
              if (nameWithCode.isNotEmpty) submittedBy = nameWithCode;
            } catch (e) {
              debugPrint('⚠️ Failed to fetch employee name for $addUser: $e');
            }
          }

          // 🚫 Mark entry as invalid
          setState(() {
            entry.isElementUsedByAnother = true;
            entry.elementErrorMessage =
                "🚫 Element $eleId already used by $submittedBy. You cannot use it.";
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(entry.elementErrorMessage!),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );

          return;
        } else {
          debugPrint('✅ Element $eleId is valid for this site/work type');
          setState(() {
            entry.isElementUsedByAnother = false;
            entry.elementErrorMessage = null;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error validating element: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error verifying element: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // 🔥 ADD HELPER METHOD FOR DATE HINT TEXT
  String _getDateHintText(bool isDateEditable, bool isEditMode) {
    if (!isDateEditable) {
      return 'Date cannot be changed';
    } else if (isEditMode) {
      return 'Select date for this entry';
    } else {
      return 'Select date for this entry';
    }
  }

  Widget _buildEntryCard(int index) {
    final entry = _entries[index];

    // Initialize controllers for this entry
    _elementControllers.putIfAbsent(
      index,
      () => TextEditingController(text: entry.elementId),
    );

    _qtyControllers.putIfAbsent(
      index,
      () => TextEditingController(),
    );

    _elenameControllers.putIfAbsent(
      index,
      () => TextEditingController(),
    );

    // 🔥 INITIALIZE DATE CONTROLLERS PROPERLY
    _dateControllers.putIfAbsent(
      index,
      () => TextEditingController(
          text: entry.entryDate != null
              ? DateFormat('yyyy-MM-dd').format(entry.entryDate!)
              : DateFormat('yyyy-MM-dd').format(DateTime.now())),
    );

    /*// Sync controller text if entry changes externally
    if (_elementControllers[index]!.text != entry.elementId) {
      _elementControllers[index]!.text = entry.elementId;
    }

    // 🔥 SYNC DATE CONTROLLER TEXT
    final currentDateText = entry.entryDate != null
        ? DateFormat('yyyy-MM-dd').format(entry.entryDate!)
        : DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (_dateControllers[index]!.text != currentDateText) {
      _dateControllers[index]!.text = currentDateText;
    }*/

    bool defaultReadOnly = widget.isViewMode ||
        _isTimesheetLocked ||
        entry.status == 'FORWARDED' ||
        entry.status == 'APPROVED' ||
        entry.status == 'REJECTED';

    return FutureBuilder<Map<String, dynamic>>(
      future: checkElementIssuedForEntry(entry),
      builder: (context, snapshot) {
        bool apiAllowsEdit = true;
        String? blockReason;
        String elementStatus = "NOT_ISSUE";

        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          final data = snapshot.data!;
          apiAllowsEdit = data['allowEdit'] ?? true;
          blockReason = data['blockReason'];
          elementStatus = data['status'] ?? "NOT_ISSUE";

          debugPrint(
              'Element: ${entry.elementId}, WorkType: ${entry.workType}, '
              'Status: $elementStatus, AllowEdit: $apiAllowsEdit, '
              'Project: ${entry.projectId}');
        }

        bool isReadOnly = defaultReadOnly || !apiAllowsEdit;

        if (blockReason != null && !defaultReadOnly) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(blockReason!),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          });
        }

        bool canEdit = !isReadOnly && (!entry.isExisting || widget.isEditMode);
        bool isDesigningDraftingReadOnly =
            isReadOnly || (widget.isEditMode && entry.isExisting);
        bool isElementIdReadOnly = widget.isEditMode && entry.isExisting;

        // 🔥 CHECK DATE EDITING PERMISSIONS FOR DIFFERENT MODES
        bool isDateEditable;

        if (widget.isViewMode) {
          // View Mode: Never editable
          isDateEditable = false;
        } else if (_isTimesheetLocked) {
          // Locked timesheet: Never editable
          isDateEditable = false;
        } else if (widget.isEditMode) {
          // Edit Mode: Editable for BOTH existing AND new entries
          isDateEditable = !isReadOnly; // ← REMOVED the entry.isExisting check
        } else {
          // Add Mode: Always editable for new entries
          isDateEditable = !isReadOnly;
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
              filled: isReadOnly,
              fillColor: isReadOnly ? Colors.white : null,
            );
        final hasElement =
            entry.elementId.trim().isNotEmpty || entry.elementItems.isNotEmpty;
        final tsNo = entry.tsSlNo; // ✅ MUST be unique per row

        return Card(
          key:
              ValueKey('${entry.elementId}-${entry.tsSlNo}-${entry.entryDate}'),
          color: Colors.white,
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Time Sheet ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        // ✅ Checkbox
                        if (isViewMode && entry.status != 'APPROVED')
                          Checkbox(
                            value: entry.isSelected,
                            onChanged: (selected) {
                              setState(() {
                                if (entry.status == 'SUBMITTED' ||
                                    entry.status == 'RECHECK') {
                                  entry.isSelected = selected ?? false;
                                }

                                // ✅ UPDATE SELECT ALL STATE
                                final eligibleEntries = _entries.where(
                                  (e) =>
                                      e.status == 'SUBMITTED' ||
                                      e.status == 'RECHECK',
                                );

                                _selectAll = eligibleEntries.isNotEmpty &&
                                    eligibleEntries
                                        .every((e) => e.isSelected == true);
                              });
                            },
                          ),

                        // ✅ Delete Icon
                        if (!isReadOnly &&
                            (!entry.isExisting || widget.tsNo != null) &&
                            (widget.tsNo != null || _entries.length > 1))
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: AppColors.error),
                            onPressed: () async {
                              final shouldDelete = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Delete'),
                                  content: const Text(
                                      'Are you sure you want to delete this timesheet entry?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (shouldDelete ?? false) {
                                if (entry.isExisting && widget.tsNo != null) {
                                  _deleteTimesheetEntry(widget.tsNo!,
                                      entry.elementId, empCode, index);
                                } else {
                                  setState(() {
                                    _entries.removeAt(index);
                                    _dateControllers
                                        .remove(index); // 🔥 CLEAN UP
                                  });
                                }
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 🔥 UPDATED DATE FIELD WITH PROPER MODE HANDLING
                TextFormField(
                  controller: _dateControllers[index],
                  decoration: InputDecoration(
                    labelText: 'Timesheet Date *',
                    labelStyle: TextStyle(
                      fontSize: 15,
                      color: isDateEditable ? AppColors.primary : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(7),
                      borderSide: BorderSide(
                        color: isDateEditable ? AppColors.primary : Colors.grey,
                        width: 2,
                      ),
                    ),
                    suffixIcon: isDateEditable
                        ? IconButton(
                            icon: Icon(Icons.calendar_today,
                                color: AppColors.primary),
                            onPressed: () => _selectDate(context, index),
                          )
                        : Icon(Icons.calendar_today, color: Colors.grey),
                    filled: !isDateEditable,
                    fillColor: !isDateEditable ? Colors.grey[200] : null,
                    hintText:
                        _getDateHintText(isDateEditable, widget.isEditMode),
                    hintStyle: TextStyle(
                      color: !isDateEditable ? Colors.grey : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  readOnly: true,
                  onTap:
                      isDateEditable ? () => _selectDate(context, index) : null,
                  validator: (value) {
                    // ✅ MAKE DATE VALIDATION OPTIONAL - if empty, we'll use current date
                    if (value == null || value.isEmpty) {
                      return null; // No error - we'll use current date
                    }

                    try {
                      final selectedDate =
                          DateFormat('yyyy-MM-dd').parse(value);
                      if (!_isDateWithinAllowedRange(selectedDate)) {
                        return 'Date must be within the last 2 days';
                      }
                    } catch (e) {
                      return 'Invalid date format';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Designing / Drafting
                DropdownButtonFormField<String>(
                  value: entry.designingDrafting?.isNotEmpty == true
                      ? entry.designingDrafting
                      : (entry.deptType?.isNotEmpty == true
                          ? entry.deptType
                          : null),
                  decoration: _inputDecoration('Designing / Drafting *'),
                  items: ['Designing', 'Drafting']
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: isDesigningDraftingReadOnly
                      ? null
                      : (val) {
                          setState(() {
                            entry.designingDrafting = val ?? '';
                            entry.deptType = val ?? '';
                            entry.isModified = true;
                            entry.elementId = '';
                            entry.fn = null;
                            entry.an = null;
                          });
                        },
                  validator: (val) => (val == null || val.isEmpty)
                      ? 'Please select Designing or Drafting'
                      : null,
                ),
                const SizedBox(height: 10),

                // Project selection
                isReadOnly
                    ? TextFormField(
                        initialValue: entry.projectId != null
                            ? '${entry.projectId} - ${entry.projectName}'
                            : '',
                        decoration: _inputDecoration('Select Project *'),
                        readOnly: true,
                      )
                    : Autocomplete<Project>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return _projects;
                          return _projects.where((p) =>
                              p.projectName.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              p.projectId
                                  .toString()
                                  .contains(textEditingValue.text));
                        },
                        displayStringForOption: (p) =>
                            '${p.projectId} - ${p.projectName}',
                        onSelected: (selection) async {
                          setState(() {
                            entry.projectId = selection.projectId;
                            entry.projectName = selection.projectName;
                          });
                          await _validateElementForEntry(entry);
                        },
                        fieldViewBuilder: (context, controller, focusNode,
                            onEditingComplete) {
                          if (entry.projectId != null &&
                              entry.projectName != null &&
                              controller.text.isEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              controller.text =
                                  '${entry.projectId} - ${entry.projectName}';
                            });
                          }
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration:
                                _inputDecoration('Select Project *').copyWith(
                              suffixIcon: controller.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear,
                                          color: AppColors.primary),
                                      onPressed: () {
                                        setState(() {
                                          controller.clear();
                                          entry.projectId = null;
                                          entry.projectName = '';
                                        });
                                      },
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 10),

                // 🔹 Element ID Logic
                if (entry.designingDrafting == 'Designing')
                  DropdownButtonFormField<String>(
                    value: entry.elementId.isNotEmpty ? entry.elementId : null,
                    decoration: InputDecoration(
                      labelText: 'Select Element ID *',
                      labelStyle: TextStyle(
                        fontSize: 15,
                        color: isElementIdReadOnly
                            ? Colors.grey[600]
                            : AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(
                          color: isElementIdReadOnly
                              ? Colors.grey
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(
                          color: isElementIdReadOnly
                              ? Colors.grey
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                      filled: isElementIdReadOnly,
                      fillColor: isElementIdReadOnly ? Colors.grey[200] : null,
                      suffixIcon: entry.elementId.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: AppColors.primary),
                              onPressed: isElementIdReadOnly
                                  ? null
                                  : () {
                                      setState(() {
                                        entry.elementId = '';
                                        entry.isElementUsedByAnother = false;
                                      });
                                    },
                            )
                          : null,
                    ),
                    items: _designingElementIds
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: isElementIdReadOnly
                        ? null
                        : (value) async {
                            final eleId = (value ?? '').toUpperCase();
                            setState(() {
                              entry.elementId = eleId;
                              entry.isModified = true;
                            });
                            await _validateElementForEntry(entry);
                          },
                    validator: (val) => (val == null || val.isEmpty)
                        ? 'Element ID required'
                        : null,
                  )

                // 🔹 Drafting section with proper Edit Mode handling
                else if (entry.designingDrafting == 'Drafting')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drafting Type dropdown (only show in Add Mode or if not set)
                      if (!entry.isExisting || entry.draftingType == null)
                        DropdownButtonFormField<String>(
                          value: entry.draftingType?.isNotEmpty == true
                              ? entry.draftingType
                              : null,
                          decoration:
                              _inputDecoration('Select Drafting Type *'),
                          items: ['Piece Drawing', 'Erection Drawing']
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              entry.draftingType = val ?? '';
                              entry.elementId = '';
                              // Clear element items when drafting type changes
                              entry.elementItems.clear();
                            });
                          },
                          validator: (val) => (val == null || val.isEmpty)
                              ? 'Please select Drafting Type'
                              : null,
                        ),

                      const SizedBox(height: 10),

                      // Piece Drawing section with multiple items
                      /*if (entry.draftingType == 'Piece Drawing')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Platform.isAndroid
                                ? SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: _buildRowContent(
                                        index, entry, isElementIdReadOnly),
                                  )
                                : _buildRowContent(
                                    index, entry, isElementIdReadOnly),

                            const SizedBox(height: 12),

                            // 🔹 TABLE VIEW
                            if (!widget.isEditMode &&
                                entry.elementItems.isNotEmpty)
                              Platform.isAndroid
                                  ? SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(minWidth: 665),
                                        child: _buildElementTable(
                                            entry, isElementIdReadOnly),
                                      ),
                                    )
                                  : _buildElementTable(
                                      entry, isElementIdReadOnly),
                          ],
                        )*/
                      // Piece Drawing section with multiple items
                      if (entry.draftingType == 'Piece Drawing')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Platform.isAndroid
                                ? IntrinsicHeight(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: IntrinsicWidth(
                                        child: _buildRowContent(
                                            index, entry, isElementIdReadOnly),
                                      ),
                                    ),
                                  )
                                : _buildRowContent(
                                    index, entry, isElementIdReadOnly),

                            const SizedBox(height: 16),

                            // 🔹 TYPE SECTION
                            _buildTypeSection(entry, isElementIdReadOnly),

                            const SizedBox(height: 16),

                            // 🔹 WORK DURATION SECTION (Hours + Minutes)
                            SizedBox(
                              width: 4000,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Work Duration",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      // HOURS DROPDOWN
                                      Expanded(
                                        child: isElementIdReadOnly
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border.all(
                                                      color:
                                                          Colors.grey.shade400),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  "${entry.hours} Hrs",
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                              )
                                            : DropdownButtonFormField<int>(
                                                value: entry.hours.clamp(0, 12),
                                                decoration: InputDecoration(
                                                  labelText: 'Hours',
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  labelStyle: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            7),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 8),
                                                ),
                                                items: List.generate(
                                                  13,
                                                  (i) => DropdownMenuItem<int>(
                                                    value: i,
                                                    child: Text("$i Hrs"),
                                                  ),
                                                ),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    final minutes =
                                                        entry.minutes;
                                                    entry.setHoursMinutes(
                                                        val, minutes);
                                                    entry.isModified = true;
                                                    if (mounted)
                                                      setState(() {});
                                                  }
                                                },
                                              ),
                                      ),
                                      const SizedBox(width: 6),
                                      // MINUTES DROPDOWN
                                      Expanded(
                                        child: isElementIdReadOnly
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border.all(
                                                      color:
                                                          Colors.grey.shade400),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  entry.minutes
                                                          .toString()
                                                          .padLeft(2, '0') +
                                                      " Min",
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                ),
                                              )
                                            : DropdownButtonFormField<int>(
                                                value: entry.minutes,
                                                decoration: InputDecoration(
                                                  labelText: 'Minutes',
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  labelStyle: TextStyle(
                                                    fontSize: 12,
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            7),
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 8),
                                                ),
                                                items: _getMinutesDropdownItems(
                                                    entry.minutes),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    final hours = entry.hours;
                                                    entry.setHoursMinutes(
                                                        hours, val);
                                                    entry.isModified = true;
                                                    if (mounted)
                                                      setState(() {});
                                                  }
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                                  if (!isElementIdReadOnly)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        "Total: ${entry.totHrs}",
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // 🔹 ADD BUTTON
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  width: 130,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: isElementIdReadOnly
                                        ? null
                                        : () async {
                                            // Get values safely with null checks
                                            final elementController =
                                                _elementControllers[index];
                                            final qtyController =
                                                _qtyControllers[index];
                                            final elenameController =
                                                _elenameControllers[index];

                                            if (elementController == null ||
                                                qtyController == null ||
                                                elenameController == null) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Controllers not initialized'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            final element = elementController
                                                .text
                                                .replaceAll(' ', '')
                                                .toUpperCase();

                                            final qtyText =
                                                qtyController.text.trim();

                                            if (element.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content:
                                                      Text('Enter Element ID'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            if (qtyText.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text('Enter QTY'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            final qty = int.tryParse(qtyText);
                                            if (qty == null || qty <= 0) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Invalid QTY - must be a positive number'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            final elementName =
                                                elenameController.text.trim();
                                            if (elementName.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Enter Element Name'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            // Check if type, work type, and work time are selected
                                            if (entry.type.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Please select Type'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            if (entry.workType.isEmpty) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Please select Work Type'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            if (entry.tsuptime?.isEmpty ??
                                                true) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Please select Work Time (FN/AN)'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            // Duplicate check
                                            final bool alreadyExists =
                                                entry.elementItems.any((e) =>
                                                    e['elementId'] == element &&
                                                    e['type'] == entry.type &&
                                                    e['workType'] ==
                                                        entry.workType &&
                                                    e['tsuptime'] ==
                                                        entry.tsuptime);

                                            if (alreadyExists) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Element already added with same Type, Work Type, and Time'),
                                                  backgroundColor:
                                                      Colors.orange,
                                                  duration:
                                                      Duration(seconds: 3),
                                                ),
                                              );
                                              return;
                                            }

                                            setState(() {
                                              // Store duration with the element
                                              entry.elementItems.add({
                                                'elementName': elementName,
                                                'elementId': element,
                                                'qty': qty,
                                                'hours': entry.hours,
                                                'minutes': entry.minutes,
                                                'type': entry.type,
                                                'workType': entry.workType,
                                                'tsuptime': entry.tsuptime,
                                              });
                                              entry.isModified = true;

                                              // Clear controllers
                                              elementController.clear();
                                              qtyController.clear();
                                              elenameController.clear();

                                              // Reset duration after adding
                                              entry.setHoursMinutes(0, 0);

                                              // Reset type, work type, and work time after adding
                                              entry.type = '';
                                              entry.workType = '';
                                              entry.tsuptime = '';
                                            });

                                            await _validateElementForEntry(
                                                entry);
                                          },
                                    icon: const Icon(Icons.add),
                                    label: const Text("ADD"),
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // 🔹 TABLE VIEW
                            if (!widget.isEditMode &&
                                entry.elementItems.isNotEmpty)
                              Platform.isAndroid
                                  ? SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: _buildElementTable(
                                          entry, isElementIdReadOnly),
                                    )
                                  : _buildElementTable(
                                      entry, isElementIdReadOnly),
                          ],
                        )

                      // Erection Drawing section
                      else if (entry.draftingType == 'Erection Drawing')
                        DropdownButtonFormField<String>(
                          value: entry.elementId.isNotEmpty
                              ? entry.elementId
                              : null,
                          decoration:
                              _inputDecoration('Select Element ID *').copyWith(
                            suffixIcon: entry.elementId.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear,
                                        color: AppColors.primary),
                                    onPressed: () {
                                      setState(() {
                                        entry.elementId = '';
                                        entry.isElementUsedByAnother = false;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          items: _draftingElementIds
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: isElementIdReadOnly
                              ? null
                              : (val) async {
                                  final eleId = (val ?? '').toUpperCase();
                                  setState(() {
                                    entry.elementId = eleId;
                                    entry.isModified = true;
                                  });
                                },
                          validator: (val) => (val == null || val.isEmpty)
                              ? 'Element ID required'
                              : null,
                        ),
                    ],
                  )
                else if (entry.designingDrafting == 'Drafting' &&
                    entry.isExisting)
                  // Existing Drafting entries: keep typable
                  TextFormField(
                    controller: _elementControllers[index],
                    decoration: _inputDecoration('Enter Element ID *').copyWith(
                      filled: isElementIdReadOnly,
                      fillColor: isElementIdReadOnly ? Colors.grey[200] : null,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(
                          color: isElementIdReadOnly
                              ? Colors.grey
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(7),
                        borderSide: BorderSide(
                          color: isElementIdReadOnly
                              ? Colors.grey
                              : AppColors.primary,
                          width: 2,
                        ),
                      ),
                      suffixIcon: entry.elementId.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: AppColors.primary),
                              onPressed: isElementIdReadOnly
                                  ? null
                                  : () {
                                      setState(() {
                                        entry.elementId = '';
                                        entry.isElementUsedByAnother = false;
                                      });
                                    },
                            )
                          : null,
                    ),
                    readOnly: isElementIdReadOnly,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: isElementIdReadOnly
                        ? null
                        : (val) {
                            final eleId = val.replaceAll(' ', '').toUpperCase();
                            _elementIdDebounce?.cancel();
                            _elementIdDebounce = Timer(
                                const Duration(milliseconds: 1200), () async {
                              setState(() {
                                entry.elementId = eleId;
                                entry.isModified = true;
                              });
                              await _validateElementForEntry(entry);
                            });
                          },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Element ID is required';
                      }

                      return null;
                    },
                  ),

                const SizedBox(height: 10),

                // Type → only show after Element ID filled
                if (entry.draftingType != 'Piece Drawing' &&
                    hasElement &&
                    !entry.isElementUsedByAnother)
                  DropdownButtonFormField<String>(
                    value: _types.contains(entry.type) ? entry.type : null,
                    decoration: _inputDecoration('Select Type *'),
                    items: _types
                        .map((type) =>
                            DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: isReadOnly
                        ? null
                        : (val) {
                            setState(() {
                              entry.type = val ?? _types.first;
                              entry.workType = '';
                            });
                          },
                    validator: (val) => (val == null || val.isEmpty)
                        ? 'Type is required'
                        : null,
                  ),
                if (hasElement && !entry.isElementUsedByAnother)
                  const SizedBox(height: 10),

                // Work Type → only show after Type selected
                if (entry.draftingType != 'Piece Drawing' &&
                    entry.type.isNotEmpty &&
                    !entry.isElementUsedByAnother)
                  FutureBuilder<Map<String, dynamic>>(
                    future: getFilteredWorkTypes(
                        entry.projectId ?? 0, entry.elementId, entry.type),
                    builder: (context, snapshot) {
                      List<String> availableWorkTypes = entry.type == 'New'
                          ? ['Drawing', 'Checking', 'Issued']
                          : entry.type == 'Rework'
                              ? [
                                  'Revision',
                                  'Rectification',
                                  'Checking',
                                  'Correction',
                                  'Issued',
                                  'Recasting'
                                ]
                              : [];

                      List<UsedWorkType> usedWorkTypes = [];

                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData) {
                        final data = snapshot.data!;

                        final usedList = data['usedWorkTypes'] ?? [];
                        usedWorkTypes = usedList is List<UsedWorkType>
                            ? usedList
                            : (usedList as List)
                                .map((e) => e is UsedWorkType
                                    ? e
                                    : UsedWorkType.fromJson(
                                        e as Map<String, dynamic>))
                                .toList();

                        if (entry.designingDrafting == 'Drafting') {
                          if (entry.draftingType == 'Piece Drawing') {
                            availableWorkTypes = List<String>.from(
                                data['availableWorkTypes'] ?? <String>[]);
                          }
                        } else if (entry.designingDrafting == 'Designing') {
                          /*availableWorkTypes = List<String>.from(
                            data['availableWorkTypes'] ?? <String>[]);*/
                        }
                      }

                      if (entry.workType.isNotEmpty &&
                          !availableWorkTypes.contains(entry.workType)) {
                        availableWorkTypes = List.from(availableWorkTypes)
                          ..add(entry.workType);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (usedWorkTypes.isNotEmpty)
                            GestureDetector(
                              onTap: () => _showUsedWorkTypesDialog(
                                  context, usedWorkTypes),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline,
                                            size: 16, color: Colors.blue[700]),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${usedWorkTypes.length} work type${usedWorkTypes.length > 1 ? 's' : ''} used',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          DropdownButtonFormField<String>(
                            value: entry.workType.isNotEmpty
                                ? entry.workType
                                : null,
                            decoration: _inputDecoration('Select Work Type *'),
                            items: availableWorkTypes
                                .map((wt) => DropdownMenuItem(
                                      value: wt,
                                      child: Text(wt),
                                    ))
                                .toList(),
                            onChanged: isReadOnly
                                ? null
                                : (val) async {
                                    if (val == null || val.isEmpty) return;
                                    if (widget.isEditMode &&
                                        entry.isExisting &&
                                        val == 'Issued') {
                                      final alreadyIssued =
                                          await _isIssuedWorkTypeAlreadyUsed(
                                              entry);
                                      if (alreadyIssued) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '🚫 This element already has an "Issued" work type. You cannot add another.',
                                            ),
                                            backgroundColor: Colors.red,
                                            duration: Duration(seconds: 4),
                                          ),
                                        );
                                        return;
                                      }
                                    }

                                    setState(() {
                                      entry.workType = val;
                                      entry.isModified = true;
                                    });

                                    // await _validateElementForEntry(entry);

                                    if (val == 'Issued') {
                                      _refreshElementIssuedStatus(entry);
                                    }
                                  },
                            validator: (val) => (val == null || val.isEmpty)
                                ? 'Work Type is required'
                                : null,
                          ),
                        ],
                      );
                    },
                  ),

                const SizedBox(height: 10),
                if (entry.draftingType != 'Piece Drawing' &&
                    entry.workType.isNotEmpty &&
                    !entry.isElementUsedByAnother)
                  DropdownButtonFormField<String>(
                    value: entry.tsuptime?.isNotEmpty == true
                        ? entry.tsuptime
                        : null,
                    decoration: _inputDecoration('Work Time (FN/AN) *'),
                    items: const [
                      DropdownMenuItem(value: 'FN', child: Text('FN')),
                      DropdownMenuItem(value: 'AN', child: Text('AN')),
                    ],
                    onChanged: canEdit
                        ? (val) {
                            setState(() {
                              entry.tsuptime = val ?? '';
                              entry.isModified = true;
                            });
                          }
                        : null,
                    validator: (val) => (val == null || val.isEmpty)
                        ? 'Work Time required'
                        : null,
                  ),

                const SizedBox(height: 10),
                // 🔹 TOTAL WORKING HOURS (Hours + Minutes)
                if (entry.draftingType != 'Piece Drawing' &&
                    entry.tsuptime?.isNotEmpty == true &&
                    entry.workType.isNotEmpty &&
                    !entry.isElementUsedByAnother)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Work Duration",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          // HOURS DROPDOWN
                          Expanded(
                            child: isReadOnly
                                ? Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "${entry.hours} Hrs",
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  )
                                : DropdownButtonFormField<int>(
                                    value: entry.hours
                                        .clamp(0, 12), // Ensure valid range
                                    decoration: _inputDecoration('Hours *'),
                                    items: List.generate(
                                      13, // 0-12 hours
                                      (i) => DropdownMenuItem<int>(
                                        value: i,
                                        child: Text("$i Hrs"),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final minutes = entry.minutes;
                                        entry.setHoursMinutes(val, minutes);
                                        entry.isModified = true;
                                        setState(() {});
                                      }
                                    },
                                    validator: (val) =>
                                        (val == null) ? 'Hours required' : null,
                                  ),
                          ),

                          const SizedBox(width: 10),

                          // MINUTES DROPDOWN (Updated for Edit Mode)
                          Expanded(
                            child: isReadOnly
                                ? Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      entry.minutes.toString().padLeft(2, '0') +
                                          " Min",
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  )
                                : DropdownButtonFormField<int>(
                                    value: entry.minutes,
                                    decoration: _inputDecoration('Minutes *'),
                                    items:
                                        _getMinutesDropdownItems(entry.minutes),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final hours = entry.hours;
                                        entry.setHoursMinutes(hours, val);
                                        entry.isModified = true;
                                        setState(() {});
                                      }
                                    },
                                    validator: (val) => (val == null)
                                        ? 'Minutes required'
                                        : null,
                                  ),
                          ),
                        ],
                      ),

                      // Show the current total time
                      if (!isReadOnly)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "Current: ${entry.totHrs}",
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 10),

                const SizedBox(height: 10),

                // Remarks
                TextFormField(
                  initialValue: entry.remarks,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration('Enter Remarks'),
                  readOnly: isReadOnly,
                  inputFormatters: [
                    UpperCaseTextFormatter(), // 👈 custom formatter
                  ],
                  onChanged: isReadOnly
                      ? null
                      : (val) {
                          entry.remarks = val.toUpperCase();
                        },
                  validator: (val) => (val == null || val.trim().isEmpty)
                      ? 'Remarks are required'
                      : null,
                ),

                if (entry.status.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getEntryStatusColor(entry.status)
                              .withOpacity(0.1),
                          border: Border.all(
                            color: _getEntryStatusColor(entry.status),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          entry.status,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getEntryStatusColor(entry.status),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Approve/Reject buttons
                if (_showApproveRejectOptions &&
                    widget.isViewMode &&
                    (entry.status == 'SUBMITTED'))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        /*ElevatedButton(
                          onPressed: () => _updateSingleEntry(entry, 'Approve'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green),
                          child: const Text('Approve',
                              style: TextStyle(color: Colors.white)),
                        ),*/
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (entry.status == 'SUBMITTED' ||
                                  entry.status == 'RECHECK') {
                                // ✅ Mark checkbox selected
                                entry.isSelected = true;

                                // ✅ Add to selected set (IMPORTANT)
                                _selectedTimesheets.add(entry.tsSlNo);
                              }
                            });

                            // ✅ Check how many selected
                            final selectedCount = _entries
                                .where((e) =>
                                    e.isSelected &&
                                    (e.status == 'SUBMITTED' ||
                                        e.status == 'RECHECK'))
                                .length;

                            if (selectedCount > 1) {
                              // 🔥 Show Snackbar for bulk action
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Multiple selected. Use"Approve All Selected" option'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } else {
                              // ✅ Only one → proceed normally
                              _updateSingleEntry(entry, 'Approve');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text(
                            'Approve',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        /*ElevatedButton(
                          onPressed: () => _updateSingleEntry(entry, 'Reject'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          child: const Text('Reject',
                              style: TextStyle(color: Colors.white)),
                        ),*/
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (entry.status == 'SUBMITTED' ||
                                  entry.status == 'RECHECK') {
                                // ✅ Mark checkbox selected
                                entry.isSelected = true;

                                // ✅ Add to selected set (IMPORTANT)
                                _selectedTimesheets.add(entry.tsSlNo);
                              }
                            });

                            // ✅ Check how many selected
                            final selectedCount = _entries
                                .where((e) =>
                                    e.isSelected &&
                                    (e.status == 'SUBMITTED' ||
                                        e.status == 'RECHECK'))
                                .length;

                            if (selectedCount > 1) {
                              // 🔥 Show Snackbar for bulk action
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Multiple selected. Use"Reject All Selected" option'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } else {
                              // ✅ Only one → proceed normally
                              _updateSingleEntry(entry, 'Reject');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Reject',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        /*ElevatedButton(
                          onPressed: () => _updateSingleEntry(entry, 'Recheck'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange),
                          child: const Text('Recheck',
                              style: TextStyle(color: Colors.white)),
                        ),*/
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (entry.status == 'SUBMITTED' ||
                                  entry.status == 'RECHECK') {
                                // ✅ Mark checkbox selected
                                entry.isSelected = true;

                                // ✅ Add to selected set (IMPORTANT)
                                _selectedTimesheets.add(entry.tsSlNo);
                              }
                            });

                            // ✅ Check how many selected
                            final selectedCount = _entries
                                .where((e) =>
                                    e.isSelected &&
                                    (e.status == 'SUBMITTED' ||
                                        e.status == 'RECHECK'))
                                .length;

                            if (selectedCount > 1) {
                              // 🔥 Show Snackbar for bulk action
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Multiple selected. Use"Recheck All Selected" option'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } else {
                              // ✅ Only one → proceed normally
                              _updateSingleEntry(entry, 'Recheck');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text(
                            'Recheck',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
    );
  }

  Widget _buildRowContent(int index, dynamic entry, bool isElementIdReadOnly) {
    _initControllers(index); // ✅ safe init

    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 ELEMENT NAME
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 48,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: _elenameControllers[index]?.text.isNotEmpty == true
                  ? _elenameControllers[index]!.text
                  : null,
              decoration: _inputDecoration('Ele Name *')
                  .copyWith(filled: true, fillColor: Colors.white),
              items: _elementNames
                  .map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: isElementIdReadOnly
                  ? null
                  : (value) {
                      _elenameControllers[index]?.text = value ?? '';
                      entry.isModified = true;
                      if (mounted) setState(() {});
                    },
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 🔹 ELEMENT ID
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _elementControllers[index],
                decoration: _inputDecoration('Element ID *').copyWith(
                  filled: true,
                  fillColor: Colors.white,
                ),
                textCapitalization: TextCapitalization.characters,
                readOnly: isElementIdReadOnly,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                  UpperCaseTextFormatter(),
                ],
                onChanged: (value) {
                  entry.isModified = true;
                },
              ),
              const SizedBox(height: 4),
              if (!widget.isEditMode)
                Text(
                  "* Only one Element ID allowed",
                  style: TextStyle(
                    color: Colors.red.shade600,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // 🔹 QTY
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: _qtyControllers[index],
            decoration: _inputDecoration('QTY *')
                .copyWith(filled: true, fillColor: Colors.white),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            readOnly: isElementIdReadOnly,
            onChanged: (value) {
              entry.isModified = true;
            },
          ),
        ),
      ],
    );

    // Check if platform is Windows
    final bool isWindows = Platform.isWindows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (Platform.isAndroid)
          // Android: Card styling with fixed widths
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 180,
                    height: 48,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _elenameControllers[index]?.text.isNotEmpty == true
                          ? _elenameControllers[index]!.text
                          : null,
                      decoration: _inputDecoration('Ele Name *')
                          .copyWith(filled: true, fillColor: Colors.white),
                      items: _elementNames
                          .map((name) => DropdownMenuItem(
                                value: name,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: isElementIdReadOnly
                          ? null
                          : (value) {
                              _elenameControllers[index]?.text = value ?? '';
                              entry.isModified = true;
                              if (mounted) setState(() {});
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _elementControllers[index],
                          decoration: _inputDecoration('Element ID *').copyWith(
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          readOnly: isElementIdReadOnly,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9-]')),
                            UpperCaseTextFormatter(),
                          ],
                          onChanged: (value) {
                            entry.isModified = true;
                          },
                        ),
                        const SizedBox(height: 4),
                        if (!widget.isEditMode)
                          Text(
                            "* Only one Element ID allowed",
                            style: TextStyle(
                              color: Colors.red.shade600,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _qtyControllers[index],
                      decoration: _inputDecoration('QTY *')
                          .copyWith(filled: true, fillColor: Colors.white),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      readOnly: isElementIdReadOnly,
                      onChanged: (value) {
                        entry.isModified = true;
                      },
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (isWindows)
          // Windows: Full width expanded layout
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: content,
          )
        else
          // Other platforms: Regular layout without card
          content,
      ],
    );
  }

  Widget _buildTypeSection(dynamic entry, bool isReadOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 TYPE
        DropdownButtonFormField<String>(
          value: _types.contains(entry.type) ? entry.type : null,
          decoration: _inputDecoration('Select Type *')
              .copyWith(filled: true, fillColor: Colors.white),
          items: _types
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: isReadOnly
              ? null
              : (val) {
                  // Update entry values without setState
                  final newType = val ?? '';
                  if (entry.type != newType) {
                    entry.type = newType;
                    entry.workType = ''; // Reset work type when type changes
                    entry.isModified = true;
                    // Use WidgetsBinding to schedule a rebuild after the current build is complete
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {});
                      }
                    });
                  }
                },
          validator: (val) =>
              (val == null || val.isEmpty) ? 'Type is required' : null,
        ),

        const SizedBox(height: 10),

        // 🔹 WORK TYPE
        FutureBuilder<Map<String, dynamic>>(
          key: ValueKey('worktype_${entry.type}_${entry.elementId}'),
          future: getFilteredWorkTypes(
              entry.projectId ?? 0, entry.elementId, entry.type),
          builder: (context, snapshot) {
            List<String> availableWorkTypes = [];

            if (entry.type == 'New') {
              availableWorkTypes = ['Drawing', 'Checking', 'Issued'];
            } else if (entry.type == 'Rework') {
              availableWorkTypes = [
                'Revision',
                'Rectification',
                'Checking',
                'Correction',
                'Issued',
                'Recasting'
              ];
            } else if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData &&
                snapshot.data!['availableWorkTypes'] != null) {
              availableWorkTypes =
                  List<String>.from(snapshot.data!['availableWorkTypes']);
            }

            // Ensure the current workType is in the list if it's not empty
            if (entry.workType.isNotEmpty &&
                !availableWorkTypes.contains(entry.workType)) {
              availableWorkTypes = List.from(availableWorkTypes)
                ..add(entry.workType);
            }

            return DropdownButtonFormField<String>(
              value: entry.workType.isNotEmpty &&
                      availableWorkTypes.contains(entry.workType)
                  ? entry.workType
                  : null,
              decoration: _inputDecoration('Select Work Type *')
                  .copyWith(filled: true, fillColor: Colors.white),
              items: availableWorkTypes
                  .map((wt) => DropdownMenuItem(value: wt, child: Text(wt)))
                  .toList(),
              onChanged: isReadOnly
                  ? null
                  : (val) {
                      // Just update the entry, no setState needed
                      entry.workType = val ?? '';
                      entry.isModified = true;
                      // No setState here - the dropdown will handle its own value display
                    },
              validator: (val) =>
                  (val == null || val.isEmpty) ? 'Work Type is required' : null,
            );
          },
        ),

        const SizedBox(height: 10),

        // 🔹 FN / AN
        DropdownButtonFormField<String>(
          value: entry.tsuptime?.isNotEmpty == true ? entry.tsuptime : null,
          decoration: _inputDecoration('Work Time (FN/AN) *')
              .copyWith(filled: true, fillColor: Colors.white),
          items: const [
            DropdownMenuItem(value: 'FN', child: Text('FN')),
            DropdownMenuItem(value: 'AN', child: Text('AN')),
          ],
          onChanged: isReadOnly
              ? null
              : (val) {
                  entry.tsuptime = val ?? '';
                  entry.isModified = true;
                  // No setState needed
                },
          validator: (val) =>
              (val == null || val.isEmpty) ? 'Work Time required' : null,
        ),
      ],
    );
  }

  Widget _buildElementTable(dynamic entry, bool isElementIdReadOnly) {
    // Helper function to format duration
    String _formatDuration(int hours, int minutes) {
      if (hours == 0 && minutes == 0) return '-';
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FixedColumnWidth(50), // S.No
        1: FixedColumnWidth(250), // Element Name
        2: FixedColumnWidth(180), // Element ID
        3: FixedColumnWidth(80), // QTY
        4: FixedColumnWidth(120), // Type
        5: FixedColumnWidth(140), // Work Type
        6: FixedColumnWidth(80), // FN/AN
        7: FixedColumnWidth(120), // Work Duration
        8: FixedColumnWidth(65), // Delete
      },
      children: [
        // 🔹 HEADER
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: [
            _tableCell('S.No', isHeader: true),
            _tableCell('Element Name', isHeader: true),
            _tableCell('Element ID', isHeader: true),
            _tableCell('QTY', isHeader: true),
            _tableCell('Type', isHeader: true),
            _tableCell('Work Type', isHeader: true),
            _tableCell('FN/AN', isHeader: true),
            _tableCell('Work Duration', isHeader: true),
            _tableCell('Delete', isHeader: true),
          ],
        ),

        // 🔹 DATA ROWS
        ...List.generate(entry.elementItems.length, (i) {
          final item = entry.elementItems[i];

          // Get duration from stored values or use default
          final hours = item['hours'] ?? 0;
          final minutes = item['minutes'] ?? 0;
          final durationText = _formatDuration(hours, minutes);

          return TableRow(
            children: [
              _tableCell('${i + 1}'),
              _tableCell(item['elementName'] ?? ''),
              _tableCell(item['elementId'] ?? ''),
              _tableCell(item['qty']?.toString() ?? '0'),
              _tableCell(item['type'] ?? ''),
              _tableCell(item['workType'] ?? ''),
              _tableCell(item['tsuptime'] ?? ''),
              _tableCell(durationText),
              Padding(
                padding: const EdgeInsets.all(4),
                child: IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                    size: 18,
                  ),
                  onPressed: isElementIdReadOnly
                      ? null
                      : () {
                          setState(() {
                            entry.elementItems.removeAt(i);
                            entry.isModified = true;
                          });
                        },
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  List<DropdownMenuItem<int>> _getMinutesDropdownItems(int currentMinutes) {
    // Standard minutes options
    final standardItems = const [
      DropdownMenuItem<int>(value: 0, child: Text("00 Min")),
      DropdownMenuItem<int>(value: 15, child: Text("15 Min")),
      DropdownMenuItem<int>(value: 30, child: Text("30 Min")),
      DropdownMenuItem<int>(value: 45, child: Text("45 Min")),
    ];

    // If in Edit Mode and current minutes is not in standard list, add it
    if (widget.isEditMode &&
        currentMinutes != 0 &&
        currentMinutes != 15 &&
        currentMinutes != 30 &&
        currentMinutes != 45) {
      // Create a new list with the current value included
      return [
        ...standardItems,
        DropdownMenuItem<int>(
          value: currentMinutes,
          child: Text("${currentMinutes.toString().padLeft(2, '0')} Min"),
        ),
      ];
    }

    return standardItems;
  }

  Future<bool> _isIssuedWorkTypeAlreadyUsed(TimesheetEntry entry) async {
    try {
      final result = await getFilteredWorkTypes(
          entry.projectId ?? 0, entry.elementId, entry.type);

      if (result.isEmpty || result['usedWorkTypes'] == null) return false;

      final usedList = result['usedWorkTypes'];
      if (usedList is! List) return false;

      final usedWorkTypes = usedList
          .map((e) => e is UsedWorkType
              ? e
              : UsedWorkType.fromJson(e as Map<String, dynamic>))
          .toList();

      final alreadyIssued =
          usedWorkTypes.any((u) => u.workType.toUpperCase() == 'ISSUED');

      debugPrint(
          '🧩 _isIssuedWorkTypeAlreadyUsed -> ${entry.elementId} | Issued exists: $alreadyIssued');
      return alreadyIssued;
    } catch (e) {
      debugPrint('⚠️ Error checking issued work type: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> checkElementIssuedForEntry(
      TimesheetEntry entry) async {
    try {
      if (entry.elementId.isEmpty || entry.projectId == null) {
        debugPrint('❌ Element ID or Project ID empty - allowing edit');
        return {'allowEdit': true, 'blockReason': null, 'status': 'NOT_ISSUE'};
      }

      if (!widget.isEditMode) {
        debugPrint('✅ Add Mode - skipping Issued assignment validation');
        return {'allowEdit': true, 'blockReason': null, 'status': 'ADD_MODE'};
      }

      if ((entry.workType ?? '').toUpperCase() != 'ISSUED') {
        debugPrint(
            '✅ WorkType is not ISSUED (${entry.workType}) - allowing edit');
        return {
          'allowEdit': true,
          'blockReason': null,
          'status': 'WORKTYPE_NOT_ISSUED'
        };
      }

      debugPrint('🔍 Checking Element Assignment: '
          'ELEID=${entry.elementId}, SITECODE=${entry.projectId}, Emp=$empCode');

      final assignmentResult = await checkElementAssignment(
          entry.elementId, entry.projectId!, empCode);

      if (assignmentResult['Success'] == true) {
        final isAssigned = assignmentResult['IsAssigned'] ?? false;
        final assignedToCurrentUser =
            assignmentResult['AssignedToCurrentUser'] ?? false;
        final assignType = assignmentResult['LatestAssignment']?['AssignType']
                ?.toString()
                .toUpperCase() ??
            '';

        if (assignType == 'ISSUE RELEASE') {
          debugPrint('✅ ISSUE RELEASE - ALLOWING EDIT');
          return {
            'allowEdit': true,
            'blockReason': null,
            'status': 'ISSUE RELEASE'
          };
        } else if (isAssigned && !assignedToCurrentUser) {
          debugPrint('🚫 Assigned to other user - BLOCK');
          return {
            'allowEdit': false,
            'blockReason': '🚫 BLOCKED: Element assigned to another user.',
            'status': 'ASSIGNED_TO_OTHER'
          };
        } else if (!isAssigned) {
          debugPrint('🚫 Not assigned - BLOCK');
          return {
            'allowEdit': false,
            'blockReason': '🚫 BLOCKED: Element not Issue released.',
            'status': 'NOT_ASSIGNED'
          };
        } else {
          debugPrint('🚫 Invalid assignType "$assignType" - BLOCK');
          return {
            'allowEdit': false,
            'blockReason': '🚫 BLOCKED: Invalid assignment type "$assignType".',
            'status': 'INVALID_ASSIGNTYPE'
          };
        }
      } else {
        debugPrint('🚫 Assignment API failed - BLOCK');
        return {
          'allowEdit': false,
          'blockReason': '🚫 BLOCKED: Error verifying assignment.',
          'status': 'API_FAIL'
        };
      }
    } catch (e) {
      debugPrint('❌ checkElementIssuedForEntry error: $e');
      return {
        'allowEdit': false,
        'blockReason': '🚫 BLOCKED: Error checking element assignment.',
        'status': 'EXCEPTION'
      };
    }
  }

  // Add this method to refresh the element issued status when work type changes
  void _refreshElementIssuedStatus(TimesheetEntry entry) {
    // Force a rebuild of the entry card to re-run checkElementIssuedForEntry
    setState(() {
      entry.isModified = true;
    });
  }

  Future<Map<String, dynamic>> checkElementAssignment(
      String elementId, int siteCode, int loginUser) async {
    try {
      debugPrint(
          '🔍 Checking element assignment: ELEID=$elementId, SITECODE=$siteCode, ADDUSER=$loginUser');

      final url = ApiUtils.getUri('GetElementAssignment');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "ELEID": elementId,
          "SITECODE": siteCode,
          "ADDUSER": loginUser,
        }),
      );

      debugPrint('🔍 Assignment API Response Status: ${response.statusCode}');
      debugPrint('🔍 Assignment API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        debugPrint('🔍 Element Assignment Check Result: $json');

        if (json['Success'] == true) {
          final isAssigned = json['IsAssigned'] ?? false;
          final assignedToCurrentUser = json['AssignedToCurrentUser'] ?? false;
          final latestAssignment = json['LatestAssignment'];

          return {
            'Success': true,
            'IsAssigned': isAssigned,
            'AssignedToCurrentUser': assignedToCurrentUser,
            'LatestAssignment': latestAssignment,
            'Message': json['Message'] ?? 'Assignment check completed'
          };
        } else {
          return {
            'Success': false,
            'Message': json['Message'] ?? 'API error',
            'IsAssigned': false,
            'AssignedToCurrentUser': false
          };
        }
      } else {
        debugPrint(
            '❌ Assignment API call failed with status: ${response.statusCode}');
        return {
          'Success': false,
          'Message': 'API call failed with status: ${response.statusCode}',
          'IsAssigned': false,
          'AssignedToCurrentUser': false
        };
      }
    } catch (e) {
      debugPrint('❌ Error in checkElementAssignment: $e');
      return {
        'Success': false,
        'Message': 'Error checking element assignment: $e',
        'IsAssigned': false,
        'AssignedToCurrentUser': false
      };
    }
  }

  Future<bool> validateElementAssignmentAndUsage(
      String elementId, int siteCode, int userId) async {
    // Check assignment first
    final assignmentResult =
        await checkElementAssignment(elementId, siteCode, userId);

    bool allowDueToReassignment = false;

    if (assignmentResult['Success'] == true) {
      final bool isAssigned = assignmentResult['IsAssigned'] ?? false;
      final bool assignedToCurrentUser =
          assignmentResult['AssignedToCurrentUser'] ?? false;
      final latestAssignment = assignmentResult['LatestAssignment'];
      final assignType =
          latestAssignment?['AssignType']?.toString().toUpperCase();

      // ✅ ALLOW if ASSIGNTYPE is "REASSIGN" and REASSIGNTO is current user
      if (isAssigned && assignedToCurrentUser && assignType == 'REASSIGN') {
        allowDueToReassignment = true;
      }
    }

    // Check usage
    final usageResult = await checkElementUsage(elementId, siteCode, userId);

    if (usageResult['Success'] == true) {
      final bool isUsed = usageResult['IsUsed'] ?? false;
      final bool usedByCurrentUser = usageResult['UsedByCurrentUser'] ?? false;

      if (isUsed && !usedByCurrentUser && !allowDueToReassignment) {
        // Element used by someone else and not reassigned to current user - BLOCK
        final dataList = usageResult['Data'] as List?;
        final data = dataList?.first;
        final addUser = data?['ADDUSER']?.toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Cannot submit: Element $elementId is used by user $addUser",
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
        return false;
      }
    }

    return true;
  }

  Future<Map<String, dynamic>> checkElementUsage(
      String elementId, int siteCode, int loginUser) async {
    try {
      debugPrint(
          '🔍 Checking element usage: ELEID=$elementId, SITECODE=$siteCode, ADDUSER=$loginUser');

      final url = ApiUtils.getUri('GetElementUsage');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "ELEID": elementId,
          "SITECODE": siteCode,
          "ADDUSER": loginUser,
        }),
      );

      debugPrint('🔍 API Response Status: ${response.statusCode}');
      debugPrint('🔍 API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        debugPrint('🔍 Element Usage Check Result: $json');

        // ✅ FIXED: Handle the API response correctly
        if (json['Success'] == true) {
          final dataList = json['Data'] as List?;

          // If Data list has items, element is used
          if (dataList != null && dataList.isNotEmpty) {
            final data = dataList.first;
            final addUser = data['ADDUSER']?.toString();
            final usedByCurrentUser = addUser == loginUser.toString();

            return {
              'Success': true,
              'Data': dataList,
              'IsUsed': true,
              'UsedByCurrentUser': usedByCurrentUser,
              'Message': json['Message'] ?? 'Element is already used'
            };
          } else {
            // No data means element is NOT used - ALLOW
            return {
              'Success': true,
              'Data': [],
              'IsUsed': false,
              'UsedByCurrentUser': false,
              'Message': 'Element is available'
            };
          }
        } else {
          // ✅ FIXED: Success: false means element is NOT used - ALLOW
          return {
            'Success': true, // We treat this as success for availability
            'Data': [],
            'IsUsed': false,
            'UsedByCurrentUser': false,
            'Message': json['Message'] ?? 'Element is available'
          };
        }
      } else {
        debugPrint('❌ API call failed with status: ${response.statusCode}');
        return {
          'Success': false,
          'Message': 'API call failed with status: ${response.statusCode}',
          'Data': [],
          'IsUsed': false,
          'UsedByCurrentUser': false
        };
      }
    } catch (e) {
      debugPrint('❌ Error in checkElementUsage: $e');
      return {
        'Success': false,
        'Message': 'Error checking element usage: $e',
        'Data': [],
        'IsUsed': false,
        'UsedByCurrentUser': false
      };
    }
  }

  Color _getEntryStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'RECHECK':
        return Colors.orange;
      case 'FORWARDED':
        return Colors.purple;
      case 'REASSIGNED':
        return Colors.teal;
      case 'SUBMITTED':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontStyle: FontStyle.normal,
                  fontSize: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
              ),
              onPressed: () {
                setState(() {
                  final lastProjectId =
                      _entries.isNotEmpty ? _entries.last.projectId : null;
                  final lastProjectName =
                      _entries.isNotEmpty ? _entries.last.projectName : null;

                  _entries.add(TimesheetEntry(
                    elementId: '',
                    type: '',
                    workType: '',
                    remarks: '',
                    projectId: lastProjectId,
                    projectName: lastProjectName,
                    tsSlNo: 0,
                  ));
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
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
              // Show confirmation dialog before saving
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Confirm Submit'),
                    content: const Text(
                      'Are you sure you want to submit this timesheet?',
                      style: TextStyle(fontSize: 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                        },
                        child: const Text(
                          'No',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close dialog
                          _saveTimesheet(); // Call save function
                        },
                        child: const Text(
                          'Yes',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Submit Timesheet',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveTimesheet() async {
    debugPrint("🚀 ===== START SAVE TIMESHEET =====");

    // 1️⃣ FORM VALIDATION
    bool hasNonPieceDrawingEntry =
        _entries.any((e) => e.draftingType != 'Piece Drawing');

    if (hasNonPieceDrawingEntry) {
      if (!_formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all required fields before saving.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // 2️⃣ ENTRY VALIDATION
    for (var e in _entries) {
      e.entryDate ??= DateTime.now();

      if (!_isDateWithinAllowedRange(e.entryDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Date must be within last 2 days: ${DateFormat('yyyy-MM-dd').format(e.entryDate!)}'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (e.projectId == null || e.projectId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a valid Project.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (e.elementId.trim().isEmpty && e.elementItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add at least one Element.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 🔥 CONDITIONAL VALIDATION - Only for Piece Drawing
      if (e.draftingType != 'Piece Drawing') {
        if (e.type.trim().isEmpty ||
            e.workType.trim().isEmpty ||
            e.remarks.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Type, Work Type & Remarks are required for Piece Drawing.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      } else {
        // For other drafting types, only remarks is required
        if (e.remarks.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Remarks are required.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }
    }

    // 3️⃣ FILTER
    final entriesToSave = _entries.where((e) {
      return (e.elementId.trim().isNotEmpty || e.elementItems.isNotEmpty) &&
          e.projectId != null &&
          e.projectId != 0;
    }).toList();

    if (entriesToSave.isEmpty) return;

    // 🔥 IMPORTANT: Track running TSSLNO
    int runningTsslNo = 0;

    final List<Map<String, dynamic>> payload = [];

    for (var e in entriesToSave) {
      final formattedDate = e.entryDate!.toIso8601String();

      // 🔥 MULTIPLE ELEMENTS (Piece Drawing)
      if (e.elementItems.isNotEmpty) {
        for (var item in e.elementItems) {
          runningTsslNo++; // ✅ UNIQUE NUMBER

          // 🔥 GET DURATION FROM ELEMENT ITEM FOR PIECE DRAWING
          final hours = item['hours'] ?? 0;
          final minutes = item['minutes'] ?? 0;

          // Format TOTHRS based on drafting type
          String tothrs;
          if (e.draftingType == 'Piece Drawing') {
            // For Piece Drawing, use duration from each element
            tothrs =
                '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:00';
          } else {
            // For other drafting types, use entry-level duration
            tothrs =
                '${e.hours.toString().padLeft(2, '0')}:${e.minutes.toString().padLeft(2, '0')}:00';
          }

          payload.add({
            "TSNO": widget.tsNo ?? 0,

            // ✅ ALWAYS UNIQUE
            "TSSLNO": widget.isEditMode
                ? (e.isExisting ? e.tsSlNo ?? runningTsslNo : 0)
                : 0,

            "SITECODE": e.projectId,
            "ELEID": item['elementId'],
            "ELENAME": item['elementName'] ?? "",
            "ELEQNTY": item['qty'] ?? 0,

            "TYPE":
                (e.draftingType == 'Piece Drawing') ? (item['type'] ?? '') : '',
            "WORKTYPE": (e.draftingType == 'Piece Drawing')
                ? (item['workType'] ?? '')
                : '',
            "TSUPTIME": (e.draftingType == 'Piece Drawing')
                ? (item['tsuptime'] ?? '')
                : '',
            "REMARKS": e.remarks,
            "DEPTCODE": empDept,
            "TLCODE": empTL ?? '',
            "TSSTATUS": 'SUBMITTED',
            //"TSUPTIME": e.tsuptime,
            "TSDEPTTYPE": e.deptType ?? e.designingDrafting,
            "TSDT": formattedDate,
            "TOTHRS": tothrs,
            "DRAFTINGTYPE": e.draftingType ?? 'Designing Drawing',

            if (widget.isEditMode && e.isExisting)
              "EDITUSER": empCode
            else
              "ADDUSER": empCode,
          });
        }
      }

      // 🔥 SINGLE ELEMENT (Erection Drawing or Designing)
      else {
        runningTsslNo++;

        // Format TOTHRS based on drafting type
        String tothrs;
        if (e.draftingType == 'Piece Drawing') {
          // For Piece Drawing single element (should not happen, but handle if it does)
          tothrs =
              '${e.hours.toString().padLeft(2, '0')}:${e.minutes.toString().padLeft(2, '0')}:00';
        } else {
          // For other drafting types, use entry-level duration
          tothrs =
              '${e.hours.toString().padLeft(2, '0')}:${e.minutes.toString().padLeft(2, '0')}:00';
        }

        payload.add({
          "TSNO": widget.tsNo ?? 0,
          "TSSLNO": widget.isEditMode && e.isExisting ? e.tsSlNo ?? 0 : 0,
          "SITECODE": e.projectId,
          "ELEID": e.elementId,
          "ELENAME": "",
          "ELEQNTY": 0,
          "TYPE": e.type,
          "WORKTYPE": e.workType,
          "REMARKS": e.remarks,
          "DEPTCODE": empDept,
          "TLCODE": empTL ?? '',
          "TSSTATUS": 'SUBMITTED',
          "TSUPTIME": e.tsuptime,
          "TSDEPTTYPE": e.deptType ?? e.designingDrafting,
          "TSDT": formattedDate,
          "TOTHRS": tothrs,
          "DRAFTINGTYPE": e.draftingType ?? 'Designing Drawing',
          if (widget.isEditMode && e.isExisting)
            "EDITUSER": empCode
          else
            "ADDUSER": empCode,
        });
      }
    }

    debugPrint("📤 FINAL PAYLOAD: $payload");

    // 4️⃣ API CALL
    try {
      final uri = ApiUtils.getUri('SaveTimesheet');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Timesheet ${widget.isEditMode ? 'updated' : 'created'}! TSNO: ${result['TSNO']}'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pop(context, result['TSNO']);
      } else {
        throw Exception(result['Message']);
      }
    } catch (e) {
      debugPrint("❌ ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String convertToDecimalFormat(int hours, int minutes) {
    String mm = minutes.toString().padLeft(2, '0');
    return "$hours.$mm"; // Example: 1 hour 5 min = "1.05"
  }

  Future<void> _deleteTimesheetEntry(
      int tsNo, String eleId, int userId, int index) async {
    if (_isTimesheetLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Cannot delete entries from approved/rejected timesheet'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final uri = ApiUtils.getUri('DeleteTimesheetEntry');
      final response = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"TSNO": tsNo, "ELEID": eleId, "DELUSER": empCode}));

      final result = jsonDecode(response.body);
      if (response.statusCode == 200 && result['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Entry deleted!'),
              backgroundColor: AppColors.success),
        );
        setState(() {
          _entries.removeAt(index);
          _dateControllers.remove(index); // 🔥 CLEAN UP DATE CONTROLLER
        });
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed: ${result['Message']}'),
              backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> updateTimesheetStatus(
    int tsNo,
    String action,
    List<TimesheetViewModel> entries,
    List<int?> tsSlNos,
  ) async {
    final tsSlNo = tsSlNos.isNotEmpty ? tsSlNos.first : null;

    print("TSNO: $tsNo");
    print("Action: $action");
    print("TSSLNO List: $tsSlNo");

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
      final uri = ApiUtils.getUri('_UpdateTimesheetStatus');

      Map<String, dynamic> body = {
        "TSNO": tsNo,
        "TSSLNO": tsSlNo,
        "TSSTATUS": action.toUpperCase(),
      };

      // Add user fields based on action type
      if (action.toUpperCase() == 'APPROVE' ||
          action.toUpperCase() == 'REJECT') {
        body["APPUSER"] = empCode;
        body["APPREMARKS"] = remarksController.text;
      } else if (action.toUpperCase() == 'RECHECK') {
        body["RECHKUSER"] = empCode;
        body["RECHKREMARKS"] = remarksController.text;

        // ✅ FIXED: Use the entries parameter that was passed to the method
        if (entries.isNotEmpty) {
          List<Map<String, dynamic>> recheckData = entries.map((entry) {
            return {
              "TSNO": widget.tsNo ?? 0,
              "TSSLNO": entry.tsSlNo ?? 0,
              "TSDT": DateTime.now().toIso8601String(),
              "TSDEPTTYPE": entry.deptType ?? '',
              "SITECODE": entry.siteCode ?? 0,
              "ELEID": entry.eleId ?? '',
              "TYPE": entry.type ?? '',
              "WORKTYPE": entry.workType ?? '',
              "REMARKS": entry.remarks ?? '',
              "TSUPTIME": entry.tsUpTime ?? '',
            };
          }).toList();

          // ✅ FIXED: Convert to JSON string as API expects
          body["RECHKDATA"] = jsonEncode(recheckData);

          debugPrint('RECHECK Data entries: ${entries.length}');
          debugPrint('RECHECK Data JSON: ${body["RECHKDATA"]}');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No entries selected for recheck'),
              backgroundColor: AppColors.warning,
            ),
          );
          return;
        }
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

        // ✅ FIXED: Update local status for all selected entries with proper state management
        if (action.toUpperCase() == 'RECHECK') {
          setState(() {
            for (var entry in _entries.where((e) => e.isSelected)) {
              entry.status = 'RECHECK';
              entry.isModified = true;
              debugPrint('Updated ${entry.elementId} status to RECHECK');
            }
          });

          // Force additional rebuild to ensure UI updates
          await Future.delayed(Duration(milliseconds: 100));
          setState(() {});
        }

        // Navigate back to view timesheet screen
        Navigator.pop(context); // Just go back
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

  Future<void> _updateTimesheetStatus(
    int tsNo,
    String action,
    List<TimesheetViewModel> entries,
    List<int?> tsSlNos,
  ) async {
    // ✅ Clean list
    final validTsSlNos = tsSlNos.where((e) => e != null).cast<int>().toList();

    print("TSNO: $tsNo");
    print("Action: $action");
    print("TSSLNO List: $validTsSlNos");

    if (validTsSlNos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one valid entry'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (empCode == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not loaded yet. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // ✅ Remarks dialog
    final remarksController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            '${action[0].toUpperCase()}${action.substring(1).toLowerCase()} Timesheet'),
        content: TextField(
          controller: remarksController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Remarks (optional)',
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uri = ApiUtils.getUri('_UpdateTimesheetStatus');

      // ✅ SEND LIST (NOT LOOP)
      Map<String, dynamic> body = {
        "TSNO": tsNo,
        "TSSLNO": validTsSlNos, // ✅ IMPORTANT FIX
        "TSSTATUS": action.toUpperCase(),
      };

      if (action.toUpperCase() == 'APPROVE' ||
          action.toUpperCase() == 'REJECT') {
        body["APPUSER"] = empCode;
        body["APPREMARKS"] = remarksController.text;
      } else if (action.toUpperCase() == 'RECHECK') {
        body["RECHKUSER"] = empCode;
        body["RECHKREMARKS"] = remarksController.text;

        final recheckData = entries.map((entry) {
          return {
            "TSNO": tsNo,
            "TSSLNO": entry.tsSlNo ?? 0,
            "TSDT": DateTime.now().toIso8601String(),
            "TSDEPTTYPE": entry.deptType ?? '',
            "SITECODE": entry.siteCode ?? 0,
            "ELEID": entry.eleId ?? '',
            "TYPE": entry.type ?? '',
            "WORKTYPE": entry.workType ?? '',
            "REMARKS": entry.remarks ?? '',
            "TSUPTIME": entry.tsUpTime ?? '',
          };
        }).toList();

        body["RECHKDATA"] = jsonEncode(recheckData);
      }

      debugPrint('Sending: ${jsonEncode(body)}');

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
            content: Text(
              'Timesheet #$tsNo ${action.toUpperCase()} Successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message'] ?? 'Failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _updateSingleEntry(TimesheetEntry entry, String action) {
    _updateSingleEntryAPI(entry, action);
  }

  Future<void> _updateSingleEntryAPI(
      TimesheetEntry entry, String action) async {
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
            '${action[0].toUpperCase()}${action.substring(1).toLowerCase()} Entry - ${entry.elementId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Element: ${entry.elementId}'),
            Text('Project: ${entry.projectId} - ${entry.projectName}'),
            const SizedBox(height: 16),
            TextField(
              controller: remarksController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
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
                backgroundColor: AppColors.primaryDark),
            child:
                const Text('Confirm', style: TextStyle(color: AppColors.text)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uri = ApiUtils.getUri('UpdateSingleTimesheetEntry');

      Map<String, dynamic> body = {
        "TSNO": widget.tsNo,
        "ELEID": entry.elementId,
        "TSSTATUS": action.toUpperCase(),
      };

      // Add appropriate user fields based on action
      if (action.toUpperCase() == 'APPROVE' ||
          action.toUpperCase() == 'REJECT') {
        body["APPUSER"] = empCode;
        body["APPREMARKS"] = remarksController.text;
      } else if (action.toUpperCase() == 'RECHECK') {
        body["RECHKUSER"] = empCode;
        body["RECHKREMARKS"] = remarksController.text;

        // ✅ FIXED: Send RECHKDATA for single entry
        Map<String, dynamic> recheckItem = {
          "TSNO": widget.tsNo ?? 0,
          "TSDT": DateTime.now().toIso8601String(),
          "TSDEPTTYPE": entry.deptType ?? entry.designingDrafting ?? '',
          "SITECODE": entry.projectId ?? 0,
          "ELEID": entry.elementId,
          "TYPE": entry.type,
          "WORKTYPE": entry.workType,
          "REMARKS": entry.remarks,
          "TSUPTIME": entry.tsuptime ?? '',
        };

        body["RECHKDATA"] = jsonEncode(recheckItem);
        debugPrint(
            'Single entry recheck - sending RECHKDATA: ${body["RECHKDATA"]}');
      }

      debugPrint('Sending single entry update: ${jsonEncode(body)}');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message'] ?? 'Action completed successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        // ✅ FIXED: Force a state update to refresh the UI
        setState(() {
          entry.status = action.toUpperCase();
          entry.isModified = true;
          debugPrint(
              'Updated entry ${entry.elementId} status to: ${entry.status}');
        });
        Navigator.pop(context);
        // ✅ Optional: Force a small delay and rebuild to ensure UI updates
        await Future.delayed(Duration(milliseconds: 100));
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message'] ?? 'Failed to update entry'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating single entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Update _selectedEntries method to only include SUBMITTED and RECHECK entries
  List<TimesheetViewModel> _selectedEntries() {
    return _entries
        .where((e) =>
            e.isSelected && (e.status == 'SUBMITTED' || e.status == 'RECHECK'))
        .map((entry) => TimesheetViewModel(
              tsNo: widget.tsNo,
              tsSlNo: entry.tsSlNo,
              tsDt: DateTime.now().toString(),
              siteCode: entry.projectId,
              eleId: entry.elementId,
              type: entry.type,
              workType: entry.workType,
              remarks: entry.remarks,
              deptType: entry.deptType ?? entry.designingDrafting,
              tsUpTime: entry.tsuptime,
            ))
        .toList();
  }

  // Update Select All functionality to only select eligible entries
  Widget _buildEntriesList() {
    return Column(
      children: [
        // Only show select all checkbox when there are eligible entries
        if (_entries
                .any((e) => e.status == 'SUBMITTED' || e.status == 'RECHECK') &&
            _showApproveRejectOptions &&
            widget.isViewMode)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Checkbox(
                  value: _selectAll,
                  onChanged: (val) {
                    setState(() {
                      _selectAll = val ?? false;
                      // Only select entries that are SUBMITTED or RECHECK
                      for (var e in _entries) {
                        if (e.status == 'SUBMITTED' || e.status == 'RECHECK') {
                          e.isSelected = _selectAll;
                        } else {
                          e.isSelected =
                              false; // Ensure non-eligible entries are not selected
                        }
                      }
                    });
                  },
                ),
                const Text(
                  'Select All',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                // Show selection count for eligible entries only
                Text(
                  '${_entries.where((e) => e.isSelected && (e.status == 'SUBMITTED' || e.status == 'RECHECK')).length} of ${_entries.where((e) => e.status == 'SUBMITTED' || e.status == 'RECHECK').length} selected',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _entries.length,
            itemBuilder: (context, index) => _buildEntryCard(index),
          ),
        ),
      ],
    );
  }

  Color _getWTStatusColor(String status) {
    switch (status?.toLowerCase()) {
      case 'submitted':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'forwarded':
        return Colors.purple;
      case 'reassigned':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getWTStatusDisplayText(String status) {
    switch (status?.toLowerCase()) {
      case 'submitted':
        return 'Submitted';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
        return 'Pending';
      case 'Forwarded':
        return 'forwarded';
      case 'reassigned':
        return 'Reassigned';
      default:
        return status ?? 'Submitted';
    }
  }

  Future<Map<String, dynamic>> getFilteredWorkTypes(
      int siteCode, String eleId, String entryType) async {
    final defaultWorkTypes = entryType == 'New'
        ? ['Drawing', 'Checking', 'Correction', 'Issued']
        : entryType == 'Rework'
            ? ['Revision', 'Rectification']
            : <String>[];

    try {
      final url = ApiUtils.getUri('CheckUsedWorkTypes');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'siteCode': siteCode, 'eleId': eleId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true && data['UsedWorkTypes'] is List) {
          final List<dynamic> usedDynamic = data['UsedWorkTypes'];

          // Parse used work types with details from your API
          final List<UsedWorkType> usedWorkTypes = usedDynamic.map((item) {
            return UsedWorkType(
              workType: item['WorkType']?.toString() ?? '',
              employeeCode: item['EmployeeCode']?.toString() ?? '',
              status: item['Status']?.toString() ?? 'Submitted',
              submittedDate: item['SubmittedDate'] != null
                  ? DateTime.tryParse(item['SubmittedDate'].toString())
                  : null,
            );
          }).toList();

          // Get unique used work type names for filtering
          final usedWorkTypeNames =
              usedWorkTypes.map((wt) => wt.workType).toSet().toList();

          // Filter default work types
          final filtered = defaultWorkTypes
              .where((wt) => !usedWorkTypeNames.contains(wt))
              .toList();

          return {
            'availableWorkTypes': filtered,
            'usedWorkTypes': usedWorkTypes,
          };
        }
      }
    } catch (e) {
      debugPrint('Error fetching work types: $e');
    }

    return {
      'availableWorkTypes': defaultWorkTypes,
      'usedWorkTypes': [],
    };
  }

  Widget buildUsedWorkTypes(List<UsedWorkType> usedWorkTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: usedWorkTypes.map((wt) {
        Color textColor;

        // Assign colors based on status or work type
        switch (wt.status.toUpperCase()) {
          case 'SUBMITTED':
            textColor = Colors.blueGrey;
            break;
          case 'APPROVED':
            textColor = Colors.green;
            break;
          case 'REJECTED':
            textColor = Colors.red;
            break;
          case 'RECHECK':
            textColor = Colors.orange;
            break;
          case 'FORWARDED':
            textColor = Colors.purple;
            break;
          case 'REASSIGNED':
            textColor = Colors.teal;
            break;
          default:
            textColor = Colors.black;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            '${wt.workType} (${wt.employeeCode})',
            style: TextStyle(
              fontSize: 14,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showUsedWorkTypesDialog(
      BuildContext context, List<UsedWorkType> usedWorkTypes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.assignment, color: Colors.blue),
            SizedBox(width: 8),
            Text('Used Work Types'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: usedWorkTypes.length,
            itemBuilder: (context, index) {
              final wt = usedWorkTypes[index];
              final statusColor = _getWTStatusColor(wt.status);
              final statusText = _getWTStatusDisplayText(wt.status);

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          wt.workType,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: statusColor,
                          ),
                        ),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person, size: 12, color: Colors.grey),
                        SizedBox(width: 4),
                        FutureBuilder<String>(
                          future: getEmployeeNameWithCode(
                              wt.employeeCode), // no int.parse
// ensure int
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Text(
                                'Submitted by : ${wt.employeeCode} - ...',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              );
                            } else if (snapshot.hasError) {
                              return Text(
                                'Submitted by : ${wt.employeeCode} - Error',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              );
                            } else {
                              return Text(
                                'Submitted by : ${snapshot.data}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              );
                            }
                          },
                        )
                      ],
                    ),
                    if (wt.submittedDate != null) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            'Submitted on : ${DateFormat('dd MMM yyyy').format(wt.submittedDate!)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Future<String> getEmployeeNameWithCode(String empCode) async {
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

    return "$empCode - -"; // fallback
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/*void _saveTimesheet() async {
  if (!_formKey.currentState!.validate()) return;

  // Filter only edited entries
  final editedEntries = _entries.where((e) => e.isEdited).toList();

  if (editedEntries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No changes to save.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  final payload = editedEntries
      .map((e) => {
            "TSNO": widget.tsNo ?? 0,
            "SITECODE": e.projectId,
            "ELEID": e.elementId,
            "TYPE": e.type,
            "WORKTYPE": e.workType,
            "REMARKS": e.remarks,
            "DEPTCODE": empDept,
            "TLCODE": empTL ?? '',
            "ADDUSER": e.isEdited && widget.isEditMode ? null : empCode,
            "EDITUSER": widget.isEditMode ? empCode : null,
          })
      .toList();

  debugPrint(
      'Saving ${editedEntries.length} edited entries for TSNO: ${widget.tsNo}');

  try {
    final uri = ApiUtils.getUri('SaveTimesheet');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final result = jsonDecode(response.body);
    debugPrint('Save Timesheet Response: $result');

    if (response.statusCode == 200 && result['Success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Timesheet updated! TSNO: ${result['TSNO']}'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, result['TSNO']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${result['Message']}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  } catch (e) {
    debugPrint('Error saving timesheet: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}*/

/*void _SaveTimesheet() async {
    // 1️⃣ Validate the form
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields before saving.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2️⃣ Validate each entry manually - REMOVED DATE VALIDATION ERRORS
    for (var e in _entries) {
      // ✅ Set current date if no date is selected (NO ERROR)
      if (e.entryDate == null) {
        e.entryDate = DateTime.now();
        debugPrint(
            'No date selected for entry "${e.elementId}", using current date: ${e.entryDate}');
      }

      // ✅ Still validate date range but don't show error for missing date
      if (!_isDateWithinAllowedRange(e.entryDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Date for entry "${e.elementId}" must be within the last 2 days. Selected date: ${DateFormat('yyyy-MM-dd').format(e.entryDate!)}'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ✅ Validate Project Selection
      if (e.projectId == null || e.projectId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a valid Project for all entries.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ✅ Ensure the projectId actually exists in the dropdown list
      final bool isValidProject =
          _projects.any((p) => p.projectId == e.projectId);

      if (!isValidProject) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid Project ID. Please select a project from the dropdown list.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if ((e.elementId.trim().isEmpty) && (e.elementItems.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Element ID cannot be empty.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (e.type.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Type cannot be empty.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (e.workType.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work Type cannot be empty.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (e.hours == 0 && e.minutes == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Work Duration cannot be 0 for entry "${e.elementId}".'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Validate minimum duration (if needed)
      final totalMinutes = (e.hours * 60) + e.minutes;
      if (totalMinutes < 15) {
        // Minimum 15 minutes
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Work Duration must be at least 15 minutes for entry "${e.elementId}".'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (e.remarks.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Remarks cannot be empty.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // 3️⃣ Determine entries to save
    List<TimesheetEntry> entriesToSave;
    if (widget.isEditMode) {
      entriesToSave = _entries
          .where((e) =>
              e.elementId.trim().isNotEmpty &&
              e.projectId != null &&
              e.projectId != 0)
          .toList();
      debugPrint('Edit mode: Sending ${entriesToSave.length} entries');
    } else {
      entriesToSave = _entries
          .where((e) =>
              e.elementId.trim().isNotEmpty &&
              e.projectId != null &&
              e.projectId != 0 &&
              e.type.trim().isNotEmpty &&
              e.workType.trim().isNotEmpty &&
              e.remarks.trim().isNotEmpty)
          .toList();
    }

    if (entriesToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid data to save.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 4️⃣ Handle REASSIGNED entries
    bool hasReassigned =
        entriesToSave.any((e) => e.status.toUpperCase() == 'REASSIGNED');
    if (hasReassigned) {
      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Submission'),
          content: const Text(
              'Some entries have status REASSIGNED. Do you want to submit them as SUBMITTED?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Submit')),
          ],
        ),
      );
      if (!confirm) return;
      for (var e in entriesToSave) {
        if (e.status.toUpperCase() == 'REASSIGNED') {
          e.status = 'SUBMITTED';
        }
      }
    }

    // 5️⃣ Prepare payload - FIXED DATE FORMATTING
    final payload = entriesToSave.map((e) {
      if (widget.isEditMode && e.status.toUpperCase() == 'RECHECK') {
        e.status = 'SUBMITTED';
      }

      // 🔥 USE INDIVIDUAL ENTRY DATE (guaranteed to be not null now)
      final formattedDate = e.entryDate!.toIso8601String();

      // ✅ FIXED: Proper user assignment for new vs existing entries
      Map<String, dynamic> payloadEntry = {
        "TSNO": widget.tsNo ?? 0,
        "TSSLNO": e.tsSlNo ?? 0,
        "SITECODE": e.projectId,
        "ELEID": e.elementId,
        "TYPE": e.type,
        "WORKTYPE": e.workType,
        "REMARKS": e.remarks,
        "DEPTCODE": empDept,
        "TLCODE": empTL ?? '',
        "TSSTATUS": 'SUBMITTED',
        "TSUPTIME": e.tsuptime,
        "TSDEPTTYPE": e.deptType ?? e.designingDrafting,
        "TSDT": formattedDate,
        "TOTHRS":
            '${e.hours.toString().padLeft(2, '0')}:${e.minutes.toString().padLeft(2, '0')}:00',
        "DRAFTINGTYPE": (e.designingDrafting == 'Drafting')
            ? (e.draftingType == 'Piece Drawing'
                ? 'Piece Drawing'
                : e.draftingType == 'Erection Drawing'
                    ? 'Erection Drawing'
                    : 'Designing Drawing')
            : 'Designing Drawing',
        //"TOTHRS": e.totHrsAsDecimal, // Convert to decimal for backend
      };

      // ✅ CRITICAL FIX: Proper user assignment
      if (widget.isEditMode) {
        if (e.isExisting) {
          // Existing entry in edit mode - use EDITUSER
          payloadEntry["EDITUSER"] = empCode;
        } else {
          // New entry in edit mode - use ADDUSER
          payloadEntry["ADDUSER"] = empCode;
        }
      } else {
        // Add mode - always use ADDUSER
        payloadEntry["ADDUSER"] = empCode;
      }

      return payloadEntry;
    }).toList();

    // 🔥 ADD DEBUG LOGGING FOR DATES
    for (var i = 0; i < entriesToSave.length; i++) {
      debugPrint('Entry $i: ELEID=${entriesToSave[i].elementId}, '
          'Date=${entriesToSave[i].entryDate}, '
          'isExisting=${entriesToSave[i].isExisting}');
    }

    debugPrint(
        'Saving ${entriesToSave.length} entries for TSNO: ${widget.tsNo}');
    debugPrint('Payload: $payload');

    // 6️⃣ Send to API
    try {
      final uri = ApiUtils.getUri('SaveTimesheet');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final result = jsonDecode(response.body);
      debugPrint('Save Timesheet Response: $result');

      if (response.statusCode == 200 && result['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Timesheet ${widget.isEditMode ? 'updated' : 'created'}! TSNO: ${result['TSNO']}'),
            backgroundColor: AppColors.success,
          ),
        );

        for (var entry in _entries) {
          entry.isModified = false;
        }

        Navigator.pop(context, result['TSNO']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${result['Message']}'),
            backgroundColor: AppColors.error,
          ),
        );
        debugPrint('Failed: ${result['Message']}');
      }
    } catch (e) {
      debugPrint('Error saving timesheet: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> saveTimesheet() async {
    debugPrint("🚀 ===== START SAVE TIMESHEET =====");

    // 1️⃣ FORM VALIDATION
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields before saving.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2️⃣ ENTRY VALIDATION
    for (var e in _entries) {
      e.entryDate ??= DateTime.now();

      if (!_isDateWithinAllowedRange(e.entryDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Date must be within last 2 days: ${DateFormat('yyyy-MM-dd').format(e.entryDate!)}'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (e.projectId == null || e.projectId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a valid Project.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final isValidProject = _projects.any((p) => p.projectId == e.projectId);

      if (!isValidProject) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid Project selected.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (e.elementId.trim().isEmpty && e.elementItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add at least one Element.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (e.type.trim().isEmpty ||
          e.workType.trim().isEmpty ||
          e.remarks.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Type, Work Type & Remarks are required.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final totalMinutes = (e.hours * 60) + e.minutes;

      if (totalMinutes < 15) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimum 15 minutes required.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // 3️⃣ FILTER VALID ENTRIES
    final entriesToSave = _entries.where((e) {
      return (e.elementId.trim().isNotEmpty || e.elementItems.isNotEmpty) &&
          e.projectId != null &&
          e.projectId != 0;
    }).toList();

    if (entriesToSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid data to save.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 4️⃣ BUILD PAYLOAD (🔥 FINAL FIX)
    final List<Map<String, dynamic>> payload = [];

    for (var e in entriesToSave) {
      final formattedDate = e.entryDate!.toIso8601String();

      // 🔥 MULTI ELEMENTS
      if (e.elementItems.isNotEmpty) {
        for (var item in e.elementItems) {
          final eleId = item['elementId'];

          int tsslNo = (item['tsSlNo'] != null && item['tsSlNo'] > 0)
              ? item['tsSlNo']
              : 0;

          final row = {
            "TSNO": widget.tsNo ?? 0,
            "TSSLNO": tsslNo,
            "SITECODE": e.projectId,

            // ✅ REQUIRED FIELDS
            "ELEID": eleId,
            "ELENAME": item['elementName'] ?? "",
            "ELEQNTY": item['qty'] ?? 0,

            "TYPE": e.type,
            "WORKTYPE": e.workType,
            "REMARKS": e.remarks,
            "DEPTCODE": empDept,
            "TLCODE": empTL ?? '',
            "TSSTATUS": 'SUBMITTED',
            "TSUPTIME": e.tsuptime,
            "TSDEPTTYPE": e.deptType ?? e.designingDrafting,
            "TSDT": formattedDate,
            "TOTHRS":
                '${e.hours.toString().padLeft(2, '0')}:${e.minutes.toString().padLeft(2, '0')}:00',
            "DRAFTINGTYPE": (e.designingDrafting == 'Drafting')
                ? (e.draftingType ?? 'Designing Drawing')
                : 'Designing Drawing',

            // ✅ USER HANDLING
            if (widget.isEditMode && tsslNo > 0)
              "EDITUSER": empCode
            else
              "ADDUSER": empCode,
          };

          payload.add(row);

          debugPrint("🧾 MULTI ROW: $row");
        }
      }

      // 🔥 SINGLE ELEMENT
      else {
        int tsslNo = (widget.isEditMode && e.isExisting && e.tsSlNo != null)
            ? e.tsSlNo!
            : 0;

        final row = {
          "TSNO": widget.tsNo ?? 0,
          "TSSLNO": tsslNo,
          "SITECODE": e.projectId,
          "ELEID": e.elementId,
          "ELENAME": "",
          "ELEQNTY": 0,
          "TYPE": e.type,
          "WORKTYPE": e.workType,
          "REMARKS": e.remarks,
          "DEPTCODE": empDept,
          "TLCODE": empTL ?? '',
          "TSSTATUS": 'SUBMITTED',
          "TSUPTIME": e.tsuptime,
          "TSDEPTTYPE": e.deptType ?? e.designingDrafting,
          "TSDT": formattedDate,
          "TOTHRS":
              '${e.hours.toString().padLeft(2, '0')}:${e.minutes.toString().padLeft(2, '0')}:00',
          "DRAFTINGTYPE": (e.designingDrafting == 'Drafting')
              ? (e.draftingType ?? 'Designing Drawing')
              : 'Designing Drawing',
          if (widget.isEditMode && tsslNo > 0)
            "EDITUSER": empCode
          else
            "ADDUSER": empCode,
        };

        payload.add(row);

        debugPrint("🧾 SINGLE ROW: $row");
      }
    }

    for (var e in entriesToSave) {
      final formattedDate = e.entryDate!.toIso8601String();
      for (var item in e.elementItems) {
        payload.add({
          "TSNO": widget.tsNo ?? 0,

          // ✅ FIXED
          "TSSLNO": e.isExisting ? (e.tsSlNo ?? 0) : 0,

          "SITECODE": e.projectId,
          "ELEID": item['elementId'],
          "ELENAME": item['elementName'] ?? "",
          "ELEQNTY": item['qty'] ?? 0,

          "TYPE": e.type,
          "WORKTYPE": e.workType,
          "REMARKS": e.remarks,
          "DEPTCODE": empDept,
          "TLCODE": empTL ?? '',
          "TSSTATUS": 'SUBMITTED',
          "TSUPTIME": e.tsuptime,
          "TSDEPTTYPE": e.deptType ?? e.designingDrafting,
          "TSDT": e.entryDate!.toIso8601String(),

          "TOTHRS":
              '${e.hours.toString().padLeft(2, '0')}:${e.minutes.toString().padLeft(2, '0')}:00',

          "DRAFTINGTYPE": e.draftingType ?? 'Designing Drawing',

          // ✅ USER FIX
          if (widget.isEditMode && e.isExisting)
            "EDITUSER": empCode
          else
            "ADDUSER": empCode,
        });
      }
    }

    debugPrint("📤 FINAL PAYLOAD COUNT: ${payload.length}");
    debugPrint("📤 PAYLOAD: $payload");

    // 5️⃣ API CALL
    try {
      final uri = ApiUtils.getUri('SaveTimesheet');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Timesheet ${widget.isEditMode ? 'updated' : 'created'}! TSNO: ${result['TSNO']}'),
            backgroundColor: AppColors.success,
          ),
        );

        for (var entry in _entries) {
          entry.isModified = false;
        }

        Navigator.pop(context, result['TSNO']);
      } else {
        throw Exception(result['Message']);
      }
    } catch (e) {
      debugPrint("❌ ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _saveTimesheet() async {
    debugPrint("🚀 ===== START SAVE TIMESHEET =====");

    // 1️⃣ FORM VALIDATION
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields before saving.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2️⃣ ENTRY VALIDATION
    for (var e in _entries) {
      e.entryDate ??= DateTime.now();

      if (!_isDateWithinAllowedRange(e.entryDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Date must be within last 2 days: ${DateFormat('yyyy-MM-dd').format(e.entryDate!)}'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (e.projectId == null || e.projectId == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a valid Project.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (e.elementId.trim().isEmpty && e.elementItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add at least one Element.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (e.type.trim().isEmpty ||
          e.workType.trim().isEmpty ||
          e.remarks.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Type, Work Type & Remarks are required.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    // 3️⃣ FILTER
    final entriesToSave = _entries.where((e) {
      return (e.elementId.trim().isNotEmpty || e.elementItems.isNotEmpty) &&
          e.projectId != null &&
          e.projectId != 0;
    }).toList();

    if (entriesToSave.isEmpty) return;

    // 🔥 IMPORTANT: Track running TSSLNO
    int runningTsslNo = 0;

    final List<Map<String, dynamic>> payload = [];

    for (var e in entriesToSave) {
      final formattedDate = e.entryDate!.toIso8601String();

      // 🔥 MULTIPLE ELEMENTS
      if (e.elementItems.isNotEmpty) {
        for (var item in e.elementItems) {
          runningTsslNo++; // ✅ UNIQUE NUMBER

          payload.add({
            "TSNO": widget.tsNo ?? 0,

            // ✅ ALWAYS UNIQUE
            "TSSLNO": widget.isEditMode
                ? (e.isExisting ? e.tsSlNo ?? runningTsslNo : 0)
                : 0,

            "SITECODE": e.projectId,
            "ELEID": item['elementId'],
            "ELENAME": item['elementName'] ?? "",
            "ELEQNTY": item['qty'] ?? 0,

            "TYPE": e.type,
            "WORKTYPE": e.workType,
            "REMARKS": e.remarks,
            "DEPTCODE": empDept,
            "TLCODE": empTL ?? '',
            "TSSTATUS": 'SUBMITTED',
            "TSUPTIME": e.tsuptime,
            "TSDEPTTYPE": e.deptType ?? e.designingDrafting,
            "TSDT": formattedDate,
            "TOTHRS":
                '${e.hours.toString().padLeft(2, '0')}:${e.minutes.toString().padLeft(2, '0')}:00',
            "DRAFTINGTYPE": e.draftingType ?? 'Designing Drawing',

            if (widget.isEditMode && e.isExisting)
              "EDITUSER": empCode
            else
              "ADDUSER": empCode,
          });
        }
      }

      // 🔥 SINGLE ELEMENT
      else {
        runningTsslNo++;

        payload.add({
          "TSNO": widget.tsNo ?? 0,
          "TSSLNO": widget.isEditMode && e.isExisting ? e.tsSlNo ?? 0 : 0,
          "SITECODE": e.projectId,
          "ELEID": e.elementId,
          "ELENAME": "",
          "ELEQNTY": 0,
          "TYPE": e.type,
          "WORKTYPE": e.workType,
          "REMARKS": e.remarks,
          "DEPTCODE": empDept,
          "TLCODE": empTL ?? '',
          "TSSTATUS": 'SUBMITTED',
          "TSUPTIME": e.tsuptime,
          "TSDEPTTYPE": e.deptType ?? e.designingDrafting,
          "TSDT": formattedDate,
          "TOTHRS":
              '${e.hours.toString().padLeft(2, '0')}:${e.minutes.toString().padLeft(2, '0')}:00',
          "DRAFTINGTYPE": e.draftingType ?? 'Designing Drawing',
          if (widget.isEditMode && e.isExisting)
            "EDITUSER": empCode
          else
            "ADDUSER": empCode,
        });
      }
    }

    debugPrint("📤 FINAL PAYLOAD: $payload");

    // 4️⃣ API CALL
    try {
      final uri = ApiUtils.getUri('SaveTimesheet');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Timesheet ${widget.isEditMode ? 'updated' : 'created'}! TSNO: ${result['TSNO']}'),
            backgroundColor: AppColors.success,
          ),
        );

        Navigator.pop(context, result['TSNO']);
      } else {
        throw Exception(result['Message']);
      }
    } catch (e) {
      debugPrint("❌ ERROR: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }*/

/*Widget _buildEntriesList() {
  return Column(
    children: [
      // Only show select all checkbox when timesheet is submitted and user can approve/reject
      if (_showApproveRejectOptions)
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Checkbox(
                  value: _selectAll,
                  onChanged: (val) {
                    setState(() {
                      _selectAll = val ?? false;
                      for (var e in _entries) e.isSelected = _selectAll;
                    });
                  }),
              const Text(
                'Select All',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              // Show selection count
              Text(
                '${_entries.where((e) => e.isSelected).length} of ${_entries.length} selected',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      Expanded(
        child: ListView.builder(
          itemCount: _entries.length,
          itemBuilder: (context, index) => _buildEntryCard(index),
        ),
      ),
    ],
  );
}*/
