import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:tsm/colors/app_colors.dart';

class AppUpdater {
  static const String versionUrl =
      'http://103.130.205.198:1415/AndroidAPK/tsm_version.json';
  static const String apkBaseUrl = 'http://103.130.205.198:1415/AndroidAPK/';

  final BuildContext context;
  final bool isMandatory;
  final String? updateTitle;
  final String? updateDescription;
  final Color? primaryColor;
  final Color? secondaryColor;

  AppUpdater({
    required this.context,
    this.isMandatory = true,
    this.updateTitle,
    this.updateDescription,
    this.primaryColor,
    this.secondaryColor,
  });

  Future<void> checkForUpdate() async {
    try {
      final dio = Dio();
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await dio.get(
        versionUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      final latestVersion = response.data['version'] as String;
      final apkName = response.data['apk_name'] as String;
      final apkUrl = '$apkBaseUrl$apkName';
      final mandatory = response.data['is_mandatory'] ?? true;
      final changelog = response.data['changelog'] as String?;

      if (_shouldUpdate(currentVersion, latestVersion)) {
        await _showUpdateDialog(
          latestVersion: latestVersion,
          apkUrl: apkUrl,
          isMandatory: mandatory,
          changelog: changelog,
        );
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to check for updates')),
        );
      }
    }
  }

