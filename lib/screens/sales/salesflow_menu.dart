import 'package:flutter/material.dart';

import '../../widgets/common_menu_screen.dart';
import 'billing_entry_screen.dart';
import 'overallsummaryscreen.dart';
import 'stage_update_screen.dart';

class Billingmenu extends StatefulWidget {
  const Billingmenu({super.key});

  @override
  State<Billingmenu> createState() => _BillingmenuState();
}

class _BillingmenuState extends State<Billingmenu> {
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
          MaterialPageRoute(
            builder: (_) => BillingEntryScreen(),
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
