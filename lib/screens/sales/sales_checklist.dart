import 'package:flutter/material.dart';
import 'package:tsm/screens/sales/view_checklist_screen.dart';

import '../../widgets/common_menu_screen.dart';
import 'entry_checklist_screen.dart';

class SalesChecklist extends StatefulWidget {
  const SalesChecklist({super.key});

  @override
  State<SalesChecklist> createState() => _SalesChecklistState();
}

class _SalesChecklistState extends State<SalesChecklist> {
  final List<Map<String, dynamic>> menuItems = [
    {
      'title': 'Checklist',
      'icon': Icons.checklist,
    },
    {
      'title': 'View Check List',
      'icon': Icons.list_alt_rounded,
    },
  ];
  @override
  Widget build(BuildContext context) {
    return CommonMenuScreen(
      title: 'Sales Check List',
      menuItems: menuItems,
      onItemTap: _onItemTap,
    );
  }

  void _onItemTap(BuildContext context, Map<String, dynamic> item) {
    switch (item['title'] as String) {
      case 'Checklist':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EntryChecklistScreen()),
        );
        break;

      case 'View Check List':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ViewChecklistScreen()),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No screen available for ${item['title']}")),
        );
    }
  }
}
