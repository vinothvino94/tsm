import 'dart:convert';
import 'dart:io';
import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tsm/screens/sales/view_design_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';
import '../../widgets/crop_screen.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path/path.dart' as path;

class DesignEntryScreen extends StatefulWidget {
  final bool isSuperAdmin;
  final bool? isReadOnly;
  final SalesDesignModel? designData;
  final VoidCallback? onDataSaved;
  const DesignEntryScreen({
    super.key,
    this.isSuperAdmin = false,
    this.isReadOnly = false,
    this.designData,
    this.onDataSaved,
  });

  @override
  State<DesignEntryScreen> createState() => _DesignEntryScreenState();
}

class _DesignEntryScreenState extends State<DesignEntryScreen> {
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  TextEditingController customerController = TextEditingController();
  TextEditingController siteController = TextEditingController();
  TextEditingController elenameController = TextEditingController();
  TextEditingController deleqntyController = TextEditingController();
  TextEditingController eleunitController = TextEditingController();
  TextEditingController eletotalController = TextEditingController();
  TextEditingController deletotalController = TextEditingController();
  TextEditingController delermksController = TextEditingController();

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

  List<SalesEntryModel> _salesEntries = [];
  bool _hasAttemptedSubmit = false;
  List<ElementMasterModel> elementMasterList = [];
  int? selectedEleCode;
  String? selectedEleName;

  // ✅ Separate file lists for Sales and Design
  List<PlatformFile> _salesAttachedFiles = [];
  List<String> _existingSalesFiles = [];
  List<String> _removedSalesFiles = [];

  List<PlatformFile> _designAttachedFiles = [];
  List<String> _existingDesignFiles = [];
  List<String> _removedDesignFiles = [];

  @override
  void initState() {
    super.initState();
    loadCustomers();
    _loadUserDetails();
    _loadElementMaster();
    if (widget.designData != null) {
      _populateFormData();
    }
  }

