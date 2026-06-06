import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';
import '../../models/project.dart';
import '../../services/file_service.dart';
import '../../services/prefrence_helper.dart';

class WorkElementReassignScreen extends StatefulWidget {
  final int? tsNo;
  final bool isEditMode;
  const WorkElementReassignScreen({
    super.key,
    this.tsNo,
    this.isEditMode = false,
  });

  @override
  State<WorkElementReassignScreen> createState() =>
      _WorkElementReassignScreenState();
}

class _WorkElementReassignScreenState extends State<WorkElementReassignScreen> {
  final _formKey = GlobalKey<FormState>();
  final FileService _fileService = FileService();
  String? selectedtype;
  final List<String> typeOptions = [
    'REASSIGN',
    'ISSUE RELEASE',
  ];
  List<Project> _projects = [];
  List<Map<String, dynamic>> _employeeList = [];
  List<String> eleidOptions = [];
  String eleid = '';
  String? selectedEmployee = 'ALL';
  int? _projectId;
  String? _selectedProject;
  bool _isSiteSelectionEnabled = true;
  bool _showTable = false;
  bool _isLoading = false;
  late FocusNode _employeeFocusNode;
  TextEditingController eleidController = TextEditingController();
  List<String> employeeList = [];
  String? selectEmployee;

  late List<TimesheetEntry> _entries;
  String? empDept;
  String? empTL;
  late int empCode;
  String? empName;
  String? selecteddept;
  final List<String> deptOptions = [
    'Designing',
    'Drafting',
  ];

