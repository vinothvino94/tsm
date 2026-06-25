import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tsm/screens/sales/view_billing_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';
import '../../widgets/crop_screen.dart';
import 'dart:io' as io;
import 'package:universal_html/html.dart' as html;
import 'package:path/path.dart' as path;
import 'package:math_expressions/math_expressions.dart';

class BillingEntryScreen extends StatefulWidget {
  final SalesStagelistModel? stagelistData;
  final SalesBillingModel? billingData;
  final bool? isReadOnly;
  final VoidCallback? onDataSaved;
  final bool isSuperAdmin;
  const BillingEntryScreen({
    super.key,
    this.stagelistData,
    this.billingData,
    this.isReadOnly = false,
    this.onDataSaved,
    this.isSuperAdmin = false,
  });

  @override
  State<BillingEntryScreen> createState() => _BillingEntryScreenState();
}

class _BillingEntryScreenState extends State<BillingEntryScreen> {
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  TextEditingController customerController = TextEditingController();
  TextEditingController siteController = TextEditingController();
  TextEditingController stageController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  TextEditingController secamountController = TextEditingController();
  TextEditingController secadvrmksController = TextEditingController();
  TextEditingController mobamountController = TextEditingController();
  TextEditingController otherdedamountController = TextEditingController();
  TextEditingController whamountController = TextEditingController();
  TextEditingController whrlamountController = TextEditingController();
  TextEditingController mobadvrecamountController = TextEditingController();
  TextEditingController mobadvrmksController = TextEditingController();
  TextEditingController otherdedrmksController = TextEditingController();
  TextEditingController whrmksController = TextEditingController();
  TextEditingController whrlrmksController = TextEditingController();
  TextEditingController netamntrecdrmksController = TextEditingController();
  TextEditingController mobadvrecrmksController = TextEditingController();
  TextEditingController totbillamountController = TextEditingController();
  TextEditingController itController = TextEditingController();
  TextEditingController otherDeductionController = TextEditingController();
  TextEditingController mobintController = TextEditingController();
  TextEditingController whController = TextEditingController();
  TextEditingController whrlController = TextEditingController();
  TextEditingController netamntrecController = TextEditingController();
  TextEditingController totdedController = TextEditingController();
  TextEditingController netrecController = TextEditingController();
  TextEditingController osController = TextEditingController();
  TextEditingController retentionController = TextEditingController();
  TextEditingController gstController = TextEditingController();
  TextEditingController invnoController = TextEditingController();
  TextEditingController descController = TextEditingController();
  TextEditingController gstAmountController = TextEditingController();
  TextEditingController itAmountController = TextEditingController();
  TextEditingController secdepositController = TextEditingController();
  TextEditingController woValueController = TextEditingController();
  TextEditingController WorkDoneController = TextEditingController();
  TextEditingController percentWorkController = TextEditingController();
  TextEditingController _secTotalController = TextEditingController();
  TextEditingController _mobTotalController = TextEditingController();
  TextEditingController _otherdedTotalController = TextEditingController();
  TextEditingController _whTotalController = TextEditingController();
  TextEditingController _whrlTotalController = TextEditingController();
  TextEditingController _netamntrecdTotalController = TextEditingController();
  TextEditingController _mobadvrecTotalController = TextEditingController();
  TextEditingController TDSCGSTController = TextEditingController();
  TextEditingController TDSSGSTController = TextEditingController();
  TextEditingController labcessController = TextEditingController();
  final TextEditingController stageRemarksController = TextEditingController();
  late final TextEditingController _invDateController = TextEditingController();
  late final TextEditingController _recDateController = TextEditingController();

  List<ChecklistCustomer> customerList = [];
  List<Project> projectList = [];
  int? selectedCustomerId;
  int? selectedProjectId;
  int empCode = 0;
  String empName = '';
  String? selectedstage;
  String? selectedstageId;
  List<SalesStagelistModel> stageList = [];
  Map<String, String> dynamicStages = {};
  bool isLoadingStages = false;
  DateTime? invDate, recDate;
  List<PlatformFile> _attachedFiles = [];
  List<String> _existingFiles = [];
  List<String> _removedFiles = [];

  bool _isLoading = false;
  double? _woValueInclGst;
  double? _woValueExclGst;
  List<SecureAdvanceEntry> _secureAdvanceEntries = [];
  List<SecureAdvanceEntry> _mobAdvanceEntries = [];
  List<SecureAdvanceEntry> _otherdedEntries = [];
  List<SecureAdvanceEntry> _whEntries = [];
  List<SecureAdvanceEntry> _mobadvrecEntries = [];
  List<SecureAdvanceEntry> _whrlEntries = [];
  List<NetAmountRecd> _netamntrecdEntries = [];
  List<Map<String, String>> _stageEntries = [];
  @override
  void initState() {
    super.initState();
    if (invDate != null) {
      _invDateController.text = DateFormat('yyyy-MM-dd').format(invDate!);
    }
    if (recDate != null) {
      _recDateController.text = DateFormat('yyyy-MM-dd').format(recDate!);
    }
    itController.text = '2';
    retentionController.text = '5';
    gstController.text = '18';
    amountController.addListener(_calculateTotals);
    gstController.addListener(_calculateTotals);

    // Load customers first, then load billing data
    _initializeData();
  }

  Future<void> _initializeData() async {
    await loadCustomers();
    await _loadUserDetails();

    // Now customerList is populated, load billing data
    if (widget.billingData != null) {
      _loadBillingData();
    }
  }

