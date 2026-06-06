import 'package:flutter/material.dart';

import '../../colors/app_colors.dart';

class DepartmentMasterScreen extends StatelessWidget {
  const DepartmentMasterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Department Master'),
        backgroundColor: AppColors.primary,
      ),
      body: const Center(
        child: Text('Department Master Details Page'),
      ),
    );
  }
}