  // Add these to your state class
  bool _shouldResetElementId = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _loadProjects();
    _clearElementId();
    _fetchElementId();
    _employeeFocusNode = FocusNode();
    _fetchEmployees();
  }

  @override
  void dispose() {
    _employeeFocusNode.dispose();
    super.dispose();
  }

  /*@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reassign & Issue Release',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
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
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: ListView(
            physics: BouncingScrollPhysics(),
            children: [
              DropdownButtonFormField<String>(
                value: selectedtype,
                decoration: _inputDecoration("Type").copyWith(
                  suffixIcon: (selectedtype != null)
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              selectedtype = null;
                              eleid = '';
                            });
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          padding: EdgeInsets.zero,
                          tooltip: 'Clear type filter',
                        )
                      : null,
                ),
                items: typeOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedtype = value;
                    eleid = '';
                  });
                },
              ),
              SizedBox(height: 20),
              _buildProjectDropdown(),
              SizedBox(height: 20),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _employeeList
                        .map((emp) => '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                        .toList();
                  } else {
                    return _employeeList
                        .where((emp) {
                          final empCode =
                              (emp['EMPCODE'] ?? '').toString().toLowerCase();
                          final empName =
                              (emp['EMPNAME'] ?? '').toString().toLowerCase();
                          final query = textEditingValue.text.toLowerCase();
                          return empCode.contains(query) ||
                              empName.contains(query);
                        })
                        .map((emp) => '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                        .toList();
                  }
                },
                displayStringForOption: (option) => option,
                fieldViewBuilder: (context, textEditingController, focusNode,
                    onFieldSubmitted) {
                  if (selectedEmployee != null &&
                      textEditingController.text.isEmpty) {
                    textEditingController.text = _employeeList
                            .where((emp) => emp['EMPCODE'] == selectedEmployee)
                            .map((emp) =>
                                '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                            .firstOrNull ??
                        '';
                  }

                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: _inputDecoration("Submitted By").copyWith(
                      suffixIcon: (selectedEmployee != null &&
                              selectedEmployee!.isNotEmpty)
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: "Clear Employee",
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                textEditingController.clear();
                                setState(() {
                                  selectedEmployee = null;
                                  eleid = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setState(() {
                          selectedEmployee = null;
                          eleid = '';
                        });
                      }
                    },
                  );
                },
                onSelected: (String selectedOption) {
                  // Check if a project is selected
                  if (_selectedProject == null || _selectedProject!.isEmpty) {
                    // Show a SnackBar prompting the user to select a project first
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please Select a Project First.')),
                    );
                    return; // Do not proceed further if no project is selected
                  }

                  final empCode = selectedOption.split('-').first.trim();
                  setState(() {
                    selectedEmployee = empCode;
                  });
                  _fetchElementId();
                  _fetchDepartmentTypeForEmployee(empCode);
                },
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selecteddept,
                decoration: _inputDecoration("Entry Department").copyWith(
                  suffixIcon: (selecteddept != null)
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              selecteddept = null;
                              eleid =
                                  ''; // Clear the element ID when department is cleared
                            });
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          padding: EdgeInsets.zero,
                          tooltip: 'Clear type filter',
                        )
                      : null,
                ),
                items: deptOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selecteddept = value;
                    eleid =
                        ''; // Clear the element ID whenever the department is changed
                  });
                  _fetchElementId();
                },
              ),
              SizedBox(height: 20),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return eleidOptions;
                  } else {
                    return eleidOptions.where((element) => element
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()));
                  }
                },
                displayStringForOption: (option) => option,
                fieldViewBuilder: (context, textEditingController, focusNode,
                    onFieldSubmitted) {
                  textEditingController.text = eleid;

                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: _inputDecoration("Element Id/Name").copyWith(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: eleid.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                textEditingController.clear();
                                setState(() {
                                  eleid = '';
                                });
                              },
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: 'Clear Element Id',
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        eleid = value;
                      });
                    },
                  );
                },
                onSelected: (String selectedOption) {
                  setState(() {
                    eleid = selectedOption;
                  });
                },
              ),
              SizedBox(height: 20),
              if (selectedtype == "REASSIGN")
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (employeeList.isEmpty)
                      return const Iterable<String>.empty();

                    // Show all employees if the field is empty
                    if (textEditingValue.text.isEmpty) {
                      return employeeList;
                    }

                    final query = textEditingValue.text.toLowerCase();
                    return employeeList.where(
                      (empName) => empName.toLowerCase().contains(query),
                    );
                  },
                  displayStringForOption: (option) => option,
                  fieldViewBuilder: (context, textEditingController, focusNode,
                      onFieldSubmitted) {
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: _inputDecoration("Reassign To").copyWith(
                        suffixIcon:
                            selectEmployee != null && selectEmployee!.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    tooltip: "Clear Employee",
                                    onPressed: () {
                                      textEditingController.clear();
                                      setState(() {
                                        selectEmployee = null;
                                      });
                                    },
                                  )
                                : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectEmployee = null; // Reset selection while typing
                        });
                      },
                      onTap: () {
                        _employeeFocusNode.requestFocus();
                      },
                    );
                  },
                  onSelected: (String selectedOption) {
                    final selectedEmpCode =
                        selectedOption.split('-').first.trim();

                    if (selectedEmpCode == selectedEmployee) {
                      // Show a warning that the employee cannot be the same
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Reassign To cannot be the same as Submitted By.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else {
                      setState(() {
                        selectEmployee = selectedOption;
                      });
                    }
                  },
                ),
              SizedBox(height: 20),
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
                            offset: Offset(2, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            InsertEleIDReassign();
                            handleReassign();
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Center(
                            child: Text(
                              'Submit',
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
    );
  }*/
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reassign & Issue Release',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Form(
          key: _formKey,
          child: ListView(
            physics: BouncingScrollPhysics(),
            children: [
              DropdownButtonFormField<String>(
                value: selectedtype,
                decoration: _inputDecoration("Type").copyWith(
                  suffixIcon: (selectedtype != null)
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              selectedtype = null;
                              eleid = '';
                            });
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          padding: EdgeInsets.zero,
                          tooltip: 'Clear type filter',
                        )
                      : null,
                ),
                items: typeOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedtype = value;
                    eleid = '';
                  });
                },
              ),
              SizedBox(height: 20),
              _buildProjectDropdown(),
              SizedBox(height: 20),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _employeeList
                        .map((emp) => '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                        .toList();
                  } else {
                    return _employeeList
                        .where((emp) {
                          final empCode =
                              (emp['EMPCODE'] ?? '').toString().toLowerCase();
                          final empName =
                              (emp['EMPNAME'] ?? '').toString().toLowerCase();
                          final query = textEditingValue.text.toLowerCase();
                          return empCode.contains(query) ||
                              empName.contains(query);
                        })
                        .map((emp) => '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                        .toList();
                  }
                },
                displayStringForOption: (option) => option,
                fieldViewBuilder: (context, textEditingController, focusNode,
                    onFieldSubmitted) {
                  if (selectedEmployee != null &&
                      textEditingController.text.isEmpty) {
                    textEditingController.text = _employeeList
                            .where((emp) => emp['EMPCODE'] == selectedEmployee)
                            .map((emp) =>
                                '${emp['EMPCODE']} - ${emp['EMPNAME']}')
                            .firstOrNull ??
                        '';
                  }

                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: _inputDecoration("Submitted By").copyWith(
                      suffixIcon: (selectedEmployee != null &&
                              selectedEmployee!.isNotEmpty)
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: "Clear Employee",
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                textEditingController.clear();
                                setState(() {
                                  selectedEmployee = null;
                                  eleid = '';
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        setState(() {
                          selectedEmployee = null;
                          eleid = '';
                        });
                      }
                    },
                    onTap: () {},
                  );
                },
                onSelected: (String selectedOption) {
                  // Check if a project is selected
                  if (_selectedProject == null || _selectedProject!.isEmpty) {
                    return;
                  }

                  final empCode = selectedOption.split('-').first.trim();
                  setState(() {
                    selectedEmployee = empCode;
                  });
                  _fetchElementId();
                  _fetchDepartmentTypeForEmployee(empCode);
                },
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selecteddept,
                decoration: _inputDecoration("Entry Department").copyWith(
                  suffixIcon: (selecteddept != null)
                      ? IconButton(
                          onPressed: () {
                            setState(() {
                              selecteddept = null;
                              eleid = '';
                            });
                          },
                          icon: const Icon(Icons.clear, size: 18),
                          padding: EdgeInsets.zero,
                          tooltip: 'Clear type filter',
                        )
                      : null,
                ),
                items: deptOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selecteddept = value;
                    eleid = '';
                  });
                  _fetchElementId();
                },
                onTap: () {
                  if (_selectedProject == null || _selectedProject!.isEmpty) {
                  } else if (selectedEmployee == null ||
                      selectedEmployee!.isEmpty) {}
                },
              ),
              SizedBox(height: 20),
              // Element ID Field with validation
              _buildElementIdFieldWithValidation(),
              SizedBox(height: 20),
              if (selectedtype == "REASSIGN")
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (employeeList.isEmpty)
                      return const Iterable<String>.empty();

                    if (textEditingValue.text.isEmpty) {
                      return employeeList;
                    }

                    final query = textEditingValue.text.toLowerCase();
                    return employeeList.where(
                      (empName) => empName.toLowerCase().contains(query),
                    );
                  },
                  displayStringForOption: (option) => option,
                  fieldViewBuilder: (context, textEditingController, focusNode,
                      onFieldSubmitted) {
                    return TextFormField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: _inputDecoration("Reassign To").copyWith(
                        suffixIcon:
                            selectEmployee != null && selectEmployee!.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    tooltip: "Clear Employee",
                                    onPressed: () {
                                      textEditingController.clear();
                                      setState(() {
                                        selectEmployee = null;
                                      });
                                    },
                                  )
                                : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          selectEmployee = null;
                        });
                      },
                      onTap: () {
                        _employeeFocusNode.requestFocus();
                      },
                    );
                  },
                  onSelected: (String selectedOption) {
                    final selectedEmpCode =
                        selectedOption.split('-').first.trim();

                    if (selectedEmpCode == selectedEmployee) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Reassign To cannot be the same as Submitted By.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else {
                      setState(() {
                        selectEmployee = selectedOption;
                      });
                    }
                  },
                ),
              SizedBox(height: 20),
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
                            offset: Offset(2, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          if (_validateRequiredFields()) {
                            setState(() {
                              InsertEleIDReassign();
                              handleReassign();
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Center(
                            child: Text(
                              'Submit',
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
    );
  }

  // Helper method to build Element ID field with validation
  Widget _buildElementIdFieldWithValidation() {
    // Check if all required fields are filled
    final bool areRequiredFieldsFilled = _selectedProject != null &&
        _selectedProject!.isNotEmpty &&
        selectedEmployee != null &&
        selectedEmployee!.isNotEmpty &&
        selecteddept != null &&
        selecteddept!.isNotEmpty;

    if (!areRequiredFieldsFilled) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey.shade100,
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Please select Project, Submitted By and Entry Department first',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return eleidOptions;
        } else {
          return eleidOptions.where((element) => element
              .toLowerCase()
              .contains(textEditingValue.text.toLowerCase()));
        }
      },
      displayStringForOption: (option) => option,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        textEditingController.text = eleid;

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: _inputDecoration("Element Id/Name").copyWith(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: eleid.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      textEditingController.clear();
                      setState(() {
                        eleid = '';
                      });
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Clear Element Id',
                  )
                : null,
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() {
              eleid = value;
            });
          },
          onTap: () {
            if (!areRequiredFieldsFilled) {}
          },
        );
      },
      onSelected: (String selectedOption) {
        setState(() {
          eleid = selectedOption;
        });
      },
    );
  }

  // Method to show required field message

  // Method to validate all required fields before submit
  bool _validateRequiredFields() {
    if (_selectedProject == null || _selectedProject!.isEmpty) {
      return false;
    }

    if (selectedEmployee == null || selectedEmployee!.isEmpty) {
      return false;
    }

    if (selecteddept == null || selecteddept!.isEmpty) {
      return false;
    }

    if (eleid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an Element ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return true;
  }

  void _clearElementId() {
    eleid = '';
    _shouldResetElementId = true;
    eleidController.clear();
  }

  Future<void> _loadUserDetails() async {
    try {
      final prefsHelper = PreferencesHelper();
      empCode = (await prefsHelper.getEmpCode()) ?? 0;
      empName = await prefsHelper.getEmpName();
      empDept = await prefsHelper.getEmpDept();
      empTL = await prefsHelper.getEmpTL();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading user: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildProjectDropdown() {
    final TextEditingController _projectController = TextEditingController();

    try {
      return Autocomplete<Project>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Project>.empty();
          }
          return _projects.where((project) =>
              project.projectName
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase()) ||
              project.projectId.toString().contains(textEditingValue.text));
        },
        displayStringForOption: (project) =>
            '${project.projectId} - ${project.projectName}',
        fieldViewBuilder:
            (context, textEditingController, focusNode, onFieldSubmitted) {
          if (textEditingController.text.isEmpty) {
            textEditingController.text = _projectController.text;
          }

          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            decoration: _inputDecoration("Project").copyWith(
              hintText: 'Search by site code or name...',
              suffixIcon: textEditingController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 18),
                      onPressed: () {
                        textEditingController.clear();
                        setState(() {
                          _projectId = 0;
                          _selectedProject = '';
                          eleid = '';
                        });
                      },
                    )
                  : null,
            ),
            enabled: _isSiteSelectionEnabled,
          );
        },
        onSelected: (Project selection) async {
          setState(() {
            _selectedProject = selection.projectName;
            _projectController.text =
                '${selection.projectId} - ${selection.projectName}';
            _projectId = selection.projectId;
            eleid = ''; // Reset the selected element
          });

          // Fetch employees only when a project is selected
          await _fetchSubmittedUsers(
              selection.projectId!); // Fetch employees for selected project
          await _fetchElementId();

          try {
            final id = await _fileService.ProjectId(_selectedProject!);
            setState(() {
              _projectId = id;
              _showTable = false;
            });
          } catch (e) {
            setState(() {
              _projectId = 0;
              _showTable = false;
            });
          }
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Material(
            elevation: 4,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final project = options.elementAt(index);
                return ListTile(
                  title: Text('${project.projectId} - ${project.projectName}'),
                  subtitle: Text('Site Code: ${project.projectId}'),
                  onTap: () => onSelected(project),
                );
              },
            ),
          );
        },
      );
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading projects: $e')),
        );
      });
      return Container();
    }
  }

  Future<void> _loadProjects() async {
    try {
      setState(() => _isLoading = true);
      final projects = await _fileService.loadProjNames();

      final uniqueProjects = <Project>[];
      final names = <String>{};

      for (final project in projects) {
        if (!names.contains(project.projectName)) {
          uniqueProjects.add(project);
          names.add(project.projectName);
        }
      }

      setState(() {
        // Insert "All" option at the top
        _projects = [
          ...uniqueProjects,
        ];

        if (_projects.isNotEmpty && _isSiteSelectionEnabled) {
          _selectedProject = _projects.first.projectName;
          _projectId = _projects.first.projectId;
        }
      });

      // Do not call _fetchSubmittedUsers() here.
      // Wait for the user to select a project first!
    } catch (e) {
      print('Error loading projects: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load projects: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Add this method to your class
  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 15,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
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

  void _fetchDepartmentTypeForEmployee(String empCode) {
    final selectedEmp = _employeeList.firstWhere(
      (emp) => emp['EMPCODE'] == empCode,
      orElse: () => {}, // Handle case if employee is not found
    );

    if (selectedEmp.isNotEmpty) {
      // Assuming the department type is stored in 'TSDEPTTYPE'
      final deptType = selectedEmp['TSDEPTTYPE'];
      setState(() {
        selecteddept =
            deptType; // Update department dropdown based on employee's department type
      });
    }
  }

  Future<void> _fetchSubmittedUsers(int projectId) async {
    try {
      setState(() {
        _employeeList = [];
        selectedEmployee = null;
        selecteddept = null;
        eleid = '';
        eleidOptions = [];
      });

      final response = await http.post(
        ApiUtils.getUri('SubmittedUsers'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'SiteCode': projectId // Remove .toString() - send as integer
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['Success'] == true && data['SubmittedUsers'] != null) {
          setState(() {
            _employeeList =
                List<Map<String, dynamic>>.from(data['SubmittedUsers']);
          });
          debugPrint(
              "✅ Loaded ${_employeeList.length} employees for project $projectId");
        } else {
          debugPrint("⚠️ No submitted users found for this project");
          setState(() {
            _employeeList = [];
          });
        }
      } else {
        debugPrint("❌ API error: ${response.statusCode}");
        setState(() {
          _employeeList = [];
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching submitted users: $e");
      setState(() {
        _employeeList = [];
      });
    }
  }

  Future<void> _fetchElementId() async {
    try {
      setState(() {
        eleidOptions = [];
      });

      if (_projectId == 0 ||
          selectedEmployee == null ||
          selectedEmployee!.isEmpty ||
          selecteddept == null ||
          selecteddept!.isEmpty) {
        debugPrint("⚠️ Project, employee, or department not selected");

        setState(() => eleidOptions = []);
        return;
      }

      final endpoint = (selectedtype != null && selectedtype == "REASSIGN")
          ? 'GetReAssignElementId'
          : 'GetIssueReleaseElementId';

      // ✅ Determine the 'isIssued' flag based on selected type
      final isIssued = selectedtype != null && selectedtype == "ISSUED";

      // Use the selected department as a query parameter
      final uri = ApiUtils.getUri(endpoint).replace(queryParameters: {
        'TSDEPTTYPE': selecteddept, // Send department filter as query parameter
        'SITECODE': _projectId.toString(),
        'ADDUSER': selectedEmployee,
      });

      debugPrint('Fetching ELEIDs with URI: $uri');

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "SITECODE": _projectId,
          "ADDUSER": int.tryParse(selectedEmployee!),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint("🔍 API Response: $data");

        if (data['Success'] == true && data['ElementIds'] != null) {
          final allElements = List<String>.from(
              data['ElementIds'].map((e) => e['ELEID'].toString()));
          setState(() {
            eleidOptions = allElements;
          });
          debugPrint("✅ Element IDs Loaded: ${eleidOptions.length}");
        } else {
          debugPrint("⚠️ No element IDs found");
          setState(() => eleidOptions = []);
        }
      } else {
        debugPrint("❌ API error: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Exception: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching element IDs: $e")),
      );
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final url = ApiUtils.getUri('GetTSEmp');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Success'] == true && data['GetTSEmp'] != null) {
          final employees = data['GetTSEmp'] as List;
          setState(() {
            employeeList = employees
                .map((e) => "${e['EMPCODE']} - ${e['EMPNAME']}")
                .toList()
                .cast<String>();
          });
        } else {
          setState(() {
            employeeList = [];
          });
          debugPrint("⚠️ No employees found");
        }
      } else {
        debugPrint("❌ HTTP error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Exception in _fetchEmployees: $e");
    }
  }

  Future<String> getEmployeeNameWithCode(int empCode) async {
    try {
      final uri = ApiUtils.getUri("GetEmployeeNames");
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"EMPCODE": empCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true && data['Departments'].isNotEmpty) {
          final emp = data['Departments'][0];
          return "${emp['EMPCODE'] ?? empCode} - ${emp['EMPNAME'] ?? '-'}";
        }
      }
    } catch (e) {
      debugPrint("Error fetching employee name: $e");
    }

    return "$empCode - -"; // fallback
  }

  Future<void> InsertEleIDReassign() async {
    if (selectedEmployee == selectEmployee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Reassign To cannot be the same as Submitted By."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final url = ApiUtils.getUri('InsertEleIDReassign');

    // Determine which employee code to use
    int? empCodeToUse;

    if (selectedtype == "REASSIGN") {
      if (selectEmployee != null && selectEmployee!.isNotEmpty) {
        empCodeToUse = int.tryParse(selectEmployee!.split('-').first.trim());
      }
    } else {
      empCodeToUse = int.tryParse(selectedEmployee!.split('-').first.trim());
    }

    final Map<String, dynamic> data = {
      "SITECODE": _projectId,
      "SUBMITTEDBY": selectedEmployee,
      "REASSIGNTO": empCodeToUse,
      "ELEID": eleid,
      "ASSIGNTYPE": selectedtype,
      "ADDUSER": empCode,
      //"ADDUSER": int.tryParse(selectedEmployee ?? '0'),
    };

    debugPrint("Insert Data: $data");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['Success'] == true) {
          /* ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅Inserted Successfully"),
              backgroundColor: Colors.green,
            ),
          );*/
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Please fill all mandatory fields"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Server error: ${response.statusCode}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> getTimesheetDetails({
    required int siteCode,
    required int addUser,
    required String eleId,
  }) async {
    final url = ApiUtils.getUri('TSGetEleIDDetails');

    final Map<String, dynamic> data = {
      "SITECODE": siteCode,
      "ADDUSER": addUser,
      "ELEID": eleId,
    };

    print("Sending request to: $url");
    print("Request Data: $data");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(data),
      );

      print("Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print("Response Body: $result");

        if (result != null) {
          // Check if response is success and handle accordingly
          if (result['Success'] == true) {
            return result['Timesheet']; // Return the timesheet data if success
          } else {
            // Handle failure scenario if Success is false
            print("Error: ${result['Message']}");
            return null; // Return null if there is an error message
          }
        }
      } else {
        // Handle non-200 status codes (e.g., 404, 500)
        print(
            "Error: Server responded with status code ${response.statusCode}");
        throw Exception('Failed to load timesheet data');
      }
    } catch (e) {
      print("Error while fetching timesheet data: $e");
      return null; // Return null if an error occurs
    }

    return null; // Return null if response status is not 200
  }

  Future<int> insertTimeSheetReassign(TimeSheet ts) async {
    try {
      print("Sending POST request to InsertTimeSheetReassign...");
      print("TimeSheet Data: ${json.encode(ts.toJson())}");

      final response = await http.post(
        ApiUtils.getUri('InsertTimeSheetReassign'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(ts.toJson()),
      );

      print("Response Status Code: ${response.statusCode}");

      // Decode the body if it's in byte format
      final responseBody = utf8.decode(response.bodyBytes);
      print("Response Body: $responseBody");

      if (response.statusCode == 200) {
        print("Response Status Code: 200 - OK");
        var result = json.decode(responseBody);
        print("Response Body (Decoded): $result");

        // Assuming the result is a number (int)
        if (result == 1) {
          print("Timesheet reassigned successfully!");
          return 1; // Success
        } else if (result == 0) {
          print("Insertion failed. Response body: $result");
          return 0; // Failure
        } else {
          print("Unexpected response format: $result");
          return 0; // Unexpected response
        }
      } else {
        print(
            "Failed to insert timesheet. Status Code: ${response.statusCode}");
        return 0; // Failure due to API error
      }
    } catch (e) {
      print("Error in insertTimeSheetReassign: $e");
      return 0;
    }
  }

  Future<void> handleReassign() async {
    try {
      // Ensure submitted employee is selected
      if (selectedEmployee == null || selectedEmployee!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select Submitted By employee')),
        );
        return;
      }

      // Extract emp codes

      final submittedByCode =
          int.parse(selectedEmployee!.split('-').first.trim());
      final submittedByFullName =
          await getEmployeeNameWithCode(submittedByCode);
      // final currentUser = empCode; // logged-in user
      print("submittedByCode: $submittedByCode");

      // Reassigning to employee, check for "ISSUE RELEASE" type before using selectEmployee
      String reassignedToText = 'ISSUE RELEASE';
      if (selectedtype != "ISSUE RELEASE") {
        if (selectEmployee == null || selectEmployee!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please select Reassigned To employee')),
          );
          return;
        }
        reassignedToText = selectEmployee!;
      }

      //final reassignedToText = selectEmployee!;
      final reassignedToCode = reassignedToText.split('-').first.trim();

      // Prevent reassignment to same employee
      if (reassignedToCode == submittedByCode.toString()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reassign To cannot be the same as Submitted By'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      String reassignedData =
          'Forwarded From: $submittedByFullName Reassigning to: $reassignedToText';
      print("Reassigning data: $reassignedData");

      if (selectedtype == "ISSUE RELEASE") {
        reassignedData = 'ISSUE RELEASE';
      }

      // Reassign data string with names
      String Data = 'ISSUE RELEASE';
      print("Reassigning data: $Data");

      // If selectedtype is "ISSUE RELEASE", update reassignedData to "ISSUE RELEASE"
      if (selectedtype == "ISSUE RELEASE") {
        Data = 'ISSUE RELEASE';
        print("Reassigning data updated to: $Data");
      }

      // STEP 1: Fetch ELEID for the selected "Submitted By" employee
      final url = ApiUtils.getUri('TSGetEleIDDetails');
      // ensure empCode is int
      final int currentUser = int.parse(empCode
          .toString()); // or use the int variable directly if it's already int

      final data = {
        "SITECODE": _projectId!,
        "ADDUSER": submittedByCode,
        "ELEID": eleid,
        "REASSIGNDATA": reassignedToText,
        "RECHKUSER": currentUser,
      };

      print("Request JSON: ${json.encode(data)}");

      print("Sending request to: $url");
      print("Request Data: $data");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode != 200) {
        print("Failed to load timesheet data");
        if (selectedtype == "REASSIGN") {
          /*ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load timesheet data')),
          );*/
        }
        return;
      }

      final apiResult = jsonDecode(response.body);
      print("Response Body: $apiResult");

      // STEP 2: Create the TimeSheet object for reassignment
      final fetchedEleId = apiResult['ELEID'] ?? eleid;
      print("Fetched ELEID: $fetchedEleId");

      //final reassignedEmpCode = int.parse(reassignedToCode);
      final ts = TimeSheet(
        siteCode: _projectId!,
        addUser: submittedByCode,
        eleId: fetchedEleId.toString(),
        reassignData: reassignedData,
      );

      print("TimeSheet object created: ${ts.toJson()}");

      // STEP 3: Call the InsertTimeSheetReassign API
      final insertResult = await insertTimeSheetReassign(ts);

      if (insertResult == 1) {
        print("Timesheet reassigned successfully!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timesheet - Reassigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print("Failed to reassign timesheet.");
      }
      // STEP 4: Update the timesheet data using the updateTimesheetReassignData API
      String tsStatus = 'FORWARDED'; // Default value for TSSTATUS

      // Check if the selected type is 'ISSUE RELEASE'
      if (selectedtype == 'ISSUE RELEASE') {
        tsStatus =
            'RECHECK'; // Change TSSTATUS to 'RECHECK' for 'ISSUE RELEASE'
      }

      final updateData = {
        "SITECODE": _projectId!,
        "ADDUSER": submittedByCode,
        "ELEID": fetchedEleId.toString(),
        "RECHKUSER": currentUser,
        "REASSIGNDATA": reassignedToText,
        "RECHKREMARKS": reassignedToText,
        "TSSTATUS": tsStatus, // Dynamically set TSSTATUS
      };

      final updateResult = await updateTimesheetReassignData(updateData);

      if (updateResult == 1) {
        print("Timesheet updated successfully!");
        if (selectedtype == 'ISSUE RELEASE') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Timesheet - Issue Release successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        print("Failed to update timesheet.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update timesheet')),
        );
        return;
      }
    } catch (e, st) {
      print("Error while handling reassignment: $e");
      print(st);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error while handling reassignment: $e')),
      );
    }
  }

  Future<int> updateTimesheetReassignData(
      Map<String, dynamic> timesheetData) async {
    final url = ApiUtils.getUri('UpdateTimeSheetReassignData');

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(timesheetData),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result ?? 0;
      } else {
        throw Exception('Failed to update timesheet data');
      }
    } catch (e) {
      print("Error while updating timesheet: $e");
      return 0;
    }
  }
}
