import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:pluto_grid/pluto_grid.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import 'dart:io';

import '../../widgets/filedownloadservice.dart';

class BillingEntryScreen extends StatefulWidget {
  final bool isSuperAdmin;
  final bool? isReadOnly;
  final VoidCallback? onDataSaved;
  final int? initialCustomerId;
  final int? initialProjectId;
  final String? initialCustomerName;
  final String? initialProjectName;

  const BillingEntryScreen({
    super.key,
    this.isSuperAdmin = false,
    this.isReadOnly = false,
    this.onDataSaved,
    this.initialCustomerId,
    this.initialProjectId,
    this.initialCustomerName,
    this.initialProjectName,
  });

  @override
  State<BillingEntryScreen> createState() => _BillingEntryScreenState();
}

class _BillingEntryScreenState extends State<BillingEntryScreen> {
  late List<PlutoColumn> columns;
  late List<PlutoRow> rows;
  List<ChecklistCustomer> customerList = [];
  List<Project> projectList = [];
  int? selectedCustomerId;
  int? selectedProjectId;

  PlutoGridStateManager? stateManager;
  TextEditingController customerController = TextEditingController();
  TextEditingController siteController = TextEditingController();
  TextEditingController woValueController = TextEditingController();

  // ── Column field name constants ───────────────────────────────────────────
  static const String _fBillNo = 'col1';
  static const String _fDate = 'col2';
  static const String _fBillDesc = 'col3';
  static const String _fPerWork = 'col4';
  static const String _fWorkDone = 'col5';
  static const String _fSecAdv = 'col6';
  static const String _fMobAdv = 'col7';
  static const String _fTaxable = 'col8';
  static const String _fGST = 'col9';
  static const String _fTotBill = 'col10';
  static const String _fTDS = 'col11';
  static const String _fTDSCGST = 'col12';
  static const String _fTDSSGST = 'col13';
  static const String _fSecDep = 'col14';
  static const String _fLabCess = 'col15';
  static const String _fMobInt = 'col16';
  static const String _fOthDed = 'col17';
  static const String _fWithheld = 'col18';
  static const String _fMobAdvRec = 'col19';
  static const String _fWhRelease = 'col20';
  static const String _fTotDed = 'col21';
  static const String _fNetRec = 'col22';
  static const String _fNetAmtRecd = 'col23';
  static const String _fRecDate = 'col24';
  static const String _fOutstanding = 'col25';
  static const String _fAttachment = 'col26';
  double? _woValueInclGst;
  double? _woValueExclGst;
  bool _isLoading = false;
  int empCode = 0;
  String empName = '';

  final Map<String, String> remarkFields = {
    _fSecAdv: 'col6Remark',
    _fMobAdv: 'col7Remark',
    _fOthDed: 'col17Remark',
    _fWithheld: 'col18Remark',
    _fMobAdvRec: 'col19Remark',
    _fWhRelease: 'col20Remark',
    _fNetAmtRecd: 'col23Remark',
  };
  final Map<String, Map<String, String>> remarkConfig = {
    _fSecAdv: {
      'remark': 'col6Remark',
      'title': 'Secure Advance',
    },
    _fMobAdv: {
      'remark': 'col7Remark',
      'title': 'Mobilisation Advance',
    },
    _fOthDed: {
      'remark': 'col17Remark',
      'title': 'Other Deduction',
    },
    _fWithheld: {
      'remark': 'col18Remark',
      'title': 'Withheld',
    },
    _fMobAdvRec: {
      'remark': 'col19Remark',
      'title': 'Mobilisation Advance Recovery',
    },
    _fWhRelease: {
      'remark': 'col20Remark',
      'title': 'Withheld Release',
    },
    _fNetAmtRecd: {
      'remark': 'col23Remark',
      'title': 'Net Amount Received',
    },
  };
  final Set<String> _existingRowKeys = {};

  List<SalesBillingModel> _billingList = [];
  bool _isLoadingBilling = false;
  bool _showDownloadButton = true;
  SalesBillingSummaryModel? _billingSummary;
  bool _isLoadingStages = false;
  final Set<String> _dirtyRowKeys = {};
  bool _isInitialLoadInProgress = false;

