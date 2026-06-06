import 'package:flutter/services.dart';
import 'dart:io';

class ScreenSecurity {
  static const _channel = MethodChannel('com.your.app/screenshot');

  static Future<void> enableSecure() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('enableSecure');
      } catch (e) {
        print("Error enabling secure flag: $e");
      }
    }
  }

  static Future<void> disableSecure() async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('disableSecure');
      } catch (e) {
        print("Error disabling secure flag: $e");
      }
    }
  }
}