  bool _shouldUpdate(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  Future<void> _showUpdateDialog({
    required String latestVersion,
    required String apkUrl,
    required bool isMandatory,
    String? changelog,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (context) => UpdateDialog(
        apkUrl: apkUrl,
        latestVersion: latestVersion,
        isMandatory: isMandatory,
        changelog: changelog,
        title: updateTitle,
        description: updateDescription,
        primaryColor: primaryColor ?? Theme.of(context).primaryColor,
        secondaryColor:
            secondaryColor ?? Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}

class UpdateDialog extends StatefulWidget {
  final String apkUrl;
  final String latestVersion;
  final bool isMandatory;
  final String? changelog;
  final String? title;
  final String? description;
  final Color primaryColor;
  final Color secondaryColor;

  const UpdateDialog({
    super.key,
    required this.apkUrl,
    required this.latestVersion,
    required this.isMandatory,
    this.changelog,
    this.title,
    this.description,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with TickerProviderStateMixin {
  double _progress = 0;
  bool _isDownloading = false;
  bool _isPreparing = false;
  CancelToken? _cancelToken;
  double _downloadSpeed = 0;
  int _lastReceived = 0;
  DateTime _lastUpdate = DateTime.now();
  final List<int> _speedSamples = [];
  static const int _maxSamples = 5;

  // Animation controllers
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();

    // Wave animation for progress bar
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _waveAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: Curves.easeInOut,
      ),
    );

    // Ripple effect animation
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _rippleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _waveController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title ?? 'New Update Available',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version ${widget.latestVersion}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.description != null) ...[
            Text(widget.description!),
            const SizedBox(height: 8),
          ],
          if (widget.changelog != null) ...[
            const Text(
              'What\'s new:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.changelog!,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
          ],
          if (_isDownloading || _isPreparing) ...[
            const SizedBox(height: 8),
            _buildProgressIndicator(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(_progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  _formatSpeed(_downloadSpeed),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        if (!widget.isMandatory && !_isDownloading && !_isPreparing)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'LATER',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          onPressed: _isDownloading || _isPreparing ? null : _startDownload,
          child: _isDownloading || _isPreparing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'UPDATE NOW',
                  style: TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return AnimatedBuilder(
      animation: Listenable.merge([_waveController, _rippleController]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Background track
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // Progress track with wave effect
            Container(
              height: 8,
              width: MediaQuery.of(context).size.width * 0.7 * _progress,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.primaryColor,
                    widget.secondaryColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: CustomPaint(
                painter: _WavePainter(
                  animationValue: _waveAnimation.value,
                  progress: _progress,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ),

            // Ripple effect at progress head
            if (_progress > 0)
              Positioned(
                left: MediaQuery.of(context).size.width * 0.7 * _progress - 8,
                child: Opacity(
                  opacity: 1 - _rippleAnimation.value,
                  child: Container(
                    width: 16 * _rippleAnimation.value,
                    height: 16 * _rippleAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.primaryColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _formatSpeed(double speed) {
    if (speed <= 0) return _isPreparing ? 'Preparing...' : 'Starting...';
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  Future<void> _startDownload() async {
    setState(() {
      _isPreparing = true;
      _progress = 0;
      _downloadSpeed = 0;
      _lastReceived = 0;
      _lastUpdate = DateTime.now();
      _speedSamples.clear();
      _cancelToken = CancelToken();
    });

    try {
      if (!await _checkPermissions()) {
        throw Exception('Storage permission required');
      }

      final dir = await getExternalStorageDirectory();
      final downloadsDir = Directory('${dir?.path}/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final path = '${downloadsDir.path}/TSM_${widget.latestVersion}.apk';

      // Configure Dio for download
      final dio = Dio(BaseOptions(
        receiveTimeout: const Duration(minutes: 5),
        connectTimeout: const Duration(seconds: 10),
        responseType: ResponseType.stream,
      ));

      setState(() {
        _isPreparing = false;
        _isDownloading = true;
      });

      final response = await dio.get<ResponseBody>(
        widget.apkUrl,
        options: Options(responseType: ResponseType.stream),
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final now = DateTime.now();
            final timeDiff = now.difference(_lastUpdate).inMilliseconds;

            if (timeDiff > 0) {
              final bytesPerMilli = (received - _lastReceived) / timeDiff;
              final currentSpeed = bytesPerMilli * 1000;

              _speedSamples.add(currentSpeed.toInt());
              if (_speedSamples.length > _maxSamples) {
                _speedSamples.removeAt(0);
              }

              final avgSpeed = _speedSamples.isNotEmpty
                  ? _speedSamples.reduce((a, b) => a + b) / _speedSamples.length
                  : currentSpeed;

              _lastReceived = received;
              _lastUpdate = now;

              if (mounted) {
                setState(() {
                  _progress = received / total;
                  _downloadSpeed = avgSpeed;
                });
              }
            }
          }
        },
      );

      final file = File(path);
      final raf = file.openSync(mode: FileMode.write);

      final completer = Completer<void>();
      final subscription = response.data!.stream.listen(
        (chunk) async {
          raf.writeFromSync(chunk);
        },
        onDone: () async {
          await raf.close();
          if (!completer.isCompleted) {
            completer.complete();
          }
          await _installApk(path);
        },
        onError: (e) async {
          await raf.close();
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        cancelOnError: true,
      );

      _cancelToken?.whenCancel.then((_) {
        subscription.cancel();
        raf.closeSync();
        if (!completer.isCompleted) {
          completer.completeError(Exception('Download cancelled'));
        }
      });

      await completer.future;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: ${e.toString()}')),
        );
        setState(() {
          _isDownloading = false;
          _isPreparing = false;
        });
      }
    }
  }

  Future<void> _installApk(String path) async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 26) {
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          throw Exception('Install permission denied');
        }
      }
    }

    final result = await OpenFile.open(path,
        type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done && mounted) {
      throw Exception('Installation failed: ${result.message}');
    }

    if (mounted) Navigator.pop(context);
  }

  Future<bool> _checkPermissions() async {
    if (!Platform.isAndroid) return true;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      return await Permission.manageExternalStorage.request().isGranted;
    } else if (sdkInt >= 29) {
      return true;
    } else {
      return await Permission.storage.request().isGranted;
    }
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final double progress;
  final Color color;

  _WavePainter({
    required this.animationValue,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = 4.0;
    final waveLength = size.width / 3;

    path.moveTo(0, size.height / 2);

    for (double x = 0; x < size.width; x++) {
      final percent = x / size.width;
      final waveX = x / waveLength;
      final waveY = sin(waveX + animationValue * 2 * pi) * waveHeight;
      path.lineTo(x, size.height / 2 + waveY);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        progress != oldDelegate.progress ||
        color != oldDelegate.color;
  }
}
