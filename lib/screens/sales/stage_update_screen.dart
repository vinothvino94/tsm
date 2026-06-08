import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/prefrence_helper.dart';

class StageUpdateScreen extends StatefulWidget {
  final SalesStagelistModel? stagelistData;
  final bool? isReadOnly;

  const StageUpdateScreen({
    super.key,
    this.stagelistData,
    this.isReadOnly = false,
  });

  @override
  State<StageUpdateScreen> createState() => _StageUpdateScreenState();
}

class _StageUpdateScreenState extends State<StageUpdateScreen> {
  static const List<String> stages = [
    'Stage 1',
    'Stage 2',
    'Stage 3',
    'Stage 4',
    'Stage 5',
    'Stage 6',
    'Stage 7',
    'Stage 8',
  ];

  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  TextEditingController customerController = TextEditingController();
  TextEditingController siteController = TextEditingController();
  TextEditingController stageController = TextEditingController();
  TextEditingController percentageController = TextEditingController();
  List<ChecklistCustomer> customerList = [];
  List<Project> projectList = [];
  int? selectedCustomerId;
  int? selectedProjectId;
  int empCode = 0;
  String empName = '';
  String? selectedstage;
  int? selectedstageId;
  List<SalesStagelistModel> stageList = [];
  bool isSubmitting = false;
  bool _hasAttemptedSubmit = false;
  List<String> availableStagesList = [];
  bool isLoadingStages = false;

