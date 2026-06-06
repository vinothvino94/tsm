import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../../api/api_utils.dart';
import '../../colors/app_colors.dart';

class TimesheetSummaryScreen extends StatefulWidget {
  const TimesheetSummaryScreen({super.key});

  @override
  State<TimesheetSummaryScreen> createState() => _TimesheetSummaryScreenState();
}

class _TimesheetSummaryScreenState extends State<TimesheetSummaryScreen> {
  List<dynamic> statusSummary = [];
  List<dynamic> deptSummary = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() => isLoading = true);
    try {
      final uri = ApiUtils.getUri("Upload/GetTimesheetSummary");
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["Success"] == true) {
          setState(() {
            statusSummary = data["StatusSummary"];
            deptSummary = data["DepartmentSummary"];
          });
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<PieChartSectionData> _buildPieData(List<dynamic> data, bool isStatus) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.cyan,
    ];

    return List.generate(data.length, (index) {
      final item = data[index];
      final title = isStatus
          ? item["Status"]?.toString() ?? "-"
          : "Dept ${item["DeptCode"]}";
      final count = item["Count"] ?? 0;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: count.toDouble(),
        title: "$title\n($count)",
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Timesheet Summary"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    "Status-wise Timesheet Count",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 1.3,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieData(statusSummary, true),
                        centerSpaceRadius: 30,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const Divider(height: 40),
                  const Text(
                    "Department-wise Timesheet Count",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  AspectRatio(
                    aspectRatio: 1.3,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieData(deptSummary, false),
                        centerSpaceRadius: 30,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
