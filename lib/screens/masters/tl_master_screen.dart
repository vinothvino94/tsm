import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';

class TlMasterScreen extends StatefulWidget {
  final int empCode;
  final bool isSuperAdmin;
  final bool isTeamLead;
  const TlMasterScreen({
    super.key,
    required this.empCode,
    required this.isSuperAdmin,
    required this.isTeamLead,
  });

  @override
  State<TlMasterScreen> createState() => _TlMasterScreenState();
}

class _TlMasterScreenState extends State<TlMasterScreen> {
  List<dynamic> _allEmployees = [];
  List<dynamic> _teamLeaders = [];
  List<dynamic> _filteredEmployees = [];
  String? _selectedTeamLead = "0";
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  /// ✅ Fetch Employee List and Extract Unique Team Leads
  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final uri = ApiUtils.getUri('EmployeeListByTeamLead');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "HRIACCNO": widget.isSuperAdmin ? "0" : widget.empCode.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true && data['EmployeeList'] is List) {
          final employees = data['EmployeeList'];
          final uniqueTLs = _getUniqueTeamLeads(employees);

          setState(() {
            _allEmployees = employees;
            _teamLeaders = uniqueTLs;

            if (widget.isTeamLead && !widget.isSuperAdmin) {
              // Team Lead: Only show their own team members
              _filteredEmployees = employees
                  .where((e) =>
                      e['HRIACCNO']?.toString() == widget.empCode.toString())
                  .toList();
              _selectedTeamLead = widget.empCode.toString();
            } else if (widget.isSuperAdmin) {
              // Super Admin: Show all employees initially
              _filteredEmployees = employees;
              _selectedTeamLead = "0"; // "All Team Leads"
            } else {
              // Regular employee (shouldn't reach here, but fallback)
              _filteredEmployees = [];
            }
          });
        } else {
          _showError('Failed to load: ${data['Message']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// ✅ Unique TL list based on HRIACCNO
  List<dynamic> _getUniqueTeamLeads(List<dynamic> allEmployees) {
    final seen = <String>{};
    final unique = <dynamic>[];
    for (final emp in allEmployees) {
      final code = emp['HRIACCNO']?.toString();
      if (code != null &&
          code != "0" &&
          code.isNotEmpty &&
          !seen.contains(code)) {
        seen.add(code);
        unique.add(emp);
      }
    }
    return unique;
  }

  /// ✅ Validate selected TL code
  String? _validatedSelectedTeamLead(List<dynamic> validLeads) {
    if (_selectedTeamLead == null || _selectedTeamLead == "0") return "0";
    final exists =
        validLeads.any((tl) => tl['HRIACCNO']?.toString() == _selectedTeamLead);
    return exists ? _selectedTeamLead : "0";
  }

  /// ✅ Filter employee list by TL
  void _filterEmployees(String? teamLeadCode) {
    if (teamLeadCode == null || teamLeadCode == "0") {
      setState(() => _filteredEmployees = _allEmployees);
    } else {
      setState(() {
        _filteredEmployees = _allEmployees
            .where((emp) => emp['HRIACCNO']?.toString() == teamLeadCode)
            .toList();
      });
    }
  }

  /// ✅ Fetch Employee or TL Name from backend
  Future<String> getEmployeeNameWithCode(String empCode) async {
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
    return "$empCode - -";
  }

  String _getDepartmentName(String? code) {
    switch (code) {
      case '1':
        return 'DESIGNING';
      case '2':
        return 'DRAFTING';
      case '3':
        return 'SALES';
      default:
        return 'UNKNOWN';
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredSearch = _filteredEmployees.where((emp) {
      final term = _searchController.text.toLowerCase();
      return emp['EMPNAME']?.toString().toLowerCase().contains(term) == true ||
          emp['EMPCODE']?.toString().toLowerCase().contains(term) == true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('TL Master',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                widget.isSuperAdmin
                    ? "Super Admin"
                    : widget.isTeamLead
                        ? "Team Lead"
                        : "Employee",
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              backgroundColor: widget.isSuperAdmin
                  ? Colors.purple
                  : widget.isTeamLead
                      ? Colors.blue
                      : Colors.grey,
            ),
          ],
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
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadEmployees),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔹 TL Dropdown - Only show for Super Admin
                if (widget.isSuperAdmin)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        const Icon(Icons.groups, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FutureBuilder<List<DropdownMenuItem<String>>>(
                            future: _buildTeamLeadDropdownItems(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              return DropdownButtonFormField<String>(
                                value: _selectedTeamLead,
                                decoration: InputDecoration(
                                  labelText: 'Select Team Lead',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: snapshot.data!,
                                onChanged: (value) {
                                  setState(() => _selectedTeamLead = value);
                                  _filterEmployees(value);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                else if (widget.isTeamLead)
                  // Team Lead view - show their team info
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppColors.primaryLight.withOpacity(0.1),
                    child: Row(
                      children: [
                        const Icon(Icons.group, color: AppColors.primary),
                        const SizedBox(width: 12),
                        FutureBuilder<String>(
                          future: getEmployeeNameWithCode(
                              widget.empCode.toString()),
                          builder: (context, snapshot) {
                            final tlName = snapshot.data ?? "Loading...";
                            return Expanded(
                              child: Text(
                                "Viewing: $tlName's Team",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                // 🔹 Search box
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search employees...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                // 🔹 Employee count info
                if (filteredSearch.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${filteredSearch.length} employee(s) found',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        if (widget.isTeamLead && !widget.isSuperAdmin)
                          const Text(
                            'You can edit department only',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // 🔹 Employee list
                Expanded(
                  child: filteredSearch.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No employees found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Try adjusting your search or filters',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredSearch.length,
                          itemBuilder: (context, index) {
                            final emp = filteredSearch[index];
                            final empCode = emp['EMPCODE']?.toString() ?? '-';
                            final dept = _getDepartmentName(emp['HRIIFSCCODE']);
                            final tlCode = emp['HRIACCNO']?.toString() ?? '0';

                            // Check if current user can edit this employee
                            final canEdit = widget.isSuperAdmin ||
                                (widget.isTeamLead &&
                                    tlCode == widget.empCode.toString());

                            return FutureBuilder<String>(
                              future: getEmployeeNameWithCode(empCode),
                              builder: (context, empSnapshot) {
                                final empDisplay =
                                    empSnapshot.data ?? "$empCode - Loading...";
                                return FutureBuilder<String>(
                                  future: getEmployeeNameWithCode(tlCode),
                                  builder: (context, tlSnapshot) {
                                    final tlDisplay = tlSnapshot.data ??
                                        "$tlCode - Loading...";
                                    return Card(
                                      color: Colors.white,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 6),
                                      elevation: 2,
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              AppColors.primaryLight,
                                          child: Text(
                                            (emp['EMPNAME'] != null &&
                                                    emp['EMPNAME']
                                                        .toString()
                                                        .isNotEmpty)
                                                ? emp['EMPNAME']
                                                    .toString()
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        title: Text(
                                          empDisplay,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Dept: $dept',
                                              style: TextStyle(
                                                  color: Colors.grey[600]),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'TL: $tlDisplay',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        trailing: canEdit
                                            ? IconButton(
                                                icon: const Icon(Icons.edit,
                                                    color: AppColors.primary),
                                                onPressed: () {
                                                  _showEditDialog(context, emp);
                                                },
                                              )
                                            : widget.isTeamLead
                                                ? const Tooltip(
                                                    message:
                                                        'You can only edit employees in your team',
                                                    child: Icon(
                                                      Icons.lock_outline,
                                                      color: Colors.grey,
                                                      size: 20,
                                                    ),
                                                  )
                                                : null,
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  /// 🔧 Show edit popup for changing Team Lead or Department
  void _showEditDialog(BuildContext context, Map<String, dynamic> emp) async {
    // Check if user has permission to edit this employee
    final empTlCode = emp['HRIACCNO']?.toString();

    if (widget.isTeamLead && !widget.isSuperAdmin) {
      // Team Lead can only edit employees in their own team
      if (empTlCode != widget.empCode.toString()) {
        _showError("You can only edit employees in your own team");
        return;
      }
    }

    String? selectedTl = empTlCode ?? "0";
    String? selectedDept = emp['HRIIFSCCODE']?.toString() ?? "1";

    final tlItems = await _buildTeamLeadDropdownItems();
    final deptItems = const [
      DropdownMenuItem(value: "1", child: Text("Designing")),
      DropdownMenuItem(value: "2", child: Text("Drafting")),
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  minWidth: 350,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        "Edit Employee (${emp['EMPCODE']})",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Team Lead dropdown - disabled for Team Leads
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Team Lead",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            child: DropdownButtonFormField<String>(
                              value: selectedTl,
                              items: tlItems.map((item) {
                                final text = (item.child as Text).data ??
                                    ""; // Extract safe text

                                return DropdownMenuItem<String>(
                                  value: item.value,
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 300),
                                    child: Text(
                                      _truncateText(text, 40),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                );
                              }).toList(),
                              decoration: InputDecoration(
                                hintText: widget.isTeamLead
                                    ? "Your Team (Fixed)"
                                    : "Select Team Lead",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                isDense: true,
                              ),
                              onChanged: widget.isTeamLead &&
                                      !widget.isSuperAdmin
                                  ? null // Team Leads cannot change TL assignment
                                  : (val) {
                                      setStateDialog(() => selectedTl = val);
                                    },
                              isExpanded: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Department dropdown - always editable
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Department",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            child: DropdownButtonFormField<String>(
                              value: selectedDept,
                              items: deptItems,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                isDense: true,
                              ),
                              onChanged: (val) =>
                                  setStateDialog(() => selectedDept = val),
                              isExpanded: true,
                            ),
                          ),
                        ],
                      ),

                      // Show role-based info
                      if (widget.isTeamLead && !widget.isSuperAdmin)
                        const Padding(
                          padding: EdgeInsets.only(top: 12.0),
                          child: Text(
                            "Note: You can only edit department for employees in your team",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              await _updateEmployeeTLDept(
                                emp['EMPCODE'].toString(),
                                selectedTl ?? "0",
                                selectedDept ?? "1",
                              );
                            },
                            child: const Text(
                              "Update",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  /// 🌐 Update Employee TL and Department
  Future<void> _updateEmployeeTLDept(
      String empCode, String hriaccno, String hriifsccode) async {
    try {
      final uri = ApiUtils.getUri("UpdateEmployeeTeamLeadDept");
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "EMPCODE": int.tryParse(empCode),
          "HRIACCNO": hriaccno,
          "HRIIFSCCODE": hriifsccode,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Employee updated successfully"),
              backgroundColor: Colors.green,
            ),
          );
          _loadEmployees(); // Refresh list
        } else {
          _showError(data['Message'] ?? "Update failed.");
        }
      } else {
        _showError("HTTP ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error updating employee: $e");
    }
  }

  /// ✅ Build TL dropdown based on role
  Future<List<DropdownMenuItem<String>>> _buildTeamLeadDropdownItems() async {
    List<DropdownMenuItem<String>> items = [];

    if (widget.isSuperAdmin) {
      // Super Admin → Can see ALL TLs and "All Team Leads"
      items.add(
        const DropdownMenuItem(value: "0", child: Text("All Team Leads")),
      );

      // Sort team leaders by employee code
      final sortedTeamLeaders = List<Map<String, dynamic>>.from(_teamLeaders)
        ..sort((a, b) {
          final aCode = int.tryParse(a['HRIACCNO']?.toString() ?? '0') ?? 0;
          final bCode = int.tryParse(b['HRIACCNO']?.toString() ?? '0') ?? 0;
          return aCode.compareTo(bCode);
        });

      for (final tl in sortedTeamLeaders) {
        final code = tl['HRIACCNO']?.toString() ?? '';
        if (code.isNotEmpty && code != "0") {
          final name = await getEmployeeNameWithCode(code);
          items.add(
            DropdownMenuItem(value: code, child: Text(name)),
          );
        }
      }
    } else if (widget.isTeamLead) {
      // Team Lead → Only themselves (read-only)
      final name = await getEmployeeNameWithCode(widget.empCode.toString());
      items.add(
        DropdownMenuItem(
          value: widget.empCode.toString(),
          child: Text("$name (Your Team)"),
        ),
      );
    }

    return items;
  }
}
