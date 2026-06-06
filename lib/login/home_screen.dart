import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:tsm/api/api_utils.dart';
import 'package:tsm/login/change_password.dart';
import 'package:tsm/widgets/approved_animation.dart';

import '../colors/app_colors.dart';
import '../screens/sales/sales_menu_screen.dart';
import '../screens/timesheet/add_timesheet_screen.dart';
import '../screens/report/generate_report_screen.dart';
import '../screens/masters/tl_master_screen.dart';
import '../screens/timesheet/view_timesheet_screen.dart';
import '../screens/masters/work_element_reassign_screen.dart';
import '../services/file_service.dart';
import '../services/prefrence_helper.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  final int empcode;
  final String employeeName;

  const HomeScreen({
    Key? key,
    required this.empcode,
    required this.employeeName,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 0; // bottom nav selected index
  int _selectedCardIndex = -1; // for the dashboard cards

  int pendingCount = 0;
  int reworkCount = 0;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isCollapsed = false;
  bool isSelected = false;
  int? empCode;
  String? empName;
  bool _isLoading = false;
  int submittedCount = 0;
  int recheckCount = 0;
  int reassignCount = 0;
  int approvedCount = 0; // ✅ ADD THIS: Approved count variable
  // User role info
  bool isTeamLead = false;
  bool isSuperAdmin = false;
  int teamMemberCount = 0;
  List<int> _allowedReportUsers = [];

  int designDeptCount = 0;
  int draftingDeptCount = 0;
  int otherDeptCount = 0;
  final FileService fileService = FileService();
  double siteTotalHours = 0.0;
  double employeeTotalHours = 0.0;
  String selectedEmployeeName = '';
  List<Map<String, dynamic>> employeeList = [];

  bool _hasSalesAccess = false;

  @override
  void initState() {
    super.initState();
    _fetchStatusCounts();
    _loadUserDetails().then((_) {
      _fetchStatusCounts();
      _fetchAllowedReportUsers(); // ✅ ADD THIS: Fetch allowed users
      _loadSalesAccess();
    });

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: _buildDashboard(context)),
        bottomNavigationBar: !_hasSalesAccess
            ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: BottomNavigationBar(
                        currentIndex: _selectedNavIndex,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        selectedItemColor: AppColors.primary,
                        unselectedItemColor: AppColors.textSecondary,
                        type: BottomNavigationBarType.fixed,
                        onTap: _onItemTapped,
                        items: _canAccessReports
                            ? [
                                // ✅ With Reports access: 4 items
                                _buildAnimatedNavItem(
                                  index: 0,
                                  icon: Icons.dashboard_rounded,
                                  label: 'Masters',
                                ),
                                _buildAnimatedNavItem(
                                  index: 1,
                                  icon: Icons.access_time_rounded,
                                  label: 'Time Sheet',
                                ),
                                _buildAnimatedNavItem(
                                  index: 2,
                                  icon: Icons.list,
                                  label: 'View Time Sheets',
                                ),
                                _buildAnimatedNavItem(
                                  index: 3,
                                  icon: Icons.bar_chart_rounded,
                                  label: 'Reports',
                                ),
                                _buildAnimatedNavItem(
                                  index: 4,
                                  icon: Icons.sell,
                                  label: 'Sales',
                                ),
                              ]
                            : [
                                // ✅ Without Reports access: 2 items
                                _buildAnimatedNavItem(
                                  index: 1,
                                  icon: Icons.access_time_rounded,
                                  label: 'Time Sheet',
                                ),
                                _buildAnimatedNavItem(
                                  index: 2,
                                  icon: Icons.list,
                                  label: 'View Time Sheets',
                                ),
                              ],
                      ),
                    ),
                  ),
                ),
              )
            : null);
  }

  // Future<void> _fetchCounts() async {
  //   await Future.delayed(const Duration(seconds: 1));
  //   setState(() {
  //     pendingCount = Random().nextInt(10);
  //     reworkCount = Random().nextInt(5);
  //   });
  // }
  Future<void> _fetchAllowedReportUsers() async {
    try {
      List<int> combinedUsers = [];

      // ✅ Fetch from TeamLead endpoint
      final teamLeadUri = ApiUtils.getUri('TeamLead');
      final teamLeadResponse = await http.post(
        teamLeadUri,
        headers: {'Content-Type': 'application/json'},
      );

      if (teamLeadResponse.statusCode == 200) {
        final teamLeadData = jsonDecode(teamLeadResponse.body);
        if (teamLeadData is List) {
          combinedUsers.addAll(teamLeadData.cast<int>());
          debugPrint('✅ TeamLead Users: ${teamLeadData.cast<int>()}');
        }
      }

      // ✅ Fetch from ShowAppRej endpoint
      final appRejUri = ApiUtils.getUri('ShowAppRej');
      final appRejResponse = await http.post(
        appRejUri,
        headers: {'Content-Type': 'application/json'},
      );

      if (appRejResponse.statusCode == 200) {
        final appRejData = jsonDecode(appRejResponse.body);
        if (appRejData is List) {
          combinedUsers.addAll(appRejData.cast<int>());
          debugPrint('✅ ShowAppRej Users: ${appRejData.cast<int>()}');
        }
      }

      // ✅ Remove duplicates and update state
      final uniqueUsers = combinedUsers.toSet().toList();
      setState(() {
        _allowedReportUsers = uniqueUsers;
      });

      debugPrint('✅ Combined Allowed Report Users: $_allowedReportUsers');
    } catch (e) {
      debugPrint('❌ Error fetching allowed report users: $e');
    }
  }

  // ✅ ADD THIS GETTER: Check if current user can access reports
  bool get _canAccessReports {
    final currentUserCode = empCode ?? widget.empcode;
    final canAccess = _allowedReportUsers.contains(currentUserCode);
    /*debugPrint(
        '🔍 Reports Access Check: User $currentUserCode, Allowed: $canAccess');*/
    return canAccess;
  }

  Future<void> _loadUserDetails() async {
    try {
      setState(() => _isLoading = true);
      final prefsHelper = PreferencesHelper();
      empCode = (await prefsHelper.getEmpCode()) ?? 0;
      empName = await prefsHelper.getEmpName();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading projects: $e')),
      );
    }
  }

  Future<void> _fetchStatusCounts() async {
    try {
      setState(() => _isLoading = true);

      final currentEmpCode = empCode ?? widget.empcode;

      final uri = ApiUtils.getUri('GetTimesheetStatusCounts');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'EMPCODE': currentEmpCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          final counts = data['Counts'];
          setState(() {
            submittedCount = counts['SubmittedCount'] ?? 0;
            recheckCount = counts['RecheckCount'] ?? 0;
            reassignCount = counts['ReassignCount'] ?? 0;
            approvedCount =
                counts['ApprovedCount'] ?? 0; // ✅ ADD THIS: Get approved count
            isTeamLead = data['IsTeamLead'] ?? false;
            isSuperAdmin = data['IsSuperAdmin'] ?? false;
          });

          // If user is team lead or super admin, fetch team member count
          if (isTeamLead || isSuperAdmin) {
            await _fetchTeamMemberCount(currentEmpCode);
          }
        } else {
          debugPrint('API Error: ${data['Message']}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load counts: ${data['Message']}'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching status counts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchTeamMemberCount(int empCode) async {
    try {
      final uri = ApiUtils.getUri('EmployeeListByTeamLead');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'HRIACCNO': isSuperAdmin ? "0" : empCode.toString()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true && data['EmployeeList'] is List) {
          setState(() {
            teamMemberCount = data['EmployeeList'].length;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching team member count: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedNavIndex = index;
    });

    if (_canAccessReports) {
      // ✅ User has access to Masters and Reports (4 items)
      switch (index) {
        case 0:
          _showMastersMenu(context);
          Future.delayed(const Duration(milliseconds: 300), () {
            _fetchStatusCounts();
          });
          break;

        case 1:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTimesheetScreen()),
          ).then((_) => _fetchStatusCounts());
          break;
        case 2:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ViewTimesheetScreen()),
          ).then((_) => _fetchStatusCounts());
          break;
        case 3:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TSReportScreen()),
          ).then((_) => _fetchStatusCounts());
          break;
        case 4:
          if (_hasSalesAccess)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SalesMenuScreen()),
            ).then((_) => _fetchStatusCounts());
          break;
      }
    } else {
      // ✅ User has access to only 2 items (Time Sheet, View Time Sheets)
      switch (index) {
        case 0:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTimesheetScreen()),
          ).then((_) => _fetchStatusCounts());
          break;
        case 1:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ViewTimesheetScreen()),
          ).then((_) => _fetchStatusCounts());
          break;
      }
    }
  }

  void _showMastersMenu(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final dialogWidth = size.width < 500 ? size.width * 0.9 : 400.0;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              width: dialogWidth,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔹 Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Masters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),

                  // 🔸 Menu Items
                  _buildMenuItem(
                    context,
                    title: 'TL Master',
                    icon: Icons.supervisor_account,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (isTeamLead) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TlMasterScreen(
                              empCode: widget.empcode,
                              isTeamLead: true,
                              isSuperAdmin: false,
                            ),
                          ),
                        );
                      } else if (isSuperAdmin) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TlMasterScreen(
                              empCode: widget.empcode,
                              isTeamLead: false,
                              isSuperAdmin: true,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildMenuItem(
                    context,
                    title: 'Work / Element ID Reassign Master',
                    icon: Icons.repeat_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WorkElementReassignScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24),

                  // 🔹 Close Button
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 🔹 Reusable Menu Tile Widget
  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.white24,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Gradient Icon Circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: gradient,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildAnimatedNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedNavIndex == index;
    Color selectedColor = AppColors.primaryDark;

    return BottomNavigationBarItem(
      icon: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing background
          if (isSelected)
            AnimatedContainer(
              duration: const Duration(milliseconds: 2000),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    selectedColor.withOpacity(0.3),
                    selectedColor.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

          // Main icon container
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        selectedColor,
                        selectedColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? selectedColor.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: AnimatedRotation(
              turns: isSelected ? 0.05 : 0.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              child: AnimatedScale(
                scale: isSelected ? 1.4 : 1.0,
                duration: const Duration(milliseconds: 400),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  size: isSelected ? 22 : 18,
                ),
              ),
            ),
          ),
        ],
      ),
      label: label,
    );
  }

  void _navigateToSubmittedTimesheets() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewTimesheetScreen(
          initialStatusFilter: 'SUBMITTED',
        ),
      ),
    ).then((_) {
      _fetchStatusCounts();
    });
  }

  void _navigateToApprovedTimesheets() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewTimesheetScreen(
          initialStatusFilter: 'APPROVED',
        ),
      ),
    ).then((_) {
      _fetchStatusCounts();
    });
  }

  void _navigateToRecheckTimesheets() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewTimesheetScreen(
          initialStatusFilter: 'RECHECK',
        ),
      ),
    ).then((_) {
      _fetchStatusCounts();
    });
  }

  void _navigateToReassignedTimesheets() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewTimesheetScreen(
          initialStatusFilter: 'REASSIGNED',
        ),
      ),
    ).then((_) {
      _fetchStatusCounts();
    });
  }

  // ✅ FIXED: Also update the bottom navigation bar to use the correct indices

  Widget _buildDashboard(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return RefreshIndicator(
      onRefresh: _fetchStatusCounts,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            if (isSuperAdmin || isTeamLead)
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.pie_chart, color: Colors.white),
                  label: const Text(
                    'View Summary',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showPieChartDialog(context),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: isMobile
                  // MOBILE: 2 cards per row, stats stacked below
                  ? Column(
                      children: [
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.1,
                          children: [
                            if (_canAccessReports)
                              _buildMenuCard(
                                label: 'TL Master',
                                icon: Icons.dashboard,
                                onTap: () => _handleCardTap(0),
                                isSelected: _selectedCardIndex == 0,
                              ),
                            if (_canAccessReports)
                              _buildMenuCard(
                                label: 'Reassign & Issue Release',
                                icon: Icons.swap_horiz,
                                onTap: () => _handleCardTap(1),
                                isSelected: _selectedCardIndex == 1,
                              ),
                            if (!_hasSalesAccess || _canAccessReports)
                              _buildMenuCard(
                                label: 'Time Sheet',
                                icon: Icons.access_time,
                                onTap: () =>
                                    _handleCardTap(_canAccessReports ? 2 : 0),
                                isSelected: _selectedCardIndex ==
                                    (_canAccessReports ? 2 : 0),
                              ),
                            if (!_hasSalesAccess || _canAccessReports)
                              _buildMenuCard(
                                label: 'View Time Sheets',
                                icon: Icons.list,
                                onTap: () =>
                                    _handleCardTap(_canAccessReports ? 3 : 1),
                                isSelected: _selectedCardIndex ==
                                    (_canAccessReports ? 3 : 1),
                              ),
                            if (_canAccessReports || _canAccessReports)
                              _buildMenuCard(
                                label: 'Reports',
                                icon: Icons.bar_chart,
                                onTap: () => _handleCardTap(4),
                                isSelected: _selectedCardIndex == 4,
                              ),
                            if (_canAccessReports || _canAccessReports)
                              _buildMenuCard(
                                label: 'Summary Reports',
                                icon: Icons.analytics,
                                onTap: () => _handleCardTap(5),
                                isSelected: _selectedCardIndex == 5,
                              ),
                            if (_hasSalesAccess)
                              _buildMenuCard(
                                label: 'Sales',
                                icon: Icons.sell,
                                onTap: () =>
                                    _handleCardTap(_canAccessReports ? 6 : 0),
                                isSelected: _selectedCardIndex ==
                                    (_canAccessReports ? 6 : 0),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (!_hasSalesAccess || _canAccessReports)
                          _buildStatTileMobile(
                            title: _getStatusTitle('Submitted'),
                            count: submittedCount,
                            color: Colors.orange.shade700,
                            isBlinking: submittedCount > 0,
                            icon: Icons.pending_actions,
                            onTap: _navigateToSubmittedTimesheets, // Add this
                          ),
                        const SizedBox(height: 12),
                        if (!_hasSalesAccess || _canAccessReports)
                          _buildStatTileMobile(
                            title: _getStatusTitle('Recheck'),
                            count: recheckCount,
                            color: Colors.blue.shade700,
                            isBlinking: recheckCount > 0,
                            icon: Icons.refresh_rounded,
                            onTap: _navigateToRecheckTimesheets, // Add this
                          ),
                        const SizedBox(height: 12),
                        if (!_hasSalesAccess || _canAccessReports)
                          _buildStatTileMobile(
                            title: _getStatusTitle('Reassigned'),
                            count: reassignCount,
                            color: Colors.purple.shade700,
                            isBlinking: reassignCount > 0,
                            icon: Icons.assignment_return_rounded,
                            onTap: _navigateToReassignedTimesheets, // Add this
                          ),
                      ],
                    )

                  // DESKTOP/WEB: menu cards on left, stats column next to them
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Menu Cards Grid
                        Expanded(
                          flex: 3,
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 4,
                            crossAxisSpacing: 40,
                            mainAxisSpacing: 40,
                            childAspectRatio: 1,
                            children: [
                              if (_canAccessReports)
                                _buildMenuCard(
                                  label: 'TL Master',
                                  icon: Icons.dashboard,
                                  onTap: () => _handleCardTap(0),
                                  isSelected: _selectedCardIndex == 0,
                                ),
                              if (_canAccessReports)
                                _buildMenuCard(
                                  label: 'Reassign & Issue Release',
                                  icon: Icons.swap_horiz,
                                  onTap: () => _handleCardTap(1),
                                  isSelected: _selectedCardIndex == 1,
                                ),
                              // ✅ Show Time Sheet only when hasSalesAccess is false
                              if (!_hasSalesAccess || _canAccessReports)
                                _buildMenuCard(
                                  label: 'Time Sheet',
                                  icon: Icons.access_time,
                                  onTap: () =>
                                      _handleCardTap(_canAccessReports ? 2 : 0),
                                  isSelected: _selectedCardIndex ==
                                      (_canAccessReports ? 2 : 0),
                                ),
                              // ✅ Show View Time Sheets only when hasSalesAccess is false
                              if (!_hasSalesAccess || _canAccessReports)
                                _buildMenuCard(
                                  label: 'View Time Sheets',
                                  icon: Icons.list,
                                  onTap: () =>
                                      _handleCardTap(_canAccessReports ? 3 : 1),
                                  isSelected: _selectedCardIndex ==
                                      (_canAccessReports ? 3 : 1),
                                ),
                              if (_canAccessReports || !_hasSalesAccess)
                                _buildMenuCard(
                                  label: 'Reports',
                                  icon: Icons.bar_chart,
                                  onTap: () => _handleCardTap(4),
                                  isSelected: _selectedCardIndex == 4,
                                ),
                              if (_canAccessReports || !_hasSalesAccess)
                                _buildMenuCard(
                                  label: 'Summary Reports',
                                  icon: Icons.analytics,
                                  onTap: () => _handleCardTap(5),
                                  isSelected: _selectedCardIndex == 5,
                                ),
                              // ✅ Show Sales only when hasSalesAccess is true
                              if (_hasSalesAccess)
                                _buildMenuCard(
                                  label: 'Sales',
                                  icon: Icons.sell,
                                  onTap: () =>
                                      _handleCardTap(_canAccessReports ? 6 : 0),
                                  isSelected: _selectedCardIndex ==
                                      (_canAccessReports ? 6 : 0),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                        // Stats Column
                        Expanded(
                          child: Column(
                            children: [
                              if (!_hasSalesAccess || _canAccessReports)
                                _buildStatTile(
                                  title: _getStatusTitle('Submitted'),
                                  count: submittedCount,
                                  color: Colors.orange.shade700,
                                  isBlinking: submittedCount > 0,
                                  icon: Icons.pending_actions,
                                  onTap: _navigateToSubmittedTimesheets,
                                ),
                              const SizedBox(height: 16),
                              if (!_hasSalesAccess || _canAccessReports)
                                _buildStatTile(
                                  title: _getStatusTitle('Recheck'),
                                  count: recheckCount,
                                  color: Colors.blue.shade700,
                                  isBlinking: recheckCount > 0,
                                  icon: Icons.refresh_rounded,
                                  onTap: _navigateToRecheckTimesheets,
                                ),
                              const SizedBox(height: 16),
                              if (!_hasSalesAccess || _canAccessReports)
                                _buildStatTile(
                                  title: _getStatusTitle('Reassigned'),
                                  count: reassignCount,
                                  color: Colors.purple.shade700,
                                  isBlinking: reassignCount > 0,
                                  icon: Icons.assignment_return_rounded,
                                  onTap: _navigateToReassignedTimesheets,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTileMobile({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    bool isBlinking = false,
    required VoidCallback onTap, // Add this parameter
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(width: 12),
            HeartbeatAnimation(
              isAnimating: isBlinking,
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            // Add a chevron icon to indicate it's clickable
            Icon(Icons.chevron_right, color: color.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }

  // ✅ FIXED: Handle card tap with conditional indices
  void handleCardTap(int index) {
    setState(() {
      _selectedCardIndex = index;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_hasSalesAccess) {
        // Only Sales card is shown
        switch (index) {
          case 0:
            _navigateToSalesscreen();
            break;
          default:
            break;
        }
      } else {
        // Normal flow without sales access
        if (_canAccessReports) {
          switch (index) {
            case 0:
              _navigateToTLMasters();
              break;
            case 1:
              _navigateToMasters();
              break;
            case 2:
              _navigateToTimeSheet();
              break;
            case 3:
              _navigateToViewList();
              break;
            case 4:
              _navigateToReports();
              break;
            case 5:
              _navigateToReports(isSummary: true);
              break;
            default:
              break;
          }
        } else {
          switch (index) {
            case 0:
              _navigateToTimeSheet();
              break;
            case 1:
              _navigateToViewList();
              break;
            default:
              break;
          }
        }
      }

      // Reset selection after navigation
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _selectedCardIndex = -1;
          });
        }
      });
    });
  }

  void _handleCardTap(int clickedIndex) {
    setState(() {
      _selectedCardIndex = clickedIndex;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      // Build the list of visible cards in order
      List<String> visibleCardActions = [];

      if (_canAccessReports) {
        visibleCardActions.add('tl_master');
        visibleCardActions.add('reassign');
      }

      if (!_hasSalesAccess || _canAccessReports) {
        visibleCardActions.add('timesheet');
        visibleCardActions.add('view_timesheets');
      }

      if (_canAccessReports || !_hasSalesAccess) {
        visibleCardActions.add('reports');
        visibleCardActions.add('summary_reports');
      }

      if (_hasSalesAccess) {
        visibleCardActions.add('sales');
      }

      // Get the action for the clicked index
      if (clickedIndex >= 0 && clickedIndex < visibleCardActions.length) {
        String action = visibleCardActions[clickedIndex];

        switch (action) {
          case 'tl_master':
            _navigateToTLMasters();
            break;
          case 'reassign':
            _navigateToMasters();
            break;
          case 'timesheet':
            _navigateToTimeSheet();
            break;
          case 'view_timesheets':
            _navigateToViewList();
            break;
          case 'reports':
            _navigateToReports(isSummary: false);
            break;
          case 'summary_reports':
            _navigateToReports(isSummary: true);
            break;
          case 'sales':
            _navigateToSalesscreen();
            break;
        }
      }

      // Reset selection
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _selectedCardIndex = -1;
          });
        }
      });
    });
  }

  void _navigateToMasters() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkElementReassignScreen(),
      ),
    ).then((_) {
      // This runs when returning from Masters screen
      _fetchStatusCounts();
    });
  }

  void _navigateToTLMasters() {
    if (isTeamLead || isSuperAdmin) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TlMasterScreen(
            empCode: widget.empcode,
            isTeamLead: isTeamLead,
            isSuperAdmin: isSuperAdmin,
          ),
        ),
      ).then((_) {
        // Refresh data when returning from TL Master screen
        _fetchStatusCounts();
      });
    } else {
      // Show message for regular employees
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Access denied: TL Master is only available for Team Leads and Super Admins'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _navigateToReports({bool isSummary = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TSReportScreen(
          initialStatus: isSummary ? "SUMMARY" : null, // ✅ flag
        ),
      ),
    ).then((_) {
      _fetchStatusCounts();
    });
  }

  void _navigateToTimeSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTimesheetScreen(),
      ),
    ).then((_) {
      // This runs when returning from Timesheet screen
      _fetchStatusCounts();
    });
  }

  void _navigateToViewList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewTimesheetScreen(),
      ),
    ).then((_) {
      // This runs when returning from View List screen
      _fetchStatusCounts();
    });
  }

  void _navigateToSalesscreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SalesMenuScreen(),
      ),
    ).then((_) {
      // This runs when returning from View List screen
      _fetchStatusCounts();
    });
  }

  // Update the header to show super admin status
  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final firstLetter =
        (widget.employeeName.isNotEmpty ? widget.employeeName[0] : 'U')
            .toUpperCase();

    // Determine greeting based on current hour
    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      greeting = "Good Afternoon";
    } else if (hour >= 17 && hour < 21) {
      greeting = "Good Evening";
    } else {
      greeting = "Good Night";
    }

    // User role badge
    String userRole = "Employee";
    Color roleColor = Colors.white;
    IconData roleIcon = Icons.person;

    if (isSuperAdmin) {
      userRole = "Super Admin";
      roleColor = Colors.white;
      roleIcon = Icons.admin_panel_settings;
    } else if (isTeamLead) {
      userRole = "Team Lead";
      roleColor = Colors.white;
      roleIcon = Icons.groups;
    }

    return Container(
      height: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Text(
              firstLetter,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Greeting + Employee Name
                Text(
                  "$greeting,",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.employeeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Employee Code: ${widget.empcode}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                // User Role Badge
                GestureDetector(
                  onTap: () {
                    if (isTeamLead || isSuperAdmin) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TlMasterScreen(
                            empCode: widget.empcode,
                            isTeamLead: isTeamLead,
                            isSuperAdmin: isSuperAdmin,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: roleColor),
                      ),
                      child: /*Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(roleIcon, color: roleColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          userRole,
                          style: TextStyle(
                            color: roleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if ((isTeamLead || isSuperAdmin) &&
                            teamMemberCount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• $teamMemberCount members',
                            style: TextStyle(
                              color: roleColor.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),*/
                          Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(roleIcon, color: roleColor, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            userRole,
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if ((isTeamLead || isSuperAdmin) &&
                              teamMemberCount > 0) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '• $teamMemberCount members',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  color: roleColor.withOpacity(0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      )),
                ),
                // ✅ ADD THIS: Approved Count in Header - ONLY for allowed users
              ],
            ),
          ),
          // Icons for Change Password and Logout
          isMobile
              ? Column(
                  children: [
                    if (_canAccessReports && approvedCount > 0) ...[
                      GestureDetector(
                        onTap: _navigateToApprovedTimesheets,
                        child: Tooltip(
                          message: 'Click to view Approved Time Sheets',
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          waitDuration: const Duration(milliseconds: 400),
                          showDuration: const Duration(seconds: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ApprovedCelebration(
                                approvedCount: approvedCount,
                                onTap: _navigateToApprovedTimesheets,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildHeaderIcon(
                      icon: Icons.lock_outline,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ChangePassword(empCodee: empCode!),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildHeaderIcon(
                      icon: Icons.logout,
                      onTap: _showLogoutConfirmation,
                    ),
                  ],
                )
              : Row(
                  children: [
                    // ✅ ADD THIS: Approved Count for Web/Windows - ONLY for allowed users

                    Column(children: [
                      if (_canAccessReports && approvedCount > 0) ...[
                        GestureDetector(
                          onTap: _navigateToApprovedTimesheets,
                          child: Tooltip(
                            message: 'Click to view Approved Time Sheets',
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            waitDuration: const Duration(milliseconds: 400),
                            showDuration: const Duration(seconds: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ApprovedCelebration(
                                  approvedCount: approvedCount,
                                  onTap: _navigateToApprovedTimesheets,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const SizedBox(height: 12),
                      _buildHeaderIcon(
                        icon: Icons.lock_outline,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ChangePassword(empCodee: empCode!),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildHeaderIcon(
                        icon: Icons.logout,
                        onTap: _showLogoutConfirmation,
                      ),
                    ])
                  ],
                ),
        ],
      ),
    );
  }

  String _getStatusTitle(String status) {
    if (isSuperAdmin) {
      return 'Total $status';
    } else if (isTeamLead) {
      return 'Team $status';
    } else {
      return 'My $status';
    }
  }

  Widget _buildHeaderIcon(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppColors.primary,
          size: 28,
        ),
      ),
    );
  }

  // 🔹 Logout confirmation dialog
  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Perform logout logic here
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'RECHECK':
        return Colors.orange;
      case 'FORWARDED':
        return Colors.purple;
      case 'REASSIGNED':
        return Colors.teal;
      case 'SUBMITTED':
        return Colors.blueGrey;
      default:
        return Colors.white;
    }
  }

  Color _getDepartmentColor(String deptCode) {
    switch (deptCode) {
      case '1':
        return Colors.blueAccent; // Designing
      case '2':
        return Colors.orangeAccent; // Drafting
      default:
        return Colors.grey;
    }
  }

  String _getDepartmentName(String deptCode) {
    switch (deptCode) {
      case '1':
        return 'Designing';
      case '2':
        return 'Drafting';
      default:
        return 'Other';
    }
  }

  // Function to load employee hours data AND employee list
  Future<void> _loadEmployeeHoursData(int? siteCode, int? empCode) async {
    try {
      final uri = ApiUtils.getUri('GetSiteEmployeeHoursSummary');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'SITECODE': siteCode,
          'EMPCODE': empCode,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) {
          setState(() {
            siteTotalHours = (data['SiteTotalHours'] ?? 0.0).toDouble();
            employeeTotalHours = (data['EmployeeHours'] ?? 0.0).toDouble();
            selectedEmployeeName = data['EmployeeName']?.toString() ?? '';
            employeeList =
                List<Map<String, dynamic>>.from(data['SiteEmployees'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading employee hours: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchTimesheetSummary({
    String? siteCode,
  }) async {
    final apiUrl = ApiUtils.getUri('GetTimesheetSummary');

    final body = jsonEncode({
      'SiteCode': siteCode ?? '', // empty for "All Sites"
    });

    final response = await http.post(
      apiUrl,
      headers: {
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['Success'] == true) {
        return data;
      }
    }

    throw Exception('Failed to load summary');
  }

  void _showPieChartDialog(BuildContext context) async {
    try {
      // ✅ Load initial summary (All Sites)
      final summaryData = await _fetchTimesheetSummary();
      List<Map<String, dynamic>> statusSummary =
          List<Map<String, dynamic>>.from(summaryData['StatusSummary']);
      List<Map<String, dynamic>> deptSummary =
          List<Map<String, dynamic>>.from(summaryData['DepartmentSummary']);
      List<Map<String, dynamic>> siteSummary =
          List<Map<String, dynamic>>.from(summaryData['SiteSummary'] ?? []);

      // Define order for consistent bar chart sorting
      final statusOrder = [
        'SUBMITTED',
        'APPROVED',
        'REJECTED',
        'RECHECK',
        'FORWARDED',
        'REASSIGNED',
      ];

      // ✅ Step 1: Add "All Sites" option first
      List<Map<String, dynamic>> siteList = [
        {'SiteCode': '0', 'SiteName': 'All Sites'}
      ];

      // Add actual sites
      for (final s in siteSummary) {
        final code = s['SiteCode']?.toString() ?? '';
        String siteName = 'Unknown';

        try {
          final result = await fileService.loadSiteName(int.parse(code));
          if (result.isNotEmpty) {
            siteName = result.first['PROJECTNAME'] ?? 'Unknown';
          }
        } catch (_) {
          siteName = 'Unknown';
        }

        siteList.add({
          'SiteCode': code,
          'SiteName': siteName,
        });
      }

      // ✅ Initial working hours data
      double siteTotalHours = 0.0;
      double employeeTotalHours = 0.0;
      String selectedEmployeeName = '';
      List<Map<String, dynamic>> employeeList = [];

      showDialog(
        context: context,
        builder: (context) {
          String? selectedSite = 'All Sites';
          String? selectedEmployee = 'All Employees';
          List<Map<String, dynamic>> filteredStatusList =
              List.from(statusSummary);
          List<Map<String, dynamic>> filteredDeptList = List.from(deptSummary);

          return StatefulBuilder(
            builder: (context, setState) {
              double _originalSiteTotalHours = 0.0;
              double _originalEmployeeTotalHours = 0.0;
              final totalStatusCount = filteredStatusList.fold<double>(
                0,
                (sum, item) =>
                    sum + (double.tryParse(item['Count'].toString()) ?? 0),
              );
              // 🔥 REPLACE THESE CONVERSION FUNCTIONS WITH CORRECT ONES
              double _convertBackendDecimalToDisplayFormat(
                  double backendValue) {
                try {
                  debugPrint('🔄 Converting backend decimal: $backendValue');

                  // Backend sends decimal hours where .75 = 45 minutes, .5 = 30 minutes, .25 = 15 minutes
                  // Example: 2.75 = 2 hours 45 minutes
                  // We want to display as 3:15 (because 45 minutes = 0.75 hour)

                  // Convert to total minutes
                  final totalMinutes =
                      backendValue * 60; // 2.75 * 60 = 165 minutes
                  debugPrint('   Total minutes: $totalMinutes');

                  // Convert to display format where 100 minutes = 1 hour
                  // Formula: displayValue = totalMinutes * (100 / 60)
                  final displayValue =
                      totalMinutes * (100 / 60); // 165 * (100/60) = 275
                  debugPrint('   Display value: $displayValue');

                  return displayValue; // This will be 275 for 2.75
                } catch (e) {
                  debugPrint('Error converting to display format: $e');
                  return backendValue;
                }
              }

              /*String _formatHoursForDisplay(double displayValue) {
                try {
                  debugPrint('📱 Formatting display value: $displayValue');

                  // displayValue is in "100 minutes per hour" format
                  // Example: 275 means 2 hours 75 minutes = 3 hours 15 minutes

                  final totalDisplayMinutes = displayValue;

                  // Get hours and minutes (base 100)
                  var hours = totalDisplayMinutes ~/ 100; // 275 ~/ 100 = 2
                  var minutes =
                      (totalDisplayMinutes % 100).toInt(); // 275 % 100 = 75

                  debugPrint('   Raw hours: $hours, Raw minutes: $minutes');

                  // Handle overflow: if minutes >= 60, convert to hours
                  if (minutes >= 60) {
                    final extraHours = minutes ~/ 60; // 75 ~/ 60 = 1
                    hours += extraHours; // 2 + 1 = 3
                    minutes = minutes % 60; // 75 % 60 = 15
                  }

                  final result =
                      "$hours:${minutes.toString().padLeft(2, '0')} hrs";
                  debugPrint('   Result: $result');

                  return result;
                } catch (e) {
                  debugPrint('Error formatting hours: $e');
                  return "${displayValue.toStringAsFixed(2)} hrs";
                }
              }

              // Function to load employee hours data
              Future<void> _loadEmployeeHoursData(
                  int? siteCode, int? empCode) async {
                try {
                  final prefsHelper = PreferencesHelper();
                  final currentEmpCode = await prefsHelper.getEmpCode();

                  final uri = ApiUtils.getUri('GetSiteEmployeeHoursSummary');
                  final response = await http.post(
                    uri,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'SITECODE': siteCode,
                      'EMPCODE': empCode,
                    }),
                  );

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['Success'] == true) {
                      // Get raw values from API (decimal hours)
                      final rawSiteHours =
                          (data['SiteTotalHours'] ?? 0.0).toDouble();
                      final rawEmployeeHours =
                          (data['EmployeeHours'] ?? 0.0).toDouble();

                      // Convert to display format
                      final displaySiteHours =
                          _convertBackendDecimalToDisplayFormat(rawSiteHours);
                      final displayEmployeeHours =
                          _convertBackendDecimalToDisplayFormat(
                              rawEmployeeHours);

                      setState(() {
                        siteTotalHours =
                            displaySiteHours; // This is for display (e.g., 275)
                        employeeTotalHours =
                            displayEmployeeHours; // This is for display
                        _originalSiteTotalHours =
                            rawSiteHours; // Store original decimal (e.g., 2.75)
                        _originalEmployeeTotalHours =
                            rawEmployeeHours; // Store original decimal
                        selectedEmployeeName =
                            data['EmployeeName']?.toString() ?? '';

                        // Also convert hours in employee list
                        employeeList = List<Map<String, dynamic>>.from(
                            data['SiteEmployees'] ?? []);

                        for (var emp in employeeList) {
                          if (emp['EmployeeHours'] != null) {
                            final rawEmpHours = emp['EmployeeHours'].toDouble();
                            emp['EmployeeHoursOriginal'] = rawEmpHours;
                            // Store converted value for display
                            emp['EmployeeHours'] =
                                _convertBackendDecimalToDisplayFormat(
                                    rawEmpHours);
                          }
                        }
                      });

                      debugPrint('✅ Hours Data Converted:');
                      debugPrint(
                          '   Site: $rawSiteHours → $displaySiteHours → ${_formatHoursForDisplay(displaySiteHours)}');
                      debugPrint(
                          '   Employee: $rawEmployeeHours → $displayEmployeeHours → ${_formatHoursForDisplay(displayEmployeeHours)}');

                      // Test other values
                      // _testConversions();
                    }
                  }
                } catch (e) {
                  debugPrint('❌ Error loading employee hours: $e');
                }
              }*/
              // 🔥 SIMPLIFY THESE FUNCTIONS - Just format the decimal hours directly

              String _formatHoursFromDecimal(double decimalHours) {
                try {
                  debugPrint('📱 Formatting decimal hours: $decimalHours');

                  // Backend sends decimal hours where .25 = 15 minutes, .5 = 30 minutes, .75 = 45 minutes
                  // Example: 28.25 = 28 hours 15 minutes
                  // Example: 2.75 = 2 hours 45 minutes

                  final hours = decimalHours.floor(); // Get whole hours
                  final decimalPart =
                      decimalHours - hours; // Get the decimal part

                  // Convert decimal part to minutes (0.25 = 15 minutes, 0.5 = 30 minutes, 0.75 = 45 minutes)
                  var minutes = (decimalPart * 60).round(); // 0.25 * 60 = 15

                  // Ensure minutes are between 0-59
                  if (minutes >= 60) {
                    minutes = 0;
                  }

                  final result =
                      "$hours:${minutes.toString().padLeft(2, '0')} hrs";
                  debugPrint('   Result: $result');

                  return result;
                } catch (e) {
                  debugPrint('Error formatting hours: $e');
                  return "${decimalHours.toStringAsFixed(2)} hrs";
                }
              }

// Remove _convertBackendDecimalToDisplayFormat function entirely
// or keep it but make it just pass through the value:
              double convertBackendDecimalToDisplayFormat(double backendValue) {
                // Just return the original value - no conversion needed
                return backendValue;
              }

              Future<void> _loadEmployeeHoursData(
                  int? siteCode, int? empCode) async {
                try {
                  final prefsHelper = PreferencesHelper();
                  final currentEmpCode = await prefsHelper.getEmpCode();

                  final uri = ApiUtils.getUri('GetSiteEmployeeHoursSummary');
                  final response = await http.post(
                    uri,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'SITECODE': siteCode,
                      'EMPCODE': empCode,
                    }),
                  );

                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['Success'] == true) {
                      // Get raw decimal values from API (e.g., 28.25)
                      final rawSiteHours =
                          (data['SiteTotalHours'] ?? 0.0).toDouble();
                      final rawEmployeeHours =
                          (data['EmployeeHours'] ?? 0.0).toDouble();

                      setState(() {
                        // Store the raw decimal values
                        siteTotalHours = rawSiteHours;
                        employeeTotalHours = rawEmployeeHours;
                        _originalSiteTotalHours = rawSiteHours;
                        _originalEmployeeTotalHours = rawEmployeeHours;
                        selectedEmployeeName =
                            data['EmployeeName']?.toString() ?? '';

                        // Update employee list - store raw decimal values
                        employeeList = List<Map<String, dynamic>>.from(
                            data['SiteEmployees'] ?? []);

                        // Keep raw decimal values for percentage calculation
                        for (var emp in employeeList) {
                          if (emp['EmployeeHours'] != null) {
                            final rawEmpHours = emp['EmployeeHours'].toDouble();
                            emp['EmployeeHoursOriginal'] = rawEmpHours;
                            // Don't modify the EmployeeHours field here
                          }
                        }
                      });

                      debugPrint('✅ Hours Data Loaded:');
                      debugPrint('   Site Hours (decimal): $rawSiteHours');
                      debugPrint(
                          '   Employee Hours (decimal): $rawEmployeeHours');
                    }
                  }
                } catch (e) {
                  debugPrint('❌ Error loading employee hours: $e');
                }
              }

              // Initialize with All Sites data
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await _loadEmployeeHoursData(0, null);
              });

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: Colors.white,
                insetPadding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '📊 Timesheet Summary',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // 🔹 HEADER WITH FILTERS
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 🔹 SITE SELECTION
                                Card(
                                  elevation: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.business,
                                                color: Colors.blue, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Select Site:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 8),
                                        /*DropdownButtonFormField<String>(
                                          value: selectedSite,
                                          decoration: InputDecoration(
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                          ),
                                          items: siteList.map((site) {
                                            final code =
                                                site['SiteCode']?.toString() ??
                                                    '0';
                                            final name =
                                                site['SiteName']?.toString() ??
                                                    'Unknown';
                                            final display = code == '0'
                                                ? 'All Sites'
                                                : '$code - $name';
                                            return DropdownMenuItem(
                                              value: display,
                                              child: Text(display),
                                            );
                                          }).toList(),
                                          onChanged: (value) async {
                                            if (value == null) return;

                                            setState(() {
                                              selectedSite = value;
                                              selectedEmployee =
                                                  'All Employees';
                                              employeeTotalHours = 0.0;
                                              selectedEmployeeName = '';
                                              employeeList = [];
                                            });

                                            // Extract site code from display value
                                            int? siteCode;
                                            if (value == 'All Sites') {
                                              siteCode = 0;
                                            } else {
                                              final parts = value.split(' - ');
                                              if (parts.isNotEmpty) {
                                                siteCode =
                                                    int.tryParse(parts[0]);
                                              }
                                            }

                                            // Load site-specific timesheet summary
                                            final newSummary =
                                                await _fetchTimesheetSummary(
                                              siteCode: siteCode == 0
                                                  ? null
                                                  : siteCode?.toString(),
                                            );

                                            final newStatus =
                                                List<Map<String, dynamic>>.from(
                                                    newSummary[
                                                        'StatusSummary']);
                                            final newDept =
                                                List<Map<String, dynamic>>.from(
                                                    newSummary[
                                                        'DepartmentSummary']);

                                            newStatus.sort((a, b) {
                                              final i1 = statusOrder.indexOf(
                                                  a['Status']
                                                          ?.toString()
                                                          ?.toUpperCase() ??
                                                      '');
                                              final i2 = statusOrder.indexOf(
                                                  b['Status']
                                                          ?.toString()
                                                          ?.toUpperCase() ??
                                                      '');
                                              return i1.compareTo(i2);
                                            });

                                            setState(() {
                                              filteredStatusList = newStatus;
                                              filteredDeptList = newDept;
                                            });

                                            // Load hours data for the site
                                            await _loadEmployeeHoursData(
                                                siteCode, null);
                                          },
                                        ),*/
                                        // Replace your existing DropdownButtonFormField with this Autocomplete widget:

                                        Autocomplete<String>(
                                          optionsBuilder: (TextEditingValue
                                              textEditingValue) {
                                            // Always show all options when clicked (even with empty text)
                                            // This makes it work like a dropdown
                                            if (textEditingValue.text.isEmpty) {
                                              return siteList.map((site) {
                                                final code = site['SiteCode']
                                                        ?.toString() ??
                                                    '0';
                                                final name = site['SiteName']
                                                        ?.toString() ??
                                                    'Unknown';
                                                return code == '0'
                                                    ? 'All Sites'
                                                    : '$code - $name';
                                              });
                                            }

                                            // Filter sites based on search query when typing
                                            return siteList.where((site) {
                                              final code = site['SiteCode']
                                                      ?.toString() ??
                                                  '0';
                                              final name = site['SiteName']
                                                      ?.toString()
                                                      ?.toLowerCase() ??
                                                  'unknown';
                                              final query = textEditingValue
                                                  .text
                                                  .toLowerCase();

                                              return code.contains(query) ||
                                                  name.contains(query) ||
                                                  '$code - $name'
                                                      .toLowerCase()
                                                      .contains(query);
                                            }).map((site) {
                                              final code = site['SiteCode']
                                                      ?.toString() ??
                                                  '0';
                                              final name = site['SiteName']
                                                      ?.toString() ??
                                                  'Unknown';
                                              return code == '0'
                                                  ? 'All Sites'
                                                  : '$code - $name';
                                            });
                                          },
                                          displayStringForOption: (option) =>
                                              option,
                                          fieldViewBuilder: (context,
                                              textEditingController,
                                              focusNode,
                                              onFieldSubmitted) {
                                            // Initialize with selected value
                                            if (selectedSite != null &&
                                                textEditingController
                                                    .text.isEmpty) {
                                              textEditingController.text =
                                                  selectedSite!;
                                            }

                                            return TextFormField(
                                              controller: textEditingController,
                                              focusNode: focusNode,
                                              readOnly: false, // Allow typing
                                              onTap: () {
                                                // When clicked, show all options
                                                if (textEditingController
                                                    .text.isEmpty) {
                                                  // Trigger options builder to show all sites
                                                  textEditingController.clear();
                                                }
                                                // Focus is handled automatically by Autocomplete
                                              },
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                                hintText: selectedSite ??
                                                    'Select site...',
                                                suffixIcon: selectedSite != null
                                                    ? IconButton(
                                                        icon: Icon(Icons.clear,
                                                            size: 18),
                                                        onPressed: () {
                                                          textEditingController
                                                              .clear();
                                                          setState(() {
                                                            selectedSite = null;
                                                            selectedEmployee =
                                                                'All Employees';
                                                            employeeTotalHours =
                                                                0.0;
                                                            selectedEmployeeName =
                                                                '';
                                                            employeeList = [];
                                                          });
                                                        },
                                                      )
                                                    : Icon(
                                                        Icons.arrow_drop_down),
                                              ),
                                            );
                                          },
                                          onSelected: (String selection) async {
                                            if (selection == selectedSite)
                                              return;

                                            setState(() {
                                              selectedSite = selection;
                                              selectedEmployee =
                                                  'All Employees';
                                              employeeTotalHours = 0.0;
                                              selectedEmployeeName = '';
                                              employeeList = [];
                                            });

                                            // Extract site code from display value
                                            int? siteCode;
                                            if (selection == 'All Sites') {
                                              siteCode = 0;
                                            } else {
                                              final parts =
                                                  selection.split(' - ');
                                              if (parts.isNotEmpty) {
                                                siteCode =
                                                    int.tryParse(parts[0]);
                                              }
                                            }

                                            // Load site-specific timesheet summary
                                            final newSummary =
                                                await _fetchTimesheetSummary(
                                              siteCode: siteCode == 0
                                                  ? null
                                                  : siteCode?.toString(),
                                            );

                                            final newStatus =
                                                List<Map<String, dynamic>>.from(
                                                    newSummary[
                                                        'StatusSummary']);
                                            final newDept =
                                                List<Map<String, dynamic>>.from(
                                                    newSummary[
                                                        'DepartmentSummary']);

                                            newStatus.sort((a, b) {
                                              final i1 = statusOrder.indexOf(
                                                  a['Status']
                                                          ?.toString()
                                                          ?.toUpperCase() ??
                                                      '');
                                              final i2 = statusOrder.indexOf(
                                                  b['Status']
                                                          ?.toString()
                                                          ?.toUpperCase() ??
                                                      '');
                                              return i1.compareTo(i2);
                                            });

                                            setState(() {
                                              filteredStatusList = newStatus;
                                              filteredDeptList = newDept;
                                            });

                                            // Load hours data for the site
                                            await _loadEmployeeHoursData(
                                                siteCode, null);
                                          },
                                          optionsViewBuilder:
                                              (context, onSelected, options) {
                                            if (options.isEmpty) {
                                              return Material(
                                                elevation: 4,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      16.0),
                                                  child: Center(
                                                      child: Text(
                                                          'No sites found')),
                                                ),
                                              );
                                            }

                                            return Material(
                                              elevation: 4,
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                    maxHeight: 300),
                                                child: ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  itemCount: options.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final option = options
                                                        .elementAt(index);
                                                    final isAllSites =
                                                        option == 'All Sites';
                                                    final parts =
                                                        option.split(' - ');
                                                    final siteCode = isAllSites
                                                        ? 'All'
                                                        : (parts.isNotEmpty
                                                            ? parts[0]
                                                            : '');
                                                    final siteName = isAllSites
                                                        ? 'All Sites'
                                                        : (parts.length > 1
                                                            ? parts[1]
                                                            : '');

                                                    return ListTile(
                                                      leading: isAllSites
                                                          ? Icon(
                                                              Icons
                                                                  .all_inclusive,
                                                              color:
                                                                  Colors.blue)
                                                          : Icon(
                                                              Icons
                                                                  .construction,
                                                              color:
                                                                  Colors.green),
                                                      title: Text(option),
                                                      subtitle: isAllSites
                                                          ? Text(
                                                              'Show all sites')
                                                          : Text(
                                                              'Code: $siteCode'),
                                                      trailing: selectedSite ==
                                                              option
                                                          ? Icon(Icons.check,
                                                              color:
                                                                  Colors.green)
                                                          : null,
                                                      onTap: () =>
                                                          onSelected(option),
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // 🔹 EMPLOYEE DROPDOWN (Only show for specific sites)
                                if (selectedSite != 'All Sites')
                                  Card(
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.person,
                                                  color: Colors.green,
                                                  size: 20),
                                              SizedBox(width: 8),
                                              Text(
                                                'Select Employee:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blueGrey,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          /*DropdownButtonFormField<String>(
                                            value: selectedEmployee,
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                            ),
                                            items: [
                                              DropdownMenuItem(
                                                value: 'All Employees',
                                                child: Text('All Employees'),
                                              ),
                                              ...employeeList.map((emp) {
                                                final code =
                                                    emp['EMPCODE'] ?? 0;
                                                final name =
                                                    emp['EMPNAME'] ?? 'Unknown';
                                                final hours =
                                                    emp['EmployeeHoursOriginal'] ??
                                                        emp['EmployeeHours'] ??
                                                        0.0;

                                                // Format the decimal hours for display
                                                final formattedHours =
                                                    _formatHoursFromDecimal(
                                                        hours.toDouble());
                                                // Truncate long names for display
                                                final displayName = name
                                                            .length >
                                                        20
                                                    ? '${name.substring(0, 20)}...'
                                                    : name;

                                                return DropdownMenuItem(
                                                  value: '$code - $name',
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          '$code - $displayName',
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        '($formattedHours)', // Use the formatted string
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                            onChanged: (value) async {
                                              if (value == null) return;

                                              setState(() =>
                                                  selectedEmployee = value);

                                              // Extract site code from selected site
                                              int? siteCode;
                                              if (selectedSite == 'All Sites') {
                                                siteCode = 0;
                                              } else {
                                                final siteParts =
                                                    selectedSite?.split(' - ');
                                                if (siteParts != null &&
                                                    siteParts.isNotEmpty) {
                                                  siteCode = int.tryParse(
                                                      siteParts[0]);
                                                }
                                              }

                                              // Extract employee code
                                              int? empCode;
                                              if (value != 'All Employees') {
                                                final empParts =
                                                    value.split(' - ');
                                                if (empParts.isNotEmpty) {
                                                  empCode =
                                                      int.tryParse(empParts[0]);
                                                }
                                              }

                                              // Load employee hours
                                              await _loadEmployeeHoursData(
                                                  siteCode, empCode);
                                            },
                                          ),*/
                                          DropdownButtonFormField<String>(
                                            value: selectedEmployee,
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                            ),
                                            items: [
                                              DropdownMenuItem(
                                                value: 'All Employees',
                                                child: Text('All Employees'),
                                              ),
                                              ...employeeList.map((emp) {
                                                final code =
                                                    emp['EMPCODE'] ?? 0;
                                                final name =
                                                    emp['EMPNAME'] ?? 'Unknown';
                                                final hours =
                                                    emp['EmployeeHoursOriginal'] ??
                                                        emp['EmployeeHours'] ??
                                                        0.0;

                                                // Format the decimal hours for display
                                                final formattedHours =
                                                    _formatHoursFromDecimal(
                                                        hours.toDouble());

                                                return DropdownMenuItem(
                                                  value: '$code - $name',
                                                  child: Row(
                                                    children: [
                                                      Text('$code - $name'),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        '($formattedHours)', // Use the formatted string
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                            onChanged: (value) async {
                                              if (value == null) return;

                                              setState(() =>
                                                  selectedEmployee = value);

                                              // Extract site code from selected site
                                              int? siteCode;
                                              if (selectedSite == 'All Sites') {
                                                siteCode = 0;
                                              } else {
                                                final siteParts =
                                                    selectedSite?.split(' - ');
                                                if (siteParts != null &&
                                                    siteParts.isNotEmpty) {
                                                  siteCode = int.tryParse(
                                                      siteParts[0]);
                                                }
                                              }

                                              // Extract employee code
                                              int? empCode;
                                              if (value != 'All Employees') {
                                                final empParts =
                                                    value.split(' - ');
                                                if (empParts.isNotEmpty) {
                                                  empCode =
                                                      int.tryParse(empParts[0]);
                                                }
                                              }

                                              // Load employee hours
                                              await _loadEmployeeHoursData(
                                                  siteCode, empCode);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 10),

                                // 🔹 WORKING HOURS SUMMARY
                                const SizedBox(height: 10),

                                // 🔹 WORKING HOURS SUMMARY (Only show for specific sites)
                                if (selectedSite != 'All Sites')
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    child: const Text(
                                      'Working Hours Summary',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),

                                if (selectedSite != 'All Sites')
                                  const SizedBox(height: 10),

                                const SizedBox(height: 10),
                                if (selectedSite != 'All Sites')
                                  // 🔹 HOURS DISPLAY CARDS
                                  Row(
                                    children: [
                                      // Site Total Hours Card - ALWAYS VISIBLE
                                      Expanded(
                                        child: Card(
                                          elevation: 3,
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.business,
                                                        color: Colors.blue,
                                                        size: 16),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      selectedSite ==
                                                              'All Sites'
                                                          ? 'All Sites Total:'
                                                          : 'Site Total:',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                        color: Colors.blueGrey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 4),
                                                // Find this section in your code (around line where siteTotalHours is displayed):
                                                // Site Total Hours Card
                                                Text(
                                                  _formatHoursFromDecimal(
                                                      siteTotalHours), // Use the new formatting function
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green[700],
                                                  ),
                                                ),

                                                SizedBox(height: 2),
                                                Text(
                                                  selectedSite ?? 'All Sites',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[600],
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      SizedBox(width: 10),

                                      // Employee Hours Card (Only show for specific sites and when employee is selected)
                                      if (selectedSite != 'All Sites' &&
                                          selectedEmployee != 'All Employees' &&
                                          selectedEmployee != null)
                                        Expanded(
                                          child: Card(
                                            elevation: 3,
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.person,
                                                          color: Colors.green,
                                                          size: 16),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        'Employee:',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                          color:
                                                              Colors.blueGrey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 4),
                                                  // Find this section:
                                                  // Employee Hours Card
                                                  Text(
                                                    _formatHoursFromDecimal(
                                                        employeeTotalHours), // Use the new formatting function
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.orange[700],
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    selectedEmployeeName
                                                            .isNotEmpty
                                                        ? selectedEmployeeName
                                                        : selectedEmployee
                                                                ?.replaceFirst(
                                                                    ' - ',
                                                                    ': ') ??
                                                            '',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey[600],
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                // 🔹 Percentage Contribution (Only for specific sites and when employee is selected)
                                // Add these variables to track original values

// Update in _loadEmployeeHoursData:

// Update percentage calculation to use original values:
                                if (selectedSite != 'All Sites' &&
                                    selectedEmployee != 'All Employees' &&
                                    selectedEmployee != null &&
                                    _originalSiteTotalHours > 0)
                                  Card(
                                    margin: EdgeInsets.only(top: 10),
                                    elevation: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        children: [
                                          LinearProgressIndicator(
                                            value: _originalEmployeeTotalHours /
                                                _originalSiteTotalHours,
                                            backgroundColor: Colors.grey[200],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.orange),
                                            minHeight: 10,
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Contribution:',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                '${((_originalEmployeeTotalHours / _originalSiteTotalHours) * 100).toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.purple[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 10),

                                // 🔹 "By Status" Label
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  child: const Text(
                                    'By Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // 🔹 Bar Chart
                            SizedBox(
                              width: 500,
                              height: 360,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: filteredStatusList.length * 80,
                                  child: BarChart(
                                    BarChartData(
                                      backgroundColor: Colors.white,
                                      gridData: FlGridData(
                                        show: true,
                                        drawHorizontalLine: true,
                                        getDrawingHorizontalLine: (value) {
                                          if (value > 100)
                                            return FlLine(
                                                color: Colors.transparent);
                                          return FlLine(
                                            color: Colors.grey.shade300,
                                            strokeWidth: 1,
                                          );
                                        },
                                      ),
                                      borderData: FlBorderData(show: false),
                                      alignment: BarChartAlignment.center,
                                      maxY: 105,
                                      titlesData: FlTitlesData(
                                        topTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles:
                                              SideTitles(showTitles: false),
                                        ),
                                        leftTitles: AxisTitles(
                                          axisNameWidget: const Padding(
                                            padding: EdgeInsets.only(bottom: 1),
                                            child: Text(
                                              'Percentage %',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.normal,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 50,
                                            interval: 20,
                                            getTitlesWidget: (value, meta) {
                                              if (value > 100)
                                                return const SizedBox.shrink();
                                              return Text(
                                                '${value.toInt()}%',
                                                style: const TextStyle(
                                                    fontSize: 10),
                                              );
                                            },
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          axisNameWidget: const Padding(
                                            padding: EdgeInsets.only(top: 1),
                                            child: Text(
                                              'Status',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.normal,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 80,
                                            getTitlesWidget: (value, meta) {
                                              final index = value.toInt();
                                              if (index < 0 ||
                                                  index >=
                                                      filteredStatusList
                                                          .length) {
                                                return const SizedBox.shrink();
                                              }

                                              final status =
                                                  filteredStatusList[index]
                                                              ['Status']
                                                          ?.toString() ??
                                                      '';
                                              return SideTitleWidget(
                                                axisSide: meta.axisSide,
                                                space: 4,
                                                child: RotatedBox(
                                                  quarterTurns: 1,
                                                  child: Text(
                                                    status,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),

                                      // ✅ Only bars with value > 0
                                      barGroups: filteredStatusList
                                          .asMap()
                                          .entries
                                          .where((entry) {
                                        final count = double.tryParse(entry
                                                .value['Count']
                                                .toString()) ??
                                            0.0;
                                        return count > 0; // only non-empty bars
                                      }).map((entry) {
                                        final index = entry.key;
                                        final item = entry.value;
                                        final statusName = item['Status']
                                                ?.toString()
                                                ?.toUpperCase() ??
                                            '';
                                        final count = double.tryParse(
                                                item['Count'].toString()) ??
                                            0.0;
                                        final percent = totalStatusCount > 0
                                            ? ((count / totalStatusCount) * 100)
                                            : 0.0;

                                        return BarChartGroupData(
                                          x: index,
                                          barRods: [
                                            BarChartRodData(
                                              toY: percent,
                                              color:
                                                  _getStatusColor(statusName),
                                              width: 30,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ],
                                        );
                                      }).toList(),

                                      barTouchData: BarTouchData(
                                        enabled: true,
                                        handleBuiltInTouches: true,
                                        touchTooltipData: BarTouchTooltipData(
                                          tooltipBgColor: Colors.white,
                                          tooltipRoundedRadius: 8,
                                          tooltipMargin: 10,
                                          getTooltipItem: (group, groupIndex,
                                              rod, rodIndex) {
                                            final item = filteredStatusList[
                                                group.x.toInt()];
                                            final status =
                                                item['Status']?.toString() ??
                                                    '';
                                            final count = double.tryParse(
                                                    item['Count'].toString()) ??
                                                0.0;
                                            final percent = rod.toY;
                                            final color =
                                                _getStatusColor(status);
                                            return BarTooltipItem(
                                              'Status: $status\nCount: ${count.toInt()}\nPercent: ${percent.toStringAsFixed(1)}%',
                                              TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 10),

                            // 🔹 Department Summary (Pie Chart)
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(3.0),
                                child: Text(
                                  'By Department',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),
                            SizedBox(
                              height: 220,
                              child: PieChart(
                                PieChartData(
                                  sections: filteredDeptList.map((item) {
                                    final deptCode =
                                        (item['DeptCode'] ?? '0').toString();
                                    final count =
                                        (item['Count'] ?? 0).toDouble();
                                    final deptName =
                                        _getDepartmentName(deptCode);
                                    return PieChartSectionData(
                                      color: _getDepartmentColor(deptCode),
                                      value: count,
                                      title: '$deptName\n${count.toInt()}',
                                      radius: 60,
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // 🔹 Close button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.redAccent),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading summary: $e')),
      );
      debugPrint('Error loading summary: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
    bool isBlinking = false,
    required VoidCallback onTap, // Add this parameter
  }) {
    return Tooltip(
      message: 'Click to View',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 500),
            width: 160,
            height: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [color.withOpacity(0.6), color.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isBlinking ? 0.6 : 0.4),
                  blurRadius: isBlinking ? 25 : 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(-6, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HeartbeatAnimation(
                  isAnimating: isBlinking,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Icon(icon, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Adjust size for desktop/web
    final iconSize = isMobile ? 32.0 : 45.0;
    final padding = isMobile ? 10.0 : 30.0; // inner padding
    final fontSize = isMobile ? 14.0 : 16.0;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      margin: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 12, vertical: isMobile ? 4 : 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withOpacity(0.3)
            : AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.9)
                      : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : AppColors.primaryLight,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppColors.primaryDark : AppColors.primary,
                  size: iconSize,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primaryDark,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSalesAccess() async {
    _hasSalesAccess = await PreferencesHelper().hasSalesAccess();
    setState(() {});
  }
}

// Reusable Heartbeat Animation Widget
class HeartbeatAnimation extends StatefulWidget {
  final Widget child;
  final bool isAnimating;

  const HeartbeatAnimation({
    Key? key,
    required this.child,
    required this.isAnimating,
  }) : super(key: key);

  @override
  _HeartbeatAnimationState createState() => _HeartbeatAnimationState();
}

class _HeartbeatAnimationState extends State<HeartbeatAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.1), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 0.9), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 0.9, end: 1.0), weight: 1),
    ]).animate(_controller);

    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(HeartbeatAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isAnimating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}
