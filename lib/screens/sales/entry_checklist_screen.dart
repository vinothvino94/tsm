import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:tsm/api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';

class EntryChecklistScreen extends StatefulWidget {
  final SalesChecklistModel? checklistData;
  final bool? isReadOnly;
  const EntryChecklistScreen({
    super.key,
    this.checklistData,
    this.isReadOnly = false,
  });

  @override
  State<EntryChecklistScreen> createState() => _EntryChecklistScreenState();
}

class _EntryChecklistScreenState extends State<EntryChecklistScreen> {
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  TextEditingController customerController = TextEditingController();
  TextEditingController siteController = TextEditingController();
  TextEditingController verifiedbyController = TextEditingController();
  TextEditingController reviewedbyController = TextEditingController();
  TextEditingController siteaddressController = TextEditingController();
  TextEditingController billingaddressController = TextEditingController();
  TextEditingController sitegstController = TextEditingController();
  TextEditingController billgstController = TextEditingController();
  TextEditingController tenureController = TextEditingController();
  TextEditingController liabilityController = TextEditingController();
  TextEditingController contractController = TextEditingController();
  TextEditingController methodofbillingController = TextEditingController();
  TextEditingController billingfrequencyController = TextEditingController();
  TextEditingController milestonesController = TextEditingController();
  TextEditingController retentionController = TextEditingController();
  TextEditingController workscopeController = TextEditingController();
  TextEditingController waterproffingController = TextEditingController();
  TextEditingController antitermiteController = TextEditingController();
  TextEditingController siteaccController = TextEditingController();
  TextEditingController dewateringController = TextEditingController();
  TextEditingController electricitywaterController = TextEditingController();
  TextEditingController steelcementController = TextEditingController();
  TextEditingController tendermarginController = TextEditingController();
  TextEditingController soilController = TextEditingController();
  TextEditingController statapprovalController = TextEditingController();
  TextEditingController soilsurveyController = TextEditingController();
  TextEditingController barricationController = TextEditingController();
  TextEditingController treecuttingController = TextEditingController();
  TextEditingController labouraccController = TextEditingController();
  TextEditingController brickworkController = TextEditingController();
  TextEditingController sitesecController = TextEditingController();
  TextEditingController lightarrController = TextEditingController();
  TextEditingController jointreqController = TextEditingController();
  TextEditingController bankguaranteerequirementsController =
      TextEditingController();
  TextEditingController workordervalueincludinggstController =
      TextEditingController();
  int? selectedProjectId;
  bool isSameAsSiteAddress = false;
  bool isSameAsSiteGST = false;
  DateTime? efffectiveDate;
  final List<String> bankreq = [
    'Retention BG',
    'Mobilization Advance BG',
    'Performance BG',
  ];
  final List<String> esclbas = [
    'Yes',
    'No',
  ];
  final List<String> taxstructure = [
    '12%',
    '18%',
  ];
  final List<String> workscopesigned = [
    'Yes',
    'No',
  ];
  final List<String> workscopeoption = [
    'Client',
    'Teemage',
  ];
  final List<String> waterproofingsigned = [
    'Yes',
    'No',
  ];
  final List<String> waterproofingoption = [
    'Client',
    'Teemage',
  ];
  final List<String> antitermitesigned = [
    'Yes',
    'No',
  ];
  final List<String> antitermiteoption = [
    'Client',
    'Teemage',
  ];
  final List<String> siteaccsigned = [
    'Yes',
    'No',
  ];
  final List<String> siteaccoption = [
    'Client',
    'Teemage',
  ];
  final List<String> dewateringsigned = [
    'Yes',
    'No',
  ];
  final List<String> dewateringoption = [
    'Client',
    'Teemage',
  ];
  final List<String> electricitywatersigned = [
    'Yes',
    'No',
  ];
  final List<String> electricitywateroption = [
    'Client',
    'Teemage',
  ];
  final List<String> steelcementsigned = [
    'Yes',
    'No',
  ];
  final List<String> steelcementoption = [
    'Client',
    'Teemage',
  ];
  final List<String> tendermarginsigned = [
    'Yes',
    'No',
  ];
  final List<String> tendermarginoption = [
    'Client',
    'Teemage',
  ];
  final List<String> soilsigned = [
    'Yes',
    'No',
  ];
  final List<String> soiloption = [
    'Client',
    'Teemage',
  ];
  final List<String> barricationsigned = [
    'Yes',
    'No',
  ];
  final List<String> barricationoption = [
    'Client',
    'Teemage',
  ];
  final List<String> statapprovalsigned = [
    'Yes',
    'No',
  ];
  final List<String> statapprovaloption = [
    'Client',
    'Teemage',
  ];
  final List<String> soilsurveysigned = [
    'Yes',
    'No',
  ];
  final List<String> soilsurveyoption = [
    'Client',
    'Teemage',
  ];
  final List<String> treecuttingsigned = [
    'Yes',
    'No',
  ];
  final List<String> treecuttingoption = [
    'Client',
    'Teemage',
  ];
  final List<String> labouraccsigned = [
    'Yes',
    'No',
  ];
  final List<String> labouraccoption = [
    'Client',
    'Teemage',
  ];
  final List<String> brickworksigned = [
    'Yes',
    'No',
  ];
  final List<String> brickworkoption = [
    'Client',
    'Teemage',
  ];
  final List<String> sitesecsigned = [
    'Yes',
    'No',
  ];
  final List<String> sitesecoption = [
    'Client',
    'Teemage',
  ];
  final List<String> lightarrsigned = [
    'Yes',
    'No',
  ];
  final List<String> lightarroption = [
    'Client',
    'Teemage',
  ];
  final List<String> forcemajsigned = [
    'Yes',
    'No',
    'Not Available',
  ];
  final List<String> arbitrationsigned = [
    'Yes',
    'No',
    'Not Available',
  ];
  final List<String> labourcompsigned = [
    'ESI,PF,LWF,WC',
    'Car Policy',
    'Third Party Liability Insurance',
    'Not Available',
  ];
  final List<String> liqdamagesigned = [
    'Yes',
    'No',
    'Not Available',
  ];
  final List<String> stabilitysigned = [
    'Yes',
    'No',
    'Not Available',
  ];
  final List<String> groutsigned = [
    'Yes',
    'No',
    'Not Available',
  ];
  final List<String> jointreqsigned = [
    'Yes',
    'No',
  ];
  final List<String> jointreqoption = [
    'Client',
    'Teemage',
  ];
  final List<String> idlechargsigned = [
    'Yes',
    'No',
    'Not Available',
  ];
  final List<String> thirdpartytestsigned = [
    'Yes',
    'No',
    'Not Available',
  ];
  String? selectedbankreq;
  String? selectedescl;
  String? selectedtax;
  String? workscope;
  String? waterproofing;
  String? antitermite;
  String? siteacc;
  String? dewatering;
  String? electricitywater;
  String? steelcement;
  String? tendermargin;
  String? soil;
  String? barrication;
  String? treecutting;
  String? statapproval;
  String? soilsurvey;
  String? labouracc;
  String? brickwork;
  String? sitesec;
  String? lightarr;
  String? forcemaj;
  String? arbitration;
  String? labourcomp;
  String? liqdamage;
  String? stability;
  String? grout;
  String? jointreq;
  String? idlecharg;
  String? thirdpartytest;
  String? selectedworkscope;
  String? selectedwaterproffing;
  String? selectedantitermite;
  String? selectedsiteacc;
  String? selecteddewatering;
  String? selectedelectricitywater;
  String? selectedsteelcement;
  String? selectedtendermargin;
  String? selectedsoil;
  String? selectedbarrication;
  String? selectedstatapproval;
  String? selectedsoilsurvey;
  String? selectedtreecutting;
  String? selectedlabouracc;
  String? selectedbrickwork;
  String? selectedsitesec;
  String? selectedlightarr;
  String? selectedforcemaj;
  String? selectedarbitration;
  String? selectedlabourcomp;
  String? selectedliqdamage;
  String? selectedstability;
  String? selectedgrout;
  String? selectedjointreq;
  String? selectedidlecharg;
  String? selectedthirdpartytest;

  List<SalesEmployeeModel> salesEmployees = [];
  List<CustomerModel> customerList = [];
  List<Project> projectList = [];

  int? selectedCustomerId;
  int empCode = 0;
  String empName = '';

