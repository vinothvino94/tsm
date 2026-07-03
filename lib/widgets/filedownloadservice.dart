import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api/api_utils.dart';
import 'package:flutter/foundation.dart';

class DownloadConfig {
  final String getFilesEndpoint;
  final String downloadEndpoint;
  final String idParamName; // e.g. 'SBNO', 'SDNO', 'SPCNO'
  final List<String>
      fileFieldKeys; // e.g. ['SBFNAME'] or ['SDFNAME', 'DDFNAME']
  final String entityLabel; // e.g. 'Billing', 'Design', 'Project Control'

  const DownloadConfig({
    required this.getFilesEndpoint,
    required this.downloadEndpoint,
    required this.idParamName,
    required this.fileFieldKeys,
    required this.entityLabel,
  });
}

class DownloadConfigs {
  static const billing = DownloadConfig(
    getFilesEndpoint: 'GetBillingFiles',
    downloadEndpoint: 'DownloadbillFile',
    idParamName: 'SBNO',
    fileFieldKeys: ['SBFNAME'],
    entityLabel: 'Billing',
  );

  static const designing = DownloadConfig(
    getFilesEndpoint: 'GetDesigningFiles',
    downloadEndpoint: 'DownloaddesignFile',
    idParamName: 'SDNO',
    fileFieldKeys: ['SDFNAME', 'DDFNAME'],
    entityLabel: 'Design',
  );

  static const projectControl = DownloadConfig(
    getFilesEndpoint: 'GetPROJCTRLFiles',
    downloadEndpoint: 'DownloadPCFile',
    idParamName: 'SPCNO',
    fileFieldKeys: ['SDFNAME', 'DDFNAME'],
    entityLabel: 'Project Control',
  );
}

class AttachmentDownloadService {
  static Future<Map<String, dynamic>?> _getFiles({
    required DownloadConfig config,
    required int recordId,
  }) async {
    try {
      final response = await http.post(
        ApiUtils.getUri(config.getFilesEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({config.idParamName: recordId}),
      );

      print('${config.getFilesEndpoint} Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Success'] == true) return data['Data'];
      }
      return null;
    } catch (e) {
      print('Error fetching files: $e');
      return null;
    }
  }

  static Future<void> downloadFiles({
    required BuildContext context,
    required DownloadConfig config,
    required int recordId,
    Map<String, String?>? providedFiles,
  }) async {
    List<String> allFiles = [];

    // Use whatever's already in hand first (avoids an extra API round trip)
    if (providedFiles != null) {
      for (final key in config.fileFieldKeys) {
        final value = providedFiles[key];
        if (value != null && value.trim().isNotEmpty) {
          allFiles.addAll(value.split(',').map((e) => e.trim()));
        }
      }
    }

    // Fall back to fetching from API if nothing was provided
    if (allFiles.isEmpty) {
      final filesData = await _getFiles(config: config, recordId: recordId);

      if (filesData == null) {
        _showNoFilesDialog(context, recordId, config.entityLabel);
        return;
      }

      for (final key in config.fileFieldKeys) {
        final value = filesData[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          allFiles.addAll(value.toString().split(',').map((e) => e.trim()));
        }
      }

      if (allFiles.isEmpty) {
        _showNoFilesDialog(context, recordId, config.entityLabel);
        return;
      }
    }

    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission denied'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${allFiles.length} file(s)...'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );

    final List<String> success = [];
    final List<String> failed = [];

    for (final fileName in allFiles) {
      try {
        await _downloadFile(config: config, fileName: fileName);
        success.add(fileName);
        print('✓ Downloaded: $fileName');
      } catch (e) {
        failed.add(fileName);
        print('✗ Failed: $fileName - $e');
      }
    }

    _showDownloadResult(context, success, failed);
  }

  static Future<void> _downloadFile({
    required DownloadConfig config,
    required String fileName,
  }) async {
    try {
      print('Original filename from DB: "$fileName"');

      final response = await http.post(
        ApiUtils.getUri(config.downloadEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"fileName": fileName}),
      );

      print('Download API Request: fileName = "$fileName"');
      print('Download API Response Status: ${response.statusCode}');
      print('Download API Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (data['Success'] == true) {
        String base64String = data['FileBytes'];
        Uint8List fileBytes = base64Decode(base64String);

        String savePath = await _getSavePath(fileName);
        File file = File(savePath);
        await file.writeAsBytes(fileBytes);

        print('File saved to: $savePath');
      } else {
        throw Exception(data['Message'] ?? 'Download failed');
      }
    } catch (e) {
      throw Exception('Failed to download $fileName: $e');
    }
  }

  static Future<String> _getSavePath(String fileName) async {
    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) await directory.create(recursive: true);
      return '${directory.path}/$fileName';
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$fileName';
    } else if (Platform.isWindows) {
      final downloadsPath = '${Platform.environment['USERPROFILE']}\\Downloads';
      final directory = Directory(downloadsPath);
      if (!await directory.exists()) await directory.create(recursive: true);
      return '$downloadsPath\\$fileName';
    } else if (Platform.isMacOS) {
      final downloadsPath = '${Platform.environment['HOME']}/Downloads';
      final directory = Directory(downloadsPath);
      if (!await directory.exists()) await directory.create(recursive: true);
      return '$downloadsPath/$fileName';
    } else {
      final directory = Directory('./downloads');
      if (!await directory.exists()) await directory.create(recursive: true);
      return '${directory.path}/$fileName';
    }
  }

  static void _showNoFilesDialog(
      BuildContext context, int recordId, String entityLabel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('No Attachments'),
          ],
        ),
        content: Text(
          '$entityLabel #$recordId has no attached files.\n\n'
          'To add files, edit the entry and upload attachments.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  static void _showDownloadResult(
    BuildContext context,
    List<String> success,
    List<String> failed,
  ) {
    if (success.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No files were downloaded'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    } else if (failed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${success.length} file(s) downloaded successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OPEN FOLDER',
            onPressed: () async {
              String folderPath;
              if (Platform.isWindows) {
                folderPath =
                    '${Platform.environment['USERPROFILE']}\\Downloads';
              } else if (Platform.isAndroid) {
                folderPath = '/storage/emulated/0/Download';
              } else if (Platform.isIOS) {
                final directory = await getApplicationDocumentsDirectory();
                folderPath = directory.path;
              } else if (Platform.isMacOS) {
                folderPath = '${Platform.environment['HOME']}/Downloads';
              } else {
                folderPath = './downloads';
              }
              await OpenFile.open(folderPath);
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ ${success.length} downloaded, ${failed.length} failed: ${failed.join(", ")}',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

String formatIndianNumber(num value) {
  final isNegative = value < 0;
  final intVal = value.abs().round();
  final str = intVal.toString();

  String formatted;
  if (str.length <= 3) {
    formatted = str;
  } else {
    final lastThree = str.substring(str.length - 3);
    final rest = str.substring(0, str.length - 3);
    final restFormatted = rest.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{2})+$)'),
      (match) => '${match.group(1)},',
    );
    formatted = '$restFormatted,$lastThree';
  }

  return isNegative ? '-$formatted' : formatted;
}
