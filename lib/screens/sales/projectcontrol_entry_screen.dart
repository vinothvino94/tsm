import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/pdfgeneratorservice.dart';
import '../../services/prefrence_helper.dart';
import '../../widgets/crop_screen.dart';
import 'dart:typed_data';

import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path/path.dart' as path;
import 'package:pdf/widgets.dart' as pw;

class ProjectcontrolEntryScreen extends StatefulWidget {
  final bool isSuperAdmin;
  final bool? isReadOnly;
  final ProjectcontrolModel? pcData;
  final VoidCallback? onDataSaved;
  final int? initialCustomerId;
  final int? initialProjectId;
  final String? initialCustomerName;
  final String? initialProjectName;
  const ProjectcontrolEntryScreen({
    super.key,
    this.isSuperAdmin = false,
    this.isReadOnly = false,
    this.pcData,
    this.onDataSaved,
    this.initialCustomerId,
    this.initialProjectId,
    this.initialCustomerName,
    this.initialProjectName,
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
  bool _showDownloadButton = true;
  PlutoGridStateManager? _pcStateManager;
  List<PlutoColumn> _pcGridColumns = [];
  List<PlutoRow> _pcGridRows = [];
  Set<String> _existingRowKeys = {};
  int? _changedSpcsno;
  bool _gridDataReady = false;
  bool isEditMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final spcno = widget.pcData?.SPCNO;
    final isEditing = spcno != null && spcno != 0;
    loadCustomers();
    _loadUserDetails();
    _initializePCGrid();
    if (isEditing) {
      _fetchPcEntryData();
    }

    // Seed selection from navigation args (view/edit an existing project)
    if (widget.initialCustomerId != null) {
      selectedCustomerId = widget.initialCustomerId;
    }
    if (widget.initialProjectId != null) {
      selectedProjectId = widget.initialProjectId;
    }
    if (widget.initialCustomerName != null) {
      customerController.text = widget
          .initialCustomerName!; // whatever controller backs the customer field
    }
    if (widget.initialProjectName != null) {
      siteController.text = widget
          .initialProjectName!; // whatever controller backs the project field
    }

    // If we were handed a customer+project, load the grid data for it
    if (selectedCustomerId != null && selectedProjectId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchPcEntryData();
      });
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
                _addPCRow();
                setState(() => _showDownloadButton = false);
              },
            ),
          if (_showDownloadButton)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download Project Control PDF',
              onPressed: () async {
                if (selectedCustomerId == null || selectedProjectId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select Customer and Site first.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (_pcStateManager != null) {
                  _pcGridRows = _pcStateManager!.rows;
                }

                if (_pcGridRows.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No entries to download.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                // ✅ Build grid data as comma-joined strings
                final elementNames = _pcGridRows
                    .map((r) => r.cells['description']?.value?.toString() ?? '')
                    .join(',');

                final elementTotals = _pcGridRows
                    .map((r) => r.cells['salesQty']?.value?.toString() ?? '0')
                    .join(',');
                final designTotals = _pcGridRows
                    .map((r) =>
                        r.cells['projectcontrolqnty']?.value?.toString() ?? '0')
                    .join(',');
                final remarksList = _pcGridRows
                    .map((r) => r.cells['remarks']?.value?.toString() ?? '')
                    .join(',');

                // ✅ Gather all distinct SDNOs currently in the grid (may be multiple merged)
                final sdnoSet = _pcGridRows
                    .map((r) => (r.cells['spcno']?.value as num?)?.toInt() ?? 0)
                    .where((s) => s != 0)
                    .toSet();
                final primarySdno = sdnoSet.isNotEmpty
                    ? sdnoSet.first
                    : (widget.pcData?.SPCNO ?? 0);

                final pdfEntry = ProjectcontrolModel(
                  SPCNO: primarySdno,
                  CUSID: selectedCustomerId,
                  PROJID: selectedProjectId,
                  SPCDT: DateTime.now().toIso8601String(),
                  SPCNAME: elementNames,
                  SPCTOT: elementTotals,
                  PCTOT: designTotals,
                  PCREMKS: remarksList,
                  SFNAME: _existingSalesFiles.join(','),
                  PCFNAME: _existingDesignFiles.join(','),
                );

                // ✅ Generate the PDF summary
                await _generatePCEntriesPDF(pdfEntry);

                // ✅ Also download the actual attached files
                await PCDownloadService.downloadPCFiles(
                  context: context,
                  spcNo: pdfEntry.SPCNO ?? 0,
                  salesFiles: pdfEntry.SFNAME, // Sales files
                  designFiles: pdfEntry.PCFNAME, // Design files
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
                              if (selectedCustomerId != null &&
                                  widget.pcData == null) {
                                // new-entry mode only — don't clobber an edit-in-progress
                                _fetchPcEntryData();
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

              ///Sales & Project Control Details (combined grid entry)
              const Text(
                'Sales & Project Control Details',
                style: TextStyle(fontSize: 16, color: AppColors.primaryLight),
              ),
              const SizedBox(height: 16),

              if (!isViewOnly)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _addPCRow,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Row"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(height: 8),

              Container(
                height: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipBehavior: Clip.antiAlias,
                child: _pcGridColumns.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : PlutoGrid(
                        key: ValueKey(
                            'sales_grid_${_pcGridRows.length}_$_gridDataReady'),
                        columns: _pcGridColumns,
                        rows: _pcGridRows,
                        onLoaded: (event) {
                          _pcStateManager = event.stateManager;
                          _pcStateManager!
                              .setSelectingMode(PlutoGridSelectingMode.cell);
                        },
                        onChanged: (PlutoGridOnChangedEvent event) {
                          _changedSpcsno =
                              (event.row.cells['sno']?.value as num?)?.toInt();
                          try {
                            if (_pcStateManager != null) {
                              _pcGridRows = _pcStateManager!.rows;
                            }
                            if (mounted) {
                              setState(() {});
                            }
                          } catch (e) {
                            debugPrint('Error in onChanged: $e');
                          }
                        },
                        configuration: PlutoGridConfiguration(
                          style: PlutoGridStyleConfig(
                            rowHeight: 45,
                            columnHeight: 50,
                            gridBorderRadius: BorderRadius.circular(8),
                          ),
                          scrollbar: const PlutoGridScrollbarConfig(
                              isAlwaysShown: true),
                        ),
                        noRowsWidget: Center(
                          child: Text(
                            isViewOnly
                                ? 'No entries available'
                                : 'Click "Add Row" to start entering data',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      ),
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
                              isEditMode ? 'Update' : 'Submit',
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
      if (selectedCustomerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select a customer'),
              backgroundColor: Colors.red),
        );
        return;
      }

      if (selectedProjectId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select a project'),
              backgroundColor: Colors.red),
        );
        return;
      }

      if (_pcStateManager != null) {
        _pcGridRows = _pcStateManager!.rows;
      }

      if (_pcGridRows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please add at least one sales entry'),
              backgroundColor: Colors.red),
        );
        return;
      }

      final hasEmptyElement = _pcGridRows.any((row) =>
          (row.cells['description']?.value?.toString().trim() ?? '').isEmpty);
      if (hasEmptyElement) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select Element Name for all rows'),
              backgroundColor: Colors.red),
        );
        return;
      }

      // ✅ Group rows by their original SDNO (0 = new/unsaved rows)
      final Map<int, List<PlutoRow>> groupedBySdno = {};
      for (final row in _pcGridRows) {
        final sdno = (row.cells['spcno']?.value as num?)?.toInt() ?? 0;
        groupedBySdno.putIfAbsent(sdno, () => []).add(row);
      }

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      bool allSuccess = true;
      String lastError = '';

      // ✅ Submit each group separately — update existing SDNOs, insert new rows as one record
      for (final entry in groupedBySdno.entries) {
        final sdno = entry.key;
        final rowsInGroup = entry.value;
        final isUpdatingGroup = sdno != 0;

        final description = rowsInGroup
            .map((r) => r.cells['description']?.value ?? '')
            .join(',');

        final sTotal = rowsInGroup
            .map((r) => r.cells['salesQty']?.value?.toString() ?? '0')
            .join(',');

        final pcTotal = rowsInGroup
            .map((r) => r.cells['projectcontrolqnty']?.value?.toString() ?? '0')
            .join(',');

        final remarks = rowsInGroup
            .map((r) => r.cells['remarks']?.value?.toString() ?? '')
            .join(',');
        debugPrint('DELEREMKS being sent: $remarks');

        List<FileUploadModel>? salesUploadFiles;
        if (_salesAttachedFiles.isNotEmpty) {
          salesUploadFiles = _salesAttachedFiles
              .where((f) => f.bytes != null)
              .map((f) => FileUploadModel(
                  filename: f.name, filedata: base64Encode(f.bytes!)))
              .toList();
        }

        List<FileUploadModel>? designUploadFiles;
        if (_designAttachedFiles.isNotEmpty) {
          designUploadFiles = _designAttachedFiles
              .where((f) => f.bytes != null)
              .map((f) => FileUploadModel(
                  filename: f.name, filedata: base64Encode(f.bytes!)))
              .toList();
        }

        final design = ProjectcontrolModel(
          SPCNO: isUpdatingGroup ? sdno : 0,
          CUSID: selectedCustomerId,
          PROJID: selectedProjectId,
          SPCNAME: description,
          changedSPCsno: _changedSpcsno,
          SPCTOT: sTotal,
          PCTOT: pcTotal,
          PCREMKS: remarks,
          ADDUSER: isUpdatingGroup ? null : empCode,
          EDITUSER: isUpdatingGroup ? empCode : null,
          EDITDATE: isUpdatingGroup ? DateTime.now() : null,
          removedSalesFiles: _removedSalesFiles.isNotEmpty
              ? _removedSalesFiles.join(",")
              : null,
          removedDesignFiles: _removedDesignFiles.isNotEmpty
              ? _removedDesignFiles.join(",")
              : null,
          salesFiles: salesUploadFiles,
          designFiles: designUploadFiles,
        );

        final requestBody = design.toJson();
        requestBody.removeWhere((key, value) => value == null);

        debugPrint('=== REQUEST BODY (SDNO group: $sdno) ===');
        debugPrint(jsonEncode(requestBody));

        final result = await saveSalesDesign(requestBody);

        if (result['Success'] != true) {
          allSuccess = false;
          String errorMessage =
              result['Message']?.toString() ?? 'Unknown error';
          if (result['Errors'] != null) {
            errorMessage = (result['Errors'] as List).join('\n');
          }
          lastError = errorMessage;
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // close loading dialog

      if (allSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_existingRowKeys.isNotEmpty
                ? 'Project Control Entries Updated Successfully'
                : 'Project Control Entry Saved Successfully'),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onDataSaved != null) widget.onDataSaved!();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lastError), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error in _submitForm: $e');
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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

  void _initializePCGrid() {
    _pcGridColumns = [
      PlutoColumn(
        title: 'SPCNO',
        field: 'spcno',
        type: PlutoColumnType.number(),
        hide: true, // hidden, just carried for submit logic
      ),
      PlutoColumn(
        title: 'S.No',
        field: 'sno',
        type: PlutoColumnType.text(),
        readOnly: true,
        enableEditingMode: false, // keep this locked, revert your change here
        width: 70,
        backgroundColor: const Color(0xFFF1F5F9),
        renderer: (ctx) => Align(
          alignment: Alignment.center,
          child: Text(
            ctx.cell.value.toString(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      PlutoColumn(
          title: 'Description',
          field: 'description',
          type: PlutoColumnType.text(),
          readOnly: false,
          enableEditingMode: true,
          width: 160,
          renderer: (ctx) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  ctx.cell.value.toString(),
                  style: const TextStyle(fontSize: 13),
                ),
              )),
      PlutoColumn(
        title: 'Sales Qnty',
        field: 'salesQty',
        type: PlutoColumnType.number(format: '#,###'),
        readOnly: false,
        enableEditingMode: true,
        width: 130,
        backgroundColor: const Color(0xFFF1F5F9),
        renderer: (ctx) => Align(
          alignment: Alignment.centerRight,
          child: Text(
            ctx.cell.value == null || ctx.cell.value == 0
                ? ''
                : formatIndianNumber((ctx.cell.value as num).toDouble()),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.indigo.shade700,
            ),
          ),
        ),
        footerRenderer: (rendererContext) {
          return PlutoAggregateColumnFooter(
            rendererContext: rendererContext,
            type: PlutoAggregateColumnType.sum,
            format: '#,###',
            alignment: Alignment.centerRight,
            titleSpanBuilder: (text) => [
              TextSpan(
                text: text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo.shade900,
                ),
              ),
            ],
          );
        },
      ),
      PlutoColumn(
        title: 'Project Control Qnty',
        field: 'projectcontrolqnty',
        type: PlutoColumnType.number(format: '#,###'),
        readOnly: false,
        enableEditingMode: true,
        width: 130,
        backgroundColor: const Color(0xFFF1F5F9),
        renderer: (ctx) => Align(
          alignment: Alignment.centerRight,
          child: Text(
            ctx.cell.value == null || ctx.cell.value == 0
                ? ''
                : formatIndianNumber((ctx.cell.value as num).toDouble()),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.indigo.shade700,
            ),
          ),
        ),
        footerRenderer: (rendererContext) {
          return PlutoAggregateColumnFooter(
            rendererContext: rendererContext,
            type: PlutoAggregateColumnType.sum,
            format: '#,###',
            alignment: Alignment.centerRight,
            titleSpanBuilder: (text) => [
              TextSpan(
                text: text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo.shade900,
                ),
              ),
            ],
          );
        },
      ),
      PlutoColumn(
        title: 'Remarks',
        field: 'remarks',
        type: PlutoColumnType.text(),
        readOnly: false,
        enableEditingMode: true,
        width: 160,
        renderer: (ctx) => Align(
          alignment: Alignment.centerLeft,
          child: Text(
            ctx.cell.value.toString(),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    ];
  }

  void _addPCRow() {
    print('_pcGridColumns length = ${_pcGridColumns.length}');
    print('_pcStateManager = $_pcStateManager');
    if (_pcGridColumns.isEmpty || _pcStateManager == null) {
      debugPrint('Grid not ready yet');
      return;
    }

    final nextSno = _pcStateManager!.rows.length + 1;

    final newRow = PlutoRow(cells: {
      'sno': PlutoCell(value: nextSno),
      'description': PlutoCell(value: ''),
      'salesQty': PlutoCell(value: 0),
      'projectcontrolqnty': PlutoCell(value: 0),
      'remarks': PlutoCell(value: ''),
    });

    _pcStateManager!.appendRows([newRow]);
    setState(() => _pcGridRows = _pcStateManager!.rows);
  }

  Future<void> _fetchPcEntryData() async {
    if (selectedCustomerId == null || selectedProjectId == null) return;

    setState(() => _isLoading = true);

    try {
      final uri = ApiUtils.getUri('ViewProjectControllist');
      final requestBody = <String, dynamic>{
        'CUSID': selectedCustomerId,
        'PROJID': selectedProjectId,
      };

      debugPrint('Request URL: $uri');
      debugPrint('Request Body: $requestBody');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true) {
          final List<dynamic> list = data['DesigningList'] ?? [];
          final entries = list
              .map((e) =>
                  ProjectcontrolModel.fromJson(e as Map<String, dynamic>))
              .toList();

          if (list.isNotEmpty) {
            // ✅ loadedRows is declared HERE, inside this if-block
            final List<PlutoRow> loadedRows = [];
            int rowNumber = 1;

            for (final e in entries) {
              final names = (e.SPCNAME ?? '').split(',');
              final totals = (e.SPCTOT ?? '').split(',');
              final designTotals = (e.PCTOT ?? '').split(',');
              final remarksList = (e.PCREMKS ?? '').split(',');

              for (int i = 0; i < names.length; i++) {
                final name = names[i].trim();
                if (name.isEmpty) continue;

                loadedRows.add(
                  PlutoRow(cells: {
                    'sno': PlutoCell(value: rowNumber++),
                    'spcno': PlutoCell(value: e.SPCNO ?? 0),
                    'description': PlutoCell(value: name),
                    'salesQty': PlutoCell(
                      value: i < totals.length
                          ? (double.tryParse(totals[i].trim()) ?? 0)
                          : 0,
                    ),
                    'projectcontrolqnty': PlutoCell(
                      value: i < designTotals.length
                          ? (double.tryParse(designTotals[i].trim()) ?? 0)
                          : 0,
                    ),
                    'remarks': PlutoCell(
                      value:
                          i < remarksList.length ? remarksList[i].trim() : '',
                    ),
                  }),
                );
              }
            }

            setState(() {
              _pcGridRows = loadedRows;
              _gridDataReady = true;
              _existingRowKeys.clear();
              for (final row in loadedRows) {
                _existingRowKeys.add(row.key.toString());
              }
              isEditMode = loadedRows.isNotEmpty;

              // ✅ Combine attachments from ALL entries, not just entries.first
              final List<String> allSalesFiles = [];
              final List<String> allDesignFiles = [];

              for (final e in entries) {
                if (e.SFNAME != null && e.SFNAME!.trim().isNotEmpty) {
                  allSalesFiles.addAll(
                    e.SFNAME!
                        .split(',')
                        .map((f) => f.trim())
                        .where((f) => f.isNotEmpty),
                  );
                }
                if (e.PCFNAME != null && e.PCFNAME!.trim().isNotEmpty) {
                  allDesignFiles.addAll(
                    e.PCFNAME!
                        .split(',')
                        .map((f) => f.trim())
                        .where((f) => f.isNotEmpty),
                  );
                }
              }

              _existingSalesFiles = allSalesFiles;
              _existingDesignFiles = allDesignFiles;
            });

            if (_pcStateManager != null) {
              _pcStateManager!.removeAllRows();
              _pcStateManager!.appendRows(loadedRows);
            }
          } else {
            // ✅ else — no loadedRows needed here, just clear everything
            debugPrint(
                'No design entries found for CUSID: $selectedCustomerId, PROJID: $selectedProjectId');
            setState(() {
              _pcGridRows = [];
              _gridDataReady = true;
              _existingRowKeys.clear();
              isEditMode = false;
            });
            if (_pcStateManager != null) {
              _pcStateManager!.removeAllRows();
            }
          }
        } else {
          debugPrint('API returned Success=false: ${data['Message']}');
        }
      } else {
        debugPrint('Server error: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server error: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching design entries: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePCEntriesPDF(ProjectcontrolModel entry) async {
    // ✅ Parse sales entries from the entry data
    final List<PCEntryModel> salesEntries = [];

    final elementNames = entry.SPCNAME
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    [];
    final elementTotals = entry.SPCTOT
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final designTotals = entry.PCTOT
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    final remarks = entry.PCREMKS
            ?.split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    for (int i = 0; i < elementNames.length; i++) {
      salesEntries.add(PCEntryModel(
        elementName: elementNames[i],
        sTotal: i < elementTotals.length ? elementTotals[i] : '0',
        pcTotal: i < designTotals.length ? designTotals[i] : '0',
        pcremarks: i < remarks.length ? remarks[i] : '',
      ));
    }

    debugPrint('Parsed ${salesEntries.length} sales entries');

    if (salesEntries.isEmpty) {
      debugPrint('No sales entries found');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No sales entries to generate PDF'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final pdf = pw.Document();

    final String formattedDate = getFileSafeDateTimeFormatted();
    final String fileName =
        "Projectcontrol_Entry_${entry.SPCNO}_$formattedDate.pdf";
    debugPrint('Generated fileName: $fileName');

    // Format date
    String formatDate(DateTime? date) {
      if (date == null) return '-';
      return DateFormat('dd-MM-yyyy').format(date);
    }

    // Get customer and project names
    String customerName = '';
    String projectName = '';

    if (entry.CUSID != null) {
      final matchedCustomer = customerList.firstWhere(
        (c) => c.customerId == entry.CUSID,
        orElse: () {
          debugPrint('Customer not found in customerList, returning default');
          return ChecklistCustomer(customerId: 0, companyName: '');
        },
      );
      customerName = matchedCustomer.companyName;
      debugPrint('Customer name: $customerName');
    }

    if (entry.PROJID != null) {
      final matchedProject = projectList.firstWhere(
        (p) => p.projectId == entry.PROJID,
        orElse: () {
          debugPrint('Project not found in projectList, returning default');
          return Project(projectId: 0, projectName: '');
        },
      );
      projectName = matchedProject.projectName;
      debugPrint('Project name: $projectName');
    }

    // Calculate totals
    double totalSales = 0;
    double totalDesign = 0;
    for (var item in salesEntries) {
      totalSales += double.tryParse(item.sTotal.replaceAll(',', '')) ?? 0;
      totalDesign += double.tryParse(item.pcTotal.replaceAll(',', '')) ?? 0;
    }

    final headers = [
      'S.No',
      'Element Name',
      'Sales Qnty',
      'Project Control Qnty',
      'Remarks',
    ];

    final List<List<String>> data = [];
    debugPrint('Building data rows for ${salesEntries.length} entries...');

    for (int i = 0; i < salesEntries.length; i++) {
      final item = salesEntries[i];
      debugPrint(
          'Processing entry ${i + 1}/${salesEntries.length}: ${item.elementName}');

      data.add([
        '${i + 1}',
        item.elementName,
        item.sTotal,
        item.pcTotal,
        item.pcremarks ?? '',
      ]);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.portrait,
        margin: const pw.EdgeInsets.all(8),
        build: (context) {
          // Build table rows with custom styling for total row
          final tableRows = <pw.TableRow>[];

          // Add header row - Increased font size to 10
          tableRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green200),
              children: headers.map((header) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    header,
                    style: pw.TextStyle(
                      fontSize: 10, // ✅ Increased from 8 to 10
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                );
              }).toList(),
            ),
          );

          // Add data rows - Increased font size to 9
          for (var row in data) {
            tableRows.add(
              pw.TableRow(
                children: [
                  // S.No
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      row[0],
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),

                  // Element Name
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      row[1],
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),

                  // Sales Qty
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      row[2],
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),

                  // Project Control Qty
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      row[3],
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),

                  // Remarks
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      row[4],
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ],
              ),
            );
          }

          // Add total row with background color - Increased font size to 10
          tableRows.add(
            pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(''),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      totalSales.toStringAsFixed(0),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      totalDesign.toStringAsFixed(0),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(''),
                  ),
                ]),
          );

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Main content - Expanded to push footer to bottom
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // ===== Report Title =====
                    pw.Center(
                      child: pw.Text(
                        'Project Control Report',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Container(
                      width: double.infinity,
                      decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300)),
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Entry No and Date on the SAME ROW
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              // Left side - Customer
                              pw.Expanded(
                                child: pw.Row(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.SizedBox(
                                      width: 90,
                                      child: pw.Text(
                                        'Customer',
                                        style: pw.TextStyle(
                                          fontWeight: pw.FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    pw.Expanded(
                                      child: pw.Text(
                                        customerName.isNotEmpty
                                            ? customerName
                                            : '-',
                                        style: const pw.TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Right side - Date
                              pw.Row(
                                children: [
                                  pw.Text(
                                    'Date : ',
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                  pw.Text(
                                    formatDate(
                                      entry.SPCDT != null
                                          ? DateTime.tryParse(entry.SPCDT!)
                                          : null,
                                    ),
                                    style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 4),

                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.SizedBox(
                                width: 90,
                                child: pw.Text('Project',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 12)),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                    projectName.isNotEmpty ? projectName : '-',
                                    style: const pw.TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey),
                      children: tableRows,
                    ),
                  ],
                ),
              ),
              // ✅ Footer at the bottom of the page
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 10),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                        'Generated on: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        'Page ${context.pageNumber} of ${context.pagesCount}',
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    if (kIsWeb) {
      final blob = html.Blob([pdfBytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ PDF saved to:\n$fileName")),
      );
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final downloadsPath = await getDownloadsDirectory();
      if (downloadsPath != null) {
        final file = File('${downloadsPath.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ PDF saved to:\n${file.path}")),
        );
        await OpenFile.open(file.path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Could not access Downloads folder")),
        );
      }
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      // Share the file on mobile
      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: "Project Control Entry Report - SPCNO: ${entry.SPCNO}",
        );
      } catch (e) {
        // If share fails, at least show the file location
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF saved at: ${file.path}")),
        );
      }
    }
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

class PCDownloadService {
  static Future<Map<String, dynamic>?> _getPCFiles({
    required int spcNo,
  }) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('GetPROJCTRLFiles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"SPCNO": spcNo}),
      );

      print('GetDesigningFiles Response: ${response.body}');

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

  static Future<void> downloadPCFiles({
    required BuildContext context,
    required int spcNo,
    String? salesFiles,
    String? designFiles,
  }) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting file information...'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 1),
      ),
    );

    // Get Sales files
    List<String> salesFileList = [];
    if (salesFiles != null && salesFiles.trim().isNotEmpty) {
      salesFileList = salesFiles.split(',').map((e) => e.trim()).toList();
    }

    // Get Design files
    List<String> designFileList = [];
    if (designFiles != null && designFiles.trim().isNotEmpty) {
      designFileList = designFiles.split(',').map((e) => e.trim()).toList();
    }

    // If no files provided, try to fetch from API
    if (salesFileList.isEmpty && designFileList.isEmpty) {
      final filesData = await _getPCFiles(spcNo: spcNo);

      if (filesData == null) {
        _showNoFilesDialog(context, spcNo);
        return;
      }

      // Get Sales files
      if (filesData['SDFNAME'] != null) {
        salesFileList = filesData['SDFNAME']
            .toString()
            .split(',')
            .map((e) => e.trim())
            .toList();
      }

      // Get Design files
      if (filesData['DDFNAME'] != null) {
        designFileList = filesData['DDFNAME']
            .toString()
            .split(',')
            .map((e) => e.trim())
            .toList();
      }

      if (salesFileList.isEmpty && designFileList.isEmpty) {
        _showNoFilesDialog(context, spcNo);
        return;
      }
    }

    // Combine all files for download
    final allFiles = [...salesFileList, ...designFileList];

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${allFiles.length} file(s)...'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );

    final List<String> success = [];
    final List<String> failed = [];

    for (final fileName in allFiles) {
      try {
        await _downloadFile(fileName, spcNo);
        success.add(fileName);
        print('✓ Downloaded: $fileName');
      } catch (e) {
        failed.add(fileName);
        print('✗ Failed: $fileName - $e');
      }
    }

    _showDownloadResult(context, success, failed);
  }

  static Future<void> _downloadFile(String fileName, int sdNo) async {
    try {
      print('Original filename from DB: "$fileName"');

      final response = await http.post(
        ApiUtils.getUri('DownloadPCFile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"fileName": fileName}),
      );

      print('Download API Request: fileName = "$fileName"');
      print('Download API Response Status: ${response.statusCode}');
      print('Download API Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (data['Success'] == true) {
        String base64String = data['FileBytes'];
        Uint8List fileBytes = base64Decode(base64String);

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

  static Future<String> _getSavePath(String fileName) async {
    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '${directory.path}/$fileName';
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$fileName';
    } else if (Platform.isWindows) {
      final downloadsPath = '${Platform.environment['USERPROFILE']}\\Downloads';
      final directory = Directory(downloadsPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '$downloadsPath\\$fileName';
    } else if (Platform.isMacOS) {
      final downloadsPath = '${Platform.environment['HOME']}/Downloads';
      final directory = Directory(downloadsPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '$downloadsPath/$fileName';
    } else {
      final directory = Directory('./downloads');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return '${directory.path}/$fileName';
    }
  }

  static void _showNoFilesDialog(BuildContext context, int sdNo) {
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
          'Billing #$sdNo has no attached files.\n\n'
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
