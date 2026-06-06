import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_utils.dart';
import '../colors/app_colors.dart';
import '../services/file_service.dart';
import '../services/prefrence_helper.dart';
import '../widgets/app_updater.dart';
import 'home_screen.dart';
import 'login_model.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'dart:math' as math;

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  final FileService fileService = FileService();
  String _appVersion = "V-1.0";
  bool isLoading = false;
  final String phoneNumber = "9894108187";
  final String webUrl = "https://teemageprecast.in/";
  final String whatsappText = "Hello! I need some help.";

  // Add these constants for version checking
  static const String versionJsonUrl =
      'http://103.130.205.198:1415/AndroidAPK/tsm_version.JSON';
  static const String networkLocation =
      '\\\\192.168.2.2\\Design1\\Timesheet Management';
  static const String apkDownloadUrl =
      'http://103.130.205.198:1415/AndroidAPK/TSM.apk';

  bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  bool get isWindows {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  bool get isWeb => kIsWeb;

  @override
  void initState() {
    super.initState();
    _fetchAppVersion();
    if (isAndroid) {
      _initApp();
    } else if (isWindows) {
      // Check for updates on Windows startup
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForWindowsUpdate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWideScreen = size.width > 800;

    return Scaffold(
      body: Stack(
        children: [
          // Modern gradient background using new colors
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.background,
                  Colors.white,
                  AppColors.primary.withOpacity(0.03),
                ],
              ),
            ),
          ),

          // Animated background elements with new colors
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      size.height - MediaQuery.of(context).padding.vertical,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWideScreen ? size.width * 0.15 : 24,
                    vertical: 20,
                  ),
                  child: Column(
                    children: [
                      // Header Section
                      _buildHeaderSection(size),

                      SizedBox(height: 40),

                      // Login Form Card
                      _buildLoginFormCard(size, isWideScreen),

                      SizedBox(height: 40),

                      // Footer Section
                      _buildFooterSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NEW METHOD: Check for Windows updates
  Future<void> _checkForWindowsUpdate() async {
    try {
      debugPrint('Checking for updates on Windows...');

      // Get current version from package info
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Fetch version info from JSON
      final response = await http.get(Uri.parse(versionJsonUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> versionInfo = json.decode(response.body);
        final latestVersion = versionInfo['version'] as String;
        final isMandatory = versionInfo['is_mandatory'] as bool? ?? true;
        final changelog = versionInfo['changelog'] as String? ?? '';

        debugPrint(
            'Current version: $currentVersion, Latest version: $latestVersion');

        // Compare versions
        if (_compareVersions(currentVersion, latestVersion) < 0) {
          // Update available
          _showUpdateDialog(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            isMandatory: isMandatory,
            changelog: changelog,
          );
        } else {
          debugPrint('App is up to date.');
        }
      } else {
        debugPrint('Failed to fetch version info: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  // Helper method to compare version strings
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();

    for (int i = 0; i < math.max(parts1.length, parts2.length); i++) {
      final num1 = i < parts1.length ? parts1[i] : 0;
      final num2 = i < parts2.length ? parts2[i] : 0;

      if (num1 != num2) {
        return num1.compareTo(num2);
      }
    }
    return 0;
  }

  // NEW METHOD: Show update dialog for Windows
  void _showUpdateDialog({
    required String currentVersion,
    required String latestVersion,
    required bool isMandatory,
    required String changelog,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory, // Mandatory updates cannot be dismissed
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.update, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Update Available'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'A new version of the app is available.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('Current Version: V-$currentVersion'),
              Text('Latest Version: V-$latestVersion'),
              SizedBox(height: 15),
              if (changelog.isNotEmpty) ...[
                Text(
                  'What\'s New:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(changelog),
                SizedBox(height: 15),
              ],
              Text(
                'Location: $networkLocation',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              SizedBox(height: 5),
              Text(
                'Please use the latest version V-$latestVersion',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          if (!isMandatory)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Later'),
            ),
          ElevatedButton(
            onPressed: () async {
              final Uri uri = Uri.file(networkLocation);

              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                print('Could not open network location');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text(
              'Open Location',
              style: TextStyle(color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }

  // Rest of your existing methods remain the same...
  Future<void> _initApp() async {
    if (mounted) {
      AppUpdater(
        context: context,
      ).checkForUpdate();
    }
  }

  Future<void> _launchDialer() async {
    if (isWeb || isWindows) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Contact Support'),
            content: Text('Please call: $phoneNumber'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final Uri callUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    } else {
      debugPrint('Could not launch dialer: $callUri');
      _showErrorSnackbar('Could not launch phone dialer');
    }
  }

  Future<void> _launchWhatsApp({
    required String phoneNumber,
    required String whatsappText,
    required BuildContext context,
  }) async {
    final encodedText = Uri.encodeComponent(whatsappText);
    Uri whatsappUri;

    if (kIsWeb) {
      whatsappUri = Uri.parse("https://wa.me/$phoneNumber?text=$encodedText");
    } else if (Platform.isIOS) {
      whatsappUri = Uri.parse("https://wa.me/$phoneNumber?text=$encodedText");
    } else if (Platform.isAndroid) {
      whatsappUri = Uri.parse(
          "https://api.whatsapp.com/send?phone=$phoneNumber&text=$encodedText");
    } else {
      _showErrorSnackbar('Unsupported platform');
      return;
    }

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch WhatsApp');
      _showErrorSnackbar('Could not launch WhatsApp');
    }
  }

  Future<void> _launchWebsite() async {
    try {
      String url = webUrl;
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (Platform.isWindows) {
          await Process.run('start', [uri.toString()], runInShell: true);
          return;
        }

        if (mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Browser Required'),
              content: Text(
                  'No browser found to open the website. Would you like to install one?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await launchUrl(
                      Uri.parse(
                        Platform.isAndroid
                            ? 'market://details?id=com.android.chrome'
                            : 'https://play.google.com/store/search?q=browser',
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text('Install'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Website launch error: $e');
      if (mounted) {
        _showErrorSnackbar(
            'Failed to open website. Please check your browser installation.');
      }
    }
  }

  Future<void> _fetchAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = 'V-${packageInfo.version}';
        });
      }
    } catch (e) {
      debugPrint('Error fetching app version: $e');
      setState(() {
        _appVersion = "V-1.0";
      });
    }
  }

  Future<void> login() async {
    debugPrint('Login initiated');

    if (_formKey.currentState?.validate() ?? false) {
      setState(() => isLoading = true);
      debugPrint('Form validation passed');

      final loginModel = LoginModel(
        empCode: _emailController.text,
        empPass: _passwordController.text,
        oldEmpPass: '',
      );

      try {
        debugPrint('Attempting login with empCode: ${_emailController.text}');
        final response = await fileService.loginUser(loginModel);

        debugPrint('Received response with status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          debugPrint('Response data: $data');

          if (data is Map<String, dynamic> && data.containsKey('EMPCODE')) {
            // ✅ SUCCESS CASE
            final empName = data['EMPNAME'] ?? 'User';
            final empCode = int.parse(data['EMPCODE'].toString());
            final empSite = int.parse(data['EMPSITE'].toString());
            final empBran = int.parse(data['EMPBRAN'].toString());
            final empDept = data['HRIIFSCCODE'].toString();
            final empTL = data['HRIACCNO'].toString();
            final sales = data['HRIAMOUNT'].toString();

            final hasSalesAccess = double.tryParse(sales) == 555.0;
            debugPrint('Sales access: $hasSalesAccess (HRIAMOUNT: $sales)');

            await PreferencesHelper().saveUserDetails(empName, empCode, empSite,
                empBran, empDept, empTL, sales, hasSalesAccess);
            debugPrint('User details saved to preferences');

            debugPrint('Login successful, proceeding to home screen');
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    HomeScreen(
                  empcode: empCode,
                  employeeName: empName,
                ),
              ),
            );
          } else {
            // ❌ INVALID CREDENTIALS CASE
            debugPrint('Invalid credentials: EMPCODE not found in response');
            if (mounted) {
              _showErrorSnackbar('Invalid Employee Code or Password.');
            }
          }
        } else {
          // ❌ SERVER ERROR
          debugPrint('Server error with status: ${response.statusCode}');
          if (mounted) {
            _showErrorSnackbar(
                'Server error (${response.statusCode}). Please try again later.');
          }
        }
      } on SocketException {
        // ❌ NETWORK ISSUE
        debugPrint('No internet connection');
        if (mounted) {
          _showErrorSnackbar(
              'No internet connection. Please check your network.');
        }
      } catch (e) {
        // ❌ UNEXPECTED ERROR
        debugPrint('Login failed with error: $e');
        if (mounted) {
          _showErrorSnackbar('Login failed. Please try again.');
        }
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
          debugPrint('Login process completed');
        }
      }
    } else {
      debugPrint('Form validation failed');
      _showErrorSnackbar('Please fill all required fields correctly.');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Widget _buildHeaderSection(Size size) {
    return Column(
      children: [
        SizedBox(height: size.height * 0.05),

        // 🌟 Animated Logo Container

        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 2000),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            final safeValue = value.clamp(0.0, 1.0);

            // Split the phases
            final logoOpacity = Curves.easeIn
                .transform((safeValue * 2).clamp(0.0, 1.0))
                .clamp(0.0, 1.0);
            final circleProgress = Curves.elasticOut
                .transform(((safeValue - 0.4) * 1.6).clamp(0.0, 1.0))
                .clamp(0.0, 1.0);

            // Glow pulse animation
            final glowPulse = 0.4 +
                0.3 *
                    (1 +
                        math.sin(DateTime.now().millisecondsSinceEpoch / 400)) /
                    2;

            return Stack(
              alignment: Alignment.center,
              children: [
                // 🌸 Circle background
                Transform.scale(
                  scale: circleProgress,
                  child: Opacity(
                    opacity: circleProgress.clamp(0.0, 1.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.surface.withOpacity(0.95),
                            AppColors.background.withOpacity(0.9),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: const Offset(2, 4),
                          ),
                          BoxShadow(
                            color: AppColors.primary
                                .withOpacity(0.25 * glowPulse.clamp(0.0, 1.0)),
                            blurRadius: 30 * glowPulse,
                            spreadRadius: 4 * glowPulse,
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 20,
                            offset: const Offset(-4, -4),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.15),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),

                // 🪶 Logo fade-in & zoom
                Opacity(
                  opacity: logoOpacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: (0.8 + (0.25 * logoOpacity)).clamp(0.8, 1.05),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                      builder: (context, bounce, _) {
                        final bounceScale =
                            1 + 0.05 * math.sin(bounce * math.pi);
                        return Transform.scale(
                          scale: bounceScale.clamp(0.0, 1.2),
                          child: Image.asset(
                            'assets/images/jata_logo.png',
                            fit: BoxFit.contain,
                            height: 70,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 32),

        // Welcome text
        Column(
          children: [
            Text(
              "Sign in to manage your timesheets",
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginFormCard(Size size, bool isWideScreen) {
    return Container(
      width: isWideScreen ? size.width * 0.4 : double.infinity,
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 40,
            spreadRadius: 5,
            offset: Offset(0, 15),
          ),
        ],
        border: Border.all(
          color: AppColors.border.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Employee Code Field
            _buildModernTextField(
              controller: _emailController,
              label: "Employee Code",
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter your Employee Code";
                }
                if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return "Only numbers are allowed";
                }
                return null;
              },
            ),

            SizedBox(height: 24),

            // Password Field
            _buildModernTextField(
              controller: _passwordController,
              label: "Password",
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary.withOpacity(0.6),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter your password";
                }
                if (value.length < 3) {
                  //return "Password must be at least 3 characters";
                }
                return null;
              },
            ),

            SizedBox(height: 32),

            // Login Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: AppColors.primary.withOpacity(0.3),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "SIGN IN",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    AutovalidateMode? autovalidateMode,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        return TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          autovalidateMode:
              autovalidateMode ?? AutovalidateMode.onUserInteraction,
          onChanged: (value) {
            // ✅ This forces only this field to revalidate
            setState(() {});
          },
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Container(
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.all(12),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            filled: true,
            fillColor: AppColors.background,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        );
      },
    );
  }

  Widget _buildFooterSection() {
    return Column(
      children: [
        Text(
          "Need assistance? Contact support",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),

        SizedBox(height: 24),

        // Contact buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildModernContactButton(
              icon: FontAwesomeIcons.phone,
              tooltip: "Call Support",
              onPressed: _launchDialer,
            ),
            SizedBox(width: 16),
            _buildModernContactButton(
              icon: Icons.download_rounded,
              tooltip: "Download APK",
              onPressed: () {
                DownloadHelper.downloadApk(context);
              },
            ),
            // SizedBox(width: 16),
            // _buildModernContactButton(
            //   icon: FontAwesomeIcons.whatsapp,
            //   tooltip: "WhatsApp Support",
            //   onPressed: () {
            //     _launchWhatsApp(
            //       phoneNumber: phoneNumber,
            //       whatsappText: whatsappText,
            //       context: context,
            //     );
            //   },
            // ),
          ],
        ),

        SizedBox(height: 32),

        // App version
        Text(
          "$_appVersion",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModernContactButton({
    required IconData icon,
    String tooltip = "",
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primaryLight,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: FaIcon(
                icon,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DownloadHelper {
  static Future<void> downloadApk(BuildContext context) async {
    const url = 'http://103.130.205.198:1415/AndroidAPK/TSM.apk';
    String filePath;

    if (kIsWeb) {
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (BuildContext ctx) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text("Preparing download..."),
                SizedBox(height: 10),
                LinearProgressIndicator(),
                SizedBox(height: 10),
                Text("Saving through browser..."),
              ],
            ),
          );
        },
      );

      await Future.delayed(const Duration(seconds: 2));
      Navigator.pop(context);

      html.AnchorElement anchor = html.AnchorElement(href: url)
        ..target = 'blank'
        ..download = 'TSM.apk';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("📥 Download Completed.")),
      );
      return;
    }

    if (Platform.isAndroid) {
      if (!await _requestStoragePermission()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Storage permission denied")),
        );
        return;
      }

      final dir = Directory('/storage/emulated/0/Download');
      if (!(await dir.exists())) {
        await dir.create(recursive: true);
      }
      filePath = '${dir.path}/TSM.apk';
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dir = await getDownloadsDirectory();
      filePath = '${dir!.path}/TSM.apk';
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Unsupported platform")),
      );
      return;
    }

    try {
      final dio = Dio();
      double progress = 0.0;
      late StateSetter bottomSheetSetState;

      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (BuildContext ctx) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              bottomSheetSetState = setState;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        "Downloading... ${(progress * 100).toStringAsFixed(0)}%"),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 10),
                    Text("Saving to: $filePath",
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            },
          );
        },
      );

      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            progress = received / total;
            if (bottomSheetSetState != null) {
              bottomSheetSetState(() {});
            }
          }
        },
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Download completed: $filePath")),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Download failed: $e")),
      );
      print("❌ Download failed: $e");
    }
  }

  static Future<bool> _requestStoragePermission() async {
    if (await Permission.storage.request().isGranted) return true;
    if (await Permission.manageExternalStorage.request().isGranted) return true;
    return false;
  }
}

