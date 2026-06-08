import 'package:flutter/material.dart';
import 'package:tsm/screens/sales/sales_checklist.dart';

import '../../widgets/common_menu_screen.dart';
import 'salesflow_menu.dart';

class SalesMenuScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const SalesMenuScreen({
    super.key,
    this.isSuperAdmin = false,
  });

  @override
  State<SalesMenuScreen> createState() => _SalesMenuScreenState();
}

class _SalesMenuScreenState extends State<SalesMenuScreen> {
  final List<Map<String, dynamic>> menuItems = [
    {
      'title': 'SalesChecklist',
      'icon': Icons.checklist,
    },
    {
      'title': 'Sales Flow',
      'icon': Icons.trending_up,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return CommonMenuScreen(
      title: 'Sales',
      menuItems: menuItems,
      onItemTap: _onItemTap,
    );
  }

  void _onItemTap(BuildContext context, Map<String, dynamic> item) {
    switch (item['title'] as String) {
      case 'SalesChecklist':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SalesChecklist()),
        );
        break;

      case 'Sales Flow':
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SalesflowMenu(
                    isSuperAdmin: widget.isSuperAdmin,
                  )),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No screen available for ${item['title']}")),
        );
    }
  }
}
