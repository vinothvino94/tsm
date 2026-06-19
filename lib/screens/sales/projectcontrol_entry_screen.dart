import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tsm/screens/sales/view_projeectcontrol_screen.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';
import '../../widgets/crop_screen.dart';
import 'dart:typed_data';

import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path/path.dart' as path;

class ProjectcontrolEntryScreen extends StatefulWidget {
  final bool isSuperAdmin;
  final bool? isReadOnly;
  final ProjectcontrolModel? pcData;
  final VoidCallback? onDataSaved;
  const ProjectcontrolEntryScreen({
    super.key,
    this.isSuperAdmin = false,
    this.isReadOnly = false,
    this.pcData,
    this.onDataSaved,
  });

  @override
  State<ProjectcontrolEntryScreen> createState() =>
      _ProjectcontrolEntryScreenState();
}

class _ProjectcontrolEntryScreenState extends State<ProjectcontrolEntryScreen> {
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

  List<PCEntryModel> _salesEntries = [];
  bool _hasAttemptedSubmit = false;
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

    if (widget.pcData != null) {
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
        title: const Text('Project Control Update'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'View Project Control List',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewProjectControlScreen(
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
                  ///Ele Name - TextFormField
                  Expanded(
                    child: isViewOnly
                        ? TextFormField(
                            controller: elenameController,
                            decoration: _inputDecoration("Name of Element"),
                            readOnly: true,
                            enabled: false,
                          )
                        : TextFormField(
                            controller: elenameController,
                            decoration: InputDecoration(
                              labelText: "Name of Element",
                              hintText: "Enter Element Name",
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              suffixIcon: elenameController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          elenameController.clear();
                                          selectedEleCode = null;
                                          selectedEleName = null;
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      tooltip: 'Clear value',
                                    )
                                  : null,
                            ),
                            readOnly: isViewOnly,
                            enabled: !isViewOnly,
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                            inputFormatters: [
                              UpperCaseTextFormatter(), // ← add this
                            ],
                            textCapitalization:
                                TextCapitalization.characters, // ✅ All caps
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
                    _addPCEntry();
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
                      child: _buildPCEntriesTable(),
                    )
                  : _buildPCEntriesTable(),
              const SizedBox(height: 16),

              ///Projectcontrol Details
              Text(
                'Projectcontrol Details',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              ///Project Control Entries Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ///Project Control Total
                  Expanded(
                    child: TextFormField(
                      controller: deletotalController,
                      decoration: InputDecoration(
                        labelText: "Project Control Total",
                        hintText: "Project Control Total",
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

                  ///Remarks
                  Expanded(
                    child: TextFormField(
                      controller: delermksController,
                      decoration: InputDecoration(
                        labelText: "Remarks",
                        hintText: "Remarks",
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

              ///Project Control Document Attachment
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
                    Text('Project Control Existing Attachments:',
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
                    Text('Project Control New Attachments:',
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
                              widget.pcData != null
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
                  label: 'Project Control Files',
                  onPressed: pcpickFiles,
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

  Future<void> pcpickFiles() async {
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
    // Show snackbar asking user to download first
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download the attachment first to view it.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submitForm() async {
    try {
      final isEditing = widget.pcData != null;

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

      // Prepare comma-separated values
      String elementNames = _salesEntries.map((e) => e.elementName).join(',');
      String spcelementNames = _salesEntries.map((e) => e.sTotal).join(',');
      String pcelementTotals = _salesEntries.map((e) => e.pcTotal).join(',');
      String deleremksList = _salesEntries.map((e) => e.pcremarks).join(',');

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
      final design = ProjectcontrolModel(
        SPCNO: isEditing ? (widget.pcData?.SPCNO ?? 0) : 0,
        CUSID: selectedCustomerId,
        PROJID: selectedProjectId,
        SPCNAME: elementNames,
        SPCTOT: spcelementNames,
        SPCSNO: totalEntries,
        SFNAME: widget.pcData?.SFNAME,
        SFTYPE: widget.pcData?.SFTYPE,
        SFCOUNT: widget.pcData?.SFCOUNT,
        PCFNAME: widget.pcData?.PCFNAME,
        PCFTYPE: widget.pcData?.PCFTYPE,
        PCFCOUNT: widget.pcData?.PCFCOUNT,
        PCTOT: pcelementTotals,
        PCREMKS: deleremksList,
        // ✅ Only send ADDUSER on INSERT
        ADDUSER: isEditing ? null : empCode,
        // ✅ Only send edituser/editdate on UPDATE (edit)
        EDITUSER: isEditing ? empCode : null,
        EDITDATE: isEditing ? DateTime.now() : null,
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
                ? 'Project Control Entry Updated Successfully'
                : 'Project Control Entry Saved Successfully'),
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
      final uri = ApiUtils.getUri('SaveProjectControl');
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
    final data = widget.pcData!;

    // Set selected IDs
    selectedCustomerId = data.CUSID;
    selectedProjectId = data.PROJID;

    // Wait for customerList to be populated if needed
    if (customerList.isEmpty) {
      await loadCustomers();
    }

    // Find and display customer name
    if (data.CUSID != null) {
      final customer = customerList.firstWhere(
        (c) => c.customerId == data.CUSID,
        orElse: () => ChecklistCustomer(customerId: 0, companyName: ''),
      );
      if (customer.customerId > 0) {
        customerController.text =
            "${customer.customerId} - ${customer.companyName}";
        debugPrint('Customer set: ${customerController.text}');
      } else {
        await _fetchAndSetCustomerName(data.CUSID!);
      }
    }

    // Load projects for this customer
    if (data.CUSID != null) {
      await loadProjects(data.CUSID!);
    }

    // Find and display project name
    if (data.PROJID != null && projectList.isNotEmpty) {
      final project = projectList.firstWhere(
        (p) => p.projectId == data.PROJID,
        orElse: () => Project(projectId: 0, projectName: ''),
      );
      if (project.projectId > 0) {
        siteController.text = "${project.projectId} - ${project.projectName}";
        debugPrint('Project set: ${siteController.text}');
      }
    }

    // ✅ Set existing Sales files
    if (data.SFNAME != null && data.SFNAME!.isNotEmpty) {
      _existingSalesFiles = data.SFNAME!.split(',');
      debugPrint('Existing Sales files: $_existingSalesFiles');
    } else {
      _existingSalesFiles = [];
    }

    // ✅ Set existing Design files
    if (data.PCFNAME != null && data.PCFNAME!.isNotEmpty) {
      _existingDesignFiles = data.PCFNAME!.split(',');
      debugPrint('Existing Design files: $_existingDesignFiles');
    } else {
      _existingDesignFiles = [];
    }

    // ✅ Parse comma-separated values
    final elementNames = data.SPCNAME
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    [];
    final elementTotals = data.SPCTOT
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    // ✅ Parse DELETOT correctly (Design Totals)
    final designTotals = data.PCTOT != null && data.PCTOT!.isNotEmpty
        ? data.PCTOT!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
        : [];

    // ✅ Parse DELEREMKS correctly (Remarks)
    final remarks = data.PCREMKS != null && data.PCREMKS!.isNotEmpty
        ? data.PCREMKS!
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

      String total = i < elementTotals.length ? elementTotals[i] : '';

      // ✅ IMPORTANT: Get designTotal from designTotals list, not from elementTotals
      String designTotal = i < designTotals.length ? designTotals[i] : '0';
      String dremarks = i < remarks.length ? remarks[i] : '';

      // Only add if there's at least a name
      if (name.isNotEmpty) {
        _salesEntries.add(
          PCEntryModel(
            elementName: name,
            sTotal: total,
            pcTotal: designTotal,
            pcremarks: dremarks,
            sfname: data.SFNAME,
            sftype: data.SFTYPE,
          ),
        );
      }
    }

    // ✅ Set the FIRST entry in the input fields
    if (_salesEntries.isNotEmpty) {
      final firstEntry = _salesEntries.first;
      elenameController.text = firstEntry.elementName;

      deletotalController.text = firstEntry.pcTotal; // ✅ Set Design Total
      delermksController.text = firstEntry.pcremarks; // ✅ Set Remarks
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

  Widget _buildPCEntriesTable() {
    if (_salesEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    const double headerFs = 13;
    const double cellFs = 13;

    // ✅ Calculate totals
    double totalSales = 0;
    double totalDesign = 0;

    for (var entry in _salesEntries) {
      totalSales +=
          double.tryParse(entry.sTotal?.replaceAll(',', '') ?? '0') ?? 0;
      totalDesign += double.tryParse(entry.pcTotal.replaceAll(',', '')) ?? 0;
    }

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
                label: Text('Sales Qnty',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: const Color(0xFF1E293B))),
                numeric: true,
              ),
              DataColumn(
                label: Text('Proj Ctrl Qnty',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: headerFs,
                        color: const Color(0xFF1E293B))),
                numeric: true,
              ),
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
            rows: [
              // ── Data Rows ──
              ...List.generate(
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
                      // Sales Total
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            entry.sTotal ?? '0',
                            style: TextStyle(
                              fontSize: cellFs,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ),
                      // PC Total
                      DataCell(
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            entry.pcTotal,
                            style: TextStyle(
                              fontSize: cellFs,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Remarks cell
                      DataCell(
                        Text(
                          entry.pcremarks ?? '',
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
                                eletotalController.text = entry.sTotal ?? '';
                                deletotalController.text = entry.pcTotal;
                                delermksController.text = entry.pcremarks ?? '';

                                // ✅ Remove the elementMasterList lookup - it's not needed
                                // Just remove the entry from the list
                                setState(() {
                                  _salesEntries.removeAt(index);
                                  // Clear any selection (since it's not a dropdown)
                                  selectedEleCode = null;
                                  selectedEleName = null;
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

              // ── ✅ TOTAL ROW (MUST HAVE EXACTLY 6 CELLS) ──
              DataRow(
                color: WidgetStateProperty.all(
                  Colors.indigo.shade50.withOpacity(0.6),
                ),
                cells: [
                  // S.No - Summary Icon
                  DataCell(
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade100,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(
                        Icons.summarize,
                        size: 16,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                  ),
                  // "TOTAL" label
                  DataCell(
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: cellFs + 1,
                        fontWeight: FontWeight.w700,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                  ),
                  // ✅ Total Sales
                  DataCell(
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        totalSales.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: cellFs + 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo.shade800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  // ✅ Total PC
                  DataCell(
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        totalDesign.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: cellFs + 1,
                          fontWeight: FontWeight.w700,
                          color: Colors.indigo.shade800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  // Empty Remarks
                  DataCell(
                    Text(
                      '',
                      style: TextStyle(
                        fontSize: cellFs,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  // Empty Actions
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 20),
                      ],
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

  void _addPCEntry() {
    final elementName = elenameController.text.trim();
    final salesTotal = eletotalController.text.trim();
    final designTotal = deletotalController.text.trim();
    final designRemarks = delermksController.text.trim();

    // Validation
    if (elementName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter an Element Name"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (salesTotal.isEmpty) {
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
      _salesEntries.add(PCEntryModel(
        elementName: elementName,
        sTotal: salesTotal,
        pcTotal: designTotal,
        pcremarks: designRemarks,
      ));

      // Clear ALL fields
      elenameController.clear();
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
