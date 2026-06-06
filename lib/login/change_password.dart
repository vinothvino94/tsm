import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../services/file_service.dart';

import '../colors/app_colors.dart';
import '../services/prefrence_helper.dart';
import 'login_model.dart';
import 'login_screen.dart';

class ChangePassword extends StatefulWidget {
  final int empCodee;

  ChangePassword({required this.empCodee});

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePassword> {
  final TextEditingController _empCodeController = TextEditingController();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _rePasswordController = TextEditingController();

  bool _isLoading = false;
  final FileService _fileService = FileService();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  late int empCode;
  String? empPass;
  String? empName;
  File? _image;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final prefsHelper = PreferencesHelper();
    empCode = (await prefsHelper.getEmpCode())!;
    empPass = await prefsHelper.getEmpPass();
    empName = await prefsHelper.getEmpName();

    setState(() {
      _empCodeController.text = empCode.toString();
    });
  }

  InputDecoration _buildInputDecoration(String label, IconData icon,
      {bool isPasswordField = false,
      VoidCallback? toggleVisibility,
      bool obscureText = false}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outline),
      ),
      suffixIcon: isPasswordField
          ? IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: AppColors.primary,
              ),
              onPressed: toggleVisibility,
            )
          : null,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    );
  }

  void _changePassword() async {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final rePassword = _rePasswordController.text;

    if (oldPassword.isEmpty || newPassword.isEmpty || rePassword.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    if (newPassword != rePassword) {
      _showError("New Password and Confirm Password don't match.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final loginModel = LoginModel(
      empCode: _empCodeController.text,
      oldEmpPass: oldPassword,
      empPass: newPassword,
    );

    try {
      final result = await _fileService.changePassword(loginModel);

      if (result == '1') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => LoginScreen()));
        _showMessage('Password changed successfully.');
      } else {
        _showError('Invalid password.');
      }
    } catch (e) {
      _showError('Failed to change password. Please try again later.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
    ));
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Change Password',
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
      body: SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12),
                TextField(
                  controller: _empCodeController,
                  readOnly: true,
                  decoration: _inputDecoration('Employee Code').copyWith(
                    prefixIcon: Icon(FontAwesomeIcons.idBadge,
                        color: AppColors.primary),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _oldPasswordController,
                  obscureText: false,
                  decoration: _inputDecoration('Old Password').copyWith(
                    prefixIcon:
                        Icon(FontAwesomeIcons.lock, color: AppColors.primary),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  decoration: _inputDecoration('New Password').copyWith(
                    prefixIcon:
                        Icon(FontAwesomeIcons.key, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _rePasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _inputDecoration('Confirm New Password').copyWith(
                    prefixIcon:
                        Icon(FontAwesomeIcons.check, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 50),
                _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: InkWell(
                          onTap: _changePassword,
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
              ],
            )),
      ),
    );
  }

// Input Decoration Method
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
}
