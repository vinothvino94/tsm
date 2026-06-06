import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show PlatformDispatcher, kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:tsm/services/screen_security.dart';
import 'package:provider/provider.dart';
import 'colors/app_colors.dart';
import 'login/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';

// Global navigator key for safe navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setTheme(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }
}

class AppConfig {
  static const String appName = "TSM";
  static const bool isDebugMode = kDebugMode;
}

// Safe navigation utility
class SafeNavigator {
  static Future<bool> push(Widget page, {BuildContext? context}) async {
    try {
      final navContext = context ?? navigatorKey.currentContext;
      if (navContext != null && Navigator.of(navContext).canPop()) {
        await Navigator.of(navContext).push(
          MaterialPageRoute(builder: (context) => page),
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Navigation error: $e');
      return false;
    }
  }

  static Future<bool> pushReplacement(Widget page,
      {BuildContext? context}) async {
    try {
      final navContext = context ?? navigatorKey.currentContext;
      if (navContext != null) {
        await Navigator.of(navContext).pushReplacement(
          MaterialPageRoute(builder: (context) => page),
        );
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Navigation replacement error: $e');
      return false;
    }
  }

  static void pop({BuildContext? context, dynamic result}) {
    try {
      final navContext = context ?? navigatorKey.currentContext;
      if (navContext != null && Navigator.of(navContext).canPop()) {
        Navigator.of(navContext).pop(result);
      } else {
        debugPrint('No routes to pop');
      }
    } catch (e) {
      debugPrint('Pop navigation error: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app configurations
  await _initializeApp();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: MyApp(),
    ),
  );
}

Future<void> _initializeApp() async {
  try {
    // ⚙️ Platform-specific initialization (no screen security now)
    if (!kIsWeb && Platform.isWindows) {
      await _initializeWindows();
    }

    // 📱 Get device info for analytics/debugging
    await getDeviceInfo();
  } catch (e) {
    debugPrint('App initialization error: $e');
  }
}

Future<void> _initializeWindows() async {
  debugPrint('Windows platform detected');
}

Future<void> getDeviceInfo() async {
  try {
    if (kIsWeb) {
      debugPrint('🌐 Running on Web browser');
      return;
    }

    final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfoPlugin.androidInfo;
      debugPrint('📱 Android Device: ${androidInfo.model}');
      debugPrint('🤖 Android Version: ${androidInfo.version.release}');
      debugPrint('🏷️ Manufacturer: ${androidInfo.manufacturer}');
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfoPlugin.iosInfo;
      debugPrint('📱 iOS Device: ${iosInfo.model}');
      debugPrint('🍎 iOS Version: ${iosInfo.systemVersion}');
      debugPrint('🆔 UTI: ${iosInfo.utsname.machine}');
    } else if (Platform.isWindows) {
      final WindowsDeviceInfo windowsInfo = await deviceInfoPlugin.windowsInfo;
      debugPrint('💻 Windows Device: ${windowsInfo.computerName}');
    } else if (Platform.isLinux) {
      final LinuxDeviceInfo linuxInfo = await deviceInfoPlugin.linuxInfo;
      debugPrint('🐧 Linux Machine: ${linuxInfo.machineId}');
    } else if (Platform.isMacOS) {
      final MacOsDeviceInfo macInfo = await deviceInfoPlugin.macOsInfo;
      debugPrint('🍎 MacOS Device: ${macInfo.computerName}');
    }
  } catch (e) {
    debugPrint('❌ Error getting device info: $e');
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    //_initializeAppState();
    _setupErrorHandling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupErrorHandling() {
    // Handle Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);

      // Log navigation errors specifically
      if (details.exception.toString().contains('_history.isNotEmpty') ||
          details.exception.toString().contains('navigator')) {
        debugPrint('🚨 NAVIGATION ERROR: ${details.exception}');
        debugPrint('📝 Stack trace: ${details.stack}');
      }
    };

    // Handle Dart errors
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('🚨 DART ERROR: $error');
      debugPrint('📝 Stack trace: $stack');
      return true;
    };
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('🔄 App resumed');
        break;
      case AppLifecycleState.inactive:
        debugPrint('⏸️ App inactive');
        break;
      case AppLifecycleState.paused:
        debugPrint('⏸️ App paused');
        break;
      case AppLifecycleState.detached:
        debugPrint('❌ App detached');
        break;
      case AppLifecycleState.hidden:
        debugPrint('👻 App hidden');
        break;
    }
  }

  // Future<void> _initializeAppState() async {
  //   debugPrint('🚀 ${AppConfig.appName} v${AppConfig.appVersion} initialized');
  // }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      navigatorKey: navigatorKey, // Global navigator key
      routes: {
        '/login': (context) => LoginScreen(),
      },
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      themeMode: themeNotifier.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: LoginScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: _getTextScaleFactor(context),
          ),
          child: child!,
        );
      },
      // Add navigation observer for debugging
      navigatorObservers: [
        _NavigationObserver(),
      ],
    );
  }

  ThemeData _buildLightTheme() {
    final baseTheme = ThemeData.light(useMaterial3: true);

    return baseTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
            color: Colors.white), // Ensure back button is visible
      ),
      textTheme: GoogleFonts.robotoTextTheme(
        baseTheme.textTheme.copyWith(
          bodyLarge: TextStyle(color: AppColors.textPrimary),
          bodyMedium: TextStyle(color: AppColors.textPrimary),
          displayLarge: TextStyle(color: AppColors.textPrimary),
          displayMedium: TextStyle(color: AppColors.textPrimary),
          displaySmall: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: AppColors.background,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return baseTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
            color: Colors.white), // Ensure back button is visible
      ),
      textTheme: GoogleFonts.robotoTextTheme(
        baseTheme.textTheme.copyWith(
          bodyLarge: const TextStyle(color: Colors.white),
          bodyMedium: const TextStyle(color: Colors.white70),
          displayLarge: const TextStyle(color: Colors.white),
          displayMedium: const TextStyle(color: Colors.white),
          displaySmall: const TextStyle(color: Colors.white),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        fillColor: Colors.grey.shade800,
        filled: true,
      ),
    );
  }

  double _getTextScaleFactor(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    if (width > 1200) {
      return 1.1;
    } else if (width > 800) {
      return 1.0;
    } else {
      return 0.95;
    }
  }
}

// Navigation observer for debugging
class _NavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('➡️ Navigation: Pushed ${route.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('⬅️ Navigation: Popped ${route.settings.name}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('🗑️ Navigation: Removed ${route.settings.name}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    debugPrint(
        '🔄 Navigation: Replaced ${oldRoute?.settings.name} with ${newRoute?.settings.name}');
  }
}