  @override
  void initState() {
    super.initState();
    loadSalesDetails();
    loadCustomers();
    _loadUserDetails();
    if (widget.checklistData != null) {
      _populateFormWithData(widget.checklistData!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.checklistData != null && !widget.isReadOnly!;
    final isViewOnly = widget.isReadOnly == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(isViewOnly
            ? 'View Check List #${widget.checklistData?.chklno ?? ''}'
            : (isEditing
                ? 'Edit Check List Entry #${widget.checklistData?.chklno ?? ''}'
                : 'Check List Entry')),
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
        actions: isViewOnly
            ? [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EntryChecklistScreen(
                          checklistData: widget.checklistData,
                          isReadOnly: false,
                        ),
                      ),
                    );
                  },
                  tooltip: 'Edit',
                ),
              ]
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate minimum width needed for content
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
                                : Autocomplete<CustomerModel>(
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
                                                .contains(
                                                  textEditingValue.text
                                                      .toLowerCase(),
                                                ) ||
                                            customer.customerId
                                                .toString()
                                                .contains(
                                                    textEditingValue.text);
                                      });
                                    },
                                    onSelected: (CustomerModel selection) {
                                      customerController.text =
                                          "${selection.customerId} - ${selection.companyName}";
                                      setState(() {
                                        selectedCustomerId =
                                            selection.customerId;
                                        selectedProjectId = null;
                                        siteController.clear();
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
                                                .contains(
                                                  textEditingValue.text
                                                      .toLowerCase(),
                                                ) ||
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
                                        autovalidateMode:
                                            AutovalidateMode.onUserInteraction,
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      /// Verified By & Reviewed By
                      Row(
                        children: [
                          Expanded(
                            child: isViewOnly
                                ? TextFormField(
                                    controller: verifiedbyController,
                                    decoration: _inputDecoration("Verified By")
                                        .copyWith(
                                      suffixIcon: verifiedbyController
                                              .text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear,
                                                  size: 18),
                                              onPressed: () {
                                                setState(() {
                                                  verifiedbyController.clear();
                                                });
                                              },
                                              padding: EdgeInsets.zero,
                                              tooltip: 'Clear',
                                            )
                                          : null,
                                    ),
                                    readOnly: true,
                                    enabled: false,
                                  )
                                : Autocomplete<SalesEmployeeModel>(
                                    displayStringForOption: (option) =>
                                        "${option.empCode} - ${option.empName} ",
                                    optionsBuilder:
                                        (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return salesEmployees;
                                      }
                                      return salesEmployees.where((employee) {
                                        return employee.empName
                                                .toLowerCase()
                                                .contains(textEditingValue.text
                                                    .toLowerCase()) ||
                                            employee.empCode
                                                .toString()
                                                .contains(
                                                    textEditingValue.text);
                                      });
                                    },
                                    onSelected: (SalesEmployeeModel selection) {
                                      verifiedbyController.text =
                                          "${selection.empCode} - ${selection.empName}";
                                    },
                                    fieldViewBuilder: (
                                      context,
                                      controller,
                                      focusNode,
                                      onFieldSubmitted,
                                    ) {
                                      controller.text =
                                          verifiedbyController.text;
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          labelText: "Verified By",
                                          hintText: "Search Employee",
                                          border: const OutlineInputBorder(),
                                          suffixIcon: controller.text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear,
                                                      size: 18),
                                                  onPressed: () {
                                                    controller.clear();
                                                    verifiedbyController
                                                        .clear();
                                                    setState(() {});
                                                  },
                                                  padding: EdgeInsets.zero,
                                                  tooltip: 'Clear',
                                                )
                                              : null,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: isViewOnly
                                ? TextFormField(
                                    controller: reviewedbyController,
                                    decoration: _inputDecoration("Reviewed By")
                                        .copyWith(
                                      suffixIcon: reviewedbyController
                                              .text.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear,
                                                  size: 18),
                                              onPressed: () {
                                                setState(() {
                                                  reviewedbyController.clear();
                                                });
                                              },
                                              padding: EdgeInsets.zero,
                                              tooltip: 'Clear',
                                            )
                                          : null,
                                    ),
                                    readOnly: true,
                                    enabled: false,
                                  )
                                : Autocomplete<SalesEmployeeModel>(
                                    displayStringForOption: (option) =>
                                        "${option.empCode} - ${option.empName} ",
                                    optionsBuilder:
                                        (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return salesEmployees;
                                      }
                                      return salesEmployees.where((employee) {
                                        return employee.empName
                                                .toLowerCase()
                                                .contains(textEditingValue.text
                                                    .toLowerCase()) ||
                                            employee.empCode
                                                .toString()
                                                .contains(
                                                    textEditingValue.text);
                                      });
                                    },
                                    onSelected: (SalesEmployeeModel selection) {
                                      reviewedbyController.text =
                                          "${selection.empCode} - ${selection.empName}";
                                    },
                                    fieldViewBuilder: (
                                      context,
                                      controller,
                                      focusNode,
                                      onFieldSubmitted,
                                    ) {
                                      controller.text =
                                          reviewedbyController.text;
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          labelText: "Reviewed By",
                                          hintText: "Search Employee",
                                          border: const OutlineInputBorder(),
                                          suffixIcon: controller.text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear,
                                                      size: 18),
                                                  onPressed: () {
                                                    controller.clear();
                                                    reviewedbyController
                                                        .clear();
                                                    setState(() {});
                                                  },
                                                  padding: EdgeInsets.zero,
                                                  tooltip: 'Clear',
                                                )
                                              : null,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Center(
                        child: Text(
                          'Checklist for Contract Signing',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      ///Generic Details
                      Text(
                        'Generic Details',
                        style: TextStyle(
                            fontSize: 16, color: AppColors.primaryLight),
                      ),
                      const SizedBox(height: 16),

                      ///Site Address & Billing Address
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: TextFormField(
                            controller: siteaddressController,
                            decoration: InputDecoration(
                              labelText: "Site Address",
                              hintText: "Site Address",
                              border: const OutlineInputBorder(),
                              suffixIcon: siteaddressController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          siteaddressController.clear();
                                          if (isSameAsSiteAddress) {
                                            billingaddressController.clear();
                                            isSameAsSiteAddress = false;
                                          }
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
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                          )),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: billingaddressController,
                                  decoration: InputDecoration(
                                    labelText: "Billing Address",
                                    hintText: "Billing Address",
                                    border: const OutlineInputBorder(),
                                    suffixIcon: billingaddressController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear,
                                                size: 18),
                                            onPressed: () {
                                              setState(() {
                                                billingaddressController
                                                    .clear();
                                                if (isSameAsSiteAddress) {
                                                  isSameAsSiteAddress = false;
                                                }
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
                                  maxLines: null,
                                  keyboardType: TextInputType.multiline,
                                  readOnly: isViewOnly,
                                  enabled: !isViewOnly,
                                ),
                                const SizedBox(height: 4),
                                if (!isViewOnly) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: isSameAsSiteAddress,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (value) {
                                          setState(() {
                                            isSameAsSiteAddress =
                                                value ?? false;
                                            if (isSameAsSiteAddress) {
                                              billingaddressController.text =
                                                  siteaddressController.text;
                                            } else {
                                              billingaddressController.clear();
                                            }
                                          });
                                        },
                                      ),
                                      const Text(
                                        "Same as Site Address",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Site GST No & Billing GST No
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: sitegstController,
                              inputFormatters: [
                                // Allow only alphanumeric characters (A-Z, a-z, 0-9)
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[a-zA-Z0-9]')),
                                // Optional: Convert to uppercase automatically
                                TextInputFormatter.withFunction(
                                    (oldValue, newValue) {
                                  return newValue.copyWith(
                                    text: newValue.text.toUpperCase(),
                                  );
                                }),
                              ],
                              decoration: InputDecoration(
                                labelText: "Site GST No",
                                hintText: "Site GST No",
                                border: const OutlineInputBorder(),
                                suffixIcon: sitegstController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            sitegstController.clear();
                                            if (isSameAsSiteGST) {
                                              isSameAsSiteGST = false;
                                            }
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear',
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              readOnly: isViewOnly,
                              enabled: !isViewOnly,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: billgstController,
                                  inputFormatters: [
                                    // Allow only alphanumeric characters (A-Z, a-z, 0-9)
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[a-zA-Z0-9]')),
                                    // Optional: Convert to uppercase automatically
                                    TextInputFormatter.withFunction(
                                        (oldValue, newValue) {
                                      return newValue.copyWith(
                                        text: newValue.text.toUpperCase(),
                                      );
                                    }),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: "Billing GST No",
                                    hintText: "Billing GST No",
                                    border: const OutlineInputBorder(),
                                    suffixIcon:
                                        billgstController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear,
                                                    size: 18),
                                                onPressed: () {
                                                  setState(() {
                                                    billgstController.clear();
                                                    if (isSameAsSiteGST) {
                                                      isSameAsSiteGST = false;
                                                    }
                                                  });
                                                },
                                                padding: EdgeInsets.zero,
                                                tooltip: 'Clear',
                                              )
                                            : null,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                  ),
                                  readOnly: isViewOnly,
                                  enabled: !isViewOnly,
                                ),
                                const SizedBox(height: 4),
                                if (!isViewOnly) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: isSameAsSiteGST,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                        onChanged: (value) {
                                          setState(() {
                                            isSameAsSiteGST = value ?? false;
                                            if (isSameAsSiteGST) {
                                              billgstController.text =
                                                  sitegstController.text;
                                            } else {
                                              billgstController.clear();
                                            }
                                          });
                                        },
                                      ),
                                      const Text(
                                        "Same as Site GST No",
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Date & Work Order Value
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: TextEditingController(
                                text: efffectiveDate != null
                                    ? DateFormat('yyyy-MM-dd')
                                        .format(efffectiveDate!)
                                    : '',
                              ),
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: "Effective Date of Agreement",
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (efffectiveDate != null && !isViewOnly)
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            efffectiveDate = null;
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear date',
                                      ),
                                    if (efffectiveDate == null && !isViewOnly)
                                      Icon(
                                        Icons.calendar_today,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                              validator: (value) {
                                if (efffectiveDate == null) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Please select a agreement date'),
                                        duration: Duration(seconds: 2),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  });
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: workordervalueincludinggstController,
                              keyboardType: TextInputType.number,
                              inputFormatters: !isViewOnly
                                  ? [
                                      TextInputFormatter.withFunction(
                                          (oldValue, newValue) {
                                        if (newValue.text.isEmpty) {
                                          return newValue;
                                        }
                                        String value =
                                            newValue.text.replaceAll(',', '');
                                        value = value.replaceAll(
                                            RegExp(r'[^0-9]'), '');
                                        if (value.isEmpty) {
                                          return const TextEditingValue();
                                        }
                                        final formatter =
                                            NumberFormat("#,##,##0", "en_IN");
                                        final newText =
                                            formatter.format(int.parse(value));
                                        return TextEditingValue(
                                          text: newText,
                                          selection: TextSelection.collapsed(
                                            offset: newText.length,
                                          ),
                                        );
                                      }),
                                    ]
                                  : null,
                              readOnly: isViewOnly,
                              enabled: !isViewOnly,
                              decoration: InputDecoration(
                                labelText: "Work order value including GST",
                                hintText: "Work order value including GST",
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                suffixIcon: workordervalueincludinggstController
                                            .text.isNotEmpty &&
                                        !isViewOnly
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            workordervalueincludinggstController
                                                .clear();
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear value',
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Tenure & Liability Period
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: tenureController,
                              decoration: InputDecoration(
                                labelText: "Tenure of the project",
                                hintText: "Tenure of the project",
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                suffixIcon: tenureController.text.isNotEmpty &&
                                        !isViewOnly
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            tenureController.clear();
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear value',
                                      )
                                    : null,
                              ),
                              readOnly: isViewOnly,
                              enabled: !isViewOnly,
                              inputFormatters: [
                                CapitalizeFirstLetterFormatter(), // Add this formatter
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: liabilityController,
                              decoration: InputDecoration(
                                labelText: "Defect liability period",
                                hintText: "Defect liability period",
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                suffixIcon: liabilityController
                                            .text.isNotEmpty &&
                                        !isViewOnly
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            liabilityController.clear();
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear value',
                                      )
                                    : null,
                              ),
                              readOnly: isViewOnly,
                              enabled: !isViewOnly,
                              inputFormatters: [
                                CapitalizeFirstLetterFormatter(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Billing Details
                      Text(
                        'Billing Details',
                        style: TextStyle(
                            fontSize: 16, color: AppColors.primaryLight),
                      ),
                      const SizedBox(height: 16),

                      ///Type of contract
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: contractController,
                              decoration: InputDecoration(
                                labelText: "Type of contract-BOQ or Lumpsum",
                                hintText: "Type of contract-BOQ or Lumpsum",
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                suffixIcon: contractController
                                            .text.isNotEmpty &&
                                        !isViewOnly
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            contractController.clear();
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear value',
                                      )
                                    : null,
                              ),
                              readOnly: isViewOnly,
                              enabled: !isViewOnly,
                              inputFormatters: [
                                CapitalizeFirstLetterFormatter(), // Add this formatter
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: methodofbillingController,
                              decoration: InputDecoration(
                                labelText: "Method of billing",
                                hintText: "Method of billing",
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                suffixIcon: methodofbillingController
                                            .text.isNotEmpty &&
                                        !isViewOnly
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            methodofbillingController.clear();
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

                      ///Billing frequency & Milestones
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: billingfrequencyController,
                              decoration: InputDecoration(
                                labelText: "Billing frequency & payment terms",
                                hintText: "Billing frequency & payment terms",
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                suffixIcon: billingfrequencyController
                                            .text.isNotEmpty &&
                                        !isViewOnly
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            billingfrequencyController.clear();
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear value',
                                      )
                                    : null,
                              ),
                              readOnly: isViewOnly,
                              enabled: !isViewOnly,
                              inputFormatters: [
                                CapitalizeFirstLetterFormatter(), // Add this formatter
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: milestonesController,
                              decoration: InputDecoration(
                                labelText: "Milestones",
                                hintText: "Milestones",
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                suffixIcon: milestonesController
                                            .text.isNotEmpty &&
                                        !isViewOnly
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            milestonesController.clear();
                                          });
                                        },
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear value',
                                      )
                                    : null,
                              ),
                              readOnly: isViewOnly,
                              enabled: !isViewOnly,
                              inputFormatters: [
                                CapitalizeFirstLetterFormatter(), // Add this formatter
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Retention & Bank guarantee
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: retentionController,
                              decoration: InputDecoration(
                                labelText: "Retention",
                                hintText: "Retention",
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                suffixIcon: retentionController
                                            .text.isNotEmpty &&
                                        !isViewOnly
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            retentionController.clear();
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
                            child: DropdownButtonFormField<String>(
                              value: selectedbankreq,
                              decoration: _inputDecoration(
                                      "Bank guarantee requirements")
                                  .copyWith(
                                suffixIcon: (!isViewOnly &&
                                        selectedbankreq != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            selectedbankreq = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: bankreq.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        selectedbankreq = value;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Escalation & Tax Structure
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedescl,
                              decoration:
                                  _inputDecoration("Escalation & basic details")
                                      .copyWith(
                                suffixIcon: (!isViewOnly &&
                                        selectedescl != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            selectedescl = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: esclbas.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        selectedescl = value;
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedtax,
                              decoration:
                                  _inputDecoration("Tax structure changes")
                                      .copyWith(
                                suffixIcon: (!isViewOnly && selectedtax != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            selectedtax = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: taxstructure.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        selectedtax = value;
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Scope clearance
                      Text(
                        'Scope clearance',
                        style: TextStyle(
                            fontSize: 16, color: AppColors.primaryLight),
                      ),
                      const SizedBox(height: 16),

                      /// Scope of works
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: workscope,
                              decoration:
                                  _inputDecoration("Scope of works duly signed")
                                      .copyWith(
                                suffixIcon: (!isViewOnly && workscope != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            workscope = null;
                                            selectedworkscope = null;
                                            workscopeController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: workscopesigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        workscope = value;
                                        if (value == 'No') {
                                          selectedworkscope = null;
                                          workscopeController.text = "Nil";
                                        } else {
                                          workscopeController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (workscope != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedworkscope,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedworkscope != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedworkscope = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: workscopeoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedworkscope = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && workscope == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (workscope == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: workscopeController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (workscopeController.text == "Nil") {
                                    workscopeController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Water Proofing
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: waterproofing,
                              decoration:
                                  _inputDecoration("Waterproofing Methodology")
                                      .copyWith(
                                suffixIcon: (!isViewOnly &&
                                        waterproofing != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            waterproofing = null;
                                            selectedwaterproffing = null;
                                            waterproffingController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: waterproofingsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        waterproofing = value;
                                        if (value == 'No') {
                                          selectedwaterproffing = null;
                                          waterproffingController.text = "Nil";
                                        } else {
                                          waterproffingController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (waterproofing != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedwaterproffing,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedwaterproffing != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedwaterproffing = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: waterproofingoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedwaterproffing = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && waterproofing == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (waterproofing == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: waterproffingController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (waterproffingController.text == "Nil") {
                                    waterproffingController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Anti termite work
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: antitermite,
                              decoration: _inputDecoration("Anti termite work")
                                  .copyWith(
                                suffixIcon: (!isViewOnly && antitermite != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            antitermite = null;
                                            selectedantitermite = null;
                                            antitermiteController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: antitermitesigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        antitermite = value;

                                        if (value == 'No') {
                                          selectedantitermite = null;
                                          antitermiteController.text = "Nil";
                                        } else {
                                          antitermiteController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (antitermite != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedantitermite,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedantitermite != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedantitermite = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: antitermiteoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedantitermite = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && antitermite == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (antitermite == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: antitermiteController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (antitermiteController.text == "Nil") {
                                    antitermiteController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Site access
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: siteacc,
                              decoration: _inputDecoration(
                                      "Site access & local site issues")
                                  .copyWith(
                                suffixIcon: (!isViewOnly && siteacc != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            siteacc = null;
                                            selectedsiteacc = null;
                                            siteaccController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: siteaccsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        siteacc = value;

                                        if (value == 'No') {
                                          selectedsiteacc = null;
                                          siteaccController.text = "Nil";
                                        } else {
                                          siteaccController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (siteacc != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedsiteacc,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedsiteacc != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedsiteacc = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: siteaccoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedsiteacc = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && siteacc == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (siteacc == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: siteaccController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (siteaccController.text == "Nil") {
                                    siteaccController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Dewatering
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: dewatering,
                              decoration:
                                  _inputDecoration("Dewatering").copyWith(
                                suffixIcon: (!isViewOnly && dewatering != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            dewatering = null;
                                            selecteddewatering = null;
                                            dewateringController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: dewateringsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        dewatering = value;

                                        if (value == 'No') {
                                          selecteddewatering = null;
                                          dewateringController.text = "Nil";
                                        } else {
                                          dewateringController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (dewatering != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selecteddewatering,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selecteddewatering != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selecteddewatering = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: dewateringoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selecteddewatering = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && dewatering == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (dewatering == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: dewateringController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (dewateringController.text == "Nil") {
                                    dewateringController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Electricity & Water
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: electricitywater,
                              decoration:
                                  _inputDecoration("Electricity & Water")
                                      .copyWith(
                                suffixIcon: (!isViewOnly &&
                                        electricitywater != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            electricitywater = null;
                                            selectedelectricitywater = null;
                                            electricitywaterController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: electricitywatersigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        electricitywater = value;

                                        if (value == 'No') {
                                          selectedelectricitywater = null;
                                          electricitywaterController.text =
                                              "Nil";
                                        } else {
                                          electricitywaterController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (electricitywater != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedelectricitywater,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedelectricitywater != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedelectricitywater = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: electricitywateroption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedelectricitywater = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly &&
                                      electricitywater == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (electricitywater == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: electricitywaterController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (electricitywaterController.text ==
                                      "Nil") {
                                    electricitywaterController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Steel & Cement brands
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: steelcement,
                              decoration:
                                  _inputDecoration("Steel & Cement brands")
                                      .copyWith(
                                suffixIcon: (!isViewOnly && steelcement != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            steelcement = null;
                                            selectedsteelcement = null;
                                            steelcementController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: steelcementsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        steelcement = value;

                                        if (value == 'No') {
                                          selectedsteelcement = null;
                                          steelcementController.text = "Nil";
                                        } else {
                                          steelcementController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (steelcement != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedsteelcement,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedsteelcement != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedsteelcement = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: steelcementoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedsteelcement = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && steelcement == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (steelcement == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: steelcementController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (steelcementController.text == "Nil") {
                                    steelcementController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Non tendered items plus % margin
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: tendermargin,
                              decoration: _inputDecoration(
                                      "Non tendered items plus % margin")
                                  .copyWith(
                                suffixIcon: (!isViewOnly &&
                                        tendermargin != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            tendermargin = null;
                                            selectedtendermargin = null;
                                            tendermarginController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: tendermarginsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        tendermargin = value;

                                        if (value == 'No') {
                                          selectedtendermargin = null;
                                          tendermarginController.text = "Nil";
                                        } else {
                                          tendermarginController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (tendermargin != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedtendermargin,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedtendermargin != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedtendermargin = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: tendermarginoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedtendermargin = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && tendermargin == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (tendermargin == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: tendermarginController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (tendermarginController.text == "Nil") {
                                    tendermarginController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Soil excavation
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: soil,
                              decoration: _inputDecoration(
                                      "Soil excavation, storage & backfilling including royalties, hardrock & soft rock issues, sheet piling - as per site condition")
                                  .copyWith(
                                suffixIcon: (!isViewOnly && soil != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            soil = null;
                                            selectedsoil = null;
                                            soilController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: soilsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        soil = value;

                                        if (value == 'No') {
                                          selectedsoil = null;
                                          soilController.text = "Nil";
                                        } else {
                                          soilController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (soil != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedsoil,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedsoil != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedsoil = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: soiloption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedsoil = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && soil == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (soil == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: soilController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (soilController.text == "Nil") {
                                    soilController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///All statutory approvals for building
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: statapproval,
                              decoration: _inputDecoration(
                                      "All statutory approvals for building")
                                  .copyWith(
                                suffixIcon: (!isViewOnly &&
                                        statapproval != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            statapproval = null;
                                            selectedstatapproval = null;
                                            statapprovalController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: statapprovalsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        statapproval = value;

                                        if (value == 'No') {
                                          selectedstatapproval = null;
                                          statapprovalController.text = "Nil";
                                        } else {
                                          statapprovalController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (statapproval != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedstatapproval,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedstatapproval != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedstatapproval = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: statapprovaloption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedstatapproval = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && statapproval == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (statapproval == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: statapprovalController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (statapprovalController.text == "Nil") {
                                    statapprovalController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Soil investigation / survey
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: soilsurvey,
                              decoration: _inputDecoration(
                                      "Soil investigation / survey")
                                  .copyWith(
                                suffixIcon: (!isViewOnly && soilsurvey != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            soilsurvey = null;
                                            selectedsoilsurvey = null;
                                            soilsurveyController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: soilsurveysigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        soilsurvey = value;

                                        if (value == 'No') {
                                          selectedsoilsurvey = null;
                                          soilsurveyController.text = "Nil";
                                        } else {
                                          soilsurveyController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (soilsurvey != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedsoilsurvey,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedsoilsurvey != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedsoilsurvey = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: soilsurveyoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedsoilsurvey = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && soilsurvey == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (soilsurvey == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: soilsurveyController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (soilsurveyController.text == "Nil") {
                                    soilsurveyController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Barrication
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: barrication,
                              decoration:
                                  _inputDecoration("Barrication").copyWith(
                                suffixIcon: (!isViewOnly && barrication != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            barrication = null;
                                            selectedbarrication = null;
                                            barricationController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: barricationsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        barrication = value;

                                        if (value == 'No') {
                                          selectedbarrication = null;
                                          barricationController.text = "Nil";
                                        } else {
                                          barricationController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (barrication != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedbarrication,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedbarrication != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedbarrication = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: barricationoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedbarrication = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && barrication == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (barrication == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: barricationController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (barricationController.text == "Nil") {
                                    barricationController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Tree cutting / Demolition / Debris removal / EB & Utility line shifiting / Open well closing
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: treecutting,
                              decoration: _inputDecoration(
                                      "Tree cutting / Demolition / Debris removal / EB & Utility line shifiting / Open well closing")
                                  .copyWith(
                                suffixIcon: (!isViewOnly && treecutting != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            treecutting = null;
                                            selectedtreecutting = null;
                                            treecuttingController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: treecuttingsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        treecutting = value;

                                        if (value == 'No') {
                                          selectedtreecutting = null;
                                          treecuttingController.text = "Nil";
                                        } else {
                                          treecuttingController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (treecutting != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedtreecutting,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedtreecutting != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedtreecutting = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: treecuttingoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedtreecutting = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && treecutting == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (treecutting == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: treecuttingController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (treecuttingController.text == "Nil") {
                                    treecuttingController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Labour accommodation
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: labouracc,
                              decoration:
                                  _inputDecoration("Labour accommodation")
                                      .copyWith(
                                suffixIcon: (!isViewOnly && labouracc != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            labouracc = null;
                                            selectedlabouracc = null;
                                            labouraccController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: labouraccsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        labouracc = value;

                                        if (value == 'No') {
                                          selectedlabouracc = null;
                                          labouraccController.text = "Nil";
                                        } else {
                                          labouraccController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (labouracc != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedlabouracc,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedlabouracc != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedlabouracc = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: labouraccoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedlabouracc = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && labouracc == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (labouracc == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: labouraccController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (labouraccController.text == "Nil") {
                                    labouraccController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Brick work internal & external
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: brickwork,
                              decoration: _inputDecoration(
                                      "Brick work internal & external")
                                  .copyWith(
                                suffixIcon: (!isViewOnly && brickwork != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            brickwork = null;
                                            selectedbrickwork = null;
                                            brickworkController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: brickworksigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        brickwork = value;

                                        if (value == 'No') {
                                          selectedbrickwork = null;
                                          brickworkController.text = "Nil";
                                        } else {
                                          brickworkController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (brickwork != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedbrickwork,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedbrickwork != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedbrickwork = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: brickworkoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedbrickwork = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && brickwork == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (brickwork == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: brickworkController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (brickworkController.text == "Nil") {
                                    brickworkController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Site security
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: sitesec,
                              decoration:
                                  _inputDecoration("Site security").copyWith(
                                suffixIcon: (!isViewOnly && sitesec != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            sitesec = null;
                                            selectedsitesec = null;
                                            sitesecController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: sitesecsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        sitesec = value;

                                        if (value == 'No') {
                                          selectedsitesec = null;
                                          sitesecController.text = "Nil";
                                        } else {
                                          sitesecController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (sitesec != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedsitesec,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedsitesec != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedsitesec = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: sitesecoption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedsitesec = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && sitesec == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (sitesec == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: sitesecController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (sitesecController.text == "Nil") {
                                    sitesecController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Lighting arrangements
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: lightarr,
                              decoration:
                                  _inputDecoration("Lighting arrangements")
                                      .copyWith(
                                suffixIcon: (!isViewOnly && lightarr != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            lightarr = null;
                                            selectedlightarr = null;
                                            lightarrController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: lightarrsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        lightarr = value;

                                        if (value == 'No') {
                                          selectedlightarr = null;
                                          lightarrController.text = "Nil";
                                        } else {
                                          lightarrController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),

                          /// Show Second Dropdown only when value is NOT "No"
                          if (lightarr != 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedlightarr,
                                decoration: _inputDecoration("").copyWith(
                                  suffixIcon: (!isViewOnly &&
                                          selectedlightarr != null)
                                      ? IconButton(
                                          onPressed: () {
                                            setState(() {
                                              selectedlightarr = null;
                                            });
                                          },
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          padding: EdgeInsets.zero,
                                          tooltip: 'Clear selection',
                                        )
                                      : null,
                                ),
                                items: lightarroption.map((status) {
                                  return DropdownMenuItem<String>(
                                    value: status,
                                    child: Text(status),
                                  );
                                }).toList(),
                                onChanged: isViewOnly
                                    ? null
                                    : (value) {
                                        setState(() {
                                          selectedlightarr = value;
                                        });
                                        _formKey.currentState?.validate();
                                      },
                                validator: (value) {
                                  if (!isViewOnly && lightarr == 'Yes') {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select an option';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],

                          /// Show Remarks only when first dropdown = "No"
                          if (lightarr == 'No') ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: lightarrController,
                                readOnly: isViewOnly,
                                enabled: !isViewOnly,
                                onTap: () {
                                  if (lightarrController.text == "Nil") {
                                    lightarrController.clear();
                                  }
                                },
                                decoration: const InputDecoration(
                                  labelText: "Remarks",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Legal aspects
                      Text(
                        'Legal aspects',
                        style: TextStyle(
                            fontSize: 16, color: AppColors.primaryLight),
                      ),
                      const SizedBox(height: 16),

                      ///Force majeure conditions & Arbitration clause
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: forcemaj,
                              decoration:
                                  _inputDecoration("Force majeure conditions")
                                      .copyWith(
                                suffixIcon: (!isViewOnly && forcemaj != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            forcemaj = null;
                                            selectedforcemaj = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: forcemajsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        forcemaj = value;

                                        if (value == 'No') {
                                          selectedforcemaj = null;
                                        }
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: arbitration,
                              decoration: _inputDecoration("Arbitration clause")
                                  .copyWith(
                                suffixIcon: (!isViewOnly && arbitration != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            arbitration = null;
                                            selectedarbitration = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: arbitrationsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        arbitration = value;

                                        if (value == 'No') {
                                          selectedarbitration = null;
                                        }
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Labour compliance including insurance
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: labourcomp,
                              decoration: _inputDecoration("Lab comp incl ins")
                                  .copyWith(
                                suffixIcon: (!isViewOnly && labourcomp != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            labourcomp = null;
                                            selectedlabourcomp = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: labourcompsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        labourcomp = value;

                                        if (value == 'No') {
                                          selectedlabourcomp = null;
                                        }
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Liquidated damages & Stability certificate clause
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: liqdamage,
                              decoration:
                                  _inputDecoration("Liq damages").copyWith(
                                suffixIcon: (!isViewOnly && liqdamage != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            liqdamage = null;
                                            selectedliqdamage = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: liqdamagesigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        liqdamage = value;

                                        if (value == 'No') {
                                          selectedliqdamage = null;
                                        }
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: stability,
                              decoration: _inputDecoration(
                                      "Stability certificate clause")
                                  .copyWith(
                                suffixIcon: (!isViewOnly && stability != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            stability = null;
                                            selectedstability = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: stabilitysigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        stability = value;

                                        if (value == 'No') {
                                          selectedstability = null;
                                        }
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Other remarks
                      Text(
                        'Other remarks',
                        style: TextStyle(
                            fontSize: 16, color: AppColors.primaryLight),
                      ),
                      const SizedBox(height: 16),

                      /// Grout - Teemax approval & Expansion joint requirements
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown (Grout)
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: grout,
                              decoration: _inputDecoration(
                                "Grout - Teemax approval",
                              ).copyWith(
                                suffixIcon: (!isViewOnly && grout != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            grout = null;
                                            selectedgrout = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: groutsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        grout = value;
                                        if (value == 'No') {
                                          selectedgrout = null;
                                        }
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),

                          /// Second Dropdown (Joint Requirement)
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: jointreq,
                              decoration: _inputDecoration(
                                "Expansion joint requirements",
                              ).copyWith(
                                suffixIcon: (!isViewOnly && jointreq != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            jointreq = null;
                                            selectedjointreq = null;
                                            jointreqController.clear();
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: jointreqsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        jointreq = value;
                                        if (value == 'No') {
                                          selectedjointreq = null;
                                          jointreqController.text = "Nil";
                                        } else {
                                          jointreqController.clear();
                                        }
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),

                          /// Third Field (Remarks or Dropdown based on jointreq)
                          Expanded(
                            flex: 1,
                            child: jointreq == 'No'
                                ? TextFormField(
                                    controller: jointreqController,
                                    readOnly: isViewOnly,
                                    enabled: !isViewOnly,
                                    onTap: () {
                                      if (!isViewOnly &&
                                          jointreqController.text == "Nil") {
                                        jointreqController.clear();
                                      }
                                    },
                                    decoration: InputDecoration(
                                      labelText: "Remarks",
                                      border: const OutlineInputBorder(),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      suffixIcon: !isViewOnly &&
                                              jointreqController
                                                  .text.isNotEmpty &&
                                              jointreqController.text != "Nil"
                                          ? IconButton(
                                              icon: const Icon(Icons.clear,
                                                  size: 18),
                                              onPressed: () {
                                                setState(() {
                                                  jointreqController.clear();
                                                });
                                              },
                                              padding: EdgeInsets.zero,
                                              tooltip: 'Clear remarks',
                                            )
                                          : null,
                                    ),
                                  )
                                : DropdownButtonFormField<String>(
                                    value: selectedjointreq,
                                    decoration: _inputDecoration("").copyWith(
                                      suffixIcon: (!isViewOnly &&
                                              selectedjointreq != null)
                                          ? IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  selectedjointreq = null;
                                                });
                                              },
                                              icon: const Icon(Icons.clear,
                                                  size: 18),
                                              padding: EdgeInsets.zero,
                                              tooltip: 'Clear selection',
                                            )
                                          : null,
                                    ),
                                    items: jointreqoption.map((status) {
                                      return DropdownMenuItem<String>(
                                        value: status,
                                        child: Text(status),
                                      );
                                    }).toList(),
                                    onChanged: isViewOnly
                                        ? null
                                        : (value) {
                                            setState(() {
                                              selectedjointreq = value;
                                            });
                                          },
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Idle Charges & Third party tests
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// First Dropdown
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: idlecharg,
                              decoration:
                                  _inputDecoration("Idle Charges").copyWith(
                                suffixIcon: (!isViewOnly && idlecharg != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            idlecharg = null;
                                            selectedidlecharg = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: idlechargsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        idlecharg = value;

                                        if (value == 'No') {
                                          selectedidlecharg = null;
                                        }
                                      });
                                    },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: thirdpartytest,
                              decoration: _inputDecoration("Third party tests")
                                  .copyWith(
                                suffixIcon: (!isViewOnly &&
                                        thirdpartytest != null)
                                    ? IconButton(
                                        onPressed: () {
                                          setState(() {
                                            thirdpartytest = null;
                                            selectedthirdpartytest = null;
                                          });
                                        },
                                        icon: const Icon(Icons.clear, size: 18),
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Clear selection',
                                      )
                                    : null,
                              ),
                              items: thirdpartytestsigned.map((status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                );
                              }).toList(),
                              onChanged: isViewOnly
                                  ? null
                                  : (value) {
                                      setState(() {
                                        thirdpartytest = value;

                                        if (value == 'No') {
                                          selectedthirdpartytest = null;
                                        }
                                      });
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ///Submit & Update Button
                      if (!isViewOnly) ...[
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
                                  onTap: () async {
                                    if (_formKey.currentState!.validate()) {
                                      await insertSalesChecklist();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    child: Center(
                                      child: Text(
                                        isEditing ? 'Update' : 'Submit',
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
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
      );

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: efffectiveDate ?? now,
      firstDate: DateTime(1900), // Earliest allowed date
      lastDate: DateTime(2100), // Latest allowed date
    );

    if (picked != null && picked != efffectiveDate) {
      setState(() {
        efffectiveDate = picked;
      });
    }
  }

  Future<void> loadSalesDetails() async {
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
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> loadCustomers() async {
    try {
      final response = await http.post(ApiUtils.getUri('CustomerDetails'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true) {
          final List list = data['CustomerDetails'];

          setState(() {
            customerList = list.map((e) => CustomerModel.fromJson(e)).toList();
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

  Future<void> insertSalesChecklist() async {
    try {
      final isEditing = widget.checklistData != null;

      final requestBody = {
        // For Update: Include CHKLNO (always include for update, don't include for insert)
        if (isEditing) "CHKLNO": widget.checklistData?.chklno,

        // For Insert: Include CLIENTNAME and PROJECTNAME
        "CLIENTNAME": customerController.text,
        "PROJECTNAME": siteController.text,

        // Common fields for both Insert and Update
        "VERIFIEDBY": verifiedbyController.text,
        "REVIEWEDBY": reviewedbyController.text,
        "SITEADDRESS": siteaddressController.text,
        "BILLINGADDRESS": billingaddressController.text,
        "SITEGSTNO": sitegstController.text,
        "BILLINGGSTNO": billgstController.text,
        "EFFECTIVEDATE": efffectiveDate != null
            ? DateFormat('yyyy-MM-ddTHH:mm:ss').format(efffectiveDate!)
            : null,
        "WOVALUEINCLGST": workordervalueincludinggstController.text.isEmpty
            ? null
            : double.tryParse(
                workordervalueincludinggstController.text.replaceAll(',', '')),
        "PROJECTTENURE": tenureController.text,
        "DEFLIABPERIOD": liabilityController.text,
        "CONTRACTTYPE": contractController.text,
        "BILLINGMETHOD": methodofbillingController.text,
        "PAYMENTTERMS": billingfrequencyController.text,
        "MILESTONES": milestonesController.text,
        "RETENTION": retentionController.text,
        "BGREQ": selectedbankreq,
        "ESCDETAILS": selectedescl,
        "TAXSTRCHANGES": selectedtax,
        "SCOPEOFWORKSIGNED": workscope == "No"
            ? "No - ${workscopeController.text}"
            : (workscope == "Yes" ? "Yes - ${selectedworkscope ?? ''}" : ""),
        "WPMETHODOLOGY": waterproofing == "No"
            ? "No - ${waterproffingController.text}"
            : (waterproofing == "Yes"
                ? "Yes - ${selectedwaterproffing ?? ''}"
                : ""),
        "ANTITERMITEWORK": antitermite == "No"
            ? "No - ${antitermiteController.text}"
            : (antitermite == "Yes"
                ? "Yes - ${selectedantitermite ?? ''}"
                : ""),
        "SITEACCESSISSUES": siteacc == "No"
            ? "No - ${siteaccController.text}"
            : (siteacc == "Yes" ? "Yes - ${selectedsiteacc ?? ''}" : ""),
        "DEWATERING": dewatering == "No"
            ? "No - ${dewateringController.text}"
            : (dewatering == "Yes" ? "Yes - ${selecteddewatering ?? ''}" : ""),
        "ELECTRICITYWATER": electricitywater == "No"
            ? "No - ${electricitywaterController.text}"
            : (electricitywater == "Yes"
                ? "Yes - ${selectedelectricitywater ?? ''}"
                : ""),
        "STEELCEMENTBRANDS": steelcement == "No"
            ? "No - ${steelcementController.text}"
            : (steelcement == "Yes"
                ? "Yes - ${selectedsteelcement ?? ''}"
                : ""),
        "NONTENITEMSMAR": tendermargin == "No"
            ? "No - ${tendermarginController.text}"
            : (tendermargin == "Yes"
                ? "Yes - ${selectedtendermargin ?? ''}"
                : ""),
        "SOILEXCDETAILS": soil == "No"
            ? "No - ${soilController.text}"
            : (soil == "Yes" ? "Yes - ${selectedsoil ?? ''}" : ""),
        "BUILDINGAPP": statapproval == "No"
            ? "No - ${statapprovalController.text}"
            : (statapproval == "Yes"
                ? "Yes - ${selectedstatapproval ?? ''}"
                : ""),
        "SOILINV": soilsurvey == "No"
            ? "No - ${soilsurveyController.text}"
            : (soilsurvey == "Yes" ? "Yes - ${selectedsoilsurvey ?? ''}" : ""),
        "BARRICATION": barrication == "No"
            ? "No - ${barricationController.text}"
            : (barrication == "Yes"
                ? "Yes - ${selectedbarrication ?? ''}"
                : ""),
        "TREECUTTINGDEM": treecutting == "No"
            ? "No - ${treecuttingController.text}"
            : (treecutting == "Yes"
                ? "Yes - ${selectedtreecutting ?? ''}"
                : ""),
        "LABOURACCOM": labouracc == "No"
            ? "No - ${labouraccController.text}"
            : (labouracc == "Yes" ? "Yes - ${selectedlabouracc ?? ''}" : ""),
        "BRICKWORK": brickwork == "No"
            ? "No - ${brickworkController.text}"
            : (brickwork == "Yes" ? "Yes - ${selectedbrickwork ?? ''}" : ""),
        "SITESECURITY": sitesec == "No"
            ? "No - ${sitesecController.text}"
            : (sitesec == "Yes" ? "Yes - ${selectedsitesec ?? ''}" : ""),
        "LIGHTINGARR": lightarr == "No"
            ? "No - ${lightarrController.text}"
            : (lightarr == "Yes" ? "Yes - ${selectedlightarr ?? ''}" : ""),
        "FORCEMAJEURECON": forcemaj,
        "ARBITRATIONCLAUSE": arbitration,
        "LABCOMINS": labourcomp,
        "LIQUIDATEDDAMAGES": liqdamage,
        "STABILITYCERTCLAUSE": stability,
        "GROUTTEEMAXAPP": grout,
        "EXJOINTREQ": jointreq == "No"
            ? "No - ${jointreqController.text}"
            : (jointreq == "Yes" ? "Yes - ${selectedjointreq ?? ''}" : ""),
        "IDLECHARGES": idlecharg,
        "THIRDPARTYTESTS": thirdpartytest,
        "ADDUSER": empCode,
      };

      // Remove any null values from requestBody
      final cleanedRequestBody = Map.from(requestBody)
        ..removeWhere(
            (key, value) => value == null || value.toString().isEmpty);

      // Use the unified SaveSalesChecklist endpoint
      final apiEndpoint = 'SaveSalesChecklist';

      print("API URL : ${ApiUtils.getUri(apiEndpoint)}");
      print("REQUEST BODY : ${jsonEncode(cleanedRequestBody)}");

      final response = await http.post(
        ApiUtils.getUri(apiEndpoint),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(cleanedRequestBody),
      );

      print("STATUS CODE : ${response.statusCode}");
      print("RESPONSE BODY : ${response.body}");

      // Check if response is valid JSON
      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server error occurred. Please try again later.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final data = jsonDecode(response.body);

      if (data['Success'] == true) {
        print("${isEditing ? 'UPDATE' : 'INSERT'} SUCCESS");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['Message']),
            backgroundColor: Colors.green,
          ),
        );

        if (!isEditing) {
          clearAllFields();
        }
        Navigator.pop(context, true); // Return true to indicate data was saved
      } else {
        print("${isEditing ? 'UPDATE' : 'INSERT'} FAILED");
        print("ERROR MESSAGE : ${data['Message']}");

        String errorMessage = "";

        if (data['Message'] is List) {
          errorMessage = (data['Message'] as List).join("\n");
        } else {
          errorMessage = data['Message'].toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      print("EXCEPTION ERROR : $e");
      print("STACK TRACE : $stackTrace");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void clearAllFields() {
    customerController.clear();
    siteController.clear();
    verifiedbyController.clear();
    reviewedbyController.clear();
    siteaddressController.clear();
    billingaddressController.clear();
    sitegstController.clear();
    billgstController.clear();
    workordervalueincludinggstController.clear();
    tenureController.clear();
    liabilityController.clear();
    contractController.clear();
    methodofbillingController.clear();
    billingfrequencyController.clear();
    milestonesController.clear();
    retentionController.clear();

    workscopeController.clear();
    waterproffingController.clear();
    antitermiteController.clear();
    siteaccController.clear();
    dewateringController.clear();
    electricitywaterController.clear();
    steelcementController.clear();
    tendermarginController.clear();
    soilController.clear();
    statapprovalController.clear();
    soilsurveyController.clear();
    barricationController.clear();
    treecuttingController.clear();
    labouraccController.clear();
    brickworkController.clear();
    sitesecController.clear();
    lightarrController.clear();
    jointreqController.clear();

    setState(() {
      efffectiveDate = null;

      selectedbankreq = null;
      selectedescl = null;
      selectedtax = null;

      workscope = null;
      waterproofing = null;
      antitermite = null;
      siteacc = null;
      dewatering = null;
      electricitywater = null;
      steelcement = null;
      tendermargin = null;
      soil = null;
      statapproval = null;
      soilsurvey = null;
      barrication = null;
      treecutting = null;
      labouracc = null;
      brickwork = null;
      sitesec = null;
      lightarr = null;
      jointreq = null;

      selectedworkscope = null;
      selectedwaterproffing = null;
      selectedantitermite = null;
      selectedsiteacc = null;
      selecteddewatering = null;
      selectedelectricitywater = null;
      selectedsteelcement = null;
      selectedtendermargin = null;
      selectedsoil = null;
      selectedstatapproval = null;
      selectedsoilsurvey = null;
      selectedbarrication = null;
      selectedtreecutting = null;
      selectedlabouracc = null;
      selectedbrickwork = null;
      selectedsitesec = null;
      selectedlightarr = null;
      selectedjointreq = null;

      forcemaj = null;
      arbitration = null;
      labourcomp = null;
      liqdamage = null;
      stability = null;
      grout = null;
      idlecharg = null;
      thirdpartytest = null;
    });
  }

  void _populateFormWithData(SalesChecklistModel data) {
    // Populate customer and project fields
    customerController.text = "${data.clientname ?? ''}";
    siteController.text = "${data.projectname ?? ''}";

    // Populate verified by and reviewed by
    verifiedbyController.text = data.verifiedby ?? '';
    reviewedbyController.text = data.reviewedby ?? '';

    // Populate addresses
    siteaddressController.text = data.siteaddress ?? '';
    billingaddressController.text = data.billingaddress ?? '';
    sitegstController.text = data.sitegstno ?? '';
    billgstController.text = data.billinggstno ?? '';

    // Populate date
    if (data.effectivedate != null) {
      efffectiveDate = data.effectivedate;
    }

    // Populate numeric fields
    workordervalueincludinggstController.text =
        data.wovalueinclgst?.toString() ?? '';
    tenureController.text = data.projecttenure ?? '';
    liabilityController.text = data.defliabperiod ?? '';

    // Populate billing details
    contractController.text = data.contracttype ?? '';
    methodofbillingController.text = data.billingmethod ?? '';
    billingfrequencyController.text = data.paymentterms ?? '';
    milestonesController.text = data.milestones ?? '';
    retentionController.text = data.retention ?? '';

    // Populate dropdown selections
    selectedbankreq = data.bgreq;
    selectedescl = data.escdetails;
    selectedtax = data.taxstrchanges;

    // Helper function to extract Yes/No status from combined string
    void setStatusAndRemarks(
      String? combinedValue,
      Function(String?) setStatus,
      Function(String?) setRemarks,
      TextEditingController remarksController,
    ) {
      if (combinedValue == null || combinedValue.isEmpty) {
        setStatus(null);
        setRemarks(null);
        remarksController.clear();
        return;
      }

      // Check if the string starts with "Yes"
      if (combinedValue.startsWith('Yes')) {
        setStatus('Yes');
        if (combinedValue.length > 6) {
          // Extract the value after "Yes - "
          String option = combinedValue.substring(6).trim();
          setRemarks(option);
          remarksController.text = option;
        } else {
          setRemarks(null);
          remarksController.clear();
        }
      }
      // Check if the string starts with "No"
      else if (combinedValue.startsWith('No')) {
        setStatus('No');
        if (combinedValue.length > 5) {
          // Extract the value after "No - "
          String remark = combinedValue.substring(5).trim();
          remarksController.text = remark;
        } else {
          remarksController.clear();
        }
        setRemarks(null);
      }
      // If it's just a simple value without prefix
      else {
        // Check if it matches any of the option values
        if (workscopeoption.contains(combinedValue) ||
            waterproofingoption.contains(combinedValue) ||
            antitermiteoption.contains(combinedValue) ||
            siteaccoption.contains(combinedValue) ||
            dewateringoption.contains(combinedValue) ||
            electricitywateroption.contains(combinedValue) ||
            steelcementoption.contains(combinedValue) ||
            tendermarginoption.contains(combinedValue) ||
            soiloption.contains(combinedValue) ||
            statapprovaloption.contains(combinedValue) ||
            soilsurveyoption.contains(combinedValue) ||
            barricationoption.contains(combinedValue) ||
            treecuttingoption.contains(combinedValue) ||
            labouraccoption.contains(combinedValue) ||
            brickworkoption.contains(combinedValue) ||
            sitesecoption.contains(combinedValue) ||
            lightarroption.contains(combinedValue) ||
            jointreqoption.contains(combinedValue)) {
          setStatus('Yes');
          setRemarks(combinedValue);
          remarksController.text = combinedValue;
        } else {
          setStatus(null);
          setRemarks(null);
          remarksController.clear();
        }
      }
    }

    // Populate scope clearance fields
    setStatusAndRemarks(
      data.scopeofworksigned,
      (v) => workscope = v,
      (v) => selectedworkscope = v,
      workscopeController,
    );

    // Waterproofing
    setStatusAndRemarks(
      data.wpmethodology,
      (v) => waterproofing = v,
      (v) => selectedwaterproffing = v,
      waterproffingController,
    );

    // Anti termite
    setStatusAndRemarks(
      data.antitermitework,
      (v) => antitermite = v,
      (v) => selectedantitermite = v,
      antitermiteController,
    );

    // Site access
    setStatusAndRemarks(
      data.siteaccessissues,
      (v) => siteacc = v,
      (v) => selectedsiteacc = v,
      siteaccController,
    );

    // Dewatering
    setStatusAndRemarks(
      data.dewatering,
      (v) => dewatering = v,
      (v) => selecteddewatering = v,
      dewateringController,
    );

    // Electricity & Water
    setStatusAndRemarks(
      data.electricitywater,
      (v) => electricitywater = v,
      (v) => selectedelectricitywater = v,
      electricitywaterController,
    );

    // Steel & Cement
    setStatusAndRemarks(
      data.steelcementbrands,
      (v) => steelcement = v,
      (v) => selectedsteelcement = v,
      steelcementController,
    );

    // Non tendered items
    setStatusAndRemarks(
      data.nontenitemsmar,
      (v) => tendermargin = v,
      (v) => selectedtendermargin = v,
      tendermarginController,
    );

    // Soil excavation
    setStatusAndRemarks(
      data.soilexcdetails,
      (v) => soil = v,
      (v) => selectedsoil = v,
      soilController,
    );

    // Statutory approvals
    setStatusAndRemarks(
      data.buildingapp,
      (v) => statapproval = v,
      (v) => selectedstatapproval = v,
      statapprovalController,
    );

    // Soil investigation
    setStatusAndRemarks(
      data.soilinv,
      (v) => soilsurvey = v,
      (v) => selectedsoilsurvey = v,
      soilsurveyController,
    );

    // Barrication
    setStatusAndRemarks(
      data.barrication,
      (v) => barrication = v,
      (v) => selectedbarrication = v,
      barricationController,
    );

    // Tree cutting
    setStatusAndRemarks(
      data.treecuttingdem,
      (v) => treecutting = v,
      (v) => selectedtreecutting = v,
      treecuttingController,
    );

    // Labour accommodation
    setStatusAndRemarks(
      data.labouraccom,
      (v) => labouracc = v,
      (v) => selectedlabouracc = v,
      labouraccController,
    );

    // Brickwork
    setStatusAndRemarks(
      data.brickwork,
      (v) => brickwork = v,
      (v) => selectedbrickwork = v,
      brickworkController,
    );

    // Site security
    setStatusAndRemarks(
      data.sitesecurity,
      (v) => sitesec = v,
      (v) => selectedsitesec = v,
      sitesecController,
    );

    // Lighting arrangements
    setStatusAndRemarks(
      data.lightingarr,
      (v) => lightarr = v,
      (v) => selectedlightarr = v,
      lightarrController,
    );

    // Expansion joint requirements
    setStatusAndRemarks(
      data.exjointreq,
      (v) => jointreq = v,
      (v) => selectedjointreq = v,
      jointreqController,
    );

    // Legal aspects (simple dropdowns without remarks)
    forcemaj = data.forcemajeurecon;
    arbitration = data.arbitrationclause;
    labourcomp = data.labcomins;
    liqdamage = data.liquidateddamages;
    stability = data.stabilitycertclause;
    grout = data.groutteemaxapp;
    idlecharg = data.idlecharges;
    thirdpartytest = data.thirdpartytests;

    // After populating all fields, trigger a rebuild
    setState(() {});
  }
}

class CapitalizeFirstLetterFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final String value = newValue.text;

    if (value.isEmpty) {
      return newValue;
    }

    // Find the first alphabetical character
    int firstLetterIndex = -1;
    for (int i = 0; i < value.length; i++) {
      if (RegExp(r'[a-zA-Z]').hasMatch(value[i])) {
        firstLetterIndex = i;
        break;
      }
    }

    // If a letter is found and it's lowercase, capitalize it
    if (firstLetterIndex != -1) {
      final String firstLetter = value[firstLetterIndex];
      if (RegExp(r'[a-z]').hasMatch(firstLetter)) {
        final String beforeLetters = value.substring(0, firstLetterIndex);
        final String capitalizedLetter = firstLetter.toUpperCase();
        final String afterLetters =
            value.substring(firstLetterIndex + 1).toLowerCase();

        final String formattedValue =
            beforeLetters + capitalizedLetter + afterLetters;

        if (formattedValue != value) {
          return TextEditingValue(
            text: formattedValue,
            selection: TextSelection.collapsed(offset: formattedValue.length),
          );
        }
      }
    }

    return newValue;
  }
}

/*
@override
Widget _build(BuildContext context) {
  final isEditing = widget.checklistData != null && !widget.isReadOnly!;
  final isViewOnly = widget.isReadOnly == true;
  return Scaffold(
    appBar: AppBar(
      title: Text(isViewOnly
          ? 'View Check List #${widget.checklistData?.chklno ?? ''}'
          : (isEditing
          ? 'Edit Check List Entry #${widget.checklistData?.chklno ?? ''}'
          : 'Check List Entry')),
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
      actions: isViewOnly
          ? [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.white),
          onPressed: () {
            // Navigate to edit mode
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => EntryChecklistScreen(
                  checklistData: widget.checklistData,
                  isReadOnly: false,
                ),
              ),
            );
          },
          tooltip: 'Edit',
        ),
      ]
          : null,
    ),
    body: SingleChildScrollView(
      controller: _scrollController,
      child: Center(
        child: Container(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                            : Autocomplete<CustomerModel>(
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
                                  .contains(
                                textEditingValue.text
                                    .toLowerCase(),
                              ) ||
                                  customer.customerId
                                      .toString()
                                      .contains(textEditingValue.text);
                            });
                          },
                          onSelected: (CustomerModel selection) {
                            customerController.text =
                            "${selection.customerId} - ${selection.companyName}";

                            setState(() {
                              selectedCustomerId = selection.customerId;

                              /// Clear old project selection
                              selectedProjectId = null;
                              siteController.clear();
                            });

                            /// Load project list
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

                                      /// Clear project also
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
                                  .contains(
                                textEditingValue.text
                                    .toLowerCase(),
                              ) ||
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

                                      /// Clear project also
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
                    ],
                  ),
                  const SizedBox(height: 16),

                  /// Verified By & Reviewed By
                  Row(
                    children: [
                      /// VERIFIED BY
                      Expanded(
                        child: isViewOnly
                            ? TextFormField(
                          controller: verifiedbyController,
                          decoration:
                          _inputDecoration("Verified By").copyWith(
                            suffixIcon: verifiedbyController
                                .text.isNotEmpty
                                ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18),
                              onPressed: () {
                                // In view mode, you might not want to allow clearing
                                // But if you do, you can implement it
                                setState(() {
                                  verifiedbyController.clear();
                                });
                              },
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear',
                            )
                                : null,
                          ),
                          readOnly: true,
                          enabled: false,
                        )
                            : Autocomplete<SalesEmployeeModel>(
                          displayStringForOption: (option) =>
                          "${option.empCode} - ${option.empName} ",
                          optionsBuilder:
                              (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return salesEmployees;
                            }
                            return salesEmployees.where((employee) {
                              return employee.empName
                                  .toLowerCase()
                                  .contains(textEditingValue.text
                                  .toLowerCase()) ||
                                  employee.empCode
                                      .toString()
                                      .contains(textEditingValue.text);
                            });
                          },
                          onSelected: (SalesEmployeeModel selection) {
                            verifiedbyController.text =
                            "${selection.empCode} - ${selection.empName}";
                          },
                          fieldViewBuilder: (
                              context,
                              controller,
                              focusNode,
                              onFieldSubmitted,
                              ) {
                            controller.text = verifiedbyController.text;
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: "Verified By",
                                hintText: "Search Employee",
                                border: const OutlineInputBorder(),
                                suffixIcon: controller.text.isNotEmpty
                                    ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      size: 18),
                                  onPressed: () {
                                    controller.clear();
                                    verifiedbyController.clear();
                                    setState(() {});
                                  },
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Clear',
                                )
                                    : null,
                                contentPadding:
                                const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      /// REVIEWED BY
                      Expanded(
                        child: isViewOnly
                            ? TextFormField(
                          controller: reviewedbyController,
                          decoration:
                          _inputDecoration("Reviewed By").copyWith(
                            suffixIcon: reviewedbyController
                                .text.isNotEmpty
                                ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18),
                              onPressed: () {
                                setState(() {
                                  reviewedbyController.clear();
                                });
                              },
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear',
                            )
                                : null,
                          ),
                          readOnly: true,
                          enabled: false,
                        )
                            : Autocomplete<SalesEmployeeModel>(
                          displayStringForOption: (option) =>
                          "${option.empCode} - ${option.empName} ",
                          optionsBuilder:
                              (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return salesEmployees;
                            }
                            return salesEmployees.where((employee) {
                              return employee.empName
                                  .toLowerCase()
                                  .contains(textEditingValue.text
                                  .toLowerCase()) ||
                                  employee.empCode
                                      .toString()
                                      .contains(textEditingValue.text);
                            });
                          },
                          onSelected: (SalesEmployeeModel selection) {
                            reviewedbyController.text =
                            "${selection.empCode} - ${selection.empName}";
                          },
                          fieldViewBuilder: (
                              context,
                              controller,
                              focusNode,
                              onFieldSubmitted,
                              ) {
                            controller.text = reviewedbyController.text;
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: "Reviewed By",
                                hintText: "Search Employee",
                                border: const OutlineInputBorder(),
                                suffixIcon: controller.text.isNotEmpty
                                    ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      size: 18),
                                  onPressed: () {
                                    controller.clear();
                                    reviewedbyController.clear();
                                    setState(() {});
                                  },
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Clear',
                                )
                                    : null,
                                contentPadding:
                                const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      'Checklist for Contract Signing',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ///Generic Details
                  Text(
                    'Generic Details',
                    style: TextStyle(
                        fontSize: 16, color: AppColors.primaryLight),
                  ),
                  const SizedBox(height: 16),

                  ///Site Address & Billing Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: TextFormField(
                            controller: siteaddressController,
                            decoration: InputDecoration(
                              labelText: "Site Address",
                              hintText: "Site Address",
                              border: const OutlineInputBorder(),
                              suffixIcon: siteaddressController.text.isNotEmpty
                                  ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    siteaddressController.clear();
                                    if (isSameAsSiteAddress) {
                                      billingaddressController.clear();
                                      isSameAsSiteAddress = false;
                                    }
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
                            //minLines: 3,
                            maxLines: null, // Auto-expand
                            keyboardType: TextInputType.multiline,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                          )),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: billingaddressController,
                              decoration: InputDecoration(
                                labelText: "Billing Address",
                                hintText: "Billing Address",
                                border: const OutlineInputBorder(),
                                suffixIcon: billingaddressController
                                    .text.isNotEmpty
                                    ? IconButton(
                                  icon:
                                  const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      billingaddressController.clear();
                                      if (isSameAsSiteAddress) {
                                        isSameAsSiteAddress = false;
                                      }
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
                              //minLines: 3,
                              maxLines: null, // Auto-expand
                              keyboardType: TextInputType.multiline,
                              readOnly: isViewOnly,
                              enabled: !isViewOnly,
                            ),
                            const SizedBox(height: 4),
                            if (!isViewOnly) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: isSameAsSiteAddress,
                                    materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (value) {
                                      setState(() {
                                        isSameAsSiteAddress = value ?? false;

                                        if (isSameAsSiteAddress) {
                                          billingaddressController.text =
                                              siteaddressController.text;
                                        } else {
                                          billingaddressController.clear();
                                        }
                                      });
                                    },
                                  ),
                                  const Text(
                                    "Same as Site Address",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Site GST No & Billing GST No
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: sitegstController,
                          decoration: InputDecoration(
                            labelText: "Site GST No",
                            hintText: "Site GST No",
                            border: const OutlineInputBorder(),
                            suffixIcon: sitegstController.text.isNotEmpty
                                ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  sitegstController.clear();
                                  if (isSameAsSiteGST) {
                                    isSameAsSiteGST = false;
                                  }
                                });
                              },
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear',
                            )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                          readOnly: isViewOnly,
                          enabled: !isViewOnly,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: billgstController,
                              decoration: InputDecoration(
                                labelText: "Billing GST No",
                                hintText: "Billing GST No",
                                border: const OutlineInputBorder(),
                                suffixIcon: billgstController.text.isNotEmpty
                                    ? IconButton(
                                  icon:
                                  const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      billgstController.clear();
                                      if (isSameAsSiteGST) {
                                        isSameAsSiteGST = false;
                                      }
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Clear',
                                )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                              readOnly: isViewOnly,
                              enabled: !isViewOnly,
                            ),
                            const SizedBox(height: 4),
                            if (!isViewOnly) ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: isSameAsSiteGST,
                                    materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (value) {
                                      setState(() {
                                        isSameAsSiteGST = value ?? false;

                                        if (isSameAsSiteGST) {
                                          billgstController.text =
                                              sitegstController.text;
                                        } else {
                                          billgstController.clear();
                                        }
                                      });
                                    },
                                  ),
                                  const Text(
                                    "Same as Site GST No",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Date & Work Order Value
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: TextEditingController(
                            text: efffectiveDate != null
                                ? DateFormat('yyyy-MM-dd')
                                .format(efffectiveDate!)
                                : '',
                          ),
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Effective Date of Agreement",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (efffectiveDate != null && !isViewOnly)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        efffectiveDate = null;
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Clear date',
                                  ),
                                if (efffectiveDate == null && !isViewOnly)
                                  Icon(
                                    Icons.calendar_today,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                          validator: (value) {
                            if (efffectiveDate == null) {
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please select a agreement date'),
                                    duration: Duration(seconds: 2),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              });
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: workordervalueincludinggstController,
                          keyboardType: TextInputType.number,
                          inputFormatters: !isViewOnly
                              ? [
                            TextInputFormatter.withFunction(
                                    (oldValue, newValue) {
                                  if (newValue.text.isEmpty) {
                                    return newValue;
                                  }
                                  String value =
                                  newValue.text.replaceAll(',', '');
                                  value = value.replaceAll(
                                      RegExp(r'[^0-9]'), '');
                                  if (value.isEmpty) {
                                    return const TextEditingValue();
                                  }
                                  final formatter =
                                  NumberFormat("#,##,##0", "en_IN");
                                  final newText =
                                  formatter.format(int.parse(value));
                                  return TextEditingValue(
                                    text: newText,
                                    selection: TextSelection.collapsed(
                                      offset: newText.length,
                                    ),
                                  );
                                }),
                          ]
                              : null,
                          readOnly: isViewOnly,
                          enabled: !isViewOnly,
                          decoration: InputDecoration(
                            labelText: "Work order value including GST",
                            hintText: "Work order value including GST",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            suffixIcon: workordervalueincludinggstController
                                .text.isNotEmpty &&
                                !isViewOnly
                                ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  workordervalueincludinggstController
                                      .clear();
                                });
                              },
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear value',
                            )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Tenure & Liability Period
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: tenureController,
                          decoration: InputDecoration(
                            labelText: "Tenure of the project",
                            hintText: "Tenure of the project",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            suffixIcon: tenureController.text.isNotEmpty &&
                                !isViewOnly
                                ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  tenureController.clear();
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
                          controller: liabilityController,
                          decoration: InputDecoration(
                            labelText: "Defect liability period",
                            hintText: "Defect liability period",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            suffixIcon: liabilityController.text.isNotEmpty &&
                                !isViewOnly
                                ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  liabilityController.clear();
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

                  ///Billing Details
                  Text(
                    'Billing Details',
                    style: TextStyle(
                        fontSize: 16, color: AppColors.primaryLight),
                  ),
                  const SizedBox(height: 16),

                  ///Type of contract
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: contractController,
                          decoration: InputDecoration(
                            labelText: "Type of contract",
                            hintText: "Type of contract",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            suffixIcon: contractController.text.isNotEmpty &&
                                !isViewOnly
                                ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  contractController.clear();
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
                          controller: methodofbillingController,
                          decoration: InputDecoration(
                            labelText: "Method of billing",
                            hintText: "Method of billing",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            suffixIcon: methodofbillingController
                                .text.isNotEmpty &&
                                !isViewOnly
                                ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  methodofbillingController.clear();
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

                  ///Billing frequency & Milestones
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: billingfrequencyController,
                          decoration: InputDecoration(
                            labelText: "Billing frequency & payment terms",
                            hintText: "Billing frequency & payment terms",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            suffixIcon: billingfrequencyController
                                .text.isNotEmpty &&
                                !isViewOnly
                                ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  billingfrequencyController.clear();
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
                          controller: milestonesController,
                          decoration: InputDecoration(
                            labelText: "Milestones",
                            hintText: "Milestones",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            suffixIcon: milestonesController
                                .text.isNotEmpty &&
                                !isViewOnly
                                ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  milestonesController.clear();
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

                  ///Retention & Bank guarantee
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: retentionController,
                          decoration: InputDecoration(
                            labelText: "Retention",
                            hintText: "Retention",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            suffixIcon: retentionController.text.isNotEmpty &&
                                !isViewOnly
                                ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  retentionController.clear();
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
                        child: DropdownButtonFormField<String>(
                          value: selectedbankreq,
                          decoration:
                          _inputDecoration("Bank guarantee requirements")
                              .copyWith(
                            suffixIcon: (!isViewOnly &&
                                selectedbankreq != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedbankreq = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: bankreq.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              selectedbankreq = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Escalation & Tax Structure
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedescl,
                          decoration:
                          _inputDecoration("Escalation & basic details")
                              .copyWith(
                            suffixIcon: (!isViewOnly && selectedescl != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedescl = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: esclbas.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              selectedescl = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedtax,
                          decoration:
                          _inputDecoration("Tax structure changes")
                              .copyWith(
                            suffixIcon: (!isViewOnly && selectedtax != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedtax = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: taxstructure.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              selectedtax = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Scope clearance
                  Text(
                    'Scope clearance',
                    style: TextStyle(
                        fontSize: 16, color: AppColors.primaryLight),
                  ),
                  const SizedBox(height: 16),

                  /// Scope of works
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: workscope,
                          decoration:
                          _inputDecoration("Scope of works duly signed")
                              .copyWith(
                            suffixIcon: (!isViewOnly && workscope != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  workscope = null;
                                  selectedworkscope = null;
                                  workscopeController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: workscopesigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              workscope = value;
                              if (value == 'No') {
                                selectedworkscope = null;
                                workscopeController.text = "Nil";
                              } else {
                                workscopeController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (workscope != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedworkscope,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedworkscope != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedworkscope = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: workscopeoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedworkscope = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (workscope == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: workscopeController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (workscopeController.text == "Nil") {
                                workscopeController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Water Proofing
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: waterproofing,
                          decoration:
                          _inputDecoration("Waterproofing Methodology")
                              .copyWith(
                            suffixIcon: (!isViewOnly && waterproofing != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  waterproofing = null;
                                  selectedwaterproffing = null;
                                  waterproffingController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: waterproofingsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              waterproofing = value;
                              if (value == 'No') {
                                selectedwaterproffing = null;
                                waterproffingController.text = "Nil";
                              } else {
                                waterproffingController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (waterproofing != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedwaterproffing,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedwaterproffing != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedwaterproffing = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: waterproofingoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedwaterproffing = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (waterproofing == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: waterproffingController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (waterproffingController.text == "Nil") {
                                waterproffingController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Anti termite work
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: antitermite,
                          decoration:
                          _inputDecoration("Anti termite work").copyWith(
                            suffixIcon: (!isViewOnly && antitermite != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  antitermite = null;
                                  selectedantitermite = null;
                                  antitermiteController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: antitermitesigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              antitermite = value;

                              if (value == 'No') {
                                selectedantitermite = null;
                                antitermiteController.text = "Nil";
                              } else {
                                antitermiteController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (antitermite != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedantitermite,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedantitermite != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedantitermite = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: antitermiteoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedantitermite = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (antitermite == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: antitermiteController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (antitermiteController.text == "Nil") {
                                antitermiteController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Site access
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: siteacc,
                          decoration: _inputDecoration(
                              "Site access & local site issues")
                              .copyWith(
                            suffixIcon: (!isViewOnly && siteacc != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  siteacc = null;
                                  selectedsiteacc = null;
                                  siteaccController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: siteaccsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              siteacc = value;

                              if (value == 'No') {
                                selectedsiteacc = null;
                                siteaccController.text = "Nil";
                              } else {
                                siteaccController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (siteacc != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedsiteacc,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedsiteacc != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedsiteacc = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: siteaccoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedsiteacc = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (siteacc == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: siteaccController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (siteaccController.text == "Nil") {
                                siteaccController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Dewatering
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: dewatering,
                          decoration: _inputDecoration("Dewatering").copyWith(
                            suffixIcon: (!isViewOnly && dewatering != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  dewatering = null;
                                  selecteddewatering = null;
                                  dewateringController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: dewateringsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              dewatering = value;

                              if (value == 'No') {
                                selecteddewatering = null;
                                dewateringController.text = "Nil";
                              } else {
                                dewateringController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (dewatering != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selecteddewatering,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selecteddewatering != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selecteddewatering = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: dewateringoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selecteddewatering = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (dewatering == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: dewateringController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (dewateringController.text == "Nil") {
                                dewateringController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Electricity & Water
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: electricitywater,
                          decoration: _inputDecoration("Electricity & Water")
                              .copyWith(
                            suffixIcon: (!isViewOnly &&
                                electricitywater != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  electricitywater = null;
                                  selectedelectricitywater = null;
                                  electricitywaterController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: electricitywatersigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              electricitywater = value;

                              if (value == 'No') {
                                selectedelectricitywater = null;
                                electricitywaterController.text = "Nil";
                              } else {
                                electricitywaterController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (electricitywater != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedelectricitywater,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedelectricitywater != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedelectricitywater = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: electricitywateroption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedelectricitywater = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (electricitywater == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: electricitywaterController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (electricitywaterController.text == "Nil") {
                                electricitywaterController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Steel & Cement brands
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: steelcement,
                          decoration:
                          _inputDecoration("Steel & Cement brands")
                              .copyWith(
                            suffixIcon: (!isViewOnly && steelcement != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  steelcement = null;
                                  selectedsteelcement = null;
                                  steelcementController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: steelcementsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              steelcement = value;

                              if (value == 'No') {
                                selectedsteelcement = null;
                                steelcementController.text = "Nil";
                              } else {
                                steelcementController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (steelcement != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedsteelcement,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedsteelcement != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedsteelcement = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: steelcementoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedsteelcement = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (steelcement == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: steelcementController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (steelcementController.text == "Nil") {
                                steelcementController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Non tendered items plus % margin
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: tendermargin,
                          decoration: _inputDecoration(
                              "Non tendered items plus % margin")
                              .copyWith(
                            suffixIcon: (!isViewOnly && tendermargin != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  tendermargin = null;
                                  selectedtendermargin = null;
                                  tendermarginController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: tendermarginsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              tendermargin = value;

                              if (value == 'No') {
                                selectedtendermargin = null;
                                tendermarginController.text = "Nil";
                              } else {
                                tendermarginController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (tendermargin != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedtendermargin,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedtendermargin != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedtendermargin = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: tendermarginoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedtendermargin = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (tendermargin == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: tendermarginController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (tendermarginController.text == "Nil") {
                                tendermarginController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Soil excavation
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: soil,
                          decoration: _inputDecoration(
                              "Soil excavation, storage & backfilling including royalties, hardrock & soft rock issues, sheet piling - as per site condition")
                              .copyWith(
                            suffixIcon: (!isViewOnly && soil != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  soil = null;
                                  selectedsoil = null;
                                  soilController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: soilsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              soil = value;

                              if (value == 'No') {
                                selectedsoil = null;
                                soilController.text = "Nil";
                              } else {
                                soilController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (soil != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedsoil,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedsoil != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedsoil = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: soiloption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedsoil = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (soil == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: soilController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (soilController.text == "Nil") {
                                soilController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///All statutory approvals for building
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: statapproval,
                          decoration: _inputDecoration(
                              "All statutory approvals for building")
                              .copyWith(
                            suffixIcon: (!isViewOnly && statapproval != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  statapproval = null;
                                  selectedstatapproval = null;
                                  statapprovalController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: statapprovalsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              statapproval = value;

                              if (value == 'No') {
                                selectedstatapproval = null;
                                statapprovalController.text = "Nil";
                              } else {
                                statapprovalController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (statapproval != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedstatapproval,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedstatapproval != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedstatapproval = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: statapprovaloption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedstatapproval = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (statapproval == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: statapprovalController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (statapprovalController.text == "Nil") {
                                statapprovalController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Soil investigation / survey
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: soilsurvey,
                          decoration:
                          _inputDecoration("Soil investigation / survey")
                              .copyWith(
                            suffixIcon: (!isViewOnly && soilsurvey != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  soilsurvey = null;
                                  selectedsoilsurvey = null;
                                  soilsurveyController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: soilsurveysigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              soilsurvey = value;

                              if (value == 'No') {
                                selectedsoilsurvey = null;
                                soilsurveyController.text = "Nil";
                              } else {
                                soilsurveyController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (soilsurvey != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedsoilsurvey,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedsoilsurvey != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedsoilsurvey = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: soilsurveyoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedsoilsurvey = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (soilsurvey == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: soilsurveyController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (soilsurveyController.text == "Nil") {
                                soilsurveyController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Barrication
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: barrication,
                          decoration:
                          _inputDecoration("Barrication").copyWith(
                            suffixIcon: (!isViewOnly && barrication != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  barrication = null;
                                  selectedbarrication = null;
                                  barricationController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: barricationsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              barrication = value;

                              if (value == 'No') {
                                selectedbarrication = null;
                                barricationController.text = "Nil";
                              } else {
                                barricationController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (barrication != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedbarrication,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedbarrication != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedbarrication = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: barricationoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedbarrication = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (barrication == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: barricationController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (barricationController.text == "Nil") {
                                barricationController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Tree cutting / Demolition / Debris removal / EB & Utility line shifiting / Open well closing
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: treecutting,
                          decoration: _inputDecoration(
                              "Tree cutting / Demolition / Debris removal / EB & Utility line shifiting / Open well closing")
                              .copyWith(
                            suffixIcon: (!isViewOnly && treecutting != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  treecutting = null;
                                  selectedtreecutting = null;
                                  treecuttingController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: treecuttingsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              treecutting = value;

                              if (value == 'No') {
                                selectedtreecutting = null;
                                treecuttingController.text = "Nil";
                              } else {
                                treecuttingController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (treecutting != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedtreecutting,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedtreecutting != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedtreecutting = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: treecuttingoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedtreecutting = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (treecutting == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: treecuttingController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (treecuttingController.text == "Nil") {
                                treecuttingController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Labour accommodation
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: labouracc,
                          decoration: _inputDecoration("Labour accommodation")
                              .copyWith(
                            suffixIcon: (!isViewOnly && labouracc != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  labouracc = null;
                                  selectedlabouracc = null;
                                  labouraccController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: labouraccsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              labouracc = value;

                              if (value == 'No') {
                                selectedlabouracc = null;
                                labouraccController.text = "Nil";
                              } else {
                                labouraccController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (labouracc != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedlabouracc,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedlabouracc != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedlabouracc = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: labouraccoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedlabouracc = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (labouracc == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: labouraccController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (labouraccController.text == "Nil") {
                                labouraccController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Brick work internal & external
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: brickwork,
                          decoration: _inputDecoration(
                              "Brick work internal & external")
                              .copyWith(
                            suffixIcon: (!isViewOnly && brickwork != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  brickwork = null;
                                  selectedbrickwork = null;
                                  brickworkController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: brickworksigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              brickwork = value;

                              if (value == 'No') {
                                selectedbrickwork = null;
                                brickworkController.text = "Nil";
                              } else {
                                brickworkController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (brickwork != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedbrickwork,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedbrickwork != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedbrickwork = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: brickworkoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedbrickwork = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (brickwork == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: brickworkController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (brickworkController.text == "Nil") {
                                brickworkController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Site security
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: sitesec,
                          decoration:
                          _inputDecoration("Site security").copyWith(
                            suffixIcon: (!isViewOnly && sitesec != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  sitesec = null;
                                  selectedsitesec = null;
                                  sitesecController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: sitesecsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              sitesec = value;

                              if (value == 'No') {
                                selectedsitesec = null;
                                sitesecController.text = "Nil";
                              } else {
                                sitesecController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (sitesec != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedsitesec,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedsitesec != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedsitesec = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: sitesecoption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedsitesec = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (sitesec == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: sitesecController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (sitesecController.text == "Nil") {
                                sitesecController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Lighting arrangements
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: lightarr,
                          decoration:
                          _inputDecoration("Lighting arrangements")
                              .copyWith(
                            suffixIcon: (!isViewOnly && lightarr != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  lightarr = null;
                                  selectedlightarr = null;
                                  lightarrController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: lightarrsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              lightarr = value;

                              if (value == 'No') {
                                selectedlightarr = null;
                                lightarrController.text = "Nil";
                              } else {
                                lightarrController.clear();
                              }
                            });
                          },
                        ),
                      ),

                      /// Show Second Dropdown only when value is NOT "No"
                      if (lightarr != 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedlightarr,
                            decoration: _inputDecoration("").copyWith(
                              suffixIcon: (!isViewOnly &&
                                  selectedlightarr != null)
                                  ? IconButton(
                                onPressed: () {
                                  setState(() {
                                    selectedlightarr = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                padding: EdgeInsets.zero,
                                tooltip: 'Clear selection',
                              )
                                  : null,
                            ),
                            items: lightarroption.map((status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: isViewOnly
                                ? null
                                : (value) {
                              setState(() {
                                selectedlightarr = value;
                              });
                            },
                          ),
                        ),
                      ],

                      /// Show Remarks only when first dropdown = "No"
                      if (lightarr == 'No') ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: lightarrController,
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            onTap: () {
                              if (lightarrController.text == "Nil") {
                                lightarrController.clear();
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: "Remarks",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Legal aspects
                  Text(
                    'Legal aspects',
                    style: TextStyle(
                        fontSize: 16, color: AppColors.primaryLight),
                  ),
                  const SizedBox(height: 16),

                  ///Force majeure conditions & Arbitration clause
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: forcemaj,
                          decoration:
                          _inputDecoration("Force majeure conditions")
                              .copyWith(
                            suffixIcon: (!isViewOnly && forcemaj != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  forcemaj = null;
                                  selectedforcemaj = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: forcemajsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              forcemaj = value;

                              if (value == 'No') {
                                selectedforcemaj = null;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: arbitration,
                          decoration:
                          _inputDecoration("Arbitration clause").copyWith(
                            suffixIcon: (!isViewOnly && arbitration != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  arbitration = null;
                                  selectedarbitration = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: arbitrationsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              arbitration = value;

                              if (value == 'No') {
                                selectedarbitration = null;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Labour compliance including insurance
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: labourcomp,
                          decoration:
                          _inputDecoration("Lab comp incl ins").copyWith(
                            suffixIcon: (!isViewOnly && labourcomp != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  labourcomp = null;
                                  selectedlabourcomp = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: labourcompsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              labourcomp = value;

                              if (value == 'No') {
                                selectedlabourcomp = null;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Liquidated damages & Stability certificate clause
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: liqdamage,
                          decoration:
                          _inputDecoration("Liq damages").copyWith(
                            suffixIcon: (!isViewOnly && liqdamage != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  liqdamage = null;
                                  selectedliqdamage = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: liqdamagesigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              liqdamage = value;

                              if (value == 'No') {
                                selectedliqdamage = null;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: stability,
                          decoration:
                          _inputDecoration("Stability certificate clause")
                              .copyWith(
                            suffixIcon: (!isViewOnly && stability != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  stability = null;
                                  selectedstability = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: stabilitysigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              stability = value;

                              if (value == 'No') {
                                selectedstability = null;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Other remarks
                  Text(
                    'Other remarks',
                    style: TextStyle(
                        fontSize: 16, color: AppColors.primaryLight),
                  ),
                  const SizedBox(height: 16),

                  /// Grout - Teemax approval & Expansion joint requirements
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown (Grout)
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: grout,
                          decoration: _inputDecoration(
                            "Grout - Teemax approval",
                          ).copyWith(
                            suffixIcon: (!isViewOnly && grout != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  grout = null;
                                  selectedgrout = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: groutsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              grout = value;
                              if (value == 'No') {
                                selectedgrout = null;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      /// Second Dropdown (Joint Requirement)
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: jointreq,
                          decoration: _inputDecoration(
                            "Expansion joint requirements",
                          ).copyWith(
                            suffixIcon: (!isViewOnly && jointreq != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  jointreq = null;
                                  selectedjointreq = null;
                                  jointreqController.clear();
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: jointreqsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              jointreq = value;
                              if (value == 'No') {
                                selectedjointreq = null;
                                jointreqController.text = "Nil";
                              } else {
                                jointreqController.clear();
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      /// Third Field (Remarks or Dropdown based on jointreq)
                      Expanded(
                        flex: 1,
                        child: jointreq == 'No'
                            ? TextFormField(
                          controller: jointreqController,
                          readOnly: isViewOnly,
                          enabled: !isViewOnly,
                          onTap: () {
                            if (!isViewOnly &&
                                jointreqController.text == "Nil") {
                              jointreqController.clear();
                            }
                          },
                          decoration: InputDecoration(
                            labelText: "Remarks",
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            suffixIcon: !isViewOnly &&
                                jointreqController
                                    .text.isNotEmpty &&
                                jointreqController.text != "Nil"
                                ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18),
                              onPressed: () {
                                setState(() {
                                  jointreqController.clear();
                                });
                              },
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear remarks',
                            )
                                : null,
                          ),
                        )
                            : DropdownButtonFormField<String>(
                          value: selectedjointreq,
                          decoration: _inputDecoration("").copyWith(
                            suffixIcon: (!isViewOnly &&
                                selectedjointreq != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedjointreq = null;
                                });
                              },
                              icon: const Icon(Icons.clear,
                                  size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: jointreqoption.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              selectedjointreq = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Idle Charges & Third party tests
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// First Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: idlecharg,
                          decoration:
                          _inputDecoration("Idle Charges").copyWith(
                            suffixIcon: (!isViewOnly && idlecharg != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  idlecharg = null;
                                  selectedidlecharg = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: idlechargsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              idlecharg = value;

                              if (value == 'No') {
                                selectedidlecharg = null;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: thirdpartytest,
                          decoration:
                          _inputDecoration("Third party tests").copyWith(
                            suffixIcon: (!isViewOnly &&
                                thirdpartytest != null)
                                ? IconButton(
                              onPressed: () {
                                setState(() {
                                  thirdpartytest = null;
                                  selectedthirdpartytest = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                                : null,
                          ),
                          items: thirdpartytestsigned.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: isViewOnly
                              ? null
                              : (value) {
                            setState(() {
                              thirdpartytest = value;

                              if (value == 'No') {
                                selectedthirdpartytest = null;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ///Submit & Update Button
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
                                offset: Offset(2, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () async {
                              if (_formKey.currentState!.validate()) {
                                await insertSalesChecklist();
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 15),
                              child: Center(
                                child: Text(
                                  isEditing ? 'Update' : 'Submit',
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
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}*/