/*// NEW METHOD: Download update for Windows
  Future<void> _downloadWindowsUpdate() async {
    try {
      final dio = Dio();
      final dir = await getDownloadsDirectory();
      final filePath =
          '${dir!.path}/TSM_${DateTime.now().millisecondsSinceEpoch}.apk';

      double progress = 0.0;
      late StateSetter bottomSheetSetState;

      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (BuildContext ctx) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              bottomSheetSetState = setState;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Downloading Update... ${(progress * 100).toStringAsFixed(0)}%",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    LinearProgressIndicator(value: progress),
                    SizedBox(height: 10),
                    Text(
                      "Saving to: $filePath",
                      style: TextStyle(fontSize: 10),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      await dio.download(
        apkDownloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            progress = received / total;
            if (bottomSheetSetState != null) {
              bottomSheetSetState(() {});
            }
          }
        },
      );

      Navigator.pop(context);

      // Show success dialog with instructions
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Download Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The update has been downloaded successfully.'),
              SizedBox(height: 10),
              Text(
                'File saved to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                filePath,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              SizedBox(height: 15),
              Text(
                'Please install the APK file to update the application.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Open the file location
                Process.run('explorer', ['/select,', filePath]);
              },
              child: Text('Open Location'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackbar('Download failed: $e');
      debugPrint('❌ Download failed: $e');
    }
  }*/
