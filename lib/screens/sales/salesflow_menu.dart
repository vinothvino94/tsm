import 'package:flutter/material.dart';
import 'package:tsm/screens/sales/projectcontrol_entry_screen.dart';

import '../../widgets/common_menu_screen.dart';
import 'billing_entry_screen.dart';
import 'data_entry_screen.dart';
import 'design_entry_screen.dart';
import 'overallsummaryscreen.dart';
import 'stage_update_screen.dart';

class SalesflowMenu extends StatefulWidget {
  final bool isSuperAdmin;
  const SalesflowMenu({
    super.key,
    this.isSuperAdmin = false,
  });

  @override
  State<SalesflowMenu> createState() => _SalesflowMenuState();
}

class _SalesflowMenuState extends State<SalesflowMenu> {
  final List<Map<String, dynamic>> menuItems = [
    {
      'title': 'Stage Update',
      'icon': Icons.timeline,
    },
    {
      'title': 'Billing',
      'icon': Icons.receipt_long,
    },
    {
      'title': 'Design',
      'icon': Icons.design_services,
    },
    {
      'title': 'Project Control',
      'icon': Icons.settings_suggest,
    },
    {
      'title': 'Over All Summary',
      'icon': Icons.dashboard,
    },
  ];
  @override
  Widget build(BuildContext context) {
    return CommonMenuScreen(
      title: 'Sales Flow',
      menuItems: menuItems,
      onItemTap: _onItemTap,
    );
  }

  void _onItemTap(BuildContext context, Map<String, dynamic> item) {
    switch (item['title'] as String) {
      case 'Stage Update':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StageUpdateScreen(),
          ),
        );
        break;

      case 'Billing':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DataEntryScreen()
              //BillingEntryScreen(isSuperAdmin: widget.isSuperAdmin),
              ),
        );
        break;

      case 'Design':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DesignEntryScreen(isSuperAdmin: widget.isSuperAdmin),
          ),
        );
        break;

      case 'Project Control':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProjectcontrolEntryScreen(isSuperAdmin: widget.isSuperAdmin),
          ),
        );
        break;
      case 'Over All Summary':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OverAllSummaryScreen(),
          ),
        );
        break;

      default:
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Working in Progress'),
            content: Text(
              '${item['title']} module is currently under development.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
    }
  }
}