  @override
  void initState() {
    super.initState();
    loadCustomers();
    _loadUserDetails();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.stagelistData != null && !widget.isReadOnly!;
    final isViewOnly = widget.isReadOnly == true;
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stage Update'),
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
                                  overflow: TextOverflow
                                      .ellipsis, // Move overflow to style property
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
                                        .contains(
                                          textEditingValue.text.toLowerCase(),
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
                                            });
                                          },
                                        )
                                      : null,
                                ),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                style: const TextStyle(
                                  fontSize: 14,
                                  overflow: TextOverflow
                                      .ellipsis, // Move overflow to style property
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

              // 🔹 TABLE VIEW
              isAndroid
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildStageTable(),
                    )
                  : _buildStageTable(),
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
                          onTap: isSubmitting
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    await insertSalesStagelist();
                                  }
                                },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            child: Center(
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : Text(
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
            // Reset selected project and stages when customer changes
            selectedProjectId = null;
            selectedstageId = null;
            stageList.clear();
            stageController.clear();
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

  String getFullStageName(String stageId) {
    final int stageIdInt = int.tryParse(stageId) ?? 0;
    return (stageIdInt >= 1 && stageIdInt <= stages.length)
        ? stages[stageIdInt - 1]
        : stageId;
  }

  String getFullStageNameNoSpace(String stageId) {
    final int stageIdInt = int.tryParse(stageId) ?? 0;
    return (stageIdInt >= 1 && stageIdInt <= stages.length)
        ? stages[stageIdInt - 1].replaceAll(' ', '')
        : stageId;
  }

  Future<void> insertSalesStagelist() async {
    if (stageList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add at least one stage"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final currentSessionStageIds =
          stageList.map((stage) => stage.stageid!.trim()).toList();
      final hasDuplicatesInSession = currentSessionStageIds.length !=
          currentSessionStageIds.toSet().length;

      if (hasDuplicatesInSession) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Duplicate Stage IDs found in current session"),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Check for numeric sequential stages
      final areAllNumeric =
          currentSessionStageIds.every((id) => int.tryParse(id) != null);

      if (areAllNumeric) {
        final currentNumbers =
            currentSessionStageIds.map((id) => int.parse(id)).toList()..sort();

        bool isSequential = true;
        int missingNumber = -1;
        for (int i = 0; i < currentNumbers.length; i++) {
          if (currentNumbers[i] != i + 1) {
            isSequential = false;
            missingNumber = i + 1;
            break;
          }
        }
      }

      // Prepare data for batch insert
      final stagesToSend = stageList.map((stage) {
        final String fullStageName = getFullStageNameNoSpace(stage.stageid!);
        print(
            "Converting Stage ID ${stage.stageid} to full name: $fullStageName");

        return {
          "CUSID": selectedCustomerId,
          "PROJID": selectedProjectId,
          "STAGEID": fullStageName,
          "STAGENAME": stage.stagename,
          "STAGEPER": stage.stagepercentage != null
              ? '${stage.stagepercentage! % 1 == 0 ? stage.stagepercentage!.toInt() : stage.stagepercentage}%'
              : '',
          "ADDUSER": empCode,
        };
      }).toList();

      // Validate all stages have STAGENAME
      final missingStageNames = stagesToSend
          .where((s) =>
              s["STAGENAME"] == null || s["STAGENAME"].toString().isEmpty)
          .toList();
      if (missingStageNames.isNotEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ All stages must have a Stage Name"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      for (int i = 0; i < stagesToSend.length; i++) {}
      print("=========================================");

      final response = await http.post(
        ApiUtils.getUri('SaveSalesStagelist'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(stagesToSend),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] != true) {
          throw Exception(data['Message'] ?? 'Failed to save stages');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(data['Message'] ?? "✅ All stages saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        setState(() {
          stageList.clear();
          selectedCustomerId = null;
          selectedProjectId = null;
          selectedstageId = null;
          customerController.clear();
          siteController.clear();
          stageController.clear();
        });

        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to save stages: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  Widget _buildStageTable() {
    for (int i = 0; i < stageList.length; i++) {
      print(
          "  Stage ${i + 1}: ID=${stageList[i].stageid}, Name=${stageList[i].stagename}");
    }

    if (stageList.isEmpty && _hasAttemptedSubmit) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "No stages added",
            style: TextStyle(color: Colors.orange),
          ),
        ),
      );
    }

    // Don't show anything if list is empty and submit hasn't been attempted yet
    if (stageList.isEmpty) {
      return const SizedBox.shrink(); // Returns empty space
    }

    return DataTable(
      columns: const [
        DataColumn(label: Text('Stage ID')),
        DataColumn(label: Text('Stage Name')),
        DataColumn(label: Text('Percentage')),
        DataColumn(label: Text('Actions')),
      ],
      rows: List.generate(
        stageList.length,
        (index) {
          final item = stageList[index];
          final String stageDisplayName = getFullStageName(item.stageid ?? '');

          return DataRow(
            cells: [
              DataCell(Text(stageDisplayName)),
              DataCell(Text(item.stagename ?? '')),
              DataCell(Text(
                // ← add cell
                item.stagepercentage != null ? '${item.stagepercentage}%' : '-',
              )),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit Icon
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        setState(() {
                          selectedstageId = int.tryParse(item.stageid ?? '0');
                          stageController.text = item.stagename ?? '';
                          stageList.removeAt(index);
                          _hasAttemptedSubmit = false;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                "Editing Stage ${item.stageid} - ${item.stagename}"),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    // Delete Icon
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          stageList.removeAt(index);

                          if (stageList.isEmpty) {
                            _hasAttemptedSubmit = false;
                          }
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                "Deleted Stage ${item.stageid} - ${item.stagename}"),
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
    );
  }

  Widget _buildStageInputSection() {
    final isViewOnly = widget.isReadOnly == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FutureBuilder<List<String>>(
                future:
                    (selectedCustomerId != null && selectedProjectId != null)
                        ? getAvailableStagesFromDatabase(
                            selectedCustomerId!, selectedProjectId!)
                        : Future.value([]),
                builder: (context, snapshot) {
                  // Show loading indicator while fetching
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      selectedCustomerId != null &&
                      selectedProjectId != null) {
                    return DropdownButtonFormField<int>(
                      decoration: _inputDecoration("Select Stage"),
                      hint: const Text('Loading stages...'),
                      items: [],
                      onChanged: null,
                    );
                  }

                  // Get available stages from snapshot or use cached list
                  List<String> displayStages = snapshot.data ?? [];

                  // Also filter out stages that are already added in current session
                  final addedStageIds = stageList
                      .map((s) => getFullStageName(s.stageid ?? ''))
                      .toSet();

                  final filteredStages = displayStages
                      .where((stage) => !addedStageIds.contains(stage))
                      .toList();

                  return DropdownButtonFormField<int>(
                    value: selectedstageId,
                    decoration: _inputDecoration("Select Stage").copyWith(
                      suffixIcon: (!isViewOnly && selectedstageId != null)
                          ? IconButton(
                              onPressed: () {
                                print("Clear Stage ID button pressed");
                                setState(() {
                                  selectedstageId = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                          : null,
                    ),
                    isExpanded:
                        true, // Add this to make dropdown take full width
                    items: filteredStages.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final stageName = entry.value;
                      // Extract stage number from "Stage 1" format
                      final stageNumber =
                          int.tryParse(stageName.replaceAll('Stage ', '')) ??
                              index;
                      return DropdownMenuItem<int>(
                        value: stageNumber,
                        child: Text(
                          stageName,
                          overflow: TextOverflow
                              .ellipsis, // Add this to handle long text
                        ),
                      );
                    }).toList(),
                    onChanged: (isViewOnly || filteredStages.isEmpty)
                        ? null
                        : (value) {
                            print("Dropdown changed - New value: $value");
                            setState(() {
                              selectedstageId = value;
                            });
                          },
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: stageController,
                decoration: InputDecoration(
                  labelText: "Stage Name",
                  hintText: "Stage name",
                  border: const OutlineInputBorder(),
                  suffixIcon: stageController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            print("Clear Stage Name button pressed");
                            setState(() {
                              stageController.clear();
                            });
                          },
                          padding: EdgeInsets.zero,
                          tooltip: 'Clear',
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical:
                        14, // Reduced from default to match dropdown height
                  ),
                ),
                maxLines: null,
                keyboardType: TextInputType.text,
                readOnly: isViewOnly,
                enabled: !isViewOnly,
                onChanged: (value) {
                  print("Stage name text changed: '$value'");
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: percentageController,
                decoration: InputDecoration(
                  labelText: "Stage Percentage",
                  hintText: "Stage Percentage",
                  border: const OutlineInputBorder(),
                  suffixStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Text('%',
                            style:
                                TextStyle(fontSize: 16, color: Colors.black87)),
                      ),
                      if (percentageController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              setState(() => percentageController.clear()),
                          padding: EdgeInsets.zero,
                          tooltip: 'Clear',
                        ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                maxLines: null,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                readOnly: isViewOnly,
                enabled: !isViewOnly,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!isViewOnly)
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _addStage,
              icon: const Icon(Icons.add),
              label: const Text("Add Stage"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  void _addStage() async {
    // Simple validation
    if (selectedCustomerId == null ||
        selectedProjectId == null ||
        selectedstageId == null ||
        stageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if the selected stage is available in the database
    final availableStages = await getAvailableStagesFromDatabase(
        selectedCustomerId!, selectedProjectId!);

    final selectedStageName = getFullStageName(selectedstageId.toString());
    final isStageAvailable = availableStages.contains(selectedStageName);

    if (!isStageAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Stage $selectedStageName is not available. Please select an available stage."),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Check for duplicate Stage ID in the current list
    final isDuplicate =
        stageList.any((stage) => stage.stageid == selectedstageId.toString());

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Stage ${selectedstageId} is already added!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final customStageName = stageController.text.trim();
    final stageIdValue = selectedstageId.toString();

    print("Adding stage - ID: $stageIdValue, Name: '$customStageName'");

    setState(() {
      stageList.add(
        SalesStagelistModel(
          cusid: selectedCustomerId,
          projid: selectedProjectId,
          stageid: stageIdValue,
          stagename: customStageName,
          stagepercentage: double.tryParse(percentageController.text.trim()),
          adduser: empCode,
          adddate: DateTime.now(),
        ),
      );
      selectedstageId = null;
      stageController.clear();
      percentageController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text("✅ Stage $stageIdValue added with name: $customStageName"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<List<String>> getAvailableStagesFromDatabase(
      int cusid, int projid) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('GetAvailableStages'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "CUSID": cusid,
          "PROJID": projid,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true && data['Data'] != null) {
          // Convert "Stage1" to "Stage 1" format for display
          List<String> availableStages = List<String>.from(data['Data']);
          return availableStages
              .map((stage) => stage.replaceAll('Stage', 'Stage '))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print("Error fetching available stages: $e");
      return [];
    }
  }
}
/*Widget buildStageInputSection() {
    print("========== _buildStageInputSection RENDERED ==========");
    print("Current selectedstageId: $selectedstageId");
    print("Current stageController text: ${stageController.text}");
    print("Current stageList length: ${stageList.length}");
    print("Available stages count: ${availableStagesList.length}");
    print("====================================================");

    final isViewOnly = widget.isReadOnly == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FutureBuilder<List<String>>(
                future:
                    (selectedCustomerId != null && selectedProjectId != null)
                        ? getAvailableStagesFromDatabase(
                            selectedCustomerId!, selectedProjectId!)
                        : Future.value([]),
                builder: (context, snapshot) {
                  // Show loading indicator while fetching
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      selectedCustomerId != null &&
                      selectedProjectId != null) {
                    return DropdownButtonFormField<int>(
                      decoration: _inputDecoration("Select Stage"),
                      hint: const Text('Loading stages...'),
                      items: [],
                      onChanged: null,
                    );
                  }

                  // Get available stages from snapshot or use cached list
                  List<String> displayStages = snapshot.data ?? [];

                  // Also filter out stages that are already added in current session
                  final addedStageIds = stageList
                      .map((s) => getFullStageName(s.stageid ?? ''))
                      .toSet();

                  final filteredStages = displayStages
                      .where((stage) => !addedStageIds.contains(stage))
                      .toList();

                  return DropdownButtonFormField<int>(
                    value: selectedstageId,
                    decoration: _inputDecoration("Select Stage").copyWith(
                      suffixIcon: (!isViewOnly && selectedstageId != null)
                          ? IconButton(
                              onPressed: () {
                                print("Clear Stage ID button pressed");
                                setState(() {
                                  selectedstageId = null;
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              tooltip: 'Clear selection',
                            )
                          : null,
                    ),
                    items: filteredStages.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final stageName = entry.value;
                      // Extract stage number from "Stage 1" format
                      final stageNumber =
                          int.tryParse(stageName.replaceAll('Stage ', '')) ??
                              index;
                      return DropdownMenuItem<int>(
                        value: stageNumber,
                        child: Text(stageName),
                      );
                    }).toList(),
                    onChanged: (isViewOnly || filteredStages.isEmpty)
                        ? null
                        : (value) {
                            print("Dropdown changed - New value: $value");
                            setState(() {
                              selectedstageId = value;
                            });
                          },
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: IntrinsicHeight(
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
                  maxLines: 1,
                  keyboardType: TextInputType.text,
                  readOnly: isViewOnly,
                  enabled: !isViewOnly,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!isViewOnly)
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _addStage,
              icon: const Icon(Icons.add),
              label: const Text("Add Stage"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

@override
Widget _build(BuildContext context) {
  final isEditing = widget.stagelistData != null && !widget.isReadOnly!;
  final isViewOnly = widget.isReadOnly == true;
  return Scaffold(
    appBar: AppBar(
      title: const Text('Stage Update'),
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
                              });

                              loadProjects(selection
                                  .customerId); // Pass the parsed customer ID
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

                    _buildStageInputSection(),

                    // 🔹 TABLE VIEW
                    Platform.isAndroid
                        ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildStageTable(),
                    )
                        : _buildStageTable(),
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
                                onTap: isSubmitting
                                    ? null
                                    : () async {
                                  if (_formKey.currentState!
                                      .validate()) {
                                    await insertSalesStagelist();
                                  }
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15),
                                  child: Center(
                                    child: isSubmitting
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(Colors.white),
                                      ),
                                    )
                                        : Text(
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
}*/