  @override
  void dispose() {
    elenameController.dispose();
    eleunitController.dispose();
    eletotalController.dispose();
    deleqntyController.dispose();
    deletotalController.dispose();
    delermksController.dispose();
    customerController.dispose();
    siteController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isViewOnly = widget.isReadOnly == true;
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design Update'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'View Design Entry List',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewDesignScreen(
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

              ///Sales Details
              Text(
                'Sales Details',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              ///Sales Entries
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ///Ele Name - Dropdown
                  Expanded(
                    child: isViewOnly
                        ? TextFormField(
                            controller: elenameController,
                            decoration: _inputDecoration("Name of Element"),
                            readOnly: true,
                            enabled: false,
                          )
                        : DropdownButtonFormField<ElementMasterModel?>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: "Select Element",
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              suffixIcon: selectedEleCode != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          selectedEleCode = null;
                                          selectedEleName = null;
                                          elenameController.clear();
                                          eleunitController.clear();
                                          eletotalController.clear();
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Clear selection',
                                    )
                                  : null,
                            ),
                            value: selectedEleCode != null &&
                                    elementMasterList.isNotEmpty
                                ? elementMasterList.firstWhere(
                                    (e) => e.eleCode == selectedEleCode,
                                    orElse: () => elementMasterList.first,
                                  )
                                : null,
                            items: elementMasterList.map((element) {
                              return DropdownMenuItem<ElementMasterModel>(
                                value: element,
                                child: Text(
                                  element.eleName ?? '',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (ElementMasterModel? selected) {
                              if (selected != null) {
                                setState(() {
                                  selectedEleCode = selected.eleCode;
                                  selectedEleName = selected.eleName;
                                  elenameController.text =
                                      selected.eleName ?? '';
                                  eleunitController.text =
                                      selected.eleUnit ?? '';
                                });
                              } else {
                                setState(() {
                                  selectedEleCode = null;
                                  selectedEleName = null;
                                  elenameController.clear();
                                  eleunitController.clear();
                                  eletotalController.clear();
                                });
                              }
                            },
                          ),
                  ),
                  const SizedBox(width: 16),

                  ///Ele Unit - Dropdown (Auto-filled from Element Name)
                  Expanded(
                    child: isViewOnly
                        ? TextFormField(
                            controller: eleunitController,
                            decoration: _inputDecoration("Element Unit"),
                            readOnly: true,
                            enabled: false,
                          )
                        : DropdownButtonFormField<String?>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              hintText: "Select Unit",
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              suffixIcon: eleunitController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          eleunitController.clear();
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Clear value',
                                    )
                                  : null,
                            ),
                            value: eleunitController.text.isNotEmpty
                                ? eleunitController.text
                                : null,
                            items: elementMasterList
                                .map((element) => element.eleUnit)
                                .where(
                                    (unit) => unit != null && unit.isNotEmpty)
                                .toSet()
                                .map((unit) {
                              return DropdownMenuItem<String>(
                                value: unit,
                                child: Text(
                                  unit!,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? selectedUnit) {
                              if (selectedUnit != null) {
                                setState(() {
                                  eleunitController.text = selectedUnit;
                                });
                              }
                            },
                          ),
                  ),
                  const SizedBox(width: 16),

                  ///Ele Total
                  Expanded(
                    child: TextFormField(
                      controller: eletotalController,
                      decoration: InputDecoration(
                        labelText: "Element Total",
                        hintText: "Element Total",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            eletotalController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        eletotalController.clear();
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
                ],
              ),
              const SizedBox(height: 16),

              ///Add button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _addSalesEntry();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              // 🔹 TABLE VIEW
              isAndroid
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildSalesEntriesTable(),
                    )
                  : _buildSalesEntriesTable(),
              const SizedBox(height: 16),

              ///Design Details
              Text(
                'Design Details',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              ///Design Entries Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ///Ele Total (Design Total)
                  Expanded(
                    child: TextFormField(
                      controller: deletotalController,
                      decoration: InputDecoration(
                        labelText: "Design Total",
                        hintText: "Design Total",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            deletotalController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        deletotalController.clear();
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

                  ///Ele Remarks
                  Expanded(
                    child: TextFormField(
                      controller: delermksController,
                      decoration: InputDecoration(
                        labelText: "Element Remarks",
                        hintText: "Element Remarks",
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        suffixIcon:
                            delermksController.text.isNotEmpty && !isViewOnly
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        delermksController.clear();
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

              ///Document Upload Section
              _buildAttachCard(),
              const SizedBox(height: 16),

              ///Sales Document Attachment
              ///Document Text
              if (_existingSalesFiles.isEmpty && _salesAttachedFiles.isEmpty)
                Center(
                    child: Text('No files selected',
                        style: TextStyle(color: Colors.grey.shade600))),
              const SizedBox(height: 16),

              /// Existing files (already uploaded)
              if (_existingSalesFiles.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales Existing Attachments:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._existingSalesFiles.map(
                        (fileName) => _buildSExistingAttachmentItem(fileName)),
                  ],
                ),
              const SizedBox(height: 16),

              /// Newly picked files
              if (_salesAttachedFiles.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales New Attachments:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._salesAttachedFiles.map((file) => _buildAttachmentItem(
                          file,
                          _salesAttachedFiles,
                        )),
                  ],
                ),
              const SizedBox(height: 16),

              ///Design Document Attachment
              ///Document Text
              if (_existingDesignFiles.isEmpty && _designAttachedFiles.isEmpty)
                Center(
                    child: Text('No files selected',
                        style: TextStyle(color: Colors.grey.shade600))),
              const SizedBox(height: 16),

              /// Existing files (already uploaded)
              if (_existingDesignFiles.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Design Existing Attachments:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._existingDesignFiles.map(
                        (fileName) => _buildDExistingAttachmentItem(fileName)),
                  ],
                ),
              const SizedBox(height: 16),

              /// Newly picked files
              if (_designAttachedFiles.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Design New Attachments:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._designAttachedFiles.map((file) => _buildAttachmentItem(
                          file,
                          _designAttachedFiles,
                        )),
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
                              widget.designData != null
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

  Future<void> _loadElementMaster() async {
    final elements = await _fetchElementMaster();

    setState(() {
      elementMasterList = elements;
    });
  }

  Future<void> _loadUserDetails() async {
    final prefsHelper = PreferencesHelper();
    empCode = (await prefsHelper.getEmpCode()) ?? 0;
    empName = (await prefsHelper.getEmpName())!;
    setState(() {});
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

  Widget _buildAttachCard() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildAttachButton(
                  icon: Icons.attach_file,
                  label: 'Sales Files',
                  onPressed: salespickFiles,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 200,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildAttachButton(
                  icon: Icons.attach_file,
                  label: 'Design Files',
                  onPressed: designpickFiles,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
          ),
        ],
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

  Future<void> salespickFiles() async {
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
        _salesAttachedFiles.addAll(newFiles);
      });
    }
  }

  Future<void> designpickFiles() async {
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
        _designAttachedFiles.addAll(newFiles);
      });
    }
  }

  Widget _buildAttachmentItem(
    PlatformFile file,
    List<PlatformFile> sourceList,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
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
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        ),
        title: Text(
          file.name,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${(file.size / 1024).toStringAsFixed(1)} KB',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              sourceList.remove(file);
            });
          },
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

  Widget _buildSExistingAttachmentItem(String fileName) {
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
                    _existingSalesFiles.remove(fileName);

                    _removedSalesFiles.add(fileName);

                    print('Marked for deletion: $fileName');
                  });
                },
              )
            : null,
        onTap: () => _previewExistingFile(fileName),
      ),
    );
  }

  Widget _buildDExistingAttachmentItem(String fileName) {
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
                    _existingDesignFiles.remove(fileName);

                    _removedDesignFiles.add(fileName);
                    print('Marked for deletion: $fileName');
                  });
                },
              )
            : null,
        onTap: () => _previewExistingFile(fileName),
      ),
    );
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

  Future<void> _submitForm() async {
    try {
      final isEditing = widget.designData != null;

      // Validate required fields
      if (selectedCustomerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a customer'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (selectedProjectId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a project'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_salesEntries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one sales entry'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Prepare comma-separated values
      String elementNames = _salesEntries.map((e) => e.elementName).join(',');
      String elementUnits = _salesEntries.map((e) => e.unit).join(',');
      String elementTotals = _salesEntries.map((e) => e.totalQty).join(',');
      String delementTotals = _salesEntries.map((e) => e.designTotal).join(',');
      String deleremksList = _salesEntries.map((e) => e.dremarks).join(',');

      int totalEntries = _salesEntries.length;

      // ✅ Prepare Sales files for upload
      List<FileUploadModel>? salesUploadFiles;
      if (_salesAttachedFiles.isNotEmpty) {
        salesUploadFiles = _salesAttachedFiles
            .where((f) => f.bytes != null)
            .map((f) => FileUploadModel(
                  filename: f.name,
                  filedata: base64Encode(f.bytes!),
                ))
            .toList();
      }

      // ✅ Prepare Design files for upload
      List<FileUploadModel>? designUploadFiles;
      if (_designAttachedFiles.isNotEmpty) {
        designUploadFiles = _designAttachedFiles
            .where((f) => f.bytes != null)
            .map((f) => FileUploadModel(
                  filename: f.name,
                  filedata: base64Encode(f.bytes!),
                ))
            .toList();
      }

      // ✅ Build the design model
      final design = SalesDesignModel(
        sdno: isEditing ? (widget.designData?.sdno ?? 0) : 0,
        cusid: selectedCustomerId,
        projid: selectedProjectId,
        selename: elementNames,
        seleunit: elementUnits,
        seletot: elementTotals,
        selesno: totalEntries,
        sfname: widget.designData?.sfname,
        sftype: widget.designData?.sftype,
        sfcount: widget.designData?.sfcount,
        dfname: widget.designData?.dfname,
        dftype: widget.designData?.dftype,
        dfcount: widget.designData?.dfcount,
        deletot: delementTotals,
        deleremks: deleremksList,
        // ✅ Only send ADDUSER on INSERT
        adduser: isEditing ? null : empCode,
        // ✅ Only send edituser/editdate on UPDATE (edit)
        edituser: isEditing ? empCode : null,
        editdate: isEditing ? DateTime.now() : null,
        // ✅ Send separate removed files
        removedSalesFiles:
            _removedSalesFiles.isNotEmpty ? _removedSalesFiles.join(",") : null,
        removedDesignFiles: _removedDesignFiles.isNotEmpty
            ? _removedDesignFiles.join(",")
            : null,
        // ✅ Send separate file lists
        salesFiles: salesUploadFiles,
        designFiles: designUploadFiles,
      );

      // Create request body
      final requestBody = design.toJson();

      // Remove null values to avoid issues
      requestBody.removeWhere((key, value) => value == null);

      print('=== REQUEST BODY ===');
      print(jsonEncode(requestBody));
      print('====================');

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final result = await saveSalesDesign(requestBody);

      if (!mounted) return;
      Navigator.pop(context);

      if (result['Success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Design Entry Updated Successfully'
                : 'Design Entry Saved Successfully'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onDataSaved != null) {
          widget.onDataSaved!();
        }

        Navigator.pop(context, true);
      } else {
        String errorMessage = result['Message']?.toString() ?? 'Unknown error';
        if (result['Errors'] != null) {
          final errors = result['Errors'] as List;
          errorMessage = errors.join('\n');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('Error in _submitForm: $e');
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> saveSalesDesign(
      Map<String, dynamic> requestBody) async {
    try {
      final uri = ApiUtils.getUri('SaveSalesDesign');
      print('Sending to: $uri');

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result;
      } else {
        return {
          'Success': false,
          'Message':
              'Failed to save design entry. Status code: ${response.statusCode}',
        };
      }
    } catch (e, stackTrace) {
      print('Error in saveSalesDesign: $e');
      print('StackTrace: $stackTrace');
      return {'Success': false, 'Message': 'Error: $e'};
    }
  }

  void _populateFormData() async {
    final data = widget.designData!;

    // Set selected IDs
    selectedCustomerId = data.cusid;
    selectedProjectId = data.projid;

    // Wait for customerList to be populated if needed
    if (customerList.isEmpty) {
      await loadCustomers();
    }

    // Find and display customer name
    if (data.cusid != null) {
      final customer = customerList.firstWhere(
        (c) => c.customerId == data.cusid,
        orElse: () => ChecklistCustomer(customerId: 0, companyName: ''),
      );
      if (customer.customerId > 0) {
        customerController.text =
            "${customer.customerId} - ${customer.companyName}";
        debugPrint('Customer set: ${customerController.text}');
      } else {
        await _fetchAndSetCustomerName(data.cusid!);
      }
    }

    // Load projects for this customer
    if (data.cusid != null) {
      await loadProjects(data.cusid!);
    }

    // Find and display project name
    if (data.projid != null && projectList.isNotEmpty) {
      final project = projectList.firstWhere(
        (p) => p.projectId == data.projid,
        orElse: () => Project(projectId: 0, projectName: ''),
      );
      if (project.projectId > 0) {
        siteController.text = "${project.projectId} - ${project.projectName}";
        debugPrint('Project set: ${siteController.text}');
      }
    }

    // ✅ Set existing Sales files
    if (data.sfname != null && data.sfname!.isNotEmpty) {
      _existingSalesFiles = data.sfname!.split(',');
      debugPrint('Existing Sales files: $_existingSalesFiles');
    } else {
      _existingSalesFiles = [];
    }

    // ✅ Set existing Design files
    if (data.dfname != null && data.dfname!.isNotEmpty) {
      _existingDesignFiles = data.dfname!.split(',');
      debugPrint('Existing Design files: $_existingDesignFiles');
    } else {
      _existingDesignFiles = [];
    }

    // ✅ Parse comma-separated values
    final elementNames = data.selename
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final elementUnits = data.seleunit
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final elementTotals = data.seletot
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    // ✅ Parse DELETOT correctly (Design Totals)
    final designTotals = data.deletot != null && data.deletot!.isNotEmpty
        ? data.deletot!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : [];

    // ✅ Parse DELEREMKS correctly (Remarks)
    final remarks = data.deleremks != null && data.deleremks!.isNotEmpty
        ? data.deleremks!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : [];

    // ✅ Populate ALL sales entries
    _salesEntries.clear();

    // Get the maximum length among all lists
    int maxLength = elementNames.length;

    for (int i = 0; i < maxLength; i++) {
      String name = i < elementNames.length ? elementNames[i] : '';
      String unit = i < elementUnits.length ? elementUnits[i] : '';
      String total = i < elementTotals.length ? elementTotals[i] : '';

      // ✅ IMPORTANT: Get designTotal from designTotals list, not from elementTotals
      String designTotal = i < designTotals.length ? designTotals[i] : '0';
      String dremarks = i < remarks.length ? remarks[i] : '';

      // Only add if there's at least a name
      if (name.isNotEmpty) {
        _salesEntries.add(
          SalesEntryModel(
            elementName: name,
            unit: unit,
            totalQty: total,
            designTotal: designTotal, // ✅ This comes from DELETOT
            dremarks: dremarks, // ✅ This comes from DELEREMKS
            sfname: data.sfname,
            sftype: data.sftype,
          ),
        );
      }
    }

    // ✅ Set the FIRST entry in the input fields
    if (_salesEntries.isNotEmpty) {
      final firstEntry = _salesEntries.first;
      elenameController.text = firstEntry.elementName;
      eleunitController.text = firstEntry.unit;
      eletotalController.text = firstEntry.totalQty;
      deletotalController.text = firstEntry.designTotal; // ✅ Set Design Total
      delermksController.text = firstEntry.dremarks; // ✅ Set Remarks

      // Try to find matching element
      if (elementMasterList.isNotEmpty) {
        final matchingElement = elementMasterList.firstWhere(
          (e) => e.eleName == firstEntry.elementName,
          orElse: () => elementMasterList.first,
        );
        if (matchingElement.eleName == firstEntry.elementName) {
          selectedEleCode = matchingElement.eleCode;
          selectedEleName = matchingElement.eleName;
        }
      }
    }

    setState(() {});
    debugPrint('=== FORM POPULATION COMPLETE ===');
  }

  Future<void> _fetchAndSetCustomerName(int customerId) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('ExistingChecklistCustomers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"CUSTOMERID": customerId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['Success'] == true && result['CustomerDetails'] != null) {
          final customers = result['CustomerDetails'] as List;
          if (customers.isNotEmpty) {
            final customer = ChecklistCustomer.fromJson(customers.first);
            customerController.text =
                "${customer.customerId} - ${customer.companyName}";
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
      debugPrint('Error fetching customer: $e');
      // Fallback: show only ID
      customerController.text = customerId.toString();
    }
  }

  Widget _buildSalesEntriesTable() {
    if (_salesEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    const double headerFs = 13;
    const double cellFs = 13;

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
            dataRowMaxHeight: 54,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: [
              DataColumn(
                label: SizedBox(
                  width: 36,
                  child: Text('S.No',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: headerFs,
                          color: const Color(0xFF1E293B))),
                ),
              ),
              DataColumn(
                label: Text('Element Name',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: const Color(0xFF1E293B))),
              ),
              DataColumn(
                label: Text('Unit',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: const Color(0xFF1E293B))),
              ),
              DataColumn(
                label: Text('Sales Total',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: const Color(0xFF1E293B))),
                numeric: true,
              ),
              DataColumn(
                label: Text('Design Total',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: const Color(0xFF1E293B))),
                numeric: true,
              ),
              // ✅ NEW: Remarks column
              DataColumn(
                label: Text('Remarks',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: const Color(0xFF1E293B))),
              ),
              DataColumn(
                label: SizedBox(
                  width: 80,
                  child: Text('Actions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: headerFs,
                          color: const Color(0xFF1E293B))),
                ),
              ),
            ],
            rows: List.generate(
              _salesEntries.length,
              (index) {
                final entry = _salesEntries[index];
                return DataRow(
                  color: WidgetStateProperty.all(
                    index % 2 == 0 ? Colors.white : const Color(0xFFFAFBFD),
                  ),
                  cells: [
                    // S.No badge
                    DataCell(
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF3FA),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                    // Element name
                    DataCell(
                      Text(
                        entry.elementName,
                        style: TextStyle(
                            fontSize: cellFs,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF334155)),
                      ),
                    ),
                    // Unit as a small tag
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF3FA),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.unit,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    // Sales Total
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          entry.totalQty,
                          style: TextStyle(
                            fontSize: cellFs,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    // Design Total
                    DataCell(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          entry.designTotal,
                          style: TextStyle(
                            fontSize: cellFs,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    // ✅ NEW: Remarks cell
                    DataCell(
                      Text(
                        entry.dremarks ??
                            '', // Assuming your SalesEntry model has a 'remark' field
                        style: TextStyle(
                          fontSize: cellFs,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ActionIconButton(
                            icon: Icons.edit_outlined,
                            color: const Color(0xFF2563EB),
                            tooltip: 'Edit',
                            onPressed: () {
                              // Set the values in the controllers
                              elenameController.text = entry.elementName;
                              eleunitController.text = entry.unit;
                              eletotalController.text = entry.totalQty;
                              deletotalController.text = entry.designTotal;
                              delermksController.text =
                                  entry.dremarks ?? ''; // ✅ Load remark

                              // Find and set the selected element
                              final selectedElement =
                                  elementMasterList.firstWhere(
                                (e) => e.eleName == entry.elementName,
                                orElse: () => elementMasterList.first,
                              );

                              setState(() {
                                selectedEleCode = selectedElement.eleCode;
                                selectedEleName = selectedElement.eleName;
                                _salesEntries.removeAt(index);
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Edit the entry and click Add to update"),
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
                                _salesEntries.removeAt(index);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text("Deleted: ${entry.elementName}"),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _addSalesEntry() {
    final elementName = elenameController.text.trim();
    final unit = eleunitController.text.trim();
    final totalQty = eletotalController.text.trim(); // Sales Total
    final designTotal = deletotalController.text.trim(); // Design Total
    final designRemarks = delermksController.text.trim();

    // Validation
    if (elementName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select an Element Name"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (unit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select Element Unit"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (totalQty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter Sales Total"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if entry already exists
    final exists = _salesEntries
        .any((e) => e.elementName.toLowerCase() == elementName.toLowerCase());

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This element already exists! Use Edit to modify."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Add new entry
    setState(() {
      _salesEntries.add(SalesEntryModel(
        elementName: elementName,
        unit: unit,
        totalQty: totalQty,
        designTotal: designTotal, // ✅ Make sure this is set
        dremarks: designRemarks, // ✅ Make sure this is set
      ));

      // Clear ALL fields
      elenameController.clear();
      eleunitController.clear();
      eletotalController.clear();
      deletotalController.clear();
      delermksController.clear();

      selectedEleCode = null;
      selectedEleName = null;
      _hasAttemptedSubmit = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added: $elementName"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<List<ElementMasterModel>> _fetchElementMaster() async {
    try {
      final response = await http.post(
        ApiUtils.getUri('GetSalesElementMaster'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true) {
          final List list = data['Data'];

          return list.map((e) => ElementMasterModel.fromJson(e)).toList();
        } else {}
      }
      return [];
    } catch (e) {
      return [];
    }
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

Future<io.File> _saveToFile(String name, List<int> bytes) async {
  final tempDir = await getTemporaryDirectory();
  final file = io.File('${tempDir.path}/$name');
  return await file.writeAsBytes(bytes);
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
      child: Material(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