  @override
  void initState() {
    super.initState();
    initializeGrid(isViewOnly: widget.isReadOnly == true);
    //initializeGrid();
    loadCustomers();
    _loadUserDetails();
    if (widget.initialCustomerId != null && widget.initialProjectId != null) {
      selectedCustomerId = widget.initialCustomerId;
      selectedProjectId = widget.initialProjectId;
      customerController.text = widget.initialCustomerName ?? '';
      siteController.text = widget.initialProjectName ?? '';

      fetchWorkOrderValue(widget.initialCustomerId!, widget.initialProjectId!);
      _fetchBillingSummaryForProject(widget.initialProjectId!);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBillingRows(
          endpoint: ApiUtils.getUri('GetSalesBillingByProject'),
          requestBody: {
            'PROJID': widget.initialProjectId!,
            'CUSTOMERID': widget.initialCustomerId!,
          },
          responseListKey: 'Data',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final _scrollController = ScrollController();
    final _formKey = GlobalKey<FormState>();
    final isViewOnly = widget.isReadOnly == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Update'),
        actions: [
          if (!isViewOnly)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Row',
              onPressed: () {
                // Check if customer and project are selected
                if (selectedCustomerId == null || selectedProjectId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select Customer and Site first.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                addNewRow();
                setState(() => _showDownloadButton = false);
              },
            ),
          if (_showDownloadButton)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download Billing Data',
              onPressed: () {
                if (selectedCustomerId == null || selectedProjectId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select Customer and Site first.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                _downloadBillingData();
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            /// Fixed height section for the search fields
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: isViewOnly
                        ? TextFormField(
                            controller: customerController,
                            decoration: _inputDecoration("Customer Name"),
                            readOnly: true,
                            enabled: false,
                          )
                        : Autocomplete<ChecklistCustomer>(
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
                              customerController.text =
                                  "${selection.customerId} - ${selection.companyName}";
                              setState(() {
                                selectedCustomerId = selection.customerId;
                                selectedProjectId = null;
                                siteController.clear();
                                _billingList = [];
                                woValueController.text = '';
                                _woValueInclGst = null;
                                _woValueExclGst = null;
                              });
                              // ← clear grid safely after frame
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                stateManager?.removeAllRows();
                                setState(() => rows = []);
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
                                              rows = [];
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
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
                    child: isViewOnly
                        ? TextFormField(
                            controller: siteController,
                            decoration: _inputDecoration("Site Name"),
                            readOnly: true,
                            enabled: false,
                          )
                        : Autocomplete<Project>(
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
                              if (selectedCustomerId != null) {
                                fetchWorkOrderValue(
                                    selectedCustomerId!, selection.projectId);
                                _fetchBillingSummaryForProject(
                                    selection.projectId);
                              }
                              setState(() {
                                selectedProjectId = selection.projectId;
                                _billingList = [];
                              });
                              // ← clear grid safely after frame, then load
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                stateManager?.removeAllRows();
                                setState(() => rows = []);
                                _loadBillingRows(
                                  endpoint:
                                      ApiUtils.getUri('ViewSalesBillinglist'),
                                  requestBody: {
                                    'CUSID': selectedCustomerId,
                                    'PROJID': selection.projectId
                                  },
                                  responseListKey: 'BillingList',
                                );
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
                                              rows = [];
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
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
            ),

            /// Work Order Value Field
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Work Order Value:',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_isLoading)
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (woValueController.text.isEmpty)
                        Text(
                          'Select project to fetch',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                          ),
                        )
                      else if (woValueController.text.contains('Error') ||
                          woValueController.text == 'No data available')
                        Text(
                          woValueController.text,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.red,
                          ),
                        )
                      else
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '₹ ${formatIndianNumber(_woValueExclGst ?? 0)} (Excl. GST 18%)',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.blue),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '₹ ${formatIndianNumber(_woValueInclGst ?? 0)} (Incl. GST 18%)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Builder(
                              builder: (context) {
                                final totalWorkDone =
                                    (stateManager?.rows ?? []).fold<double>(
                                  0.0,
                                  (sum, row) {
                                    final v = row.cells[_fWorkDone]?.value;
                                    return sum +
                                        (double.tryParse(
                                                v?.toString() ?? '0') ??
                                            0.0);
                                  },
                                );
                                final toBeBilled =
                                    (_woValueInclGst ?? 0.0) - totalWorkDone;

                                return Text(
                                  'To be billed: ₹ ${formatIndianNumber(toBeBilled < 0 ? 0 : toBeBilled)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // ── Stages info button — pinned to the end of the row ─────────────
                IconButton(
                  icon: const Icon(Icons.info_outline,
                      size: 20, color: AppColors.primaryLight),
                  tooltip: 'View Stages',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _showStagesDialog(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// Grid with "Add Row" button when empty
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: PlutoGrid(
                  // ← always show PlutoGrid, never toggle
                  columns: columns,
                  rows: rows,
                  onLoaded: (PlutoGridOnLoadedEvent event) {
                    stateManager = event.stateManager;

                    stateManager!.setSelectingMode(PlutoGridSelectingMode.cell);
                    if (rows.isNotEmpty && stateManager!.rows.isEmpty) {
                      stateManager!.appendRows(rows);
                    }

                    // ✅ Numpad key support
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      stateManager!.keyManager?.subject.listen((keyEvent) {
                        final key = keyEvent.event;
                        print(
                            'Key pressed: ${key.runtimeType} - ${key is RawKeyDownEvent ? (key as RawKeyDownEvent).logicalKey : 'not raw'}');
                        if (key is! RawKeyDownEvent) return;
                        if (stateManager == null) return;
                        if (stateManager!.isEditing)
                          return; // already editing, skip

                        final numpadKeys = {
                          LogicalKeyboardKey.numpad0,
                          LogicalKeyboardKey.numpad1,
                          LogicalKeyboardKey.numpad2,
                          LogicalKeyboardKey.numpad3,
                          LogicalKeyboardKey.numpad4,
                          LogicalKeyboardKey.numpad5,
                          LogicalKeyboardKey.numpad6,
                          LogicalKeyboardKey.numpad7,
                          LogicalKeyboardKey.numpad8,
                          LogicalKeyboardKey.numpad9,
                          LogicalKeyboardKey.numpadDecimal,
                        };

                        if (numpadKeys.contains(key.logicalKey)) {
                          stateManager!.setEditing(true);
                        }
                      });
                    });
                  },
                  onRowDoubleTap: (PlutoGridOnRowDoubleTapEvent event) {
                    debugPrint('Row double tapped');
                  },
                  onChanged: _onGridChanged,
                  onSelected: (PlutoGridOnSelectedEvent event) async {
                    if (event.row == null || event.cell == null) return;

                    final column = event.cell!.column;
                    final row = event.row!;

                    // ✅ Handle Date column — open picker
                    if (column.title == 'Date') {
                      await selectDateForCell(row, column);
                      return; // ← return early, no setEditing needed for date
                    }

                    // ✅ Skip read-only, attachment, remark-icon columns
                    final skipFields = {
                      'col5', 'col8', 'col10', 'col11', 'col12',
                      'col13', 'col14', 'col15', 'col21', 'col22',
                      'col25', // Outstanding (read-only)
                      'col26', // Attachment handled by its own InkWell
                    };

                    if (skipFields.contains(column.field)) return;

                    // ✅ For remarkConfig fields — let InkWell handle it, still set editing for text part
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (stateManager == null) return;
                      if (!stateManager!.isEditing) {
                        stateManager!.setEditing(true);
                      }
                    });
                  },

                  configuration: PlutoGridConfiguration(
                    style: PlutoGridStyleConfig(
                      rowHeight: 45,
                      columnHeight: 50,
                      gridBorderRadius: BorderRadius.circular(8),
                    ),
                    scrollbar: const PlutoGridScrollbarConfig(
                      isAlwaysShown: true,
                    ),
                    // ✅ Single click enters edit mode
                    enterKeyAction: PlutoGridEnterKeyAction.editingAndMoveDown,
                    tabKeyAction: PlutoGridTabKeyAction.moveToNextOnEdge,
                    enableMoveDownAfterSelecting: true,
                  ),
                  noRowsWidget: _buildEmptyState(), // ← empty state inside grid
                ),
              ),
            ),

            // ── After PlutoGrid widget ─────────────────────────────────────────────────
            const SizedBox(height: 16),
            if (rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 5,
                          offset: Offset(2, 4))
                    ],
                  ),
                  child: InkWell(
                    onTap: _submitAllRows,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Center(
                        child: Text(
                          // ✅ Show Update if all rows are existing, Submit if any new row
                          _existingRowKeys.length == stateManager?.rows.length
                              ? 'Update'
                              : 'Submit',
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
            const SizedBox(height: 16),
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

  void initializeGrid({bool isViewOnly = false}) {
    final List<String> columnNames = [
      'Bill No',
      'Date',
      'Bill Description',
      '% of work',
      'Work Done value',
      'Secure Advance',
      'Mobilisation advance',
      'Taxable value',
      'GST',
      'Total bill amount',
      'TDS',
      'TDS CGST',
      'TDS SGST',
      'Security deposit',
      'Labour Cess',
      'Mobilization Interest',
      'Other Deduction',
      'Withheld',
      'Mobilization Advance Recovery',
      'Withheld release',
      'Total Deduction',
      'Net receivable',
      'Net amount received',
      'Date',
      'Outstanding',
      'Attachment'
    ];

    // ── Read-only (auto-calculated) columns ──────────────────────────────────
    final Set<String> readOnlyFields = {
      'col5',
      'col8',
      'col10',
      'col11',
      'col12',
      'col13',
      'col14',
      'col15',
      'col21',
      'col22',
      'col25',
    };

    final Set<String> percentFields = {'col4', 'col9'};

    final Set<String> numberFields = {
      'col5',
      'col6',
      'col7',
      'col8',
      'col10',
      'col11',
      'col12',
      'col13',
      'col14',
      'col15',
      'col16',
      'col17',
      'col18',
      'col19',
      'col20',
      'col21',
      'col22',
      'col23',
      'col25',
      'col26',
    };

    columns = List.generate(columnNames.length, (index) {
      final title = columnNames[index];
      final field = 'col${index + 1}';
      // ── Force read-only for every column when isViewOnly ─────────────────
      final isReadOnly = isViewOnly || readOnlyFields.contains(field);

      // ── Attachment column ─────────────────────────────────────────────────
      if (title == 'Attachment') {
        return PlutoColumn(
          title: title,
          field: field,
          type: PlutoColumnType.text(),
          enableEditingMode: false,
          readOnly: false,
          width: 120,
          renderer: (ctx) {
            final cellValue = ctx.cell.value;
            final hasAttachment = cellValue != null &&
                cellValue.toString().trim().isNotEmpty &&
                cellValue.toString().trim() != 'null';

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasAttachment)
                  InkWell(
                    onTap: () => _showAttachmentDialog(ctx.row, field),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_file,
                              size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text('View',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  )
                // ── Hide "Attach" option entirely in view-only mode ─────────
                else if (!isViewOnly)
                  InkWell(
                    onTap: () => _pickAndAttachFile(ctx.row, field),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add,
                              size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text('Attach',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                // ── Hide remove "X" in view-only mode ─────────────────────
                if (hasAttachment && !isViewOnly)
                  IconButton(
                    icon:
                        Icon(Icons.close, size: 16, color: Colors.red.shade400),
                    onPressed: () => _removeAttachment(ctx.row, field),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            );
          },
        );
      }

      // ── Date columns ─────────────────────────────────────────────────────
      if (title == 'Date') {
        return PlutoColumn(
          title: title,
          field: field,
          type: PlutoColumnType.date(),
          enableEditingMode: !isReadOnly,
          readOnly: isReadOnly,
          width: 150,
          backgroundColor: isReadOnly ? const Color(0xFFF1F5F9) : null,
          renderer: (ctx) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                ctx.cell.value == null || ctx.cell.value.toString().isEmpty
                    ? ''
                    : ctx.cell.value.toString(),
                style: const TextStyle(fontSize: 13),
              ),
            );
          },
        );
      }

      // ── Percent columns ───────────────────────────────────────────────────
      if (percentFields.contains(field)) {
        return PlutoColumn(
          title: title,
          field: field,
          type: PlutoColumnType.number(negative: false, format: '#,###.##'),
          enableEditingMode: !isReadOnly,
          readOnly: isReadOnly,
          width: 150,
          backgroundColor: isReadOnly ? const Color(0xFFF1F5F9) : null,
          formatter: (value) {
            if (value == null || value.toString().isEmpty) return '';
            final num = double.tryParse(value.toString()) ?? 0;
            if (num == 0) return '';
            return num == num.truncateToDouble() ? '${num.toInt()}%' : '$num%';
          },
          footerRenderer: field == 'col4'
              ? (rendererContext) {
                  return PlutoAggregateColumnFooter(
                    rendererContext: rendererContext,
                    type: PlutoAggregateColumnType.sum,
                    format: '#,###.##',
                    alignment: Alignment.centerRight,
                    titleSpanBuilder: (text) => [
                      TextSpan(
                        text: text.isEmpty ? '' : '$text%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                    ],
                  );
                }
              : null,
        );
      }

      // ── Remark-icon columns ────────────────────────────────────────────────
      if (remarkConfig.containsKey(field)) {
        final config = remarkConfig[field]!;

        return PlutoColumn(
          title: title,
          field: field,
          type: PlutoColumnType.number(),
          width: 170,
          // ── Force non-editable in view-only mode ──────────────────────────
          enableEditingMode: !isViewOnly,
          readOnly: isViewOnly,
          renderer: (ctx) {
            return Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: isViewOnly
                        ? null // ← disable tap-to-edit
                        : () {
                            stateManager!.setCurrentCell(ctx.cell, ctx.rowIdx);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              stateManager!.setEditing(true);
                            });
                          },
                    child: Text(
                      ctx.cell.value == null || ctx.cell.value == 0
                          ? ''
                          : formatIndianNumber(
                              (ctx.cell.value as num).toDouble()),
                    ),
                  ),
                ),
                // ── In view-only mode, icon still opens dialog but read-only ──
                InkWell(
                  onTap: () {
                    _showAmountRemarksDialog(
                      row: ctx.row,
                      amountField: field,
                      remarksField: config['remark']!,
                      title: config['title']!,
                    );
                  },
                  child: const Icon(Icons.edit_note,
                      color: Colors.green, size: 20),
                ),
              ],
            );
          },
          footerRenderer: (rendererContext) {
            return PlutoAggregateColumnFooter(
              rendererContext: rendererContext,
              type: PlutoAggregateColumnType.sum,
              format: '#,##,###',
              alignment: Alignment.centerRight,
              titleSpanBuilder: (text) => [
                TextSpan(
                  text: text.isEmpty ? '' : '₹ $text',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.indigo.shade900),
                ),
              ],
            );
          },
        );
      }