  @override
  void dispose() {
    stageRemarksController.dispose();
    amountController.removeListener(_calculateTotals);
    gstController.removeListener(_calculateTotals);
    gstAmountController.dispose();
    woValueController.dispose();
    WorkDoneController.dispose();
    otherDeductionController.dispose();
    _secTotalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.stagelistData != null && !widget.isReadOnly!;
    final isViewOnly = widget.isReadOnly == true;
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Update'),
        actions: [
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
                              debugPrint(
                                  'Selected Customer: ${selection.companyName}, ID: ${selection.customerId}');

                              customerController.text =
                                  "${selection.customerId} - ${selection.companyName}";

                              setState(() {
                                selectedCustomerId = selection.customerId;
                                selectedProjectId = null;
                                siteController.clear();
                                // Clear stages when customer changes
                                dynamicStages = {};
                                stageList.clear();
                                selectedstageId = null;
                                stageController.clear();
                                // Clear WO value when customer changes
                                woValueController.clear();
                                _woValueInclGst = null;
                                _woValueExclGst = null;
                                _secureAdvanceEntries.clear();
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
                                              woValueController.clear();
                                              _woValueInclGst = null;
                                              _woValueExclGst = null;
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
                              setState(() {
                                selectedProjectId = selection.projectId;
                              });

                              if (selectedCustomerId != null) {
                                // Load stages
                                loadStagesFromApi(
                                    selectedCustomerId!, selection.projectId);

                                // ✅ FETCH WORK ORDER VALUE HERE
                                fetchWorkOrderValue(
                                    selectedCustomerId!, selection.projectId);
                              }
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
                                              // Clear stages when project is cleared
                                              dynamicStages = {};
                                              stageList.clear();
                                              selectedstageId = null;
                                              stageController.clear();
                                              woValueController.clear();
                                              _woValueInclGst = null;
                                              _woValueExclGst = null;
                                              _secureAdvanceEntries.clear();
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
              const SizedBox(height: 16),

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
                                color:
                                    woValueController.text.contains('Error') ||
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

              ///Bill No & Invoice Date & Bill Description & % of work & Work done value
              if (isAndroid) ...[
                // Android: Amount & INV No in first row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: amountController,
                        decoration: InputDecoration(
                          labelText: "Amount",
                          hintText: "Amount",
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon:
                              amountController.text.isNotEmpty && !isViewOnly
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          amountController.clear();
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Clear value',
                                    )
                                  : null,
                        ),
                        readOnly: isViewOnly,
                        enabled: !isViewOnly,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter amount';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: invnoController,
                        decoration: InputDecoration(
                          labelText: "Bill No",
                          hintText: "Bill No",
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon:
                              invnoController.text.isNotEmpty && !isViewOnly
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          invnoController.clear();
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Clear value',
                                    )
                                  : null,
                        ),
                        readOnly: isViewOnly,
                        enabled: !isViewOnly,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter invoice number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: descController,
                        decoration: InputDecoration(
                          labelText: "Bill Description",
                          hintText: "Bill Description",
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon:
                              descController.text.isNotEmpty && !isViewOnly
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          descController.clear();
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Clear value',
                                    )
                                  : null,
                        ),
                        readOnly: isViewOnly,
                        enabled: !isViewOnly,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Android: INV Date in separate row
                TextFormField(
                  controller: _invDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Date",
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (invDate != null && !isViewOnly)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                invDate = null;
                                _invDateController.clear();
                              });
                            },
                            padding: EdgeInsets.zero,
                            tooltip: 'Clear date',
                          ),
                        if (invDate == null && !isViewOnly)
                          Icon(
                            Icons.calendar_today,
                            color: AppColors.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                  validator: (value) {
                    if (invDate == null) {
                      return 'Please select a bill date';
                    }
                    return null;
                  },
                  onTap: isViewOnly
                      ? null
                      : () async {
                          await _selectDate(context, true);
                        },
                ),
              ] else ...[
                // Windows/Other: All three in a single row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: invnoController,
                        decoration: InputDecoration(
                          labelText: "Bill No",
                          hintText: "Bill No",
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon:
                              invnoController.text.isNotEmpty && !isViewOnly
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          invnoController.clear();
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Clear value',
                                    )
                                  : null,
                        ),
                        readOnly: isViewOnly,
                        enabled: !isViewOnly,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 300,
                      child: TextFormField(
                        controller: _invDateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "Date",
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (invDate != null && !isViewOnly)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      invDate = null;
                                      _invDateController.clear();
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Clear date',
                                ),
                              if (invDate == null && !isViewOnly)
                                Icon(
                                  Icons.calendar_today,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                        onTap: isViewOnly
                            ? null
                            : () async {
                                await _selectDate(context, true);
                              },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: descController,
                        inputFormatters: [
                          UpperCaseTextFormatter(), // ← Custom formatter
                        ],
                        decoration: InputDecoration(
                          labelText: "Bill Description",
                          hintText: "Bill Description",
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon:
                              descController.text.isNotEmpty && !isViewOnly
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          descController.clear();
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Clear value',
                                    )
                                  : null,
                        ),
                        readOnly: isViewOnly,
                        enabled: !isViewOnly,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller:
                            percentWorkController, // ✅ Use separate controller
                        decoration: InputDecoration(
                          labelText: "% Of Work",
                          hintText: "% Of Work",
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (percentWorkController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    '%',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              if (percentWorkController.text.isNotEmpty &&
                                  !isViewOnly)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      percentWorkController.clear();
                                      _calculateWorkDoneValue();
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Clear',
                                ),
                            ],
                          ),
                        ),
                        readOnly: isViewOnly,
                        enabled: !isViewOnly,
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          setState(() {
                            _calculateWorkDoneValue();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: WorkDoneController,
                        decoration: InputDecoration(
                          labelText: "Work Done Value",
                          hintText: "Work Done Value",
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          suffixIcon: WorkDoneController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      WorkDoneController.clear();
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Clear value',
                                )
                              : null,
                        ),
                        readOnly: true,
                        enabled: true,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue
                              .shade700, // Highlight to show it's auto-filled
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              ///Secure Advance
              Text(
                'Secure Advance',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              /// Secure Advance Amount & Secure Advance Remarks
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 1. Secure Advance Amount
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: secamountController,
                      decoration: InputDecoration(
                        labelText: "Amount",
                        hintText: "Enter amount or expression",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        suffixIcon: secamountController.text.isNotEmpty &&
                                !isViewOnly
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => secamountController.clear()),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear value',
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-*/%(). ]'),
                        ),
                        IndianNumberInputFormatter(),
                      ],
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// 2. Secure Advance Remarks
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: secadvrmksController,
                      inputFormatters: [
                        UpperCaseTextFormatter(), // ← Custom formatter
                      ],
                      decoration: InputDecoration(
                        labelText: "Remarks",
                        hintText: "Enter remarks",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            secadvrmksController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        secadvrmksController.clear();
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear value',
                                  )
                                : null,
                      ),
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// Left side: Add Button + Total field stacked
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add Button
                      if (!isViewOnly)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ElevatedButton(
                            onPressed: () => _addEntry(
                              entries: _secureAdvanceEntries,
                              amountCtrl: secamountController,
                              remarksCtrl: secadvrmksController,
                              label: 'Secure Advance',
                              onUpdate: _updateSecTotalController,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                            child: const Text('Add'),
                          ),
                        ),

                      /// Total — only when table has entries
                      if (_secureAdvanceEntries.isNotEmpty) ...[
                        const SizedBox(height: 50),
                        SizedBox(
                          width: 300,
                          child: TextFormField(
                            readOnly: true,
                            controller: _secTotalController, // ← keep only this
                            // initialValue: '₹ ...',        // ← remove this line entirely
                            decoration: InputDecoration(
                              labelText: "Total Secure Advance",
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              filled: true,
                              fillColor: Colors.indigo.shade50,
                              labelStyle: TextStyle(
                                color: Colors.indigo.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.indigo.shade400,
                                size: 20,
                              ),
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.indigo.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(width: 24),

                  /// RIGHT: Secure Advance Table
                  _buildAdvanceTable(
                    entries: _secureAdvanceEntries,
                    amountCtrl: secamountController,
                    remarksCtrl: secadvrmksController,
                    label: 'Secure Advance',
                    onUpdate: _updateSecTotalController,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ///Mobilization Advance
              const Text(
                'Mobilization Advance',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              /// Mobilization Advance Amount & Mobilization Advance Remarks
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 1. Mobilization Advance Amount
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: mobamountController,
                      decoration: InputDecoration(
                        labelText: "Amount",
                        hintText: "Enter amount",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: mobamountController.text.isNotEmpty &&
                                !isViewOnly
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => mobamountController.clear()),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear value',
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-*/%(). ]'),
                        ),
                        IndianNumberInputFormatter(),
                      ],
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// 2. Mobilization Advance Remarks
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: mobadvrmksController,
                      inputFormatters: [
                        UpperCaseTextFormatter(), // ← Custom formatter
                      ],
                      decoration: InputDecoration(
                        labelText: "Remarks",
                        hintText: "Enter remarks",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            mobadvrmksController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        mobadvrmksController.clear();
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear value',
                                  )
                                : null,
                      ),
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// Left side: Add Button + Total field stacked
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add Button
                      if (!isViewOnly)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ElevatedButton(
                            onPressed: () => _addEntry(
                              entries: _mobAdvanceEntries,
                              amountCtrl: mobamountController,
                              remarksCtrl: mobadvrmksController,
                              label: 'Mobilization Advance',
                              onUpdate: _updateMobTotalController,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                            child: const Text('Add'),
                          ),
                        ),

                      /// Total — only when table has entries
                      if (_mobAdvanceEntries.isNotEmpty) ...[
                        const SizedBox(height: 50),
                        SizedBox(
                          width: 300,
                          child: TextFormField(
                            readOnly: true,
                            controller: _mobTotalController,
                            decoration: InputDecoration(
                              labelText: "Total Mobilization Advance",
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              filled: true,
                              fillColor: Colors.indigo.shade50,
                              labelStyle: TextStyle(
                                color: Colors.indigo.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.indigo.shade400,
                                size: 20,
                              ),
                              prefixText:
                                  '₹ ', // ← shows ₹ visually, not stored in controller
                              prefixStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.indigo.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(width: 24),

                  /// RIGHT: Secure Advance Table
                  _buildAdvanceTable(
                    entries: _mobAdvanceEntries,
                    amountCtrl: mobamountController,
                    remarksCtrl: mobadvrmksController,
                    label: 'Mobilization Advance',
                    onUpdate: _updateMobTotalController,
                  )
                ],
              ),
              const SizedBox(height: 16),

              ///Taxable Value
              const Text(
                'Taxable Value',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              ///Taxable Value & GST Percentage & GST Amount & Total Bill Amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 1. Taxable Value
                  Expanded(
                    child: TextFormField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: "Taxable Value",
                        hintText: "Taxable Value",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: amountController.text.isNotEmpty &&
                                !isViewOnly
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => amountController.clear()),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear value',
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [IndianNumberInputFormatter()],
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                      onChanged: (_) => setState(() {
                        _calculateTotals();
                      }),
                    ),
                  ),
                  const SizedBox(width: 16),

                  /// 2. GST %
                  Expanded(
                    child: TextFormField(
                      controller: gstController,
                      decoration: InputDecoration(
                        labelText: "GST %",
                        hintText: "GST %",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // % Symbol Icon
                            if (gstController.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  '%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            if (gstController.text.isNotEmpty && !isViewOnly)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    gstController.clear();
                                    _calculateTotals();
                                  });
                                },
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear',
                              ),
                          ],
                        ),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                      onChanged: (_) {
                        setState(() {
                          _calculateTotals();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  /// 3. GST Amount (auto calculated)
                  Expanded(
                    child: TextFormField(
                      controller: gstAmountController,
                      decoration: const InputDecoration(
                        labelText: "GST Amount",
                        hintText: "Auto calculated",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      readOnly: true,
                      enabled: true,
                    ),
                  ),
                  const SizedBox(width: 16),

                  /// 4. Total Bill Amount (auto calculated)
                  Expanded(
                    child: TextFormField(
                      controller: totbillamountController,
                      decoration: const InputDecoration(
                        labelText: "Total Bill Amount",
                        hintText: "Auto calculated",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      readOnly: true,
                      enabled: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ///Deductions
              const Text(
                'Deductions',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              ///TDS & TDSCGST & TDSSGST & Security Deposit & Labour Cess & Mobilization Interest
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ///TDS Amount (auto calculated)
                  Expanded(
                    child: TextFormField(
                      controller: itAmountController,
                      decoration: const InputDecoration(
                        labelText: "TDS Amount",
                        hintText: "Auto calculated",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      readOnly: true,
                      enabled: true,
                    ),
                  ),
                  const SizedBox(width: 16),

                  ///TDSCGST Amount (auto calculated)
                  Expanded(
                    child: TextFormField(
                      controller: TDSCGSTController,
                      decoration: const InputDecoration(
                        labelText: "TDS CGST",
                        hintText: "Auto calculated",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      readOnly: true,
                      enabled: true,
                    ),
                  ),
                  const SizedBox(width: 16),

                  ///TDSSGST Amount (auto calculated)
                  Expanded(
                    child: TextFormField(
                      controller: TDSSGSTController,
                      decoration: const InputDecoration(
                        labelText: "TDS SGST",
                        hintText: "Auto calculated",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      readOnly: true,
                      enabled: true,
                    ),
                  ),
                  const SizedBox(width: 16),

                  ///Security Deposit Amount (auto calculated)
                  Expanded(
                    child: TextFormField(
                      controller: secdepositController,
                      decoration: const InputDecoration(
                        labelText: "Security Deposit Amount",
                        hintText: "Auto calculated",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      readOnly: true,
                      enabled: true,
                    ),
                  ),
                  const SizedBox(width: 16),

                  ///Labour Cess (auto calculated)
                  Expanded(
                    child: TextFormField(
                      controller: labcessController,
                      decoration: const InputDecoration(
                        labelText: "Labour Cess Amount",
                        hintText: "Auto calculated",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      readOnly: true,
                      enabled: true,
                    ),
                  ),
                  const SizedBox(width: 16),

                  ///Mobilization Interest
                  Expanded(
                    child: TextFormField(
                      controller: mobintController,
                      decoration: InputDecoration(
                        labelText: "Mobilization Interest",
                        hintText: "Mobilization Interest",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            mobintController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        mobintController.clear();
                                        _calculateTotals();
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear value',
                                  )
                                : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [IndianNumberInputFormatter()],
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                      onChanged: (_) => setState(() => _calculateTotals()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ///Other Deductions
              const Text(
                'Other Deductions',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              /// Other Deduction & Remarks
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 1. Other Deduction
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: otherdedamountController,
                      decoration: InputDecoration(
                        labelText: "Amount",
                        hintText: "Enter amount",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: otherdedamountController.text.isNotEmpty &&
                                !isViewOnly
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(
                                    () => otherdedamountController.clear()),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear value',
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-*/%(). ]'),
                        ),
                        IndianNumberInputFormatter(),
                      ],
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// 2. Other Deduction Remarks
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: otherdedrmksController,
                      inputFormatters: [
                        UpperCaseTextFormatter(), // ← Custom formatter
                      ],
                      decoration: InputDecoration(
                        labelText: "Remarks",
                        hintText: "Enter remarks",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: otherdedrmksController.text.isNotEmpty &&
                                !isViewOnly
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    otherdedrmksController.clear();
                                  });
                                },
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear value',
                              )
                            : null,
                      ),
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// Left side: Add Button + Total field stacked
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add Button
                      if (!isViewOnly)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ElevatedButton(
                            onPressed: () => _addEntry(
                              entries: _otherdedEntries,
                              amountCtrl: otherdedamountController,
                              remarksCtrl: otherdedrmksController,
                              label: 'Other Deductions',
                              onUpdate: _updateOtherdedTotalController,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                            child: const Text('Add'),
                          ),
                        ),

                      /// Total — only when table has entries
                      if (_otherdedEntries.isNotEmpty) ...[
                        const SizedBox(height: 50),
                        SizedBox(
                          width: 300,
                          child: TextFormField(
                            readOnly: true,
                            controller: _otherdedTotalController,
                            decoration: InputDecoration(
                              labelText: "Total Other Deduction",
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              filled: true,
                              fillColor: Colors.indigo.shade50,
                              labelStyle: TextStyle(
                                color: Colors.indigo.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.indigo.shade400,
                                size: 20,
                              ),
                              prefixText:
                                  '₹ ', // ← shows ₹ visually, not stored in controller
                              prefixStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.indigo.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(width: 24),

                  /// RIGHT: Other Deduction Table
                  _buildAdvanceTable(
                    entries: _otherdedEntries,
                    amountCtrl: otherdedamountController,
                    remarksCtrl: otherdedrmksController,
                    label: 'Other Deductions',
                    onUpdate: _updateOtherdedTotalController,
                  )
                ],
              ),
              const SizedBox(height: 16),

              ///Withheld
              const Text(
                'Withheld',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              ///Withheld & Remarks
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 1. Withheld
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: whamountController,
                      decoration: InputDecoration(
                        labelText: "Amount",
                        hintText: "Enter amount",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: whamountController.text.isNotEmpty &&
                                !isViewOnly
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setState(() => whamountController.clear()),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear value',
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-*/%(). ]'),
                        ),
                        IndianNumberInputFormatter(),
                      ],
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// 2. Other Deduction Remarks
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: whrmksController,
                      inputFormatters: [
                        UpperCaseTextFormatter(), // ← Custom formatter
                      ],
                      decoration: InputDecoration(
                        labelText: "Remarks",
                        hintText: "Enter remarks",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            whrmksController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        whrmksController.clear();
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear value',
                                  )
                                : null,
                      ),
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// Left side: Add Button + Total field stacked
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add Button
                      if (!isViewOnly)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ElevatedButton(
                            onPressed: () => _addEntry(
                              entries: _whEntries,
                              amountCtrl: whamountController,
                              remarksCtrl: whrmksController,
                              label: 'Withheld',
                              onUpdate: _updatewhTotalController,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                            child: const Text('Add'),
                          ),
                        ),

                      /// Total — only when table has entries
                      if (_whEntries.isNotEmpty) ...[
                        const SizedBox(height: 50),
                        SizedBox(
                          width: 300,
                          child: TextFormField(
                            readOnly: true,
                            controller: _whTotalController,
                            decoration: InputDecoration(
                              labelText: "Total Other Deduction",
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              filled: true,
                              fillColor: Colors.indigo.shade50,
                              labelStyle: TextStyle(
                                color: Colors.indigo.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.indigo.shade400,
                                size: 20,
                              ),
                              prefixText:
                                  '₹ ', // ← shows ₹ visually, not stored in controller
                              prefixStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.indigo.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(width: 24),

                  /// RIGHT: Other Deduction Table
                  _buildAdvanceTable(
                    entries: _whEntries,
                    amountCtrl: whamountController,
                    remarksCtrl: whrmksController,
                    label: 'Withheld',
                    onUpdate: _updatewhTotalController,
                  )
                ],
              ),
              const SizedBox(height: 16),

              ///Mobilization Advance Recovery
              const Text(
                'Mobilization Advance Recovery',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              ///Mobilization Advance Recovery & Remarks
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 1. Mobilization Advance Recovery
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: mobadvrecamountController,
                      decoration: InputDecoration(
                        labelText: "Amount",
                        hintText: "Enter amount",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: mobadvrecamountController.text.isNotEmpty &&
                                !isViewOnly
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(
                                    () => mobadvrecamountController.clear()),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear value',
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-*/%(). ]'),
                        ),
                        IndianNumberInputFormatter(),
                      ],
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// 2. Mobilization Advance Recovery Remarks
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: mobadvrecrmksController,
                      inputFormatters: [
                        UpperCaseTextFormatter(), // ← Custom formatter
                      ],
                      decoration: InputDecoration(
                        labelText: "Remarks",
                        hintText: "Enter remarks",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: mobadvrecrmksController.text.isNotEmpty &&
                                !isViewOnly
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    mobadvrecrmksController.clear();
                                  });
                                },
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear value',
                              )
                            : null,
                      ),
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// Left side: Add Button + Total field stacked
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add Button
                      if (!isViewOnly)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ElevatedButton(
                            onPressed: () => _addEntry(
                              entries: _mobadvrecEntries,
                              amountCtrl: mobadvrecamountController,
                              remarksCtrl: mobadvrecrmksController,
                              label: 'MObilization Advance Recovery',
                              onUpdate: _updatemobadvrecTotalController,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                            child: const Text('Add'),
                          ),
                        ),

                      /// Total — only when table has entries
                      if (_mobadvrecEntries.isNotEmpty) ...[
                        const SizedBox(height: 50),
                        SizedBox(
                          width: 300,
                          child: TextFormField(
                            readOnly: true,
                            controller: _mobadvrecTotalController,
                            decoration: InputDecoration(
                              labelText: "Total Mobilization Recovery",
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              filled: true,
                              fillColor: Colors.indigo.shade50,
                              labelStyle: TextStyle(
                                color: Colors.indigo.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.indigo.shade400,
                                size: 20,
                              ),
                              prefixText:
                                  '₹ ', // ← shows ₹ visually, not stored in controller
                              prefixStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.indigo.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(width: 24),

                  /// RIGHT: Other Deduction Table
                  _buildAdvanceTable(
                    entries: _mobadvrecEntries,
                    amountCtrl: mobadvrecamountController,
                    remarksCtrl: mobadvrecrmksController,
                    label: 'Mobilization Advance Recovery',
                    onUpdate: _updatemobadvrecTotalController,
                  )
                ],
              ),
              const SizedBox(height: 16),

              ///Withheld release
              const Text(
                'Withheld release',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              ///Withheld release & Remarks
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 1. Withheld release
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: whrlamountController,
                      decoration: InputDecoration(
                        labelText: "Amount",
                        hintText: "Enter amount",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            whrlamountController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(
                                        () => whrlamountController.clear()),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear value',
                                  )
                                : null,
                      ),
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-*/%(). ]'),
                        ),
                        IndianNumberInputFormatter(),
                      ],
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// 2. Withheld release Remarks
                  SizedBox(
                    width: 500,
                    child: TextFormField(
                      controller: whrlrmksController,
                      inputFormatters: [
                        UpperCaseTextFormatter(), // ← Custom formatter
                      ],
                      decoration: InputDecoration(
                        labelText: "Remarks",
                        hintText: "Enter remarks",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            whrlrmksController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        whrlrmksController.clear();
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear value',
                                  )
                                : null,
                      ),
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// Left side: Add Button + Total field stacked
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add Button
                      if (!isViewOnly)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ElevatedButton(
                            onPressed: () => _addEntry(
                              entries: _whrlEntries,
                              amountCtrl: whrlamountController,
                              remarksCtrl: whrlrmksController,
                              label: 'Withheld release',
                              onUpdate: _updatewhrlTotalController,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                            child: const Text('Add'),
                          ),
                        ),

                      /// Total — only when table has entries
                      if (_whrlEntries.isNotEmpty) ...[
                        const SizedBox(height: 50),
                        SizedBox(
                          width: 300,
                          child: TextFormField(
                            readOnly: true,
                            controller: _whrlTotalController,
                            decoration: InputDecoration(
                              labelText: "Total Withheld release",
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              filled: true,
                              fillColor: Colors.indigo.shade50,
                              labelStyle: TextStyle(
                                color: Colors.indigo.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.indigo.shade400,
                                size: 20,
                              ),
                              prefixText:
                                  '₹ ', // ← shows ₹ visually, not stored in controller
                              prefixStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.indigo.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(width: 24),

                  /// RIGHT: Withheld release Table
                  _buildAdvanceTable(
                    entries: _whrlEntries,
                    amountCtrl: whrlamountController,
                    remarksCtrl: whrlrmksController,
                    label: 'Withheld Release',
                    onUpdate: _updatewhrlTotalController,
                  )
                ],
              ),
              const SizedBox(height: 16),

              ///Total Deduction & Net receivable
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: totdedController,
                      decoration: InputDecoration(
                        labelText: "Total Deduction",
                        hintText: "Total Deduction",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            totdedController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        totdedController.clear();
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear value',
                                  )
                                : null,
                      ),
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: netrecController,
                      decoration: const InputDecoration(
                        labelText: "Net receivable",
                        hintText: "Auto calculated",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      readOnly: true,
                      enabled: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ///Net Amount Received
              const Text(
                'Net Amount Received',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              ///Net amount received & remarks & Date & Outstanding
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 1. Net amount received
                  SizedBox(
                    width: 250,
                    child: TextFormField(
                      controller: netamntrecController,
                      decoration: InputDecoration(
                        labelText: "Net amount received",
                        hintText: "Enter amount",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            netamntrecController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () => setState(
                                        () => netamntrecController.clear()),
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear value',
                                  )
                                : null,
                      ),
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\-*/%(). ]'),
                        ),
                        IndianNumberInputFormatter(),
                      ],
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// 2. Net amount received Remarks
                  SizedBox(
                    width: 250,
                    child: TextFormField(
                      controller: netamntrecdrmksController,
                      inputFormatters: [
                        UpperCaseTextFormatter(), // ← Custom formatter
                      ],
                      decoration: InputDecoration(
                        labelText: "Remarks",
                        hintText: "Enter remarks",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: netamntrecdrmksController.text.isNotEmpty &&
                                !isViewOnly
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    netamntrecdrmksController.clear();
                                  });
                                },
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear value',
                              )
                            : null,
                      ),
                      readOnly: isViewOnly,
                      enabled: !isViewOnly,
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// 3. Date
                  SizedBox(
                    width: 240,
                    child: TextFormField(
                      controller: _recDateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Date",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (recDate != null && !isViewOnly)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    recDate = null;
                                    _recDateController.clear();
                                  });
                                },
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear date',
                              ),
                            if (recDate == null && !isViewOnly)
                              Icon(
                                Icons.calendar_today,
                                color: AppColors.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                      onTap: isViewOnly
                          ? null
                          : () async {
                              await _selectDate(context, false);
                            },
                    ),
                  ),
                  const SizedBox(width: 12),

                  ///4.Outstanding
                  SizedBox(
                    width: 240,
                    child: TextFormField(
                      controller: osController,
                      decoration: const InputDecoration(
                        labelText: "Outstanding",
                        hintText: "Auto calculated",
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      readOnly: true,
                      enabled: true,
                    ),
                  ),
                  const SizedBox(width: 12),

                  /// Left side: Add Button + Total field stacked
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add Button
                      if (!isViewOnly)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: ElevatedButton(
                            onPressed: () => _addnetamountEntry(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                            child: const Text('Add'),
                          ),
                        ),

                      /// Total — only when table has entries
                      if (_netamntrecdEntries.isNotEmpty) ...[
                        const SizedBox(height: 50),
                        SizedBox(
                          width: 300,
                          child: TextFormField(
                            readOnly: true,
                            controller: _netamntrecdTotalController,
                            decoration: InputDecoration(
                              labelText: "Total Netamount Received",
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              filled: true,
                              fillColor: Colors.indigo.shade50,
                              labelStyle: TextStyle(
                                color: Colors.indigo.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                                color: Colors.indigo.shade400,
                                size: 20,
                              ),
                              prefixText:
                                  '₹ ', // ← shows ₹ visually, not stored in controller
                              prefixStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.indigo.shade800,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(width: 24),
                    ],
                  ),
                  const SizedBox(width: 24),

                  /// RIGHT: Net Amount Received Table
                  Expanded(
                    child: _buildNetamountrecdTable(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildStageInputSection(),
              const SizedBox(height: 16),

              ///Document Upload Section
              _buildAttachCard(),
              const SizedBox(height: 16),

              ///Document Text
              if (_existingFiles.isEmpty && _attachedFiles.isEmpty)
                Center(
                    child: Text('No files selected',
                        style: TextStyle(color: Colors.grey.shade600))),
              const SizedBox(height: 16),

              // Existing files (already uploaded)
              if (_existingFiles.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Existing Attachments:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._existingFiles.map(
                        (fileName) => _buildExistingAttachmentItem(fileName)),
                  ],
                ),
              const SizedBox(height: 16),

              // Newly picked files
              if (_attachedFiles.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('New Attachments:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._attachedFiles.map((file) => _buildAttachmentItem(file)),
                  ],
                ),
              const SizedBox(height: 16),

              ///Submit/Update Button
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
                        onTap: () {
                          if (_formKey.currentState!.validate()) {
                            _submitForm();
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Center(
                            child: Text(
                              widget.billingData != null
                                  ? 'Update'
                                  : 'Submit', // ✅ Change button text
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
            ],
          ),
        ),
      ),
    );
  }

  void _calculateWorkDoneValue() {
    // Get WO Value (remove ₹ and commas)
    String woValueText =
        woValueController.text.replaceAll('₹', '').replaceAll(',', '').trim();

    double woValue = double.tryParse(woValueText) ?? 0;

    // Get % of Work
    String percentText = percentWorkController.text.replaceAll('%', '').trim();

    double percent = double.tryParse(percentText) ?? 0;

    // Calculate Work Done Value
    if (woValue > 0 && percent > 0) {
      double workDone = (woValue * percent) / 100;
      WorkDoneController.text = '₹ ${formatIndianNumber(workDone.round())}';
    } else {
      WorkDoneController.clear();
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

  Future<void> _submitForm() async {
    try {
      final isEditing = widget.billingData != null;

      // ── Prepare new files for upload ──────────────────────────────────────
      List<FileUploadModel>? uploadFiles;
      if (_attachedFiles.isNotEmpty) {
        uploadFiles = _attachedFiles
            .where((f) => f.bytes != null)
            .map((f) => FileUploadModel(
                  filename: f.name,
                  filedata: base64Encode(f.bytes!),
                ))
            .toList();
      }

      // ── Helper: parse formatted Indian number string to double ────────────
      double? _parseField(String text) => double.tryParse(text
          .replaceAll(',', '')
          .replaceAll('₹', '')
          .replaceAll('%', '')
          .trim());

      // ── Secure Advance ────────────────────────────────────────────────────
      final secAdvAmnt = _secureAdvanceEntries.map((e) => e.amount).join('|');
      final secAdvRemarks = _secureAdvanceEntries
          .map((e) => '${e.amount.toInt()}\$${e.remarks}')
          .join('@');
      final secAdvTotal = _getTotalSecureAdvance();

      // ── Mobilization Advance ──────────────────────────────────────────────
      final mobAdvAmnt = _mobAdvanceEntries.map((e) => e.amount).join('|');
      final mobAdvRemks = _mobAdvanceEntries
          .map((e) => '${e.amount.toInt()}\$${e.remarks}')
          .join('@');
      final mobAdvTotal = _getTotalMobAdvance();

      // ── Other Deductions ──────────────────────────────────────────────────
      final othDedAmnt = _otherdedEntries.map((e) => e.amount).join('|');
      final othDedRemks = _otherdedEntries
          .map((e) => '${e.amount.toInt()}\$${e.remarks}')
          .join('@');
      final othDedTotal = _otherdedEntries.fold(0.0, (s, e) => s + e.amount);

      // ── Withheld ──────────────────────────────────────────────────────────
      final whAmnt = _whEntries.map((e) => e.amount).join('|');
      final whRemks =
          _whEntries.map((e) => '${e.amount.toInt()}\$${e.remarks}').join('@');
      final whTotal = _whEntries.fold(0.0, (s, e) => s + e.amount);

      // ── Mobilization Advance Recovery ─────────────────────────────────────
      final mobAdvRecAmnt = _mobadvrecEntries.map((e) => e.amount).join('|');
      final mobAdvRecRemks = _mobadvrecEntries
          .map((e) => '${e.amount.toInt()}\$${e.remarks}')
          .join('@');
      final mobAdvRecTotal =
          _mobadvrecEntries.fold(0.0, (s, e) => s + e.amount);

      // ── Withheld Release ──────────────────────────────────────────────────
      final whrlAmnt = _whrlEntries.map((e) => e.amount).join('|');
      final whrlRemks = _whrlEntries
          .map((e) => '${e.amount.toInt()}\$${e.remarks}')
          .join('@');
      final whrlTotal = _whrlEntries.fold(0.0, (s, e) => s + e.amount);

      // ── Net Amount Received ───────────────────────────────────────────────
      // Pack amount|date|remarks into NETRECDREMKS using @ as section separator
      // Format: "amt1|amt2@date1|date2@rmk1|rmk2"
      // NETRECDDT  → null   (decimal? column in DB — cannot store date strings)
      // OUTSTANDAMNT → single decimal (final outstanding value)
      final netRecdAmnt = _netamntrecdEntries.map((e) => e.amount).join('|');
      final netRecdDt = _netamntrecdEntries.map((e) => e.date).join('|');
      final netRecdRemarks = _netamntrecdEntries
          .map((e) => '${e.amount.toInt()}-${e.date}-${e.remarks}')
          .join('@');
      final netRecdTotal =
          _netamntrecdEntries.fold(0.0, (s, e) => s + e.amount);

      // ── Build request body ────────────────────────────────────────────────
      final requestBody = <String, dynamic>{
        // ── Core fields ────────────────────────────────────────────────────
        'SBNO': isEditing ? (widget.billingData?.sbno ?? 0) : 0,
        'CUSID': selectedCustomerId,
        'PROJID': selectedProjectId,
        'STAGEIDNAME': _stageEntries
            .map((e) =>
                '${e['stageId']}\$${e['stageName']}\$${e['stageRemarks']}')
            .join('@'), // ← @ as separator like other remarks fields

        'BILLNO': invnoController.text.trim(),
        'BILLDATE': invDate?.toIso8601String(),
        'BILLDESC': descController.text.trim(),
        'PEROFWORK': percentWorkController.text.trim().endsWith('%')
            ? percentWorkController.text.trim()
            : '${percentWorkController.text.trim()}%',
        'WORKDONEAMNT': _parseField(WorkDoneController.text),

        // ── Secure Advance ─────────────────────────────────────────────────
        // SECADVAMNT  → decimal total (sum of all entries)
        // SECADVREMKS → "amt1|amt2@rmk1|rmk2"
        'SECADVAMNT': formatAmount(secAdvTotal),
        'SECADVREMKS': secAdvRemarks,

        // ── Mobilization Advance ───────────────────────────────────────────
        'MOBADVAMNT': formatAmount(mobAdvTotal),
        'MOBADVREMKS': mobAdvRemks,

        // ── Bill Amounts ───────────────────────────────────────────────────
        'BILLAMNT': _parseField(amountController.text),
        'GSTPER': double.tryParse(
          gstController.text.replaceAll('%', '').trim(),
        ),
        'GSTAMNT': _parseField(gstAmountController.text)?.toInt(),
        'TOTBILLAMNT': _parseField(totbillamountController.text)?.toInt(),

        // ── TDS ────────────────────────────────────────────────────────────
        'TDSAMNT': _parseField(itAmountController.text)?.toInt(),
        'TDSCGSTAMNT': _parseField(TDSCGSTController.text)?.toInt(),
        'TDSSGSTAMNT': _parseField(TDSSGSTController.text)?.toInt(),

        // ── Deductions ─────────────────────────────────────────────────────
        'SECDEPAMNT': _parseField(secdepositController.text)?.toInt(),
        'LABCESSAMNT': _parseField(labcessController.text)?.toInt(),
        'MOBINTAMNT': _parseField(mobintController.text)?.toInt(),

        'OTHDEDAMNT': othDedTotal.toInt(),
        'OTHDEDREMKS': othDedRemks,

        'WHAMNT': whTotal.toInt(),
        'WHREMKS': whRemks,

        'MOBADVRECAMNT': mobAdvRecTotal.toInt(),
        'MOBADVRECREMKS': mobAdvRecRemks,

        'WHRLSEAMNT': whrlTotal.toInt(),
        'WHRLSEREMKS': whrlRemks,

        'TOTDEDAMNT': _parseField(totdedController.text)?.toInt(),

        // ── Net & Outstanding ──────────────────────────────────────────────
        // NETRECAMNT   → Net Receivable (single decimal)
        // NETRECDAMNT  → Total Net Amount Received (sum, single decimal)
        // NETRECDDT    → null (decimal? in DB — cannot store date strings)
        // NETRECDREMKS → "amt1|amt2@date1|date2@rmk1|rmk2" (all list data packed)
        // OUTSTANDAMNT → final outstanding (single decimal)
        'NETRECAMNT': _parseField(netrecController.text)?.toInt(),
        'NETRECDAMNT': netRecdTotal.toInt(),
        'NETRECDDT': null,
        'NETRECDREMKS': netRecdRemarks,
        'OUTSTANDAMNT': _parseField(osController.text)?.toInt(),

        // ── Audit ──────────────────────────────────────────────────────────
        'ADDUSER': empCode,
        if (isEditing) 'EDITUSER': empCode,

        // ── Files ──────────────────────────────────────────────────────────
        'FILES': uploadFiles?.map((f) => f.toJson()).toList() ?? [],
        'REMOVEDFILES': _removedFiles.isNotEmpty ? _removedFiles.join(',') : '',
      };

      print('Request Body: ${jsonEncode(requestBody)}');
      print('Payload: ${jsonEncode(_stageEntries)}');

      final result = await saveSalesBilling(requestBody);

      if (!mounted) return;

      if (result['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Billing Entry Updated Successfully'
                : 'Billing Entry Saved Successfully'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onDataSaved != null) {
          widget.onDataSaved!();
        }

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['Message'].toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('Error in _submitForm: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String formatAmount(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  Future<void> _loadUserDetails() async {
    final prefsHelper = PreferencesHelper();
    empCode = (await prefsHelper.getEmpCode()) ?? 0;
    empName = (await prefsHelper.getEmpName())!;
    setState(() {});
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

  Future<void> loadStagesFromApi(int customerId, int projectId) async {
    setState(() {
      isLoadingStages = true;
      dynamicStages = {};
      selectedstageId = null;
      stageController.clear();
    });

    try {
      final uri = ApiUtils.getUri(
          'GetBillingStages'); // ← remove .replace(queryParameters)

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          // ← send as POST body
          'CUSID': customerId,
          'PROJID': projectId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true) {
          final List stages = data['Data'] ?? [];

          final loadedStages =
              stages.map((s) => SalesStagelistModel.fromJson(s)).toList();

          setState(() {
            stageList = loadedStages;
            for (var stage in stageList) {
              if (stage.stageid != null && stage.stagename != null) {
                dynamicStages[stage.stageid!] = stage.stagename!;
              }
            }
          });
        } else {
          debugPrint('GetBillingStages failed: ${data['Message']}');
        }
      }
    } catch (e) {
      print("Exception: $e");
    } finally {
      setState(() {
        isLoadingStages = false;
      });
    }
  }

  Widget _buildStageInputSection() {
    final isViewOnly = widget.isReadOnly == true;
    final hasStages = dynamicStages.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Stage Dropdown ────────────────────────────────────
            SizedBox(
              width: 290,
              child: isLoadingStages
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: selectedstageId,
                      decoration: _inputDecoration("Select Stage").copyWith(
                        suffixIcon: (!isViewOnly && selectedstageId != null)
                            ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedstageId = null;
                                    stageController.clear();
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                            : null,
                      ),
                      items: dynamicStages.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.key),
                        );
                      }).toList(),
                      onChanged: (isViewOnly || !hasStages || isLoadingStages)
                          ? null
                          : (value) {
                              setState(() {
                                selectedstageId = value;
                                if (value != null &&
                                    dynamicStages.containsKey(value)) {
                                  stageController.text = dynamicStages[value]!;
                                }
                              });
                            },
                      validator: (value) {
                        if (!isViewOnly &&
                            hasStages &&
                            value == null &&
                            stageController.text.trim().isEmpty &&
                            _stageEntries.isEmpty) {
                          // ← only validate if no entries added yet
                          return 'Please select a stage or enter custom stage name';
                        }
                        return null;
                      },
                    ),
            ),
            const SizedBox(width: 12),

            // ── 2. Stage Name ────────────────────────────────────────
            SizedBox(
              width: 350,
              child: TextFormField(
                controller: stageController,
                decoration: InputDecoration(
                  labelText: "Stage Name",
                  hintText: "Enter custom stage name",
                  border: const OutlineInputBorder(),
                  suffixIcon: stageController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              stageController.clear();
                              selectedstageId = null;
                            });
                          },
                          padding: EdgeInsets.zero,
                          tooltip: 'Clear',
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                minLines: 1,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                readOnly: isViewOnly,
                enabled: !isViewOnly,
                onChanged: (value) {
                  if (value.isNotEmpty && selectedstageId != null) {
                    setState(() => selectedstageId = null);
                  }
                },
              ),
            ),
            const SizedBox(width: 14),

            // ── 2b. Stage Remarks ────────────────────────────────────  ← ADD THIS
            SizedBox(
              width: 350,
              child: TextFormField(
                controller: stageRemarksController,
                inputFormatters: [
                  UpperCaseTextFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: "Remarks",
                  hintText: "Enter remarks",
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon:
                      stageRemarksController.text.isNotEmpty && !isViewOnly
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  stageRemarksController.clear();
                                });
                              },
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear value',
                            )
                          : null,
                ),
                readOnly: isViewOnly,
                enabled: !isViewOnly,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 14),

            // ── 3. Add Button + Total stacked ────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isViewOnly)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ElevatedButton(
                      onPressed: _addStageEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                      child: const Text('Add'),
                    ),
                  ),

                // Info message when no stages exist
                if (!isLoadingStages &&
                    !hasStages &&
                    selectedCustomerId != null &&
                    selectedProjectId != null &&
                    !isViewOnly) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 260,
                    child: Text(
                      'No stages found. Enter a custom stage name.',
                      style: TextStyle(color: Colors.orange[700], fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(width: 240),

            // ── 4. Stage Table (RIGHT side) ──────────────────────────
            if (_stageEntries.isNotEmpty)
              _buildStageTable(isViewOnly: isViewOnly),
          ],
        ),
      ],
    );
  }

  Widget _buildStageTable({required bool isViewOnly}) {
    Widget badge(int i) => Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF3FA),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text('${i + 1}',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600)),
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600), // ← limit table width
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16, // ← reduce from 20
              horizontalMargin: 12, // ← reduce from 16
              headingRowHeight: 46,
              dataRowMinHeight: 50,
              dataRowMaxHeight: double.infinity,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columns: [
                const DataColumn(
                  label: SizedBox(
                    width: 30, // ← reduce from 36
                    child: Text('S.No',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1E293B))),
                  ),
                ),
                const DataColumn(
                  label: Text('Stage ID',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1E293B))),
                ),
                const DataColumn(
                  label: Text('Stage Name',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1E293B))),
                ),
                const DataColumn(
                  label: Text('Remarks',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF1E293B))),
                ),
                if (!isViewOnly)
                  const DataColumn(
                    label: SizedBox(
                      width: 70, // ← reduce from 80
                      child: Text('Actions',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF1E293B))),
                    ),
                  ),
              ],
              rows: List.generate(_stageEntries.length, (i) {
                final entry = _stageEntries[i];
                return DataRow(
                  color: WidgetStateProperty.all(
                      i % 2 == 0 ? Colors.white : const Color(0xFFFAFBFD)),
                  cells: [
                    DataCell(badge(i)),
                    DataCell(Text(
                      entry['stageId']!.isEmpty ? '—' : entry['stageId']!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF64748B)),
                    )),
                    DataCell(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: SizedBox(
                        width: 120, // ← reduce from 180
                        child: Text(entry['stageName']!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1E293B),
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible),
                      ),
                    )),
                    DataCell(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: SizedBox(
                        width: 120, // ← reduce from 180
                        child: Text(
                          entry['stageRemarks']!.isEmpty
                              ? '—'
                              : entry['stageRemarks']!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B),
                          ),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    )),
                    if (!isViewOnly)
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ActionIconButton(
                            icon: Icons.edit_outlined,
                            color: const Color(0xFF2563EB),
                            tooltip: 'Edit',
                            onPressed: () {
                              stageController.text = entry['stageName']!;
                              stageRemarksController.text =
                                  entry['stageRemarks'] ?? '';
                              setState(() {
                                selectedstageId = entry['stageId']!.isEmpty
                                    ? null
                                    : entry['stageId'];
                                _stageEntries.removeAt(i);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Edit the entry and click Add to update'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          _ActionIconButton(
                            icon: Icons.delete_outline,
                            color: const Color(0xFFDC2626),
                            tooltip: 'Delete',
                            onPressed: () {
                              setState(() => _stageEntries.removeAt(i));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(
                                    'Deleted stage: ${entry['stageName']}'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 1),
                              ));
                            },
                          ),
                        ],
                      )),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  void _addStageEntry() {
    final stageId = selectedstageId ?? '';
    final stageName = stageController.text.trim();
    final stageRemarks = stageRemarksController.text.trim(); // ← add

    if (stageName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter or select a stage name'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      _stageEntries.add({
        'stageId': stageId,
        'stageName': stageName,
        'stageRemarks': stageRemarks, // ← add
      });
      selectedstageId = null;
      stageController.clear();
      stageRemarksController.clear(); // ← add
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Stage added: $stageName'),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _selectDate(BuildContext context, bool isInvDate) async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isInvDate ? (invDate ?? now) : (recDate ?? now),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isInvDate) {
          invDate = picked;
          _invDateController.text =
              DateFormat('yyyy-MM-dd').format(picked); // ← add
        } else {
          recDate = picked;
          _recDateController.text =
              DateFormat('yyyy-MM-dd').format(picked); // ← add
        }
      });
    }
  }

  Widget _buildAttachCard() {
    // Helper to check if we're on Android specifically

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Files button - available on all platforms
            _buildAttachButton(
              icon: Icons.attach_file,
              label: 'Files',
              onPressed: pickFiles,
              color: AppColors.primaryLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
          color: color,
        ),
        Text(label, style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Future<void> pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'pdf',
        'doc',
        'docx',
        'dwg',
        'dot', 'dotx', // Word
        'xls', 'xlsx', 'xlsm', 'xlsb', 'csv', // Excel
      ],
      type: FileType.custom,
      withData: true,
    );

    if (result != null) {
      List<PlatformFile> newFiles = [];

      for (var file in result.files) {
        if (['jpg', 'jpeg', 'png'].contains(file.extension?.toLowerCase())) {
          final bytes = file.bytes;
          if (bytes == null) continue;

          final croppedBytes = await Navigator.push<Uint8List>(
            context,
            MaterialPageRoute(
              builder: (context) => CropScreen(
                imageBytes: bytes,
                onCropped: (croppedBytes) {},
              ),
            ),
          );

          if (croppedBytes != null) {
            newFiles.add(PlatformFile(
              name: 'cropped_${file.name}',
              path: kIsWeb
                  ? null
                  : '${(await getTemporaryDirectory()).path}/cropped_${file.name}',
              bytes: croppedBytes,
              size: croppedBytes.length,
            ));
          }
        } else {
          newFiles.add(file);
        }
      }

      setState(() {
        _attachedFiles.addAll(newFiles);
      });
    }
  }

  Widget _buildAttachmentItem(PlatformFile file) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: FutureBuilder<Widget>(
          future: _generateThumbnail(file),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasData) {
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: snapshot.data,
                ),
              );
            }
            return Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[200],
              ),
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
        title: Text(file.name, overflow: TextOverflow.ellipsis),
        subtitle: Text('${(file.size / 1024).toStringAsFixed(1)} KB'),
        trailing: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => setState(() => _attachedFiles.remove(file)),
        ),
        onTap: () => _previewFile(file),
      ),
    );
  }

  Future<Widget> _generateThumbnail(PlatformFile file) async {
    final extension = file.name.split('.').last.toLowerCase();

    // For all platforms, just show icons (no thumbnails)
    if (['jpg', 'jpeg', 'png', 'gif', 'dwg'].contains(extension)) {
      return _buildFileIcon(Icons.image, Colors.amber);
    } else if (['pdf'].contains(extension)) {
      return _buildFileIcon(Icons.picture_as_pdf, Colors.red);
    } else if (['doc', 'docx'].contains(extension)) {
      return _buildFileIcon(Icons.description, Colors.blue);
    } else if (['xls', 'xlsx', 'xlsm', 'xlsb', 'csv'].contains(extension)) {
      return _buildFileIcon(Icons.table_chart, Colors.green);
    }

    // Default file icon
    return _buildFileIcon(Icons.insert_drive_file, Colors.grey);
  }

  Future<void> _previewFile(PlatformFile file) async {
    final extension = file.name.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      _showImagePreview(file);
    } else if (['pdf'].contains(extension)) {
      _showPdfPreview(file);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview not available for this file type')));
    }
  }

  Widget _buildFileIcon(IconData icon, Color color) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(icon, size: 24, color: color),
      ),
    );
  }

  void _showImagePreview(PlatformFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(file.name)),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 3.0,
              child: file.bytes != null
                  ? Image.memory(file.bytes!)
                  : (!kIsWeb && file.path != null)
                      ? Image.file(File(file.path!))
                      : Container(),
            ),
          ),
        ),
      ),
    );
  }

  void _showPdfPreview(PlatformFile file) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([file.bytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(url, '_blank');
      } else if (io.Platform.isWindows ||
          io.Platform.isMacOS ||
          io.Platform.isLinux) {
        // Save to temp directory and open with default application
        final tempDir = io.Directory.systemTemp;
        final tempFile = io.File(path.join(tempDir.path, file.name));
        await tempFile.writeAsBytes(file.bytes!);

        final uri = Uri.file(tempFile.path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw Exception('Could not open PDF file');
        }
      } else {
        // Mobile implementation
        final path =
            file.path ?? (await _saveToFile(file.name, file.bytes!)).path;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(file.name)),
              body: PDFView(
                filePath: path,
                enableSwipe: true,
                swipeHorizontal: false,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to preview PDF: $e')),
      );
    }
  }

  Future<List<FileUploadModel>> filesToBase64(List<File> pickedFiles) async {
    List<FileUploadModel> result = [];
    for (var file in pickedFiles) {
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      final filename = file.path.split('/').last;
      result.add(FileUploadModel(filename: filename, filedata: base64Str));
    }
    return result;
  }

  Future<void> _loadBillingData() async {
    if (widget.billingData != null) {
      final data = widget.billingData!;

      debugPrint('===== _loadBillingData START =====');
      debugPrint('Customer ID from data: ${data.cusid}');
      debugPrint('Project ID from data: ${data.projid}');
      debugPrint('Customer list length: ${customerList.length}');

      // Wait for customerList if empty
      if (customerList.isEmpty && data.cusid != null) {
        debugPrint('Customer list empty, waiting for customers...');
        await loadCustomers();
      }

      // Load customer with proper name
      if (data.cusid != null) {
        selectedCustomerId = data.cusid;

        // Find customer from customerList
        final customer = customerList.firstWhere(
          (c) => c.customerId == data.cusid,
          orElse: () {
            debugPrint(
                'Customer not found in customerList, will fetch from API');
            return ChecklistCustomer(customerId: 0, companyName: '');
          },
        );

        if (customer.customerId > 0 && customer.companyName.isNotEmpty) {
          customerController.text =
              "${customer.customerId} - ${customer.companyName}";
          debugPrint('Customer name set to: ${customerController.text}');
        } else {
          // If customer not found, fetch from API
          debugPrint('Customer not found, fetching from API...');
          await _fetchAndSetCustomerNameForBilling(data.cusid!);
        }

        // Load projects for this customer
        await loadProjects(data.cusid!);
      }

      // Load project with proper name
      if (data.projid != null) {
        selectedProjectId = data.projid;

        // Find project from projectList
        final project = projectList.firstWhere(
          (p) => p.projectId == data.projid,
          orElse: () {
            debugPrint('Project not found in projectList');
            return Project(projectId: 0, projectName: '');
          },
        );

        if (project.projectId > 0 && project.projectName.isNotEmpty) {
          siteController.text = "${project.projectId} - ${project.projectName}";
          debugPrint('Project name set to: ${siteController.text}');
        } else {
          // If project not found, set ID only and try to fetch
          siteController.text = data.projid.toString();
          if (data.cusid != null) {
            await _fetchAndSetProjectNameForBilling(data.cusid!, data.projid!);
          }
        }

        if (selectedCustomerId != null && selectedProjectId != null) {
          await loadStagesFromApi(selectedCustomerId!, selectedProjectId!)
              .then((_) {
            if (data.stageid != null &&
                dynamicStages.containsKey(data.stageid)) {
              setState(() {
                selectedstageId = data.stageid;
                stageController.text = dynamicStages[data.stageid] ?? '';
              });
            } else if (data.stageid != null) {
              stageController.text = data.stageid ?? '';
              selectedstageId = null;
            }
          });
        }
      }

      // Load billing details
      invnoController.text = data.billno ?? '';
      descController.text = data.billdesc ?? '';
      invDate = data.billdate;
      recDate = data.recdate;

      // Load amounts
      amountController.text = data.billamnt != null
          ? formatIndianNumber(data.billamnt!.round())
          : '';
      gstController.text = data.gstper?.toString() ?? '18';
      gstAmountController.text =
          data.gstamnt != null ? formatIndianNumber(data.gstamnt!.round()) : '';
      totbillamountController.text = data.billtotamnt != null
          ? formatIndianNumber(data.billtotamnt!.round())
          : '';

      itController.text = data.itper != null ? '${data.itper}%' : '2%';
      itAmountController.text =
          data.itamnt != null ? formatIndianNumber(data.itamnt!.round()) : '';

      retentionController.text =
          data.retnper != null ? '${data.retnper}%' : '5%';
      secdepositController.text = data.retnamnt != null
          ? formatIndianNumber(data.retnamnt!.round())
          : '';

      otherDeductionController.text =
          data.dedamnt != null ? formatIndianNumber(data.dedamnt!.round()) : '';
      whController.text =
          data.whamnt != null ? formatIndianNumber(data.whamnt!.round()) : '';
      whrlController.text = data.whrlseamnt != null
          ? formatIndianNumber(data.whrlseamnt!.round())
          : '';
      netamntrecController.text =
          data.recamnt != null ? formatIndianNumber(data.recamnt!.round()) : '';

      // Load existing files from SBFNAME
      if (data.sbfname != null && data.sbfname!.isNotEmpty) {
        _existingFiles = data.sbfname!.split(',').map((e) => e.trim()).toList();
        print('✅ Loaded existing files: $_existingFiles');
      } else {
        _existingFiles = [];
      }

      // Clear new attachments
      _attachedFiles.clear();

      setState(() {});
      _calculateTotals();

      debugPrint('===== _loadBillingData END =====');
    }
  }

  Future<void> _fetchAndSetCustomerNameForBilling(int customerId) async {
    debugPrint('Fetching customer $customerId from API...');
    try {
      final response = await http.post(
        ApiUtils.getUri('ExistingChecklistCustomers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"CUSTOMERID": customerId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint('Customer fetch response: $result');

        if (result['Success'] == true && result['CustomerDetails'] != null) {
          final customers = result['CustomerDetails'] as List;
          if (customers.isNotEmpty) {
            final customer = ChecklistCustomer.fromJson(customers.first);
            setState(() {
              customerController.text =
                  "${customer.customerId} - ${customer.companyName}";
            });
            debugPrint('Customer fetched and set: ${customerController.text}');

            // Add to customerList for future use
            if (!customerList.any((c) => c.customerId == customer.customerId)) {
              setState(() {
                customerList.add(customer);
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching customer for billing: $e');
    }
  }

  Future<void> _fetchAndSetProjectNameForBilling(
      int customerId, int projectId) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('ProjectDetails'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"CUSTOMERID": customerId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['Success'] == true && result['ProjectDetails'] != null) {
          final projects = result['ProjectDetails'] as List;
          final projectJson = projects.firstWhere(
            (p) => p['PROJECTID'] == projectId,
            orElse: () => null,
          );
          if (projectJson != null) {
            final project = Project.fromJson(projectJson);
            siteController.text =
                "${project.projectId} - ${project.projectName}";
            debugPrint('Project fetched and set: ${siteController.text}');

            // Add to projectList for future use
            if (!projectList.any((p) => p.projectId == project.projectId)) {
              setState(() {
                projectList.add(project);
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching project for billing: $e');
    }
  }

  Widget _buildExistingAttachmentItem(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: _buildFileIconSync(extension),
        title: Text(fileName, overflow: TextOverflow.ellipsis),
        trailing: !widget.isReadOnly!
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _existingFiles.remove(fileName);
                    _removedFiles.add(fileName);
                    print('Marked for deletion: $fileName');
                  });
                },
              )
            : null,
        onTap: () => _previewExistingFile(fileName),
      ),
    );
  }

  Future<void> _previewExistingFile(String fileName) async {
    // Show snackbar asking user to download first
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download the attachment first to view it.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildFileIconSync(String extension) {
    if (['jpg', 'jpeg', 'png', 'gif', 'dwg'].contains(extension)) {
      return _buildFileIcon(Icons.image, Colors.amber);
    } else if (['pdf'].contains(extension)) {
      return _buildFileIcon(Icons.picture_as_pdf, Colors.red);
    } else if (['doc', 'docx'].contains(extension)) {
      return _buildFileIcon(Icons.description, Colors.blue);
    } else if (['xls', 'xlsx', 'xlsm', 'xlsb', 'csv'].contains(extension)) {
      return _buildFileIcon(Icons.table_chart, Colors.green);
    }
    return _buildFileIcon(Icons.insert_drive_file, Colors.grey);
  }

  Future<Map<String, dynamic>> saveSalesBillingWithRemovedFiles(
      Map<String, dynamic> requestBody) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('SaveSalesBillinglist'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'Success': false,
          'Message': 'Server Error: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {
        'Success': false,
        'Message': e.toString(),
      };
    }
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

  double _getTotalSecureAdvance() {
    return _secureAdvanceEntries.fold(0.0, (sum, entry) => sum + entry.amount);
  }

  void _updateSecTotalController() {
    _secTotalController.text =
        '₹ ${formatIndianNumber(_getTotalSecureAdvance())}';
    _calculateTotals();
  }

  double _getTotalMobAdvance() {
    return _mobAdvanceEntries.fold(0.0, (sum, entry) => sum + entry.amount);
  }

  void _updateMobTotalController() {
    _mobTotalController.text =
        formatIndianNumber(_getTotalMobAdvance()); // ← no ₹ prefix
    _calculateTotals();
  }

  double _getTotalOtherDeduction() {
    return _otherdedEntries.fold(0.0, (sum, entry) => sum + entry.amount);
  }

  void _updateOtherdedTotalController() {
    _otherdedTotalController.text =
        formatIndianNumber(_getTotalOtherDeduction()); // ← no ₹ prefix
    _calculateTotals();
  }

  double _getTotalwh() {
    return _whEntries.fold(0.0, (sum, entry) => sum + entry.amount);
  }

  void _updatewhTotalController() {
    _whTotalController.text =
        formatIndianNumber(_getTotalwh()); // ← no ₹ prefix
    _calculateTotals();
  }

  double _getTotalmobadvrec() {
    return _mobadvrecEntries.fold(0.0, (sum, entry) => sum + entry.amount);
  }

  void _updatemobadvrecTotalController() {
    _mobadvrecTotalController.text =
        formatIndianNumber(_getTotalmobadvrec()); // ← no ₹ prefix
    _calculateTotals();
  }

  double _getTotalwhrl() {
    return _whrlEntries.fold(0.0, (sum, entry) => sum + entry.amount);
  }

  void _updatewhrlTotalController() {
    _whrlTotalController.text =
        formatIndianNumber(_getTotalwhrl()); // ← no ₹ prefix
    _calculateTotals();
  }

  Widget _buildAdvanceTable({
    required List<SecureAdvanceEntry> entries,
    required TextEditingController amountCtrl,
    required TextEditingController remarksCtrl,
    required String label,
    required VoidCallback onUpdate,
  }) {
    if (entries.isEmpty) return const SizedBox.shrink();

    const double headerFs = 13;
    const double cellFs = 13;
    final totalAmount = entries.fold(0.0, (sum, e) => sum + e.amount);

    // local helpers (no setState needed — they just build widgets)
    Widget badge(int i) => Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF3FA),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text('${i + 1}',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600)),
        );

    Widget amountCell(double v, {bool total = false}) => Align(
          alignment: Alignment.centerRight,
          child: Text('₹ ${formatIndianNumber(v)}',
              style: TextStyle(
                fontSize: total ? cellFs + 1 : cellFs,
                fontWeight: total ? FontWeight.w700 : FontWeight.w600,
                color: total ? Colors.indigo.shade800 : const Color(0xFF1E293B),
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        );

    Widget remarksCell(String text, {bool total = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: SizedBox(
            width: 200,
            child: Text(text,
                style: TextStyle(
                  fontSize: total ? cellFs + 1 : cellFs,
                  fontWeight: total ? FontWeight.w700 : FontWeight.w400,
                  color:
                      total ? Colors.indigo.shade800 : const Color(0xFF64748B),
                ),
                softWrap: true,
                overflow: TextOverflow.visible),
          ),
        );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            horizontalMargin: 16,
            headingRowHeight: 46,
            dataRowMinHeight: 50,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(
                label: SizedBox(
                  width: 36,
                  child: Text('S.No',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: headerFs,
                          color: Color(0xFF1E293B))),
                ),
              ),
              DataColumn(
                label: Text('Amount',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: Color(0xFF1E293B))),
                numeric: true,
              ),
              DataColumn(
                label: Text('Remarks',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: Color(0xFF1E293B))),
              ),
              DataColumn(
                label: SizedBox(
                  width: 80,
                  child: Text('Actions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: headerFs,
                          color: Color(0xFF1E293B))),
                ),
              ),
            ],
            rows: [
              // ── data rows ──────────────────────────────────────────────────
              ...List.generate(entries.length, (i) {
                final entry = entries[i];
                return DataRow(
                  color: WidgetStateProperty.all(
                      i % 2 == 0 ? Colors.white : const Color(0xFFFAFBFD)),
                  cells: [
                    DataCell(badge(i)),
                    DataCell(amountCell(entry.amount)),
                    DataCell(remarksCell(entry.remarks)),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ActionIconButton(
                          icon: Icons.edit_outlined,
                          color: const Color(0xFF2563EB),
                          tooltip: 'Edit',
                          onPressed: () {
                            amountCtrl.text = formatIndianNumber(entry.amount);
                            remarksCtrl.text = entry.remarks;
                            setState(() {
                              entries.removeAt(i);
                              onUpdate();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Edit the entry and click Add to update'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        _ActionIconButton(
                          icon: Icons.delete_outline,
                          color: const Color(0xFFDC2626),
                          tooltip: 'Delete',
                          onPressed: () {
                            setState(() {
                              entries.removeAt(i);
                              onUpdate();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  'Deleted: ₹ ${formatIndianNumber(entry.amount)}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 1),
                            ));
                          },
                        ),
                      ],
                    )),
                  ],
                );
              }),

              // ── total row ──────────────────────────────────────────────────
              DataRow(
                color: WidgetStateProperty.all(
                    Colors.indigo.shade50.withOpacity(0.6)),
                cells: [
                  DataCell(Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.summarize,
                        size: 16, color: Colors.indigo.shade700),
                  )),
                  DataCell(amountCell(totalAmount, total: true)),
                  DataCell(remarksCell('Total', total: true)),
                  const DataCell(SizedBox(width: 80)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addEntry({
    required List<SecureAdvanceEntry> entries,
    required TextEditingController amountCtrl,
    required TextEditingController remarksCtrl,
    required String label,
    required VoidCallback onUpdate,
  }) {
    final amount = evaluateExpression(amountCtrl.text.trim());
    final remarks = remarksCtrl.text.trim();

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Please enter a valid amount or expression (e.g. 100+50 or 1000-250)'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter remarks'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      entries.add(SecureAdvanceEntry(amount: amount, remarks: remarks));
      amountCtrl.clear();
      remarksCtrl.clear();
      onUpdate();
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label added: ₹ ${formatIndianNumber(amount)}'),
      backgroundColor: Colors.green,
    ));
  }

  double? evaluateExpression(String input) {
    try {
      // ← Strip Indian number commas first, then clean spaces
      final cleaned = input.replaceAll(',', '').replaceAll(' ', '').trim();
      if (cleaned.isEmpty) return null;

      // Plain number (including negatives like -250)
      final plain = double.tryParse(cleaned);
      if (plain != null) return plain;

      // Expression evaluation
      final parser = Parser();
      final exp = parser.parse(cleaned);
      final contextModel = ContextModel();
      final result = exp.evaluate(EvaluationType.REAL, contextModel) as double;

      return result.isFinite ? result : null;
    } catch (e) {
      return null;
    }
  }

  void _calculateTotals() {
    // ── Raw inputs ──
    final workDone = _parseIndianNumber(WorkDoneController.text);
    final secAdvTotal = _getTotalSecureAdvance();
    final mobAdvTotal = _getTotalMobAdvance();
    final gstPercent = double.tryParse(gstController.text.trim()) ?? 0;
    final itPercent =
        double.tryParse(itController.text.replaceAll('%', '').trim()) ?? 0;
    final retentionPercent =
        double.tryParse(retentionController.text.replaceAll('%', '').trim()) ??
            0;

    // ── Step 1: Taxable Value (Amount) ──
    final taxableValue = workDone + secAdvTotal + mobAdvTotal;
    amountController.text = formatIndianNumber(taxableValue);

    // ── Step 2: TDS CGST & SGST (1% of Work Done) ──
    final tdsCGST = workDone * 0.01;
    final tdsSGST = workDone * 0.01;
    TDSCGSTController.text = formatIndianNumber(tdsCGST);
    TDSSGSTController.text = formatIndianNumber(tdsSGST);

    // ── Step 3: GST Amount & Total Bill Amount ──
    double totalBillAmount = 0;
    if (taxableValue > 0 && gstPercent > 0) {
      final gstAmount = (taxableValue * gstPercent) / 100;
      final roundedGstAmount = gstAmount.round();
      totalBillAmount =
          taxableValue.round().toDouble() + roundedGstAmount.toDouble();

      gstAmountController.text = formatIndianNumber(roundedGstAmount);
      totbillamountController.text = formatIndianNumber(totalBillAmount);
    } else {
      gstAmountController.clear();
      totbillamountController.clear();
      totalBillAmount = 0;
    }

    // ── Step 4: Labour Cess (1% of Total Bill Amount) ──
    final labourCess = (totalBillAmount * 0.01).round();
    labcessController.text = formatIndianNumber(labourCess);

    // ── Step 5: TDSAmountValue (2% of Taxable Value) ──
    double TDSAmountValue = 0;
    if (taxableValue > 0 && itPercent > 0) {
      TDSAmountValue = ((taxableValue * itPercent) / 100).roundToDouble();
      itAmountController.text = formatIndianNumber(TDSAmountValue);
    } else {
      itAmountController.clear();
    }

    // ── Step 6: SecurityDepositAmountValue (5% of Taxable Value) ──
    double SecurityDepositAmountValue = 0;
    if (taxableValue > 0 && retentionPercent > 0) {
      SecurityDepositAmountValue =
          ((taxableValue * retentionPercent) / 100).roundToDouble();
      secdepositController.text =
          formatIndianNumber(SecurityDepositAmountValue);
    } else {
      secdepositController.clear();
    }

    // ── Step 7: Total Deduction ──
    final otherDedTotal =
        _otherdedEntries.fold(0.0, (sum, e) => sum + e.amount);
    final withheldTotal = _whEntries.fold(0.0, (sum, e) => sum + e.amount);
    final mobAdvRecTotal =
        _mobadvrecEntries.fold(0.0, (sum, e) => sum + e.amount);
    final withheldRelease = _whrlEntries.fold(0.0, (sum, e) => sum + e.amount);
    final mobInt = _parseIndianNumber(mobintController.text);

    final totalDeduction = TDSAmountValue +
        tdsCGST +
        tdsSGST +
        SecurityDepositAmountValue +
        labourCess +
        mobInt +
        otherDedTotal +
        withheldTotal +
        mobAdvRecTotal -
        withheldRelease; // ← release reduces the deduction

    if (totalDeduction != 0) {
      totdedController.text = formatIndianNumber(totalDeduction);
    } else {
      totdedController.clear();
    }

    // ── Step 8: Net Receivable = Total Bill Amount - Total Deduction ──
    double netReceivable = 0;
    if (totalBillAmount > 0) {
      netReceivable = totalBillAmount - totalDeduction;
      netrecController.text = formatIndianNumber(netReceivable);
    } else {
      netrecController.clear();
    }

    // ── Step 9: Outstanding = Net Receivable - Net Amount Received ──
    if (totalBillAmount > 0) {
      final totalNetAmountReceived =
          _netamntrecdEntries.fold(0.0, (sum, e) => sum + e.amount);
      final outstanding = netReceivable - totalNetAmountReceived;
      osController.text = formatIndianNumber(outstanding);
    } else {
      osController.clear();
    }

    debugPrint('''
=== Calculate Totals ===
Work Done              : $workDone
Secure Advance         : $secAdvTotal
Mobilization Advance   : $mobAdvTotal
Taxable Value          : $taxableValue

GST %                  : $gstPercent
GST Amount             : ${gstAmountController.text}
Total Bill Amount      : ${totbillamountController.text}
TDS Amount             : $TDSAmountValue
TDS CGST (1%)          : $tdsCGST
TDS SGST (1%)          : $tdsSGST
Security Deposit Amount: $SecurityDepositAmountValue
Labour Cess (1%)       : $labourCess
Mobilization Interest  : $mobInt
Other Deduction        : $otherDedTotal
With Held              : $withheldTotal
Mob Advance Recovery   : $mobAdvRecTotal
With Held Release      : $withheldRelease
Total Deduction        : $totalDeduction
Net Receivable         : $netReceivable
Total Net Amt Received : ${_netamntrecdEntries.fold(0.0, (s, e) => s + e.amount)}
Outstanding            : ${osController.text}
========================
''');
  }

  double _parseIndianNumber(String value) {
    // Remove ₹, spaces, commas
    final cleaned = value.replaceAll('₹', '').replaceAll(',', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  void _addnetamountEntry() {
    final amount = evaluateExpression(netamntrecController.text.trim());
    final remarks = netamntrecdrmksController.text.trim();
    final date =
        recDate != null ? DateFormat('yyyy-MM-dd').format(recDate!) : '';
    final outstanding = _parseIndianNumber(osController.text);

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Please enter a valid amount or expression (e.g. 100+50 or 1000-250)'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    if (remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter remarks'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      _netamntrecdEntries.add(NetAmountRecd(
        amount: amount,
        remarks: remarks,
        date: date,
      ));
      netamntrecController.clear();
      netamntrecdrmksController.clear();
      setState(() => recDate = null); // reset date picker
      _updatenetamntrecdTotalController();
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text('Net Amount Received added: ₹ ${formatIndianNumber(amount)}'),
      backgroundColor: Colors.green,
    ));
  }

  Widget _buildNetamountrecdTable() {
    if (_netamntrecdEntries.isEmpty) return const SizedBox.shrink();

    const double headerFs = 13;
    const double cellFs = 13;

    final totalAmount =
        _netamntrecdEntries.fold(0.0, (sum, e) => sum + e.amount);

    Widget badge(int i) => Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF3FA),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text('${i + 1}',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600)),
        );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            horizontalMargin: 16,
            headingRowHeight: 46,
            dataRowMinHeight: 50,
            dataRowMaxHeight: double.infinity,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(
                label: SizedBox(
                  width: 36,
                  child: Text('S.No',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: headerFs,
                          color: Color(0xFF1E293B))),
                ),
              ),
              DataColumn(
                label: Text('Amount',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: Color(0xFF1E293B))),
                numeric: true,
              ),
              DataColumn(
                label: Text('Remarks',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: Color(0xFF1E293B))),
              ),
              DataColumn(
                label: Text('Date',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: Color(0xFF1E293B))),
              ),
              DataColumn(
                label: SizedBox(
                  width: 80,
                  child: Text('Actions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: headerFs,
                          color: Color(0xFF1E293B))),
                ),
              ),
            ],
            rows: [
              // ── data rows ──────────────────────────────────────────────────
              ...List.generate(_netamntrecdEntries.length, (i) {
                final entry = _netamntrecdEntries[i];
                return DataRow(
                  color: WidgetStateProperty.all(
                      i % 2 == 0 ? Colors.white : const Color(0xFFFAFBFD)),
                  cells: [
                    // S.No
                    DataCell(badge(i)),

                    // Amount
                    DataCell(Align(
                      alignment: Alignment.centerRight,
                      child: Text('₹ ${formatIndianNumber(entry.amount)}',
                          style: const TextStyle(
                            fontSize: cellFs,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                            fontFeatures: [FontFeature.tabularFigures()],
                          )),
                    )),

                    // Remarks
                    DataCell(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: SizedBox(
                        width: 100,
                        child: Text(entry.remarks,
                            style: const TextStyle(
                              fontSize: cellFs,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF64748B),
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible),
                      ),
                    )),

                    // Date
                    DataCell(Text(
                      entry.date.isEmpty ? '—' : entry.date,
                      style: const TextStyle(
                        fontSize: cellFs,
                        color: Color(0xFF64748B),
                      ),
                    )),

                    // Actions
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ActionIconButton(
                          icon: Icons.edit_outlined,
                          color: const Color(0xFF2563EB),
                          tooltip: 'Edit',
                          onPressed: () {
                            netamntrecController.text =
                                formatIndianNumber(entry.amount);
                            netamntrecdrmksController.text = entry.remarks;
                            setState(() {
                              _netamntrecdEntries.removeAt(i);
                              _updatenetamntrecdTotalController();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Edit the entry and click Add to update'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        _ActionIconButton(
                          icon: Icons.delete_outline,
                          color: const Color(0xFFDC2626),
                          tooltip: 'Delete',
                          onPressed: () {
                            setState(() {
                              _netamntrecdEntries.removeAt(i);
                              _updatenetamntrecdTotalController();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  'Deleted: ₹ ${formatIndianNumber(entry.amount)}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 1),
                            ));
                          },
                        ),
                      ],
                    )),
                  ],
                );
              }),

              // ── total row ──────────────────────────────────────────────────
              DataRow(
                color: WidgetStateProperty.all(
                    Colors.indigo.shade50.withOpacity(0.6)),
                cells: [
                  // S.No — summary icon
                  DataCell(Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(Icons.summarize,
                        size: 16, color: Colors.indigo.shade700),
                  )),
                  // Total Amount
                  DataCell(Align(
                    alignment: Alignment.centerRight,
                    child: Text('₹ ${formatIndianNumber(totalAmount)}',
                        style: TextStyle(
                          fontSize: cellFs + 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo.shade800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  )),
                  // "Total" label
                  DataCell(SizedBox(
                    width: 180,
                    child: Text('Total',
                        style: TextStyle(
                          fontSize: cellFs + 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo.shade800,
                        )),
                  )),
                  const DataCell(SizedBox()), // Date — blank

                  const DataCell(SizedBox(width: 80)), // Actions — blank
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updatenetamntrecdTotalController() {
    final total = _netamntrecdEntries.fold(0.0, (sum, e) => sum + e.amount);
    _netamntrecdTotalController.text = formatIndianNumber(total);
    _calculateTotals();
  }
}

Future<io.File> _saveToFile(String name, List<int> bytes) async {
  final tempDir = await getTemporaryDirectory();
  final file = io.File('${tempDir.path}/$name');
  return await file.writeAsBytes(bytes);
}

class IndianNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // ← If it contains operators, don't format — let it stay as expression
    if (RegExp(r'[+\-*/%(). ]').hasMatch(newValue.text)) {
      return newValue;
    }

    String digitsOnly = newValue.text.replaceAll(',', '');

    if (!RegExp(r'^\d*$').hasMatch(digitsOnly)) return oldValue;
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    final formatted = formatIndianNumber(int.parse(digitsOnly));

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String formatIndianNumber(num value) {
  final isNegative = value < 0;
  final intVal = value.abs().round();
  final str = intVal.toString();

  String formatted;
  if (str.length <= 3) {
    formatted = str;
  } else {
    final lastThree = str.substring(str.length - 3);
    final rest = str.substring(0, str.length - 3);
    final restFormatted = rest.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{2})+$)'),
      (match) => '${match.group(1)},',
    );
    formatted = '$restFormatted,$lastThree';
  }

  return isNegative ? '-$formatted' : formatted;
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
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
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
