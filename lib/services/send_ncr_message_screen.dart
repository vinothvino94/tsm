import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../api/api_utils.dart';

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../api/api_utils.dart';

Future<void> sendWhatsAppMessage({
  required int empCode,
  required String ncrId,
  required String siteName,
  required String raisedBy,
  required String status,
  required String remarks,
  required String dynamicTitle,
  BuildContext? context,
}) async {
  try {
    debugPrint("🔍 Fetching WA number for empCode: $empCode");
    final uri = ApiUtils.getUri('GetWANobyEmpcode');

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"EMPCODE": empCode}),
    );

    final data = jsonDecode(response.body);
    final waNumber = data['EMPMOBNOWA'];

    if (data['Success'] == true && waNumber != null && waNumber.isNotEmpty) {
      // ✅ Format parameters string
      final rawParams =
          "$dynamicTitle,$ncrId,$siteName,$raisedBy,$status,$remarks";
      final encodedParams = Uri.encodeComponent(rawParams);

      // ✅ Construct the full API URL
      final templateUrl = "http://voice.roundsms.co/api/sendmsg.php"
          "?user=Teemage_WA"
          "&pass=9677630444" // 🔐 Replace with your actual password
          "&sender=BUZWAP"
          "&phone=$waNumber"
          "&text=ncr_template"
          "&priority=wa"
          "&stype=normal"
          "&Params=$encodedParams";

      debugPrint("📤 Sending WA message to 91$waNumber");
      debugPrint("🌐 Full URL: $templateUrl");

      final sendResponse = await http.get(Uri.parse(templateUrl));

      if (sendResponse.statusCode == 200) {
        debugPrint("✅ WA template message sent successfully to 91$waNumber");
      } else {
        debugPrint("❌ WA API failed - Status: ${sendResponse.statusCode}");
      }
    } else {
      debugPrint("❌ WhatsApp number not found or invalid for EmpCode $empCode");
    }
  } catch (e) {
    debugPrint("❌ Exception during WA send: $e");
  }
}
