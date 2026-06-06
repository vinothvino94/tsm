import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../api/api_utils.dart';
import '../login/login_model.dart';
import '../models/project.dart';

class FileService {
  Future<http.Response> loginUser(LoginModel loginModel) async {
    final url = ApiUtils.getUri('LoginUser');
    final headers = {"Content-Type": "application/json"};

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(loginModel.toJson()),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to login: ${response.body}');
      }
      return response;
    } catch (e) {
      print('Error logging in: $e');
      throw Exception("Failed to login: $e");
    }
  }

  Future<http.Response> checkWhatsAppNumber(String empCode) async {
    final uri = ApiUtils.getUri('CheckEmpWaNo');

    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'EMPCODE': empCode}),
    );
  }

  Future<String> getEmpNameByCode(String empCode) async {
    final url = ApiUtils.getUri('GetEmployeeNames');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"EMPCODE": empCode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['Departments'];
        if (list != null && list.isNotEmpty) {
          return "${list[0]['EMPCODE']} - ${list[0]['EMPNAME']}";
        }
      }
      return empCode;
    } catch (e) {
      print("Error fetching employee name: $e");
      return empCode;
    }
  }

  Future<Map<String, dynamic>?> getEmpByCode(String empCode) async {
    final url = ApiUtils.getUri('GetEmployeeByCode');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(int.tryParse(empCode)), // API expects int
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true && data['Employee'] != null) {
          return Map<String, dynamic>.from(data['Employee']);
        }
      }
      return null;
    } catch (e) {
      print("Error fetching employee: $e");
      return null;
    }
  }

  // Future<String> getAppVersion() async {
  //   try {
  //     final uri = ApiUtils.getUri('CheckTPROVersion');
  //     final response = await http.post(
  //       uri,
  //       headers: {'Content-Type': 'application/json'},
  //     );
  //
  //     if (response.statusCode == 200) {
  //       return response.body; // Returns "1.0" from your API
  //     } else {
  //       throw Exception('Failed to get version: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     debugPrint('Error getting app version: $e');
  //     throw Exception('Failed to get version');
  //   }
  // }

  Future<String> changePassword(LoginModel loginModel) async {
    final url = ApiUtils.getUri('ChangePass');
    final headers = {"Content-Type": "application/json"};

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(loginModel.toJson()),
      );

      if (response.statusCode == 200) {
        print('Response body: ${response.body}'); // Log response body
        return response.body;
      } else {
        print(
            'Error response body: ${response.body}'); // Log error response body
        throw Exception('Failed to change password');
      }
    } catch (e) {
      print('Error changing password: $e');
      throw Exception('Failed to change password');
    }
  }

  Future<int> checkEcNo(int empCode) async {
    final url = ApiUtils.getUri('CheckEcNo/$empCode');

    try {
      final response =
          await http.post(url, headers: {'Content-Type': 'application/json'});
      if (response.statusCode == 200) {
        return int.parse(response.body);
      } else {
        throw Exception('Failed to check employee code');
      }
    } catch (e) {
      throw Exception('Error checking employee code: $e');
    }
  }

  Future<List<dynamic>> loadSiteName(int projectId) async {
    final url = ApiUtils.getUri('LoadSiteName');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'PROJECTID': projectId}),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody is List) {
          return responseBody;
        } else if (responseBody == "0") {
          return []; // Return empty list when no sites found
        }
        throw Exception('Unexpected response format');
      } else {
        throw Exception('Failed to load site name: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading site name: $e');
    }
  }

  Future<List<Project>> loadProjNames() async {
    final url = ApiUtils.getUri('LoadProjName');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        return data.map((item) => Project.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load projects: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading projects: $e');
    }
  }

  Future<int> ProjectId(String projectName) async {
    final url = ApiUtils.getUri('ProjectId');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'PROJECTNAME': projectName}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return data.first['PROJECTID'] as int;
        }
        throw Exception('Project not found');
      } else {
        throw Exception('Failed to get project ID');
      }
    } catch (e) {
      throw Exception('Error getting project ID: $e');
    }
  }

  static Future<String?> getLatestAppVersion() async {
    try {
      // Make GET request to your API endpoint
      final response = await http.get(
        ApiUtils.getUri('CheckAppVersion'), // Update with your actual endpoint
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Parse the JSON response
        final data = jsonDecode(response.body);

        // Adjust based on your actual API response structure
        // Assuming your API returns: {"ACCESSTOKEN": "V-1.0.2"}
        return data['ACCESSTOKEN'] as String?;
      } else {
        debugPrint(
            'Failed to fetch version. Status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching latest version: $e');
      return null;
    }
  }

  /// Check app version against server
  static Future<Map<String, dynamic>> checkAppVersion(String appVersion) async {
    try {
      final response = await http.post(
        ApiUtils.getUri('CheckAppVersion'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'ACCESSTOKEN': appVersion,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint(
            'Failed to check version. Status code: ${response.statusCode}');
        return {
          'Success': false,
          'Message': 'Failed to check version',
          'IsValidVersion': 0
        };
      }
    } catch (e) {
      debugPrint('Error checking app version: $e');
      return {
        'Success': false,
        'Message': 'Network error',
        'IsValidVersion': 0
      };
    }
  }
}
