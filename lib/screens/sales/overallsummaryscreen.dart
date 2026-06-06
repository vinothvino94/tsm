import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';

class OverAllSummaryScreen extends StatefulWidget {
  const OverAllSummaryScreen({super.key});

  @override
  State<OverAllSummaryScreen> createState() => _OverAllSummaryScreenState();
}

class _OverAllSummaryScreenState extends State<OverAllSummaryScreen> {
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  TextEditingController customerController = TextEditingController();
  TextEditingController siteController = TextEditingController();
  TextEditingController _customerInternalController = TextEditingController();
  TextEditingController _siteInternalController = TextEditingController();
  List<ChecklistCustomer> customerList = [];
  List<Project> projectList = [];
  List<SalesBillingSummaryModel> summaryList = [];
  List<SalesBillingSummaryModel> allDataList = [];

  String? selectedCustomerId;
  String? selectedProjectId;
  bool isLoading = false;
  bool hasGenerated = false;
  bool _customerControllerInitialized = false;
  bool _siteControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    loadCustomers();
    customerController.text = 'ALL';
    siteController.text = 'ALL';
    _customerInternalController.addListener(() => setState(() {}));
    _siteInternalController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    customerController.dispose();
    siteController.dispose();
    _customerInternalController.dispose();
    _siteInternalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indianFormat = NumberFormat('#,##,##0', 'en_IN');
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Over All Summary'),
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
                    child: Autocomplete<ChecklistCustomer>(
                      displayStringForOption: (option) =>
                          "${option.customerId} - ${option.companyName}",
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return customerList;
                        }
                        return customerList.where((customer) {
                          return customer.companyName.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              customer.customerId
                                  .toString()
                                  .contains(textEditingValue.text);
                        });
                      },
                      onSelected: (ChecklistCustomer selection) {
                        final text =
                            "${selection.customerId} - ${selection.companyName}";
                        customerController.text = text;
                        _customerInternalController.text = text; // ← add this

                        setState(() {
                          selectedCustomerId = selection.customerId.toString();
                          selectedProjectId = null;
                          siteController.text = 'ALL';
                          _siteInternalController.text = 'ALL'; // ← add this
                          projectList.clear();
                          hasGenerated = false;
                          summaryList.clear();
                          allDataList.clear();
                        });

                        loadProjects(selection.customerId);
                      },
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        // Set only on first build
                        if (!_customerControllerInitialized) {
                          _customerControllerInitialized = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            controller.text = customerController.text;
                            _customerInternalController.text =
                                customerController.text;
                          });
                        }

                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: "Customer Name",
                            hintText: "Search Customer",
                            border: const OutlineInputBorder(),
                            suffixIcon: _customerInternalController
                                    .text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      _customerInternalController.clear();
                                      customerController.text = 'ALL';
                                      _customerControllerInitialized =
                                          false; // ← reset flag
                                      setState(() {
                                        selectedCustomerId = null;
                                        selectedProjectId = null;
                                        siteController.text = 'ALL';
                                        _siteInternalController.text = 'ALL';
                                        _siteControllerInitialized =
                                            false; // ← reset flag
                                        projectList.clear();
                                        hasGenerated = false;
                                        summaryList.clear();
                                        allDataList.clear();
                                      });
                                    },
                                  )
                                : null,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (value) {
                            _customerInternalController.text = value;
                          },
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
                    child: Autocomplete<Project>(
                      displayStringForOption: (option) =>
                          "${option.projectId} - ${option.projectName}",
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return projectList;
                        }
                        return projectList.where((project) {
                          return project.projectName.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase()) ||
                              project.projectId
                                  .toString()
                                  .contains(textEditingValue.text);
                        });
                      },
                      onSelected: (Project selection) {
                        final text =
                            "${selection.projectId} - ${selection.projectName}";
                        siteController.text = text;
                        _siteInternalController.text = text; // ← add this

                        setState(() {
                          selectedProjectId = selection.projectId.toString();
                        });
                      },
                      fieldViewBuilder: (
                        context,
                        controller,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        // Set only on first build
                        if (!_siteControllerInitialized) {
                          _siteControllerInitialized = true;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            controller.text = siteController.text;
                            _siteInternalController.text = siteController.text;
                          });
                        }

                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: "Site Name",
                            hintText: "Search Site",
                            border: const OutlineInputBorder(),
                            suffixIcon: _siteInternalController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      _siteInternalController.text = 'ALL';
                                      siteController.text = 'ALL';
                                      _siteControllerInitialized =
                                          false; // ← reset flag
                                      setState(() {
                                        selectedProjectId = null;
                                        if (hasGenerated &&
                                            allDataList.isNotEmpty) {
                                          summaryList = List.from(allDataList);
                                        }
                                      });
                                    },
                                  )
                                : null,
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (value) {
                            _siteInternalController.text = value;
                          },
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

              ///Generate Button
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
                        onTap: isLoading
                            ? null
                            : () async {
                                await getSalesBillingSummary();
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Center(
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : const Text(
                                    'Generate',
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
              const SizedBox(height: 16),

              ///Summary Table - Only show if Generate was clicked
              if (hasGenerated && summaryList.isNotEmpty)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: isAndroid
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildSummaryDataTable(indianFormat),
                          )
                        : _buildSummaryDataTable(indianFormat),
                  ),
                )
              else if (hasGenerated &&
                  !isLoading &&
                  summaryList.isEmpty &&
                  allDataList.isNotEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No data found for the selected project',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryDataTable(NumberFormat indianFormat) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(
        AppColors.primary.withOpacity(0.1),
      ),
      columns: const [
        DataColumn(
            label: Text('S.No', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Project Name',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Total Value',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label:
                Text('Billed', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label:
                Text('Balance', style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: summaryList.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return DataRow(
          cells: [
            DataCell(Text('${index + 1}')),
            DataCell(Text(item.projectName ?? '')),
            DataCell(Text(indianFormat.format(item.woValueInclGst ?? 0))),
            DataCell(Text(indianFormat.format(item.billed ?? 0))),
            DataCell(Text(indianFormat.format(item.balanceAmnt ?? 0))),
          ],
        );
      }).toList(),
    );
  }

  String? extractProjectIdFromProjectName(String projectName) {
    if (projectName.isEmpty) return null;
    // Extract first number from the beginning of the string
    RegExp regex = RegExp(r'^(\d+)');
    Match? match = regex.firstMatch(projectName);
    return match?.group(1);
  }

  Future<void> loadProjects(int customerId) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('ProjectDetails'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"CUSTOMERID": customerId}),
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

  Future<void> getSalesBillingSummary() async {
    setState(() {
      isLoading = true;
      summaryList.clear();
    });

    try {
      final response = await http.post(
        ApiUtils.getUri('GetSalesBillingSummary'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true) {
          List<SalesBillingSummaryModel> allData = (data['Data'] as List)
              .map((e) => SalesBillingSummaryModel.fromJson(e))
              .toList();

          debugPrint('Total records received from API: ${allData.length}');

          // Print first few project names for debugging
          for (int i = 0; i < allData.length && i < 3; i++) {
            debugPrint('Project ${i + 1}: ${allData[i].projectName}');
          }

          setState(() {
            allDataList = allData;
            // Apply project filter if a project is selected
            if (selectedProjectId != null && selectedProjectId != 'ALL') {
              List<SalesBillingSummaryModel> filtered = allData.where((item) {
                String? itemProjectId =
                    extractProjectIdFromProjectName(item.projectName ?? '');
                return itemProjectId == selectedProjectId;
              }).toList();
              summaryList = filtered;
            } else {
              summaryList = List.from(allData);
            }
            hasGenerated = true; // Set flag to true after Generate
          });

          if (summaryList.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No data found for the selected filters'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${data['Message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
/*@override
  Widget _build(BuildContext context) {
    final indianFormat = NumberFormat('#,##,##0', 'en_IN');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Over All Summary'),
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
                            child: Autocomplete<ChecklistCustomer>(
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
                                  selectedCustomerId =
                                      selection.customerId.toString();
                                  selectedProjectId = null;
                                  siteController.clear();
                                  siteController.text = 'ALL';
                                  projectList.clear();
                                  hasGenerated = false;
                                  summaryList.clear();
                                  allDataList.clear();
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
                                              customerController.text = 'ALL';
                                              setState(() {
                                                selectedCustomerId = null;
                                                selectedProjectId = null;
                                                siteController.clear();
                                                siteController.text = 'ALL';
                                                projectList.clear();
                                                hasGenerated = false;
                                                summaryList.clear();
                                                allDataList.clear();
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
                            child: Autocomplete<Project>(
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
                                  selectedProjectId =
                                      selection.projectId.toString();
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
                                              siteController.text = 'ALL';
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

                      ///Generate Button
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
                                onTap: isLoading
                                    ? null
                                    : () async {
                                        await getSalesBillingSummary();
                                      },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  child: Center(
                                    child: isLoading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text(
                                            'Generate',
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
                      const SizedBox(height: 16),

                      ///Summary Table - Only show if Generate was clicked
                      if (hasGenerated && summaryList.isNotEmpty)
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 20),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  AppColors.primary.withOpacity(0.1),
                                ),
                                columns: const [
                                  DataColumn(
                                      label: Text('S.No',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Project Name',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Total Value',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Billed',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                  DataColumn(
                                      label: Text('Balance',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold))),
                                ],
                                rows: summaryList.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text('${index + 1}')),
                                      DataCell(Text(item.projectName ?? '')),
                                      DataCell(Text(indianFormat
                                          .format(item.woValueInclGst ?? 0))),
                                      DataCell(Text(indianFormat
                                          .format(item.billed ?? 0))),
                                      DataCell(Text(indianFormat
                                          .format(item.balanceAmnt ?? 0))),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        )
                      else if (hasGenerated &&
                          !isLoading &&
                          summaryList.isEmpty &&
                          allDataList.isNotEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text(
                              'No data found for the selected project',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
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
  }*/