      // ── Number columns ────────────────────────────────────────────────────
      if (numberFields.contains(field)) {
        return PlutoColumn(
          title: title,
          field: field,
          type: PlutoColumnType.number(negative: true, format: '#,###'),
          enableEditingMode: !isReadOnly,
          readOnly: isReadOnly,
          width: 150,
          backgroundColor: isReadOnly ? const Color(0xFFF1F5F9) : null,
          renderer: isReadOnly
              ? (ctx) => Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      ctx.cell.value == 0 || ctx.cell.value == null
                          ? ''
                          : '₹ ${formatIndianNumber((ctx.cell.value as num).toDouble())}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  )
              : (ctx) => Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      ctx.cell.value == 0 || ctx.cell.value == null
                          ? ''
                          : formatIndianNumber(
                              (ctx.cell.value as num).toDouble()),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
          footerRenderer: (rendererContext) {
            return PlutoAggregateColumnFooter(
              rendererContext: rendererContext,
              type: PlutoAggregateColumnType.sum,
              format: '#,##,###',
              alignment: Alignment.centerRight,
              titleSpanBuilder: (text) => [
                TextSpan(
                  text: text.isEmpty ? '' : '₹ $text',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.indigo.shade900,
                  ),
                ),
              ],
            );
          },
        );
      }

      // ── Text columns ──────────────────────────────────────────────────────
      return PlutoColumn(
        title: title,
        field: field,
        type: PlutoColumnType.text(),
        enableEditingMode: !isReadOnly,
        readOnly: isReadOnly,
        width: 150,
        footerRenderer: title == 'Bill Description'
            ? (rendererContext) {
                return const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(
                      'TOTAL',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                );
              }
            : null,
      );
    });

    columns.addAll([
      PlutoColumn(
          title: 'SBNO',
          field: 'colSBNO',
          type: PlutoColumnType.number(),
          hide: true),
      PlutoColumn(
          title: 'SecAdvRemark',
          field: 'col6Remark',
          type: PlutoColumnType.text(),
          hide: true),
      PlutoColumn(
          title: 'MobAdvRemark',
          field: 'col7Remark',
          type: PlutoColumnType.text(),
          hide: true),
      PlutoColumn(
          title: 'OtherDedRemark',
          field: 'col17Remark',
          type: PlutoColumnType.text(),
          hide: true),
      PlutoColumn(
          title: 'WithheldRemark',
          field: 'col18Remark',
          type: PlutoColumnType.text(),
          hide: true),
      PlutoColumn(
          title: 'MobAdvRecoveryRemark',
          field: 'col19Remark',
          type: PlutoColumnType.text(),
          hide: true),
      PlutoColumn(
          title: 'WithheldReleaseRemark',
          field: 'col20Remark',
          type: PlutoColumnType.text(),
          hide: true),
      PlutoColumn(
          title: 'TotalDeductionRemark',
          field: 'col21Remark',
          type: PlutoColumnType.text(),
          hide: true),
      PlutoColumn(
          title: 'NetAmountReceivedRemark',
          field: 'col23Remark',
          type: PlutoColumnType.text(),
          hide: true),
      PlutoColumn(
          title: 'FileName',
          field: 'col26FileName',
          type: PlutoColumnType.text(),
          hide: true),
      PlutoColumn(
          title: 'FileBase64',
          field: 'col26Base64',
          type: PlutoColumnType.text(),
          hide: true),
      PlutoColumn(
          title: 'FileType',
          field: 'col26FileType',
          type: PlutoColumnType.text(),
          hide: true),
    ]);

    rows = [];
  }

  void addNewRow() {
    final Map<String, PlutoCell> cells = {};

    for (final col in columns) {
      switch (col.field) {
        case 'col1':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col2':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col3':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col4':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col5':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col6':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col7':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col8':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col9':
          cells[col.field] = PlutoCell(value: 18);
          break;
        case 'col10':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col11':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col12':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col13':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col14':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col15':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col16':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col17':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col18':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col19':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col20':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col21':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col22':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col23':
          cells[col.field] = PlutoCell(value: 0);
          break;
        case 'col24':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col25':
          cells[col.field] = PlutoCell(value: 0);
          break; // ✅ Outstanding

        case 'col26':
          cells[col.field] = PlutoCell(value: '');
          break; // ✅ Attachment

        // ✅ Hidden remark columns
        case 'col6Remark':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col7Remark':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col17Remark':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col18Remark':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col19Remark':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col20Remark':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col21Remark':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col23Remark':
          cells[col.field] = PlutoCell(value: '');
          break;

        // ✅ Hidden attachment columns — MUST be here
        case 'col25FileName':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col25Base64':
          cells[col.field] = PlutoCell(value: '');
          break;
        case 'col25FileType':
          cells[col.field] = PlutoCell(value: '');
          break;

        // ✅ Hidden SBNO column
        case 'colSBNO':
          cells[col.field] = PlutoCell(value: 0);
          break;

        default:
          cells[col.field] = PlutoCell(value: '');
          break;
      }
    }

    // ✅ ONLY use stateManager.appendRows — never PlutoRow directly
    if (stateManager != null) {
      final newRow = PlutoRow(cells: cells);
      stateManager!.appendRows([newRow]);
      setState(() => rows = stateManager!.rows);
    }
  }

  void _onGridChanged(PlutoGridOnChangedEvent event) {
    final row = event.row;
    _calculateRowTotals(row);
    if (!_isInitialLoadInProgress) {
      _dirtyRowKeys.add(row.key.toString());
    }
    setState(() {});
  }

  void _calculateRowTotals(PlutoRow row) {
    // ── Helper: get the real field name for a given column title ───────────
    String _fieldFor(String title) {
      return columns.firstWhere((c) => c.title == title).field;
    }

    double _cell(String field) {
      final v = row.cells[field]?.value;
      if (v == null) return 0;
      return double.tryParse(v.toString()) ?? 0;
    }

    void _set(String field, double value) {
      row.cells[field]?.value = value.roundToDouble();
    }

    /*// ── Step 1: Work Done ────────────────────────────────────────────────────
    final woValue = _woValueInclGst ?? 0.0;
    final perWork = _cell(_fPerWork);
    final workDone =
        woValue > 0 && perWork > 0 ? (woValue * perWork) / 100 : 0.0;
    _set(_fWorkDone, workDone);*/

    // ── Step 1: Work Done ────────────────────────────────────────────────────
    double workDone;
    if (_isInitialLoadInProgress) {
      // Initial load from API — trust the loaded WORKDONEAMNT value,
      // don't recompute it from _woValueInclGst/perWork.
      workDone = _cell(_fWorkDone);
    } else {
      final woValue = _woValueInclGst ?? 0.0;
      final perWork = _cell(_fPerWork);
      workDone = woValue > 0 && perWork > 0 ? (woValue * perWork) / 100 : 0.0;
      _set(_fWorkDone, workDone);
    }

    // ── Step 2: Taxable Value ─────────────────────────────────────────────────
    final secAdv = _cell(_fSecAdv);
    final mobAdv = _cell(_fMobAdv);
    final taxable = workDone + secAdv + mobAdv;
    _set(_fTaxable, taxable);

    // ── Step 3: TDS CGST & SGST = 1% of Work Done ────────────────────────────
    final tdsCGST = workDone * 0.01;
    final tdsSGST = workDone * 0.01;
    _set(_fTDSCGST, tdsCGST);
    _set(_fTDSSGST, tdsSGST);

    // ── Step 4: GST Amount & Total Bill Amount ────────────────────────────────
    final gstPct = _cell(_fGST);
    double totBill = 0.0;
    if (taxable > 0 && gstPct > 0) {
      final gstAmt = (taxable * gstPct / 100).roundToDouble();
      totBill = taxable.roundToDouble() + gstAmt;
      _set(_fTotBill, totBill);
    } else {
      _set(_fTotBill, 0.0);
    }

    // ── Step 5: Labour Cess = 1% of Total Bill Amount ────────────────────────
    final labCess = (totBill * 0.01).roundToDouble();
    _set(_fLabCess, labCess);

    // ── Step 6: TDS = 2% of Taxable Value ────────────────────────────────────
    final tds = taxable > 0 ? (taxable * 0.02).roundToDouble() : 0.0;
    _set(_fTDS, tds);

    // ── Step 7: Security Deposit = 5% of Taxable Value ───────────────────────
    final secDep = taxable > 0 ? (taxable * 0.05).roundToDouble() : 0.0;
    _set(_fSecDep, secDep);

    // ── Step 8: Total Deduction ───────────────────────────────────────────────
    final mobInt = _cell(_fMobInt);
    final othDed = _cell(_fOthDed);
    final withheld = _cell(_fWithheld);
    final mobAdvRec = _cell(_fMobAdvRec);
    final whRelease = _cell(_fWhRelease);

    final totDed = tds +
        tdsCGST +
        tdsSGST +
        secDep +
        labCess +
        mobInt +
        othDed +
        withheld +
        mobAdvRec -
        whRelease;
    _set(_fTotDed, totDed);

    // ── Step 9: Net Receivable ────────────────────────────────────────────────
    final netRec = totBill > 0 ? (totBill - totDed) : 0.0;
    _set(_fNetRec, netRec);

    // ── Step 10: Outstanding — written via title lookup, immune to col swaps ──
    final netAmtRecd = _cell(_fNetAmtRecd);
    final outstanding = netRec - netAmtRecd;
    final outstandingField = _fieldFor('Outstanding'); // ← always correct
    row.cells[outstandingField]?.value = outstanding.roundToDouble();

    // ── Force grid UI refresh ─────────────────────────────────────────────────
    stateManager?.notifyListeners();
  }

  void addMultipleRows(int count) {
    setState(() {
      for (int i = 0; i < count; i++) {
        rows.add(
          PlutoRow(
            cells: {
              for (int col = 1; col <= columns.length; col++)
                'col$col': PlutoCell(value: ''),
            },
          ),
        );
      }
    });
  }

  void deleteRow(int rowIndex) {
    setState(() {
      if (rows.isNotEmpty) {
        rows.removeAt(rowIndex);
      }
    });
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
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
            debugPrint(
                'Customer list loaded: ${customerList.length} customers');
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

  Widget _buildEmptyState({bool isViewOnly = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_chart,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No rows added yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (!isViewOnly)
              Text(
                'Click the + button in the app bar to add a row',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            const SizedBox(height: 24),
            if (!isViewOnly) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  if (selectedCustomerId == null || selectedProjectId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select Customer and Site first.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  addNewRow();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Row'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Future<void> selectDateForCell(
    PlutoRow row,
    PlutoColumn column,
  ) async {
    final String cellValue = row.cells[column.field]?.value?.toString() ?? '';

    DateTime? currentDate;

    if (cellValue.isNotEmpty) {
      currentDate = DateTime.tryParse(cellValue);
    }

    final DateTime pickedDate = await showDatePicker(
          context: context,
          initialDate: currentDate ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        ) ??
        (currentDate ?? DateTime.now());

    setState(() {
      row.cells[column.field]!.value =
          DateFormat('yyyy-MM-dd').format(pickedDate);
    });

    stateManager?.notifyListeners();
  }

  Future<void> fetchWorkOrderValue(int customerId, int projectId) async {
    setState(() {
      _isLoading = true;
      woValueController.text = 'Loading...';
    });

    try {
      final uri = ApiUtils.getUri('GetWorkOrderValue');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'CLIENTNAME': customerId.toString(),
              'PROJIDNAME': projectId.toString(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['Success'] == true && json['Data'] != null) {
          final double woValue =
              (json['Data']['WOVALUEINCLGST'] as num).toDouble();

          setState(() {
            _woValueInclGst = woValue;
            _woValueExclGst = woValue / 1.18;
            woValueController.text = '₹ ${formatIndianNumber(woValue)}';
          });
        } else {
          setState(() => woValueController.text = 'No data available');
        }
      } else {
        setState(() => woValueController.text = 'Error loading');
      }
    } catch (e) {
      setState(() => woValueController.text = 'Error');
      debugPrint('fetchWorkOrderValue error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAmountRemarksDialog({
    required PlutoRow row,
    required String amountField,
    required String remarksField,
    required String title,
  }) async {
    final amountController = TextEditingController(
      text: row.cells[amountField]?.value.toString() ?? '',
    );

    final remarksController = TextEditingController(
      text: row.cells[remarksField]?.value.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: remarksController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Remarks',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text("Save"),
              onPressed: () {
                row.cells[amountField]!.value =
                    double.tryParse(amountController.text) ?? 0;

                row.cells[remarksField]!.value = remarksController.text;

                _calculateRowTotals(row);

                stateManager?.notifyListeners();

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitAllRows() async {
    if (stateManager == null || stateManager!.rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No rows to submit'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ── Separate new rows vs existing rows ────────────────────────────────
    final List<PlutoRow> newRows = [];
    final List<PlutoRow> existingRows = [];

    for (final row in stateManager!.rows) {
      if (_existingRowKeys.contains(row.key.toString())) {
        existingRows.add(row); // fetched from API → UPDATE
      } else {
        newRows.add(row); // added by user → INSERT
      }
    }

    // ── Validate only new rows need Bill No + Date ─────────────────────────
    for (int i = 0; i < newRows.length; i++) {
      final row = newRows[i];
      final billNo = row.cells[_fBillNo]?.value?.toString().trim() ?? '';
      final billDate = row.cells[_fDate]?.value?.toString().trim() ?? '';

      if (billNo.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New Row ${i + 1}: Bill No is required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (billDate.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New Row ${i + 1}: Date is required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // ── Show loading ───────────────────────────────────────────────────────
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      int successCount = 0;
      int failCount = 0;
      List<String> failMessages = [];

      // ── INSERT new rows only ───────────────────────────────────────────
      for (final row in newRows) {
        final payload = _buildPayloadFromRow(row, isUpdate: false);
        final result = await saveSalesBilling(payload);

        if (result['Success'] == true) {
          successCount++;
          _existingRowKeys.add(row.key.toString()); // now it's existing
        } else {
          failCount++;
          failMessages.add(result['Message']?.toString() ?? 'Unknown error');
        }
      }

      // ── UPDATE only rows the user actually changed ─────────────────────
      final rowsToUpdate = existingRows
          .where((row) => _dirtyRowKeys.contains(row.key.toString()))
          .toList();

      for (final row in rowsToUpdate) {
        final payload = _buildPayloadFromRow(row, isUpdate: true);
        final result = await saveSalesBilling(payload);

        if (result['Success'] == true) {
          successCount++;
        } else {
          failCount++;
          failMessages.add(result['Message']?.toString() ?? 'Unknown error');
        }
      }

      // ── Clear dirty tracking after a successful submit ──────────────────
      if (failCount == 0) {
        _dirtyRowKeys.clear();
      }

      if (!mounted) return;
      Navigator.pop(context);

      if (failCount == 0) {
        // ✅ Detect if it was update or insert
        final isUpdateOnly = newRows.isEmpty && existingRows.isNotEmpty;
        final message = isUpdateOnly
            ? '$successCount ${successCount == 1 ? 'entry' : 'entries'} updated successfully'
            : '$successCount ${successCount == 1 ? 'entry' : 'entries'} saved successfully';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onDataSaved != null) widget.onDataSaved!();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$successCount saved, $failCount failed: ${failMessages.first}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> saveSalesBilling(
      Map<String, dynamic> requestBody) async {
    try {
      // ✅ Debug: confirm FILES actually made it into the outgoing payload
      debugPrint('📦 FILES in outgoing payload: ${requestBody['FILES']}');
      debugPrint('📦 Full request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        ApiUtils.getUri('SaveSalesBillinglist'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'Success': false,
          'Message': 'Server Error: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('Exception in saveSalesBilling: $e');
      return {
        'Success': false,
        'Message': e.toString(),
      };
    }
  }

  Map<String, dynamic> _buildPayloadFromRow(PlutoRow row,
      {bool isUpdate = false}) {
    // ── Helper to read cell value as double ──────────────────────────────
    double _num(String field) {
      final v = row.cells[field]?.value;
      if (v == null) return 0;
      return double.tryParse(v.toString()) ?? 0;
    }

    // ── Helper to read cell value as string ──────────────────────────────
    String _str(String field) {
      return row.cells[field]?.value?.toString().trim() ?? '';
    }

    // ── Helper to read remark field ───────────────────────────────────────
    String _remark(String field) {
      return row.cells[field]?.value?.toString().trim() ?? '';
    }

    // ── Read date ─────────────────────────────────────────────────────────
    String? _date(String field) {
      final v = _str(field);
      if (v.isEmpty) return null;
      try {
        // PlutoGrid date format is yyyy-MM-dd
        final parsed = DateTime.parse(v);
        return parsed.toIso8601String();
      } catch (_) {
        return v;
      }
    }

    // ── Build remarks strings from remark hidden columns ──────────────────
    final secAdvAmt = _num(_fSecAdv);
    final mobAdvAmt = _num(_fMobAdv);
    final othDedAmt = _num(_fOthDed);
    final whAmt = _num(_fWithheld);
    final mobAdvRecAmt = _num(_fMobAdvRec);
    final whRlAmt = _num(_fWhRelease);
    final netAmtRecd = _num(_fNetAmtRecd);

    final secAdvRemark = _remark('col6Remark');
    final mobAdvRemark = _remark('col7Remark');
    final othDedRemark = _remark('col17Remark');
    final whRemark = _remark('col18Remark');
    final mobAdvRecRemark = _remark('col19Remark');
    final whRlRemark = _remark('col20Remark');
    final netAmtRemark = _remark('col23Remark');

    // ── Pack remarks same format as existing _submitForm ─────────────────
    // Format: "amount$remark" — single entry per row
    final secAdvRemks = secAdvAmt > 0 ? '$secAdvRemark' : '';
    final mobAdvRemks = mobAdvAmt > 0 ? '$mobAdvRemark' : '';
    final othDedRemks = othDedAmt > 0 ? '$othDedRemark' : '';
    final whRemks = whAmt > 0 ? '$whRemark' : '';
    final mobAdvRecRemks = mobAdvRecAmt > 0 ? '$mobAdvRecRemark' : '';
    final whRlRemks = whRlAmt > 0 ? '$whRlRemark' : '';

    // ── Net Amount Received: "amount-date-remark" ─────────────────────────

    final netRecdRemarks = netAmtRecd > 0 ? '$netAmtRemark' : '';

    // ── % of work: strip % if present ────────────────────────────────────
    final perWork = _str(_fPerWork);
    final perWorkFormatted = perWork.endsWith('%') ? perWork : '$perWork%';

    // ── ATTACHMENT ────────────────────────────────────────────────────────
    final base64Cell = row.cells['col26Base64']?.value?.toString().trim() ?? '';

    List<Map<String, dynamic>> files = [];

    if (base64Cell.isNotEmpty) {
      try {
        // ✅ Parse JSON list stored by _pickAndAttachFile
        final decoded = jsonDecode(base64Cell) as List<dynamic>;
        files = decoded
            .map((e) => {
                  'FILENAME': e['FILENAME']?.toString() ?? '',
                  'FILEDATA': e['FILEDATA']?.toString() ?? '',
                })
            .toList();
      } catch (_) {
        // ✅ Fallback: single file old format
        final fileName =
            row.cells['col25FileName']?.value?.toString().trim() ?? '';
        if (fileName.isNotEmpty && base64Cell.isNotEmpty) {
          files = [
            {'FILENAME': fileName, 'FILEDATA': base64Cell}
          ];
        }
      }
    }

    // ✅ Get SBNO — 0 for new, real value for update
    final sbno = isUpdate ? (_num('colSBNO').toInt()) : 0;

    return {
      // ── Core ──────────────────────────────────────────────────────────
      'SBNO': sbno,
      'CUSID': selectedCustomerId,
      'PROJID': selectedProjectId,

      'BILLNO': _str(_fBillNo),
      'BILLDATE': _date(_fDate),
      'BILLDESC': _str(_fBillDesc),
      'PEROFWORK': perWorkFormatted,
      'WORKDONEAMNT': _num(_fWorkDone),

      // ── Secure Advance ────────────────────────────────────────────────
      'SECADVAMNT': secAdvAmt.toInt(),
      'SECADVREMKS': secAdvRemks,

      // ── Mob Advance ───────────────────────────────────────────────────
      'MOBADVAMNT': mobAdvAmt.toInt(),
      'MOBADVREMKS': mobAdvRemks,

      // ── Bill Amounts ──────────────────────────────────────────────────
      'BILLAMNT': _num(_fTaxable).toInt(),
      'GSTPER': _num(_fGST),
      'GSTAMNT': ((_num(_fTaxable) * _num(_fGST)) / 100).round(),
      'TOTBILLAMNT': _num(_fTotBill).toInt(),

      // ── TDS ───────────────────────────────────────────────────────────
      'TDSAMNT': _num(_fTDS).toInt(),
      'TDSCGSTAMNT': _num(_fTDSCGST).toInt(),
      'TDSSGSTAMNT': _num(_fTDSSGST).toInt(),

      // ── Deductions ────────────────────────────────────────────────────
      'SECDEPAMNT': _num(_fSecDep).toInt(),
      'LABCESSAMNT': _num(_fLabCess).toInt(),
      'MOBINTAMNT': _num(_fMobInt).toInt(),

      'OTHDEDAMNT': othDedAmt.toInt(),
      'OTHDEDREMKS': othDedRemks,

      'WHAMNT': whAmt.toInt(),
      'WHREMKS': whRemks,

      'MOBADVRECAMNT': mobAdvRecAmt.toInt(),
      'MOBADVRECREMKS': mobAdvRecRemks,

      'WHRLSEAMNT': whRlAmt.toInt(),
      'WHRLSEREMKS': whRlRemks,

      'TOTDEDAMNT': _num(_fTotDed).toInt(),

      // ── Net & Outstanding ─────────────────────────────────────────────
      'NETRECAMNT': _num(_fNetRec).toInt(),
      'NETRECDAMNT': netAmtRecd.toInt(),
      'NETRECDDT': _date(_fRecDate),
      'NETRECDREMKS': netRecdRemarks,
      'OUTSTANDAMNT': () {
        final outstandingField =
            columns.firstWhere((c) => c.title == 'Outstanding').field;
        return _num(outstandingField).toInt();
      }(),
      'STAGEIDNAME': _str('colStage'),

      // ✅ This is what saves the file on server
      'FILES': files, // ✅ now sends multiple files
      'REMOVEDFILES': '',

      // ── Audit ─────────────────────────────────────────────────────────
      'ADDUSER': empCode,
    };
  }

  Future<void> _pickAndAttachFile(PlutoRow row, String field) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'dwg'],
      );

      if (result == null || result.files.isEmpty) return;

      List<Map<String, String>> fileList = [];
      List<String> fileNames = [];

      for (final pickedFile in result.files) {
        final file = File(pickedFile.path!);
        final fileName = pickedFile.name;
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);

        fileList.add({
          'FILENAME': fileName,
          'FILEDATA': base64String,
        });
        fileNames.add(fileName);
      }

      final displayNames = fileNames.join(', ');

      // ✅ Visible cell — safe via changeCellValue (not readOnly typically blocks this if column IS readOnly)
      if (row.cells[field] != null) {
        stateManager?.changeCellValue(
          row.cells[field]!,
          displayNames,
          notify: true,
        );
      } else {
        debugPrint('⚠️ Visible cell "$field" not found on row!');
      }

      // ✅ Hidden cell — file name list
      if (row.cells['${field}FileName'] != null) {
        row.cells['${field}FileName']!.value = fileNames.join(',');
      }

      // ✅ Hidden cell — base64 JSON payload
      if (row.cells['${field}Base64'] != null) {
        row.cells['${field}Base64']!.value = jsonEncode(fileList);
        _dirtyRowKeys.add(row.key.toString());
        // ✅ Confirm it actually stuck
        debugPrint(
            '✅ Verifying stored value: ${row.cells['${field}Base64']!.value}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${fileList.length} file(s) attached successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error attaching file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAttachmentDialog(PlutoRow row, String field) {
    final fileName = row.cells[field]?.value?.toString() ?? '';
    final base64Data = row.cells['${field}Base64']?.value?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.attach_file, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              'File: $fileName',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Size: ${(base64Data.length * 0.75).toStringAsFixed(0)} bytes',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);

              final sbNo = int.tryParse(
                    row.cells['SBNO']?.value?.toString() ?? '',
                  ) ??
                  0;

              final fileNameValue = row.cells['col26']?.value?.toString();

              await AttachmentDownloadService.downloadFiles(
                context: context,
                config: DownloadConfigs.billing,
                recordId: sbNo,
                providedFiles:
                    (fileNameValue != null && fileNameValue.isNotEmpty)
                        ? {'SBFNAME': fileNameValue}
                        : null,
              );
            },
            icon: const Icon(Icons.download),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }

  void _removeAttachment(PlutoRow row, String field) {
    setState(() {
      row.cells[field]!.value = '';
      row.cells['${field}FileName']!.value = '';
      row.cells['${field}Base64']!.value = '';
    });
    stateManager?.notifyListeners();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Attachment removed'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _fetchBillingSummaryForProject(int projectId) async {
    try {
      final uri = ApiUtils.getUri('GetSalesBillingSummary');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['Success'] == true && json['Data'] != null) {
          final List<dynamic> list = json['Data'];

          final match = list.firstWhere(
            (e) => e['PROJECTID'] == projectId,
            orElse: () => null,
          );

          if (match != null) {
            setState(() {
              _billingSummary = SalesBillingSummaryModel.fromJson(match);
            });
            debugPrint(
                '✅ Project Code fetched: ${_billingSummary?.projectCode}');
          } else {
            debugPrint(
                '⚠️ No matching summary found for projectId: $projectId');
          }
        }
      }
    } catch (e) {
      debugPrint('_fetchBillingSummaryForProject error: $e');
    }
  }

  Future<void> _downloadBillingData() async {
    if (selectedCustomerId == null || selectedProjectId == null) return;

    setState(() => _isLoadingBilling = true);

    try {
      final uri = ApiUtils.getUri('ViewSalesBillinglist');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'CUSID': selectedCustomerId,
          'PROJID': selectedProjectId,
        }),
      );
      final totalWorkDone = _billingList.fold<double>(
        0.0,
        (sum, e) => sum + (e.workdoneamnt ?? 0),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true) {
          final List<dynamic> list = data['BillingList'] ?? [];
          final entries =
              list.map((e) => SalesBillingModel.fromJson(e)).toList();

          if (entries.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No billing data available to download.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          // ── Fetch Stages from separate endpoint ────────────────────────
          List<StageModel> stageList = [];
          try {
            final stagesUri = ApiUtils.getUri('ViewStagesList');
            final stagesResponse = await http.post(
              stagesUri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'CUSID': selectedCustomerId,
                'PROJID': selectedProjectId,
              }),
            );
            if (stagesResponse.statusCode == 200) {
              final stagesData = jsonDecode(stagesResponse.body);
              if (stagesData['Success'] == true) {
                final List<dynamic> stageListRaw =
                    stagesData['StageList'] ?? [];
                stageList =
                    stageListRaw.map((e) => StageModel.fromJson(e)).toList();
              }
            }
          } catch (e) {
            debugPrint('ViewStagesList error: $e');
            // Non-fatal — PDF still generates without the stages section
          }

          if (entries.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No billing data available to download.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }

          // ── Build PDF ──────────────────────────────────────────────────
          final pdf = pw.Document();

          final headers = [
            'Bill No',
            'Date',
            'Description',
            '% Work',
            'WD Value',
            'Sec Adv',
            'Mob Adv',
            'Tax Value',
            'GST %',
            'Total Bill',
            'TDS',
            'TDS CGST',
            'TDS SGST',
            'Sec Dep',
            'Lab Cess',
            'Mob Int',
            'Oth Ded',
            'Withheld',
            'Mob Adv Rec',
            'WH Release',
            'Tot Ded',
            'Net Rec',
            'Net Amt Recd',
            'Recd Date',
            'Outstanding',
          ];

          final tableRows = entries.map((e) {
            return [
              e.billno ?? '',
              e.billdate != null
                  ? DateFormat('dd-MM-yyyy').format(e.billdate!)
                  : '',
              e.billdesc ?? '',
              e.perofwork ?? '0',
              formatIndianNumber((e.workdoneamnt ?? 0).toDouble()),
              formatIndianNumber((e.secadvamnt ?? 0).toDouble()),
              formatIndianNumber((e.mobadvamnt ?? 0).toDouble()),
              formatIndianNumber((e.billamnt ?? 0).toDouble()),
              '${(e.gstper ?? 18).toStringAsFixed(0)}%',
              formatIndianNumber((e.billtotamnt ?? 0).toDouble()),
              formatIndianNumber((e.tdsamnt ?? 0).toDouble()),
              formatIndianNumber((e.tdscgstamnt ?? 0).toDouble()),
              formatIndianNumber((e.tdssgstamnt ?? 0).toDouble()),
              formatIndianNumber((e.secdepamnt ?? 0).toDouble()),
              formatIndianNumber((e.labcessamnt ?? 0).toDouble()),
              formatIndianNumber((e.mobintamnt ?? 0).toDouble()),
              formatIndianNumber((e.dedamnt ?? 0).toDouble()),
              formatIndianNumber((e.whamnt ?? 0).toDouble()),
              formatIndianNumber((e.mobadvrecamnt ?? 0).toDouble()),
              formatIndianNumber((e.whrlseamnt ?? 0).toDouble()),
              formatIndianNumber((e.totdedamnt ?? 0).toDouble()),
              formatIndianNumber((e.netrecamnt ?? 0).toDouble()),
              formatIndianNumber((e.recamnt ?? 0).toDouble()),
              e.netrecddt != null
                  ? DateFormat('dd-MM-yyyy').format(e.netrecddt!)
                  : '',
              formatIndianNumber((e.outstandamnt ?? 0).toDouble()),
            ];
          }).toList();

          // ── Compute totals ──────────────────────────────────────────────────
          double sumWorkDone = 0, sumSecAdv = 0, sumMobAdv = 0, sumTaxable = 0;
          double sumTotBill = 0, sumTDS = 0, sumCGST = 0, sumSGST = 0;
          double sumSecDep = 0, sumLabCess = 0, sumMobInt = 0, sumOthDed = 0;
          double sumWithheld = 0,
              sumMobAdvRec = 0,
              sumWhRelease = 0,
              sumTotDed = 0;
          double sumNetRec = 0, sumNetAmtRecd = 0, sumOutstanding = 0;
          double sumPerWork = 0;

          for (final e in entries) {
            sumPerWork += double.tryParse(
                    (e.perofwork ?? '0').replaceAll('%', '').trim()) ??
                0;
            sumWorkDone += (e.workdoneamnt ?? 0).toDouble();
            sumSecAdv += (e.secadvamnt ?? 0).toDouble();
            sumMobAdv += (e.mobadvamnt ?? 0).toDouble();
            sumTaxable += (e.billamnt ?? 0).toDouble();
            sumTotBill += (e.billtotamnt ?? 0).toDouble();
            sumTDS += (e.tdsamnt ?? 0).toDouble();
            sumCGST += (e.tdscgstamnt ?? 0).toDouble();
            sumSGST += (e.tdssgstamnt ?? 0).toDouble();
            sumSecDep += (e.secdepamnt ?? 0).toDouble();
            sumLabCess += (e.labcessamnt ?? 0).toDouble();
            sumMobInt += (e.mobintamnt ?? 0).toDouble();
            sumOthDed += (e.dedamnt ?? 0).toDouble();
            sumWithheld += (e.whamnt ?? 0).toDouble();
            sumMobAdvRec += (e.mobadvrecamnt ?? 0).toDouble();
            sumWhRelease += (e.whrlseamnt ?? 0).toDouble();
            sumTotDed += (e.totdedamnt ?? 0).toDouble();
            sumNetRec += (e.netrecamnt ?? 0).toDouble();
            sumNetAmtRecd += (e.recamnt ?? 0).toDouble();
            sumOutstanding += (e.outstandamnt ?? 0).toDouble();
          }

          // ── Append total row ───────────────────────────────────────────────
          tableRows.add([
            'TOTAL',
            '',
            '',
            '${sumPerWork.toStringAsFixed(0)}%',
            formatIndianNumber(sumWorkDone),
            formatIndianNumber(sumSecAdv),
            formatIndianNumber(sumMobAdv),
            formatIndianNumber(sumTaxable),
            '',
            formatIndianNumber(sumTotBill),
            formatIndianNumber(sumTDS),
            formatIndianNumber(sumCGST),
            formatIndianNumber(sumSGST),
            formatIndianNumber(sumSecDep),
            formatIndianNumber(sumLabCess),
            formatIndianNumber(sumMobInt),
            formatIndianNumber(sumOthDed),
            formatIndianNumber(sumWithheld),
            formatIndianNumber(sumMobAdvRec),
            formatIndianNumber(sumWhRelease),
            formatIndianNumber(sumTotDed),
            formatIndianNumber(sumNetRec),
            formatIndianNumber(sumNetAmtRecd),
            '',
            formatIndianNumber(sumOutstanding),
          ]);

          pdf.addPage(
            pw.MultiPage(
              pageFormat: PdfPageFormat(
                1600,
                PdfPageFormat.a3.height,
                marginLeft: 10,
                marginRight: 10,
                marginTop: 5, // Reduced top margin
                marginBottom: 5,
              ).landscape,
              header: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'Billing Report',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      border:
                          pw.Border.all(color: PdfColors.grey400, width: 0.8),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    padding: const pw.EdgeInsets.all(10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Customer: ${customerController.text}'),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Project: ${siteController.text}'),
                            pw.Text(
                              'Proj. Code: ${_billingSummary?.projectCode ?? '-'}',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 10),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Wrap(spacing: 10, runSpacing: 5, children: [
                          pw.Text(
                            'Work Order Value: Rs ${formatIndianNumber(_woValueExclGst ?? 0)} (Excl. GST 18%)',
                            style: pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey700),
                          ),
                          pw.Text(
                            'Rs ${formatIndianNumber(_woValueInclGst ?? 0)} (Incl. GST 18%)',
                            style: pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey700),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                ],
              ),
              // ── NEW: page numbers at bottom ───────────────────────────────
              footer: (context) => pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(top: 10),
                child: pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ),
              build: (context) => [
                pw.Table(
                  border:
                      pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(45),
                    1: const pw.FixedColumnWidth(45),
                    2: const pw.FixedColumnWidth(55),
                    3: const pw.FixedColumnWidth(35),
                    4: const pw.FixedColumnWidth(60),
                    5: const pw.FixedColumnWidth(55),
                    6: const pw.FixedColumnWidth(55),
                    7: const pw.FixedColumnWidth(60),
                    8: const pw.FixedColumnWidth(30),
                    9: const pw.FixedColumnWidth(60),
                    10: const pw.FixedColumnWidth(50),
                    11: const pw.FixedColumnWidth(50),
                    12: const pw.FixedColumnWidth(50),
                    13: const pw.FixedColumnWidth(50),
                    14: const pw.FixedColumnWidth(50),
                    15: const pw.FixedColumnWidth(50),
                    16: const pw.FixedColumnWidth(50),
                    17: const pw.FixedColumnWidth(50),
                    18: const pw.FixedColumnWidth(55),
                    19: const pw.FixedColumnWidth(50),
                    20: const pw.FixedColumnWidth(55),
                    21: const pw.FixedColumnWidth(60),
                    22: const pw.FixedColumnWidth(60),
                    23: const pw.FixedColumnWidth(45),
                    24: const pw.FixedColumnWidth(60),
                  },
                  children: [
                    // ── Header row — explicitly centered ──────────────────────────
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey300),
                      children: headers.map((h) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(
                            h,
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        );
                      }).toList(),
                    ),
                    // ── Data rows ────────────────────────────────────────────────
                    ...tableRows.asMap().entries.map((entry) {
                      final rowIndex = entry.key;
                      final row = entry.value;
                      final isTotalRow = rowIndex == tableRows.length - 1;

                      // Alignment per column index, matching your earlier cellAlignments map
                      final alignments = <int, pw.TextAlign>{
                        0: pw.TextAlign.left,
                        1: pw.TextAlign.left,
                        2: pw.TextAlign.left,
                        3: pw.TextAlign.right,
                        4: pw.TextAlign.right,
                        5: pw.TextAlign.right,
                        6: pw.TextAlign.right,
                        7: pw.TextAlign.right,
                        8: pw.TextAlign.right,
                        9: pw.TextAlign.right,
                        10: pw.TextAlign.right,
                        11: pw.TextAlign.right,
                        12: pw.TextAlign.right,
                        13: pw.TextAlign.right,
                        14: pw.TextAlign.right,
                        15: pw.TextAlign.right,
                        16: pw.TextAlign.right,
                        17: pw.TextAlign.right,
                        18: pw.TextAlign.right,
                        19: pw.TextAlign.right,
                        20: pw.TextAlign.right,
                        21: pw.TextAlign.right,
                        22: pw.TextAlign.right,
                        23: pw.TextAlign.left,
                        24: pw.TextAlign.right,
                      };

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color:
                              isTotalRow ? PdfColors.grey300 : PdfColors.white,
                        ),
                        children: row.asMap().entries.map((cellEntry) {
                          final colIndex = cellEntry.key;
                          final value = cellEntry.value;
                          return pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              value,
                              style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: isTotalRow
                                    ? pw.FontWeight.bold
                                    : pw.FontWeight.normal,
                              ),
                              textAlign:
                                  alignments[colIndex] ?? pw.TextAlign.left,
                            ),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ],
                ),
                // ── Stages section — outside/below the table ─────────────────────
                if (stageList.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Stages',
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 5),
                  ...stageList.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Text(
                        '${idx + 1}. ${item.stageName ?? ''} (${item.stagePer ?? '0'})',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          );

          // ── Save PDF to Downloads folder ─────────────────────────────────
          final directory = await getDownloadsDirectory();
          if (directory == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not access Downloads folder.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          final fileName =
              'BillingData_${selectedCustomerId}_${selectedProjectId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(await pdf.save());

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved: $fileName'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => OpenFile.open(filePath),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to fetch billing data.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('_downloadBillingData error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingBilling = false);
    }
  }

  Future<void> _showStagesDialog() async {
    if (selectedCustomerId == null || selectedProjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a customer and project first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingStages = true);

    List<StageModel> stageList = [];
    String? errorMsg;

    try {
      final stagesUri = ApiUtils.getUri('ViewStagesList');
      final stagesResponse = await http.post(
        stagesUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'CUSID': selectedCustomerId,
          'PROJID': selectedProjectId,
        }),
      );

      if (stagesResponse.statusCode == 200) {
        final stagesData = jsonDecode(stagesResponse.body);
        if (stagesData['Success'] == true) {
          final List<dynamic> stageListRaw = stagesData['StageList'] ?? [];
          stageList = stageListRaw.map((e) => StageModel.fromJson(e)).toList();
        } else {
          errorMsg = stagesData['Message'] ?? 'Failed to fetch stages.';
        }
      } else {
        errorMsg = 'Server error (${stagesResponse.statusCode})';
      }
    } catch (e) {
      errorMsg = 'Error fetching stages: $e';
    } finally {
      setState(() => _isLoadingStages = false);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stages'),
        content: SizedBox(
          //width: double.maxFinite,
          width: 500,
          child: errorMsg != null
              ? Text(errorMsg, style: const TextStyle(color: Colors.red))
              : stageList.isEmpty
                  ? const Text('No stages found for this project.')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: stageList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = stageList[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          title: Text(item.stageName ?? '-'),
                          trailing: Text('${item.stagePer ?? '0'}%'),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBillingRows({
    required Uri endpoint,
    required Map<String, dynamic> requestBody,
    required String responseListKey, // 'BillingList' or 'Data'
  }) async {
    setState(() => _isLoadingBilling = true);
    try {
      final response = await http.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          final List<dynamic> list = data[responseListKey] ?? [];
          final entries =
              list.map((e) => SalesBillingModel.fromJson(e)).toList();
          final loadedRows = entries.map(_buildBillingRow).toList();

          setState(() {
            _billingList = entries;
            rows = loadedRows;
            _existingRowKeys
              ..clear()
              ..addAll(loadedRows.map((r) => r.key.toString()));
          });

          _appendRowsSafely(loadedRows);
        }
      }
    } catch (e) {
      debugPrint('_loadBillingRows error: $e');
    } finally {
      setState(() => _isLoadingBilling = false);
    }
  }

  PlutoRow _buildBillingRow(SalesBillingModel e) {
    return PlutoRow(cells: {
      _fBillNo: PlutoCell(value: e.billno ?? ''),
      _fBillDesc: PlutoCell(value: e.billdesc ?? ''),
      _fDate: PlutoCell(
          value: e.billdate != null
              ? DateFormat('yyyy-MM-dd').format(e.billdate!)
              : ''),
      _fRecDate: PlutoCell(
          value: e.netrecddt != null
              ? DateFormat('yyyy-MM-dd').format(e.netrecddt!)
              : ''),
      _fPerWork: PlutoCell(
          value: double.tryParse(
                  (e.perofwork ?? '0').replaceAll('%', '').trim()) ??
              0.0),
      _fWorkDone: PlutoCell(value: (e.workdoneamnt ?? 0).toDouble()),
      _fSecAdv: PlutoCell(value: (e.secadvamnt ?? 0).toDouble()),
      _fMobAdv: PlutoCell(value: (e.mobadvamnt ?? 0).toDouble()),
      _fTaxable: PlutoCell(value: (e.billamnt ?? 0).toDouble()),
      _fGST: PlutoCell(value: (e.gstper ?? 18).toDouble()),
      _fTotBill: PlutoCell(value: (e.billtotamnt ?? 0).toDouble()),
      _fTDS: PlutoCell(value: (e.tdsamnt ?? 0).toDouble()),
      _fTDSCGST: PlutoCell(value: (e.tdscgstamnt ?? 0).toDouble()),
      _fTDSSGST: PlutoCell(value: (e.tdssgstamnt ?? 0).toDouble()),
      _fSecDep: PlutoCell(value: (e.secdepamnt ?? 0).toDouble()),
      _fLabCess: PlutoCell(value: (e.labcessamnt ?? 0).toDouble()),
      _fMobInt: PlutoCell(value: (e.mobintamnt ?? 0).toDouble()),
      _fOthDed: PlutoCell(value: (e.dedamnt ?? 0).toDouble()),
      _fWithheld: PlutoCell(value: (e.whamnt ?? 0).toDouble()),
      _fMobAdvRec: PlutoCell(value: (e.mobadvrecamnt ?? 0).toDouble()),
      _fWhRelease: PlutoCell(value: (e.whrlseamnt ?? 0).toDouble()),
      _fTotDed: PlutoCell(value: (e.totdedamnt ?? 0).toDouble()),
      _fNetRec: PlutoCell(value: (e.netrecamnt ?? 0).toDouble()),
      _fNetAmtRecd: PlutoCell(value: (e.recamnt ?? 0).toDouble()),
      _fOutstanding: PlutoCell(value: (e.outstandamnt ?? 0).toDouble()),
      _fAttachment: PlutoCell(value: e.sbfname ?? ''),
      'col26FileName': PlutoCell(value: e.sbfname ?? ''),
      'col26Base64': PlutoCell(value: ''),
      'col26FileType': PlutoCell(value: e.sbftype ?? ''),
      'colSBNO': PlutoCell(value: e.sbno ?? 0),
      'col6Remark': PlutoCell(value: e.secadvremks ?? ''),
      'col7Remark': PlutoCell(value: e.mobadvremks ?? ''),
      'col17Remark': PlutoCell(value: e.othdedremks ?? ''),
      'col18Remark': PlutoCell(value: e.whremks ?? ''),
      'col19Remark': PlutoCell(value: e.mobadvrecremks ?? ''),
      'col20Remark': PlutoCell(value: e.whrlseremks ?? ''),
      'col23Remark': PlutoCell(value: e.netrecdremks ?? ''),
      'colStage': PlutoCell(value: e.stagename ?? ''),
    });
  }

  void _appendRowsSafely(List<PlutoRow> newRows) {
    if (stateManager == null) return;
    _isInitialLoadInProgress = true;
    stateManager!.removeAllRows();
    stateManager!.appendRows(newRows);
    for (final row in stateManager!.rows) {
      _calculateRowTotals(row);
    }
    _isInitialLoadInProgress = false;
  }
}
