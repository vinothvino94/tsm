import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';

class BillingEntryScreen extends StatefulWidget {
  final SalesStagelistModel? stagelistData;
  final bool? isReadOnly;
  const BillingEntryScreen({
    super.key,
    this.stagelistData,
    this.isReadOnly = false,
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
  TextEditingController invnoController = TextEditingController();

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
  DateTime? invDate;

  @override
  void initState() {
    super.initState();
    loadCustomers();
    _loadUserDetails();
  }

  @override
  Widget _build(BuildContext context) {
    final isEditing = widget.stagelistData != null && !widget.isReadOnly!;
    final isViewOnly = widget.isReadOnly == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Update'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final minWidth =
              constraints.maxWidth < 600 ? 600.0 : constraints.maxWidth;

          return SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Container(
                width: minWidth,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
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
                                    decoration:
                                        _inputDecoration("Customer Name"),
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
                                                .contains(
                                                    textEditingValue.text);
                                      });
                                    },
                                    onSelected: (ChecklistCustomer selection) {
                                      debugPrint(
                                          'Selected Customer: ${selection.companyName}, ID: ${selection.customerId}');

                                      customerController.text =
                                          "${selection.customerId} - ${selection.companyName}";

                                      setState(() {
                                        selectedCustomerId =
                                            selection.customerId;
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
                                                  .contains(textEditingValue
                                                      .text
                                                      .toLowerCase()) ||
                                              project.projectId
                                                  .toString()
                                                  .contains(
                                                      textEditingValue.text);
                                        });
                                      },
                                      onSelected: (Project selection) {
                                        siteController.text =
                                            "${selection.projectId} - ${selection.projectName}";
                                        setState(() {
                                          selectedProjectId =
                                              selection.projectId;
                                        });

                                        // **ADD THIS LINE - Load stages when project is selected**
                                        if (selectedCustomerId != null) {
                                          loadStagesFromApi(selectedCustomerId!,
                                              selection.projectId);
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
                                            suffixIcon: controller
                                                    .text.isNotEmpty
                                                ? IconButton(
                                                    icon:
                                                        const Icon(Icons.clear),
                                                    onPressed: () {
                                                      controller.clear();
                                                      siteController.clear();
                                                      setState(() {
                                                        selectedProjectId =
                                                            null;
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
                                          autovalidateMode: AutovalidateMode
                                              .onUserInteraction,
                                        );
                                      },
                                    )),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildStageInputSection(),
                      const SizedBox(height: 16),

                      ///Amount, Invoice No & Invoice Date
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
                                suffixIcon: amountController.text.isNotEmpty &&
                                        !isViewOnly
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
                                labelText: "INV No",
                                hintText: "INV No",
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                suffixIcon: invnoController.text.isNotEmpty &&
                                        !isViewOnly
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
                              controller: TextEditingController(
                                text: invDate != null
                                    ? DateFormat('yyyy-MM-dd').format(invDate!)
                                    : '',
                              ),
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: "INV Date",
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
                                      await _selectDate(context);
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Submit Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryDark
                                  ],
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  child: Center(
                                    child: Text(
                                      'Submit',
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
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.stagelistData != null && !widget.isReadOnly!;
    final isViewOnly = widget.isReadOnly == true;
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing Update'),
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

              ///Amount, Invoice No & Invoice Date
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
                          labelText: "INV No",
                          hintText: "INV No",
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
                    labelText: "INV Date",
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
                          await _selectDate(context);
                        },
                ),
              ] else ...[
                // Windows/Other: All three in a single row
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
                          labelText: "INV No",
                          hintText: "INV No",
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
                        controller: TextEditingController(
                          text: invDate != null
                              ? DateFormat('yyyy-MM-dd').format(invDate!)
                              : '',
                        ),
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "INV Date",
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
                                await _selectDate(context);
                              },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              ///Submit Button
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
                              'Submit',
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

  Future<void> loadStagesFromApi(int customerId, int projectId) async {
    print("Loading stages for Customer: $customerId, Project: $projectId");

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

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("API Success: ${data['Success']}");
        print("Total tickets received: ${data['Tickets']?.length}");

        if (data['Success'] == true) {
          final List tickets = data['Tickets'] ?? [];

          final filteredStages = tickets
              .map((ticket) => SalesStagelistModel.fromJson(ticket))
              .where((stage) {
            bool matches = stage.cusid == customerId &&
                stage.projid == projectId &&
                stage.deleted == "N";
            print(
                "Stage: ${stage.stagename}, CUSID: ${stage.cusid}, PROJID: ${stage.projid}, Matches: $matches");
            return matches;
          }).toList();

          print("Filtered stages count: ${filteredStages.length}");

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
      final billing = SalesBillingModel(
        sbno: 0, // For Insert. Use existing SBNO for Update.
        cusid: selectedCustomerId,
        projid: selectedProjectId,
        stageid: selectedstageId,
        amount: double.tryParse(amountController.text),
        invno: invnoController.text.trim(),
        invdt: invDate,
        adduser: empCode,
      );

      final result = await saveSalesBilling(billing);

      if (!mounted) return;

      if (result['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Billing Entry Saved Successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Optional: Clear form
        _formKey.currentState?.reset();
        customerController.clear();
        siteController.clear();
        amountController.clear();
        invnoController.clear();
        stageController.clear();
        invDate = null;
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
                validator: (value) {
                  if (!isViewOnly &&
                      (value == null || value.trim().isEmpty) &&
                      selectedstageId == null) {
                    return 'Please enter stage name or select from dropdown';
                  }
                  return null;
                },
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: invDate ?? now,
      firstDate: DateTime(1900), // Earliest allowed date
      lastDate: DateTime(2100), // Latest allowed date
    );

    if (picked != null && picked != invDate) {
      setState(() {
        invDate = picked;
      });
    }
  }

  Future<Map<String, dynamic>> saveSalesBilling(
      SalesBillingModel billing) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('SaveSalesBillinglist'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(billing.toJson()),
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
