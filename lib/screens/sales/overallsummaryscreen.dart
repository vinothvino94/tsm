import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tsm/screens/sales/projectcontrol_entry_screen.dart';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import '../../services/pdfgeneratorservice.dart';
import 'package:path/path.dart' as p;

import 'billing_entry_screen.dart';
import 'design_entry_screen.dart';

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
  List<SalesDesignSummaryModel> designList = [];
  List<SalesPCSummaryModel> pcList = [];
  List<SalesBillingSummaryModel> allDataList = [];

  String? selectedCustomerId;
  String? selectedProjectId;
  bool isLoading = false;
  bool hasGenerated = false;
  bool _customerControllerInitialized = false;
  bool _siteControllerInitialized = false;
  bool _isDownloadingAll = false;

  String? selectedModule = 'Billing';

  final List<String> moduleList = [
    'Billing',
    'Design',
    'Project Control',
  ];

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
        actions: [
          // ✅ Show download button only when data is generated
          if (hasGenerated && hasDataToShow)
            _isDownloadingAll
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: 'Download All Projects',
                    onPressed: _downloadAllProjects,
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

              /// Module Dropdown
              DropdownButtonFormField<String>(
                value: selectedModule,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: moduleList.map((module) {
                  return DropdownMenuItem<String>(
                    value: module,
                    child: Text(module),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedModule = value;
                  });
                },
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
                                if (selectedModule == 'Billing') {
                                  await getSalesBillingSummary();
                                } else if (selectedModule == 'Design') {
                                  await getSalesDesignSummary();
                                } else if (selectedModule ==
                                    'Project Control') {
                                  await getProjectControlSummary();
                                }
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
              if (hasGenerated && hasDataToShow)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: isAndroid
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildSelectedSummaryTable(indianFormat),
                          )
                        : _buildSelectedSummaryTable(indianFormat),
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

  bool get hasDataToShow {
    switch (selectedModule) {
      case 'Billing':
        return summaryList.isNotEmpty;

      case 'Design':
        return designList.isNotEmpty;

      case 'Project Control':
        return pcList.isNotEmpty;

      default:
        return false;
    }
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

        // ✅ Debug: Print the first item from API response
        if (data['Success'] == true &&
            data['Data'] != null &&
            data['Data'].isNotEmpty) {
          debugPrint('===== First API Response Item =====');
          debugPrint('${data['Data'][0]}');
          debugPrint(
              'PROJECTCODE in first item: ${data['Data'][0]['PROJECTCODE']}');
        }

        if (data['Success'] == true) {
          List<SalesBillingSummaryModel> allData =
              (data['Data'] as List).map((e) {
            // ✅ Debug each item as it's being parsed
            debugPrint(
                'Parsing item: ${e['PROJECTNAME']} - Code: ${e['PROJECTCODE']}');
            return SalesBillingSummaryModel.fromJson(e);
          }).toList();

          debugPrint('Total records received from API: ${allData.length}');

          // ✅ Check if project codes are populated
          for (int i = 0; i < allData.length && i < 3; i++) {
            debugPrint(
                'Project ${i + 1}: ${allData[i].projectName} - Code: ${allData[i].projectCode}');
          }

          setState(() {
            allDataList = allData;
            if (selectedProjectId != null && selectedProjectId != 'ALL') {
              List<SalesBillingSummaryModel> filtered = allData.where((item) {
                String? itemProjectId =
                    extractProjectIdFromProjectName(item.projectName);
                return itemProjectId == selectedProjectId;
              }).toList();
              summaryList = filtered;
            } else {
              summaryList = List.from(allData);
            }
            hasGenerated = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> getSalesDesignSummary() async {
    setState(() {
      isLoading = true;
      designList.clear();
    });

    try {
      final response = await http.post(
        ApiUtils.getUri('GetSalesDesignSummary'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true &&
            data['Data'] != null &&
            data['Data'].isNotEmpty) {
          debugPrint('===== First Design API Response =====');
          debugPrint('${data['Data'][0]}');
        }

        if (data['Success'] == true) {
          List<SalesDesignSummaryModel> allData = (data['Data'] as List)
              .map((e) => SalesDesignSummaryModel.fromJson(e))
              .toList();

          debugPrint('Total Design Records: ${allData.length}');

          setState(() {
            if (selectedProjectId != null && selectedProjectId != 'ALL') {
              designList = allData
                  .where(
                      (item) => item.projectId.toString() == selectedProjectId)
                  .toList();
            } else {
              designList = List.from(allData);
            }

            hasGenerated = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['Message'] ?? 'No data found')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server Error : ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> getProjectControlSummary() async {
    setState(() {
      isLoading = true;
      pcList.clear();
    });

    try {
      final response = await http.post(
        ApiUtils.getUri('GetSalesPCSummary'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['Success'] == true &&
            data['Data'] != null &&
            data['Data'].isNotEmpty) {
          debugPrint('===== First Design API Response =====');
          debugPrint('${data['Data'][0]}');
        }

        if (data['Success'] == true) {
          List<SalesPCSummaryModel> allData = (data['Data'] as List)
              .map((e) => SalesPCSummaryModel.fromJson(e))
              .toList();

          debugPrint('Total Design Records: ${allData.length}');

          setState(() {
            if (selectedProjectId != null && selectedProjectId != 'ALL') {
              pcList = allData
                  .where(
                      (item) => item.projectId.toString() == selectedProjectId)
                  .toList();
            } else {
              pcList = List.from(allData);
            }

            hasGenerated = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['Message'] ?? 'No data found')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server Error : ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<String?> getUniqueFilePath(String fileName) async {
    final downloadsDir = await getDownloadsFolder();
    if (downloadsDir == null) return null;

    final ncrDir =
        Directory(p.join(downloadsDir.path, "Over all summary report"));
    if (!(await ncrDir.exists())) {
      await ncrDir.create(recursive: true);
    }

    final nameWithoutExt = fileName.replaceAll(RegExp(r'\.pdf$'), '');
    String fullPath = p.join(ncrDir.path, fileName);
    int counter = 1;

    while (await File(fullPath).exists()) {
      fullPath = p.join(ncrDir.path, '${nameWithoutExt}($counter).pdf');
      counter++;
    }

    return fullPath;
  }

  Future<Directory?> getDownloadsFolder() async {
    if (Platform.isWindows) {
      // Windows default Downloads
      final userProfile = Platform.environment['USERPROFILE'];
      return Directory('$userProfile\\Downloads');
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      return Directory('$home/Downloads');
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Use the downloads_path_provider_28 plugin here
      //return await DownloadsPathProvider.downloadsDirectory;
    }
    return null;
  }

  Future<void> _downloadAllProjects() async {
    setState(() => _isDownloadingAll = true);

    try {
      final indianFormat = NumberFormat('#,##,##0', 'en_IN');
      final pdf = pw.Document();

      debugPrint('Download tapped — selectedModule: $selectedModule');
      debugPrint('designList.length: ${designList.length}');
      debugPrint('pcList.length: ${pcList.length}');
      debugPrint('summaryList.length: ${summaryList.length}');

      late final List<String> headers;
      late final List<List<String>> data;
      final String reportTitle =
          '${selectedModule ?? 'Billing'} Summary Report';

      if (selectedModule == 'Design') {
        headers = [
          'S.No',
          'Project Name',
          'Sales Qnty',
          'Design Qnty',
        ];

        data = List.generate(designList.length, (i) {
          final item = designList[i];
          return [
            (i + 1).toString(),
            item.projectName ?? '',
            indianFormat.format(item.salesQnty ?? 0),
            indianFormat.format(item.designQnty ?? 0),
          ];
        });
      } else if (selectedModule == 'Project Control') {
        headers = [
          'S.No',
          'Project Name',
          'Sales Qnty',
          'Project Control Qnty',
        ];

        data = List.generate(pcList.length, (i) {
          final item = pcList[i];
          return [
            (i + 1).toString(),
            item.projectName ?? '',
            indianFormat.format(item.salesQnty ?? 0),
            indianFormat.format(item.pcQnty ?? 0),
          ];
        });
      } else {
        headers = [
          'S.No',
          'Project Name',
          'Total Bill Amount',
          'Billed',
          'Net Amount Received',
          'Outstanding',
        ];

        data = List.generate(summaryList.length, (i) {
          final item = summaryList[i];
          return [
            (i + 1).toString(),
            item.projectName ?? '',
            indianFormat.format(item.woValueInclGst ?? 0),
            indianFormat.format(item.billed ?? 0),
            indianFormat.format(item.recamnt ?? 0),
            indianFormat.format(item.balanceAmnt ?? 0),
          ];
        });
      }

      if (data.isEmpty) {
        debugPrint('⚠️ No rows to export for module: $selectedModule');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No $selectedModule data to download'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isDownloadingAll = false);
        }
        return;
      }

      // ── Build table rows once, reused inside MultiPage's build() ────────
      final tableRows = <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green200),
          children: headers.map((header) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                header,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            );
          }).toList(),
        ),
        ...data.map((row) {
          return pw.TableRow(
            children: row.asMap().entries.map((e) {
              final colIndex = e.key;
              final value = e.value;
              final align = colIndex == 0
                  ? pw.TextAlign.center
                  : (colIndex == 1 ||
                          (colIndex == 2 &&
                              (selectedModule == 'Design' ||
                                  selectedModule == 'Project Control')))
                      ? pw.TextAlign.left
                      : pw.TextAlign.right;

              return pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  value,
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: align,
                ),
              );
            }).toList(),
          );
        }),
      ];

      // ── MultiPage: paginates automatically, no more Expanded/spaceBetween hack ──
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          header: (context) {
            // Only show the title block on the first page
            if (context.pageNumber != 1) return pw.SizedBox();
            return pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    reportTitle,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated on: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                  ),
                  pw.SizedBox(height: 4),
                  if (selectedCustomerId != null && selectedCustomerId != 'ALL')
                    pw.Text(
                      'Customer: ${customerController.text}',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  if (selectedProjectId != null && selectedProjectId != 'ALL')
                    pw.Text(
                      'Project: ${siteController.text}',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  pw.SizedBox(height: 10),
                ],
              ),
            );
          },
          footer: (context) {
            return pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            );
          },
          build: (context) => [
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),
              children: tableRows,
            ),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final String formattedDate =
          DateFormat('dd-MM-yyyy_HH-mm-ss').format(DateTime.now());
      final String safeModule =
          (selectedModule ?? 'Billing').replaceAll(' ', '_');
      final String fileName = '${safeModule}_Summary_Report_$formattedDate.pdf';

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ PDF saved: $fileName")),
          );
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final uniquePath = await getUniqueFilePath(fileName);
        if (uniquePath != null) {
          final file = File(uniquePath);
          await file.writeAsBytes(pdfBytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("✅ PDF saved to:\n${file.path}")),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("❌ Could not access Downloads folder")),
            );
          }
        }
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);
        if (mounted) {
          await Share.shareXFiles([XFile(file.path)], text: reportTitle);
        }
      }

      debugPrint(
          '✅ Successfully downloaded $selectedModule report with ${data.length} rows');
    } catch (e) {
      debugPrint('Error downloading $selectedModule summary: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingAll = false);
    }
  }

  Widget _buildSelectedSummaryTable(NumberFormat indianFormat) {
    switch (selectedModule) {
      case 'Design':
        return _buildDesignSummaryDataTable(indianFormat);

      case 'Project Control':
        return _buildProjectControlSummaryDataTable(indianFormat);

      case 'Billing':
      default:
        return _buildBillingSummaryDataTable(indianFormat);
    }
  }

  Widget _buildBillingSummaryDataTable(NumberFormat indianFormat) {
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
            label: Text('Total value',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label:
                Text('Billed', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Net amount received',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Outstanding',
                style: TextStyle(fontWeight: FontWeight.bold))),
      ],
      rows: summaryList.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return DataRow(
          cells: [
            DataCell(Text('${index + 1}')),
            DataCell(
              _ProjectNameCell(
                projectName: item.projectName ?? '',
                onTap: () {
                  // ── Look up real customer name from already-loaded customerList ────
                  final matchedCustomer = customerList.firstWhere(
                    (c) => c.customerId == item.customerId,
                    orElse: () => ChecklistCustomer(
                        customerId: item.customerId ?? 0, companyName: ''),
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BillingEntryScreen(
                        isReadOnly: true,
                        initialCustomerId: item.customerId,
                        initialProjectId: item.projectId,
                        initialCustomerName:
                            '${matchedCustomer.customerId} - ${matchedCustomer.companyName}',
                        initialProjectName: item.projectName ??
                            '', // ← also fixed: no duplicate prefix
                      ),
                    ),
                  );
                },
              ),
            ),
            DataCell(Text(indianFormat.format(item.woValueInclGst ?? 0))),
            DataCell(Text(indianFormat.format(item.billed ?? 0))),
            DataCell(Text(indianFormat.format(item.recamnt ?? 0))),
            DataCell(Text(indianFormat.format(item.balanceAmnt ?? 0))),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDesignSummaryDataTable(NumberFormat indianFormat) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(
        AppColors.primary.withOpacity(0.1),
      ),
      columns: const [
        DataColumn(
          label: Text(
            'S.No',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Project Name',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Sales Qnty',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Design Qnty',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
      rows: designList.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        return DataRow(
          cells: [
            DataCell(Text('${index + 1}')),
            DataCell(
              _ProjectNameCell(
                projectName: item.projectName ?? '',
                onTap: () {
                  // ── Look up real customer name from already-loaded customerList ────
                  final matchedCustomer = customerList.firstWhere(
                    (c) => c.customerId == item.customerId,
                    orElse: () => ChecklistCustomer(
                        customerId: item.customerId ?? 0, companyName: ''),
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DesignEntryScreen(
                        isReadOnly: true,
                        initialCustomerId: item.customerId,
                        initialProjectId: item.projectId,
                        initialCustomerName:
                            '${matchedCustomer.customerId} - ${matchedCustomer.companyName}',
                        initialProjectName: item.projectName ?? '',
                      ),
                    ),
                  );
                },
              ),
            ),
            DataCell(Text(indianFormat.format(item.salesQnty ?? 0))),
            DataCell(Text(indianFormat.format(item.designQnty ?? 0))),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildProjectControlSummaryDataTable(NumberFormat indianFormat) {
    return DataTable(
      headingRowColor: WidgetStateProperty.all(
        AppColors.primary.withOpacity(0.1),
      ),
      columns: const [
        DataColumn(
          label: Text(
            'S.No',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Project Name',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Sales Qnty',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Project Control Qnty',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
      rows: pcList.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        return DataRow(
          cells: [
            DataCell(Text('${index + 1}')),
            DataCell(
              _ProjectNameCell(
                projectName: item.projectName ?? '',
                onTap: () {
                  // ── Look up real customer name from already-loaded customerList ────
                  final matchedCustomer = customerList.firstWhere(
                    (c) => c.customerId == item.customerId,
                    orElse: () => ChecklistCustomer(
                        customerId: item.customerId ?? 0, companyName: ''),
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProjectcontrolEntryScreen(
                        isReadOnly: true,
                        initialCustomerId: item.customerId,
                        initialProjectId: item.projectId,
                        initialCustomerName:
                            '${matchedCustomer.customerId} - ${matchedCustomer.companyName}',
                        initialProjectName: item.projectName ??
                            '', // ← also fixed: no duplicate prefix
                      ),
                    ),
                  );
                },
              ),
            ),
            DataCell(Text(indianFormat.format(item.salesQnty ?? 0))),
            DataCell(Text(indianFormat.format(item.pcQnty ?? 0))),
          ],
        );
      }).toList(),
    );
  }
}

class _ProjectNameCell extends StatefulWidget {
  final String projectName;
  final VoidCallback onTap;

  const _ProjectNameCell({
    required this.projectName,
    required this.onTap,
  });

  @override
  State<_ProjectNameCell> createState() => _ProjectNameCellState();
}

class _ProjectNameCellState extends State<_ProjectNameCell>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _hovering
                ? AppColors.primary.withOpacity(0.08)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _hovering ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Folder icon that "opens" on hover
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  _hovering ? Icons.folder_open_rounded : Icons.folder_rounded,
                  key: ValueKey(_hovering),
                  size: 16,
                  color: _hovering
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 6),
              // Name with animated underline + color shift
              Flexible(
                child: Text(
                  widget.projectName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        _hovering ? AppColors.primaryDark : AppColors.primary,
                    fontWeight: _hovering ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.5,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Arrow that slides in on hover instead of a static underline
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _hovering ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 150),
                  offset: _hovering ? Offset.zero : const Offset(-0.3, 0),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
