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
  TextEditingController totbillamountController = TextEditingController();
  TextEditingController itController = TextEditingController();
  TextEditingController otherDeductionController = TextEditingController();
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
  TextEditingController retentionAmountController = TextEditingController();

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

  @override
  void initState() {
    super.initState();
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
    amountController.removeListener(_calculateTotals);
    gstController.removeListener(_calculateTotals);
    gstAmountController.dispose();
    otherDeductionController.dispose();
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
                                loadStagesFromApi(
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

              _buildStageInputSection(),
              const SizedBox(height: 16),

              ///Bill No & Invoice Date & Bill Description
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
                  controller: TextEditingController(
                    text: invDate != null
                        ? DateFormat('yyyy-MM-dd').format(invDate!)
                        : '',
                  ),
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
                    Expanded(
                      child: TextFormField(
                        controller: TextEditingController(
                          text: invDate != null
                              ? DateFormat('yyyy-MM-dd').format(invDate!)
                              : '',
                        ),
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
              ],
              const SizedBox(height: 16),

              ///Amount & GST Percentage & GST Amount & Total Bill Amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Amount
                  Expanded(
                    child: TextFormField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: "Amount",
                        hintText: "Amount",
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

                  // 2. GST %
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

                  // 3. GST Amount (auto calculated)
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

                  // 4. Total Bill Amount (auto calculated)
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
              Text(
                'Deductions',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              ///IT & Retention
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ///IT % Amount
                  Expanded(
                    child: TextFormField(
                      controller: itController,
                      decoration: InputDecoration(
                        labelText: "IT",
                        hintText: "IT",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (itController.text.isNotEmpty)
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
                            if (itController.text.isNotEmpty && !isViewOnly)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    itController.clear();
                                    _calculateTotals();
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
                      onChanged: (value) {
                        setState(() {
                          _calculateTotals();
                        });
                      },
                      onEditingComplete: () {
                        _appendPercent(itController);
                        FocusScope.of(context).nextFocus();
                      },
                      onTapOutside: (_) => _appendPercent(itController),
                    ),
                  ),
                  const SizedBox(width: 16),

                  ///IT Amount (auto calculated)
                  Expanded(
                    child: TextFormField(
                      controller: itAmountController,
                      decoration: const InputDecoration(
                        labelText: "IT Amount",
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

                  ///Retention % Amount
                  Expanded(
                    child: TextFormField(
                      controller: retentionController,
                      decoration: InputDecoration(
                        labelText: "Retention",
                        hintText: "Retention",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (retentionController.text.isNotEmpty)
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
                            if (retentionController.text.isNotEmpty &&
                                !isViewOnly)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    retentionController.clear();
                                    _calculateTotals();
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
                      onChanged: (value) {
                        setState(() {
                          _calculateTotals();
                        });
                      },
                      onEditingComplete: () {
                        _appendPercent(retentionController);
                        FocusScope.of(context).nextFocus();
                      },
                      onTapOutside: (_) => _appendPercent(retentionController),
                    ),
                  ),
                  const SizedBox(width: 16),

                  ///Retention Amount (auto calculated)
                  Expanded(
                    child: TextFormField(
                      controller: retentionAmountController,
                      decoration: const InputDecoration(
                        labelText: "Retention Amount",
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

              ///Other Deduction & With held
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: otherDeductionController,
                      decoration: InputDecoration(
                        labelText: "Other Deduction / Material",
                        hintText: "Other Deduction / Material",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: otherDeductionController.text.isNotEmpty &&
                                !isViewOnly
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    otherDeductionController.clear();
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: whController,
                      decoration: InputDecoration(
                        labelText: "With held",
                        hintText: "With held",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon: whController.text.isNotEmpty && !isViewOnly
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    whController.clear();
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

              ///With held Release & Total Deduction & Net receivable
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /*Expanded(
                    child: TextFormField(
                      controller: whrlController,
                      decoration: InputDecoration(
                        labelText: "With held release",
                        hintText: "With held release",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            whrlController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        whrlController.clear();
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
                  const SizedBox(width: 16),*/
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

              ///Net amount received & Date & Outstanding
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: netamntrecController,
                      decoration: InputDecoration(
                        labelText: "Net amount received",
                        hintText: "Net amount received",
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
                  Expanded(
                    child: TextFormField(
                      controller: TextEditingController(
                        text: recDate != null
                            ? DateFormat('yyyy-MM-dd').format(recDate!)
                            : '',
                      ),
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
                  const SizedBox(width: 16),
                  Expanded(
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
                ],
              ),
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

  void _calculateTotals() {
    final amount =
        double.tryParse(amountController.text.replaceAll(',', '').trim()) ?? 0;
    final gst = double.tryParse(gstController.text.trim()) ?? 0;
    final it =
        double.tryParse(itController.text.replaceAll('%', '').trim()) ?? 0;
    final retention =
        double.tryParse(retentionController.text.replaceAll('%', '').trim()) ??
            0;

    // GST Amount & Total Bill Amount
    if (amount > 0 && gst > 0) {
      final gstAmount = (amount * gst) / 100;
      final roundedGstAmount = gstAmount.round();
      final total = amount.round() + roundedGstAmount;

      final newGstAmount = formatIndianNumber(roundedGstAmount);
      final newTotal = formatIndianNumber(total);

      if (gstAmountController.text != newGstAmount) {
        gstAmountController.text = newGstAmount;
      }
      if (totbillamountController.text != newTotal) {
        totbillamountController.text = newTotal;
      }
    } else {
      gstAmountController.clear();
      totbillamountController.clear();
    }

    // IT Amount calculation (based on Amount)
    if (amount > 0 && it > 0) {
      final itAmount = (amount * it) / 100;
      final roundedItAmount = itAmount.round();
      final newItAmount = formatIndianNumber(roundedItAmount);

      if (itAmountController.text != newItAmount) {
        itAmountController.text = newItAmount;
      }
    } else {
      itAmountController.clear();
    }

    // Retention Amount calculation (based on Amount)
    double retentionAmountValue = 0;
    if (amount > 0 && retention > 0) {
      final retentionAmount = (amount * retention) / 100;
      retentionAmountValue = retentionAmount.round().toDouble();
      final newRetentionAmount = formatIndianNumber(retentionAmountValue);

      if (retentionAmountController.text != newRetentionAmount) {
        retentionAmountController.text = newRetentionAmount;
      }
    } else {
      retentionAmountController.clear();
    }

    // Total Deduction = IT Amount + Retention Amount + Other Deduction + With Held
    final otherDeduction = double.tryParse(
            otherDeductionController.text.replaceAll(',', '').trim()) ??
        0;
    final itAmount =
        double.tryParse(itAmountController.text.replaceAll(',', '').trim()) ??
            0;
    final withHeld =
        double.tryParse(whController.text.replaceAll(',', '').trim()) ?? 0;

    final totalDeduction =
        itAmount + retentionAmountValue + otherDeduction + withHeld;

    if (totalDeduction > 0) {
      final newTotalDeduction = formatIndianNumber(totalDeduction);
      if (totdedController.text != newTotalDeduction) {
        totdedController.text = newTotalDeduction;
      }
    } else {
      totdedController.clear();
    }

    // Net Receivable = Total Bill Amount - Total Deduction
    final totalBillAmount = double.tryParse(
            totbillamountController.text.replaceAll(',', '').trim()) ??
        0;
    final totalDeductionValue =
        double.tryParse(totdedController.text.replaceAll(',', '').trim()) ?? 0;

    final netReceivable = totalBillAmount - totalDeductionValue;

    if (totalBillAmount > 0) {
      final newNetReceivable = formatIndianNumber(netReceivable);
      if (netrecController.text != newNetReceivable) {
        netrecController.text = newNetReceivable;
      }
    } else {
      netrecController.clear();
    }

    // Outstanding = Total Bill Amount - Net Amount Received
    final netAmountReceived =
        double.tryParse(netamntrecController.text.replaceAll(',', '').trim()) ??
            0;

    final outstanding = netReceivable - netAmountReceived;

    if (totalBillAmount > 0) {
      final newOutstanding = formatIndianNumber(outstanding);
      if (osController.text != newOutstanding) {
        osController.text = newOutstanding;
      }
    } else {
      osController.clear();
    }
  }

  void _appendPercent(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return; // don't add % to empty field
    if (!text.endsWith('%')) {
      controller.text = '$text%';
      controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length),
      );
    }
    setState(() {});
  }

  Future<void> loadStagesFromApi(int customerId, int projectId) async {
    setState(() {
      isLoadingStages = true;
      dynamicStages = {};
      selectedstageId = null;
      stageController.clear();
    });

    try {
      final response = await http.post(
        ApiUtils.getUri('StageViewList'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "CUSID": customerId,
          "PROJID": projectId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true) {
          final List tickets = data['Tickets'] ?? [];

          final filteredStages = tickets
              .map((ticket) => SalesStagelistModel.fromJson(ticket))
              .where((stage) {
            bool matches = stage.cusid == customerId &&
                stage.projid == projectId &&
                stage.deleted == "N";
            return matches;
          }).toList();

          setState(() {
            stageList = filteredStages;
            for (var stage in stageList) {
              if (stage.stageid != null && stage.stagename != null) {
                dynamicStages[stage.stageid!] = stage.stagename!;
              }
            }
          });
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

  Future<void> _submitForm() async {
    try {
      final isEditing = widget.billingData != null;

      // Prepare new files for upload
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

      // Create billing model
      final billing = SalesBillingModel(
        sbno: isEditing ? (widget.billingData?.sbno ?? 0) : 0,
        cusid: selectedCustomerId,
        projid: selectedProjectId,
        stageid: selectedstageId ??
            (stageController.text.isNotEmpty ? stageController.text : null),
        billno: invnoController.text.trim(),
        billdate: invDate,
        billdesc: descController.text.trim(),
        billamnt:
            double.tryParse(amountController.text.replaceAll(',', '').trim()),
        gstper: double.tryParse(gstController.text.trim()),
        gstamnt: double.tryParse(
            gstAmountController.text.replaceAll(',', '').trim()),
        billtotamnt: double.tryParse(
            totbillamountController.text.replaceAll(',', '').trim()),
        itper: double.tryParse(itController.text.replaceAll('%', '').trim()),
        itamnt:
            double.tryParse(itAmountController.text.replaceAll(',', '').trim()),
        retnper: double.tryParse(
            retentionController.text.replaceAll('%', '').trim()),
        retnamnt: double.tryParse(
            retentionAmountController.text.replaceAll(',', '').trim()),
        dedamnt: double.tryParse(
            otherDeductionController.text.replaceAll(',', '').trim()),
        whamnt:
            double.tryParse(whController.text.replaceAll(',', '').trim()) ?? 0,
        whrlseamnt:
            double.tryParse(whrlController.text.replaceAll(',', '').trim()) ??
                0,
        recamnt: double.tryParse(
            netamntrecController.text.replaceAll(',', '').trim()),
        recdate: recDate,
        adduser: empCode,
        files: uploadFiles,
      );

      // Create request body
      final requestBody = billing.toJson();

      // ✅ Add REMOVEDFILES to the request body
      if (_removedFiles.isNotEmpty) {
        requestBody['REMOVEDFILES'] = _removedFiles.join(",");
        print('Removed files: ${_removedFiles.join(",")}');
      }

      // Add EDITUSER for update
      if (isEditing) {
        requestBody['EDITUSER'] = empCode;
      }

      print('Request Body: ${jsonEncode(requestBody)}');

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

        // ✅ Call onDataSaved callback if provided
        if (widget.onDataSaved != null) {
          widget.onDataSaved!();
        }

        // Navigate back with result to refresh the list
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

  Widget _buildStageInputSection() {
    final isViewOnly = widget.isReadOnly == true;
    final hasStages = dynamicStages.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
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
                                  print("Clear Stage ID button pressed");
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
                        final stageId = entry.key;
                        final stageName = entry.value;
                        return DropdownMenuItem<String>(
                          value: stageId,
                          child: Text('$stageId'),
                        );
                      }).toList(),
                      onChanged: (isViewOnly || !hasStages || isLoadingStages)
                          ? null
                          : (value) {
                              print("Dropdown changed - New value: $value");
                              setState(() {
                                selectedstageId = value;
                                // Auto-fill stage name when dropdown is selected
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
                            stageController.text.trim().isEmpty) {
                          return 'Please select a stage or enter custom stage name';
                        }
                        return null;
                      },
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
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
                            print("Clear Stage Name button pressed");
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
                minLines: 1, // ← starts as single line
                maxLines: null, // ← grows automatically with content
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction
                    .newline, // ← allows newline on Android keyboard
                readOnly: isViewOnly,
                enabled: !isViewOnly,

                onChanged: (value) {
                  print("Stage name text changed: '$value'");
                  if (value.isNotEmpty && selectedstageId != null) {
                    setState(() {
                      selectedstageId = null;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        // Show info message
        if (!isLoadingStages &&
            !hasStages &&
            selectedCustomerId != null &&
            selectedProjectId != null &&
            !isViewOnly)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'No stages found for this project. You can enter a custom stage name.',
              style: TextStyle(color: Colors.orange[700], fontSize: 12),
            ),
          ),
      ],
    );
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
        } else {
          recDate = picked;
        }
      });
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

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

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
      retentionAmountController.text = data.retnamnt != null
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
    final extension = fileName.split('.').last.toLowerCase();

    // Show a message since we don't have the file bytes locally
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File stored on server: $fileName'),
        backgroundColor: Colors.blue,
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

    // Remove existing commas to get raw digits
    String digitsOnly = newValue.text.replaceAll(',', '');

    // Allow only digits (no decimals for amount; remove this check if you need decimals)
    if (!RegExp(r'^\d*$').hasMatch(digitsOnly)) {
      return oldValue;
    }

    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    final formatted = formatIndianNumber(int.parse(digitsOnly));

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String formatIndianNumber(num value) {
  final intVal = value.round();
  final str = intVal.toString();
  if (str.length <= 3) return str;

  final lastThree = str.substring(str.length - 3);
  final rest = str.substring(0, str.length - 3);
  final restFormatted = rest.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{2})+$)'),
    (match) => '${match.group(1)},',
  );
  return '$restFormatted,$lastThree';
}
