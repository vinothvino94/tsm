import 'dart:convert';
import 'dart:io';

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
import 'package:tsm/screens/sales/view_billing_screen.dart';

import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';
import 'billing_entry_screen.dart';

class DataEntryScreen extends StatefulWidget {
  final bool isSuperAdmin;
  final bool? isReadOnly;
  final VoidCallback? onDataSaved;

  const DataEntryScreen({
    super.key,
    this.isSuperAdmin = false,
    this.isReadOnly = false,
    this.onDataSaved,
  });

  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen> {
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
  static const String _fAttachment = 'col25';
  static const String _fOutstanding = 'col26';
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

  List<SalesBillingModel> _billingList = [];
  bool _isLoadingBilling = false;

  @override
  void initState() {
    super.initState();
    initializeGrid();
    loadCustomers();
    _loadUserDetails();
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
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'View Billing List',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewBillingScreen(
                    isSuperAdmin: widget.isSuperAdmin,
                  ),
                ),
              );
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
                              }
                              setState(() {
                                selectedProjectId = selection.projectId;
                                _billingList = [];
                              });
                              // ← clear grid safely after frame, then load
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                stateManager?.removeAllRows();
                                setState(() => rows = []);
                                _fetchAndLoadBillingEntries();
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
            Row(children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WO Value:',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Text(
                            woValueController.text.isEmpty
                                ? 'Select project to fetch'
                                : woValueController.text,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: woValueController.text.contains('Error') ||
                                      woValueController.text ==
                                          'No data available'
                                  ? Colors.red
                                  : woValueController.text.isEmpty
                                      ? Colors.grey.shade500
                                      : Colors.blue.shade700,
                            ),
                          ),
                          if (woValueController.text.isNotEmpty &&
                              woValueController.text != 'No data available' &&
                              woValueController.text != 'Error loading' &&
                              woValueController.text != 'Error' &&
                              woValueController.text != 'Loading...')
                            IconButton(
                              icon: const Icon(Icons.info_outline, size: 18),
                              onPressed: () {
                                if (_woValueInclGst != null) {
                                  _showWODetailsDialog(context);
                                }
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'View details',
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ]),
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
                    stateManager!.setShowColumnFilter(true);
                    // ← if rows were added before onLoaded fired, sync them
                    if (rows.isNotEmpty && stateManager!.rows.isEmpty) {
                      stateManager!.appendRows(rows);
                    }
                  },
                  onRowDoubleTap: (PlutoGridOnRowDoubleTapEvent event) {
                    debugPrint('Row double tapped');
                  },
                  onChanged: _onGridChanged,
                  onSelected: (PlutoGridOnSelectedEvent event) async {
                    if (event.cell != null &&
                        event.cell!.column.title == 'Date') {
                      await selectDateForCell(event.row!, event.cell!.column);
                    }
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
                    child: const Padding(
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

  void initializeGrid() {
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
      'Attachment',
      'Outstanding'
    ];

    // ── Read-only (auto-calculated) columns ──────────────────────────────────
    final Set<String> readOnlyFields = {
      'col5', // Work Done value
      'col8', // Taxable value
      'col10', // Total bill amount
      'col11', // TDS
      'col12', // TDS CGST
      'col13', // TDS SGST
      'col14', // Security deposit
      'col15', // Labour Cess
      'col21', // Total Deduction
      'col22', // Net receivable
      'col25', // Outstanding
    };

    // ── Percent columns ───────────────────────────────────────────────────────
    final Set<String> percentFields = {
      'col4',
      'col9',
    };

    // ── Number columns ────────────────────────────────────────────────────────
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
    };

    columns = List.generate(columnNames.length, (index) {
      final title = columnNames[index];
      final field = 'col${index + 1}';
      final isReadOnly = readOnlyFields.contains(field);
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
            final hasAttachment =
                ctx.cell.value != null && ctx.cell.value.toString().isNotEmpty;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasAttachment)
                  InkWell(
                    onTap: () {
                      _showAttachmentDialog(ctx.row, field);
                    },
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
                          Text(
                            'View',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: () {
                      _pickAndAttachFile(ctx.row, field);
                    },
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
                          Text(
                            'Attach',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (hasAttachment)
                  IconButton(
                    icon:
                        Icon(Icons.close, size: 16, color: Colors.red.shade400),
                    onPressed: () {
                      _removeAttachment(ctx.row, field);
                    },
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
        );
      }

      // ── Percent columns ───────────────────────────────────────────────────
      if (percentFields.contains(field)) {
        return PlutoColumn(
          title: title,
          field: field,
          type: PlutoColumnType.number(
            negative: false,
            format: '#,###.##',
          ),
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
        );
      }

      // ── Number columns ────────────────────────────────────────────────────

      if (remarkConfig.containsKey(field)) {
        final config = remarkConfig[field]!;

        return PlutoColumn(
          title: title,
          field: field,
          type: PlutoColumnType.number(),
          width: 170,
          renderer: (ctx) {
            return Row(
              children: [
                Expanded(
                  child: Text(
                    ctx.cell.value == null || ctx.cell.value == 0
                        ? ''
                        : formatIndianNumber(
                            (ctx.cell.value as num).toDouble(),
                          ),
                  ),
                ),
                InkWell(
                  child: const Icon(
                    Icons.edit_note,
                    color: Colors.green,
                    size: 20,
                  ),
                  onTap: () {
                    _showAmountRemarksDialog(
                      row: ctx.row,
                      amountField: field,
                      remarksField: config['remark']!,
                      title: config['title']!,
                    );
                  },
                ),
              ],
            );
          },
        );
      }
      if (numberFields.contains(field)) {
        return PlutoColumn(
          title: title,
          field: field,
          type: PlutoColumnType.number(
            negative: true,
            format: '#,###',
          ),
          enableEditingMode: !isReadOnly,
          readOnly: isReadOnly,
          width: 150,
          backgroundColor: isReadOnly
              ? const Color(0xFFF1F5F9) // ← grey tint for auto-calc fields
              : null,
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
              : null,
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
      );
    });

    columns.addAll([
      PlutoColumn(
        title: 'SecAdvRemark',
        field: 'col6Remark',
        type: PlutoColumnType.text(),
        hide: true,
      ),
      PlutoColumn(
        title: 'MobAdvRemark',
        field: 'col7Remark',
        type: PlutoColumnType.text(),
        hide: true,
      ),
      PlutoColumn(
        title: 'OtherDedRemark',
        field: 'col17Remark',
        type: PlutoColumnType.text(),
        hide: true,
      ),
      PlutoColumn(
        title: 'WithheldRemark',
        field: 'col18Remark',
        type: PlutoColumnType.text(),
        hide: true,
      ),
      PlutoColumn(
        title: 'MobAdvRecoveryRemark',
        field: 'col19Remark',
        type: PlutoColumnType.text(),
        hide: true,
      ),
      PlutoColumn(
        title: 'WithheldReleaseRemark',
        field: 'col20Remark',
        type: PlutoColumnType.text(),
        hide: true,
      ),
      PlutoColumn(
        title: 'TotalDeductionRemark',
        field: 'col21Remark',
        type: PlutoColumnType.text(),
        hide: true,
      ),
      PlutoColumn(
        title: 'NetAmountReceivedRemark',
        field: 'col23Remark',
        type: PlutoColumnType.text(),
        hide: true,
      ),
      // ── Add file columns too ───────────────────────────────────────────
      PlutoColumn(
        title: 'FileName',
        field: 'col25FileName',
        type: PlutoColumnType.text(),
        hide: true,
      ),
      PlutoColumn(
        title: 'FileBase64',
        field: 'col25Base64',
        type: PlutoColumnType.text(),
        hide: true,
      ),
    ]);

    rows = [];
  }

  void addNewRow() {
    // ── Build cell map with ONLY fields that exist in columns ─────────────
    final Map<String, PlutoCell> cells = {};

    // ← iterate columns and assign default values per field
    for (final col in columns) {
      switch (col.field) {
        case 'col1':
          cells[col.field] = PlutoCell(value: '');
          break; // Bill No
        case 'col2':
          cells[col.field] = PlutoCell(value: '');
          break; // Date
        case 'col3':
          cells[col.field] = PlutoCell(value: '');
          break; // Bill Desc
        case 'col4':
          cells[col.field] = PlutoCell(value: 0);
          break; // % of work
        case 'col5':
          cells[col.field] = PlutoCell(value: 0);
          break; // Work Done
        case 'col6':
          cells[col.field] = PlutoCell(value: 0);
          break; // Sec Adv
        case 'col7':
          cells[col.field] = PlutoCell(value: 0);
          break; // Mob Adv
        case 'col8':
          cells[col.field] = PlutoCell(value: 0);
          break; // Taxable
        case 'col9':
          cells[col.field] = PlutoCell(value: 18);
          break; // GST
        case 'col10':
          cells[col.field] = PlutoCell(value: 0);
          break; // Tot Bill
        case 'col11':
          cells[col.field] = PlutoCell(value: 0);
          break; // TDS
        case 'col12':
          cells[col.field] = PlutoCell(value: 0);
          break; // TDS CGST
        case 'col13':
          cells[col.field] = PlutoCell(value: 0);
          break; // TDS SGST
        case 'col14':
          cells[col.field] = PlutoCell(value: 0);
          break; // Sec Dep
        case 'col15':
          cells[col.field] = PlutoCell(value: 0);
          break; // Lab Cess
        case 'col16':
          cells[col.field] = PlutoCell(value: 0);
          break; // Mob Int
        case 'col17':
          cells[col.field] = PlutoCell(value: 0);
          break; // Oth Ded
        case 'col18':
          cells[col.field] = PlutoCell(value: 0);
          break; // Withheld
        case 'col19':
          cells[col.field] = PlutoCell(value: 0);
          break; // Mob Adv Rec
        case 'col20':
          cells[col.field] = PlutoCell(value: 0);
          break; // WH Release
        case 'col21':
          cells[col.field] = PlutoCell(value: 0);
          break; // Tot Ded
        case 'col22':
          cells[col.field] = PlutoCell(value: 0);
          break; // Net Rec
        case 'col23':
          cells[col.field] = PlutoCell(value: 0);
          break; // Net Amt Recd
        case 'col24':
          cells[col.field] = PlutoCell(value: '');
          break; // Rec Date
        case 'col25':
          cells[col.field] = PlutoCell(value: 0);
          break; // Outstanding
        // ── Hidden remark/file columns ─────────────────────────────────
        default:
          cells[col.field] = PlutoCell(value: '');
          break;
      }
    }

    final newRow = PlutoRow(cells: cells);

    if (stateManager != null) {
      stateManager!.appendRows([newRow]);
      setState(() => rows = stateManager!.rows);
    } else {
      setState(() => rows = [...rows, newRow]);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (stateManager != null) {
          stateManager!.removeAllRows();
          stateManager!.appendRows(rows);
        }
      });
    }
  }

  void _onGridChanged(PlutoGridOnChangedEvent event) {
    final row = event.row;
    _calculateRowTotals(row);
  }

  void _calculateRowTotals(PlutoRow row) {
    double _cell(String field) {
      final v = row.cells[field]?.value;
      if (v == null) return 0;
      return double.tryParse(v.toString()) ?? 0;
    }

    void _set(String field, double value) {
      // ← directly set cell value without going through stateManager
      row.cells[field]?.value = value.roundToDouble();
    }

    // ── Step 1: Work Done ────────────────────────────────────────────────────
    final woValue = _woValueInclGst ?? 0.0;
    final perWork = _cell(_fPerWork);
    final workDone =
        woValue > 0 && perWork > 0 ? (woValue * perWork) / 100 : 0.0;
    _set(_fWorkDone, workDone);

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

    // ── Step 10: Outstanding ──────────────────────────────────────────────────
    final netAmtRecd = _cell(_fNetAmtRecd);
    final outstanding = netRec - netAmtRecd;
    _set(_fOutstanding, outstanding);

    // ── Force grid UI refresh ─────────────────────────────────────────────────
    stateManager?.notifyListeners(); // ← this is the key fix
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

  Widget _buildEmptyState() {
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
            Text(
              'Click the + button in the app bar to add a row',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
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

  void _showWODetailsDialog(BuildContext context) {
    if (_woValueInclGst == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Work Order Value Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 90,
                  child: Text(
                    'Value',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    ' ₹ ${formatIndianNumber(_woValueExclGst ?? 0)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const Text(
                  'Exclusive of GST 18%',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 90),
                SizedBox(
                  width: 100,
                  child: Text(
                    '₹ ${formatIndianNumber(_woValueInclGst ?? 0)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const Text(
                  'Inclusive of GST 18%',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
              'CUSID': customerId,
              'PROJID': projectId,
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
    if (stateManager == null || rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No rows to submit'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ── Validate required fields ───────────────────────────────────────────
    for (int i = 0; i < stateManager!.rows.length; i++) {
      final row = stateManager!.rows[i];
      final billNo = row.cells[_fBillNo]?.value?.toString().trim() ?? '';
      final billDate = row.cells[_fDate]?.value?.toString().trim() ?? '';

      if (billNo.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Row ${i + 1}: Bill No is required'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (billDate.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Row ${i + 1}: Date is required'),
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

      for (final row in stateManager!.rows) {
        final payload = _buildPayloadFromRow(row);
        final result = await saveSalesBilling(payload);

        if (result['Success'] == true) {
          successCount++;
        } else {
          failCount++;
          failMessages.add(result['Message']?.toString() ?? 'Unknown error');
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // close loading

      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$successCount ${successCount == 1 ? 'entry' : 'entries'} saved successfully'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onDataSaved != null) widget.onDataSaved!();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '$successCount saved, $failCount failed: ${failMessages.first}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
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

  Future<void> _fetchAndLoadBillingEntries() async {
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true) {
          final List<dynamic> list = data['BillingList'] ?? [];
          final entries =
              list.map((e) => SalesBillingModel.fromJson(e)).toList();

          final loadedRows = entries.map((e) {
            return PlutoRow(cells: {
              // ── Text ──────────────────────────────────────────────────
              _fBillNo: PlutoCell(value: e.billno ?? ''),
              _fBillDesc: PlutoCell(value: e.billdesc ?? ''),

              // ── Date ──────────────────────────────────────────────────
              _fDate: PlutoCell(
                value: e.billdate != null
                    ? DateFormat('yyyy-MM-dd').format(e.billdate!)
                    : '',
              ),
              _fRecDate: PlutoCell(
                value: e.netrecddt != null
                    ? DateFormat('yyyy-MM-dd').format(e.netrecddt!)
                    : '',
              ),

              // ── % of work — model has no direct field, default 0 ──────
              // your model doesn't have perofwork/workdoneamnt
              // use itper as TDS% reference, keep perwork as 0
              _fPerWork: PlutoCell(
                  value: double.tryParse(
                          (e.perofwork ?? '0').replaceAll('%', '').trim()) ??
                      0.0),
              _fWorkDone: PlutoCell(value: (e.workdoneamnt ?? 0).toDouble()),

              // ── Advance amounts ────────────────────────────────────────
              // model has no secadvamnt/mobadvamnt — default 0
              _fSecAdv: PlutoCell(value: (e.secadvamnt ?? 0).toDouble()),
              _fMobAdv: PlutoCell(value: (e.mobadvamnt ?? 0).toDouble()),

              // ── Taxable / Bill amounts ─────────────────────────────────
              _fTaxable: PlutoCell(value: (e.billamnt ?? 0).toDouble()),
              _fGST: PlutoCell(value: (e.gstper ?? 18).toDouble()),
              _fTotBill: PlutoCell(value: (e.billtotamnt ?? 0).toDouble()),

              // ── TDS ────────────────────────────────────────────────────
              _fTDS: PlutoCell(value: (e.tdsamnt ?? 0).toDouble()),
              _fTDSCGST: PlutoCell(value: (e.tdscgstamnt ?? 0).toDouble()),
              _fTDSSGST: PlutoCell(value: (e.tdssgstamnt ?? 0).toDouble()),

              // ── Deductions ─────────────────────────────────────────────
              _fSecDep: PlutoCell(value: (e.secdepamnt ?? 0).toDouble()),
              _fLabCess: PlutoCell(value: (e.labcessamnt ?? 0).toDouble()),
              _fMobInt: PlutoCell(value: (e.mobintamnt ?? 0).toDouble()),

              _fOthDed: PlutoCell(value: (e.dedamnt ?? 0).toDouble()),
              _fWithheld: PlutoCell(value: (e.whamnt ?? 0).toDouble()),
              // model has no mobadvrec — default 0
              _fMobAdvRec: PlutoCell(value: (e.mobadvrecamnt ?? 0).toDouble()),
              _fWhRelease: PlutoCell(value: (e.whrlseamnt ?? 0).toDouble()),

              // ── Totals ─────────────────────────────────────────────────
              _fTotDed: PlutoCell(value: (e.totdedamnt ?? 0).toDouble()),
              _fNetRec: PlutoCell(value: (e.netrecamnt ?? 0).toDouble()),

              // ── Net Amount Received ────────────────────────────────────
              _fNetAmtRecd: PlutoCell(value: (e.recamnt ?? 0).toDouble()),
              _fOutstanding: PlutoCell(value: (e.outstandamnt ?? 0).toDouble()),

              // ── Attachment fields ──────────────────────────────────────────
              _fAttachment: PlutoCell(
                value: e.sbfname ?? '', // Assuming model has this field
              ),
              'col25FileName': PlutoCell(
                value: e.sbfname ?? '', // Store filename
              ),
              'col25Base64': PlutoCell(
                value: e.sbfname ?? '', // Store base64 data (if returned)
              ),

              // ── Hidden remark columns ──────────────────────────────────────
              'col6Remark': PlutoCell(value: e.secadvremks ?? ''),
              'col7Remark': PlutoCell(value: e.mobadvremks ?? ''),
              'col17Remark': PlutoCell(value: e.othdedremks ?? ''),
              'col18Remark': PlutoCell(value: e.whremks ?? ''),
              'col19Remark': PlutoCell(value: e.mobadvrecremks ?? ''),
              'col20Remark': PlutoCell(value: e.whrlseremks ?? ''),
              'col23Remark': PlutoCell(value: e.netrecdremks ?? ''),
            });
          }).toList();

          setState(() {
            _billingList = entries;
            rows = loadedRows;
          });

          if (stateManager != null) {
            stateManager!.removeAllRows();
            stateManager!.appendRows(loadedRows);
          }

          // ── Recalculate all loaded rows ────────────────────────────────
          if (stateManager != null) {
            for (final row in stateManager!.rows) {
              _calculateRowTotals(row);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('_fetchAndLoadBillingEntries error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading billing data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoadingBilling = false);
    }
  }

  Map<String, dynamic> _buildPayloadFromRow(PlutoRow row) {
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

    // ── ATTACHMENT DATA - CRITICAL FIX ──────────────────────────────────
    // Get attachment data from the hidden columns
    String attachmentFileName = '';
    String attachmentBase64 = '';

    // Safely get attachment filename
    final fileNameCell = row.cells['col25FileName'];
    if (fileNameCell != null && fileNameCell.value != null) {
      attachmentFileName = fileNameCell.value.toString().trim();
    }

    // Safely get attachment base64 data
    final base64Cell = row.cells['col25Base64'];
    if (base64Cell != null && base64Cell.value != null) {
      attachmentBase64 = base64Cell.value.toString().trim();
    }

    // Also check the main attachment field as fallback
    if (attachmentFileName.isEmpty) {
      final attachmentCell = row.cells[_fAttachment];
      if (attachmentCell != null && attachmentCell.value != null) {
        attachmentFileName = attachmentCell.value.toString().trim();
      }
    }

    // ── DEBUG LOGGING ────────────────────────────────────────────────────
    print('=== Attachment Debug ===');
    print('Attachment File Name: $attachmentFileName');
    print('Attachment Base64 Length: ${attachmentBase64.length}');
    print(
        'Attachment Base64 Preview: ${attachmentBase64.substring(0, attachmentBase64.length > 50 ? 50 : attachmentBase64.length)}...');
    print('========================');

    return {
      // ── Core ──────────────────────────────────────────────────────────
      'SBNO': 0, // always insert new
      'CUSID': selectedCustomerId,
      'PROJID': selectedProjectId,
      'STAGEIDNAME': '', // stage not in grid — keep empty or handle separately

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
      'OUTSTANDAMNT': _num(_fOutstanding).toInt(),

      // ── ATTACHMENT FIELDS - ENSURE THEY'RE INCLUDED ───────────────────
      'ATTACHMENTFILENAME':
          attachmentFileName.isNotEmpty ? attachmentFileName : '',
      'ATTACHMENTBASE64': attachmentBase64.isNotEmpty ? attachmentBase64 : '',

      'FILES': attachmentBase64.isNotEmpty ? [] : [], // Empty array for files
      'REMOVEDFILES': '',

      // ── Audit ─────────────────────────────────────────────────────────
      'ADDUSER': empCode,
    };
  }

  Future<void> _pickAndAttachFile(PlutoRow row, String field) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'dwg'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      // ── DEBUG LOGGING ──────────────────────────────────────────────────
      print('=== File Picked Debug ===');
      print('File Name: $fileName');
      print('File Size: ${bytes.length} bytes');
      print('Base64 Length: ${base64String.length}');
      print('==========================');

      setState(() {
        // Store in main attachment column (visible)
        if (row.cells[field] != null) {
          row.cells[field]!.value = fileName;
        }

        // Store in hidden columns for payload
        final fileNameField = '${field}FileName';
        if (row.cells[fileNameField] != null) {
          row.cells[fileNameField]!.value = fileName;
        }

        final base64Field = '${field}Base64';
        if (row.cells[base64Field] != null) {
          row.cells[base64Field]!.value = base64String;
        }
      });

      stateManager?.notifyListeners();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attachment "$fileName" added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error in _pickAndAttachFile: $e');
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

    if (base64Data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attachment found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

              await BillingDownloadService.downloadBillingFiles(
                context: context,
                sbNo: sbNo,
                sbfname: row.cells[field]?.value?.toString(),
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

/*@override
  Widget _build(BuildContext context) {
    final _scrollController = ScrollController();
    final _formKey = GlobalKey<FormState>();
    final isViewOnly = widget.isReadOnly == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Update'),
        actions: [
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
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'View Billing List',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewBillingScreen(
                    isSuperAdmin: widget.isSuperAdmin,
                  ),
                ),
              );
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
                              final value =
                                  "${selection.customerId} - ${selection.companyName}";

                              customerController.text = value;

                              setState(() {
                                selectedCustomerId = selection.customerId;
                                selectedProjectId = null;
                                siteController.clear();
                                // Clear rows when customer changes
                                rows = [];
                                _billingList = [];
                                stateManager?.removeAllRows(); // ← clear grid
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
                                // ✅ FETCH WORK ORDER VALUE HERE
                                fetchWorkOrderValue(
                                    selectedCustomerId!, selection.projectId);
                              }
                              setState(() {
                                selectedProjectId = selection.projectId;
                                rows = []; // ← clear first
                                stateManager
                                    ?.removeAllRows(); // ← clear grid too
                              });

                              _fetchAndLoadBillingEntries(); // ← load billing data into grid
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
            Row(children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WO Value:',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Text(
                            woValueController.text.isEmpty
                                ? 'Select project to fetch'
                                : woValueController.text,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: woValueController.text.contains('Error') ||
                                      woValueController.text ==
                                          'No data available'
                                  ? Colors.red
                                  : woValueController.text.isEmpty
                                      ? Colors.grey.shade500
                                      : Colors.blue.shade700,
                            ),
                          ),
                          if (woValueController.text.isNotEmpty &&
                              woValueController.text != 'No data available' &&
                              woValueController.text != 'Error loading' &&
                              woValueController.text != 'Error' &&
                              woValueController.text != 'Loading...')
                            IconButton(
                              icon: const Icon(Icons.info_outline, size: 18),
                              onPressed: () {
                                if (_woValueInclGst != null) {
                                  _showWODetailsDialog(context);
                                }
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'View details',
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 16),

            /// Grid with "Add Row" button when empty
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: rows.isEmpty
                    ? _buildEmptyState()
                    : PlutoGrid(
                        columns: columns,
                        rows: rows,
                        onLoaded: (PlutoGridOnLoadedEvent event) {
                          stateManager = event.stateManager;
                          stateManager!.setShowColumnFilter(true);
                        },
                        onRowDoubleTap: (PlutoGridOnRowDoubleTapEvent event) {
                          debugPrint('Row double tapped');
                        },
                        onChanged: _onGridChanged,
                        onSelected: (PlutoGridOnSelectedEvent event) async {
                          if (event.cell != null &&
                              event.cell!.column.title == 'Date') {
                            await selectDateForCell(
                                event.row!, event.cell!.column);
                          }
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
                        ),
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
                    child: const Padding(
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
              ),
          ],
        ),
      ),
    );
  }*/
