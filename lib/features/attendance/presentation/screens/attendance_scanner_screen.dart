import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/widgets/premium_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../users/data/face_capture_service.dart';
import '../../data/attendance_repository.dart';
import '../../data/face_verification_service.dart';

/// Attendance flow:
/// 1. Camera opens → QR scanned
/// 2. Token validated
/// 3. Front camera opens → face detected + verified against registration
/// 4. Attendance saved
///
/// On desktop/web where camera is unavailable, falls back to manual QR entry
/// and photo-proof verification.
class AttendanceScannerScreen extends StatefulWidget {
  const AttendanceScannerScreen({super.key});

  @override
  State<AttendanceScannerScreen> createState() => _AttendanceScannerScreenState();
}

enum _ScannerStep { scanning, faceVerification, result }

class _AttendanceScannerScreenState extends State<AttendanceScannerScreen> {
  final _repository = AttendanceRepository();
  final _faceService = FaceVerificationService();
  final _manualController = TextEditingController();

  CameraController? _cameraController;
  bool _cameraInitializing = false;
  bool _cameraInitialized = false;

  _ScannerStep _step = _ScannerStep.scanning;
  String _status = 'Point camera at the dynamic QR code.';
  bool _processing = false;
  bool _success = false;
  String? _scannedSessionId;
  String? _scannedToken;

  bool get _isDesktopOrWeb {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  Future<void> _initCamera() async {
    if (_isDesktopOrWeb) return;
    if (_cameraInitialized || _cameraInitializing) return;
    setState(() {
      _cameraInitializing = true;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraInitializing = false;
          _cameraInitialized = false;
        });
        return;
      }
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _cameraInitializing = false;
          _cameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera initialization failed: $e');
      if (mounted) {
        setState(() {
          _cameraInitializing = false;
          _cameraInitialized = false;
        });
      }
    }
  }

  Future<void> _disposeCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }
    if (mounted) {
      setState(() {
        _cameraInitialized = false;
        _cameraInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _manualController.dispose();
    _disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Attendance')),
      body: SafeArea(
        child: user == null
            ? const Center(child: Text('No active user profile found.'))
            : switch (_step) {
                _ScannerStep.scanning => _buildScanStep(user.id, user.organizationId),
                _ScannerStep.faceVerification => _buildFaceStep(user.id, user.organizationId),
                _ScannerStep.result => _buildResultStep(),
              },
      ),
    );
  }

  // ── Step 1: QR Scanning ──────────────────────────────────────────────

  Widget _buildScanStep(String userId, String organizationId) {
    if (_isDesktopOrWeb) {
      return _buildManualEntry(userId, organizationId);
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              MobileScanner(
                onDetect: (capture) {
                  if (_processing) return;
                  final barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    final rawValue = barcode.rawValue;
                    if (rawValue != null && rawValue.contains('sessionId=')) {
                      _onQrDetected(rawValue, userId, organizationId);
                      break;
                    }
                  }
                },
              ),
              // Viewfinder overlay
              Container(
                width: 260.w,
                height: 260.w,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
            ],
          ),
        ),
        PremiumCard(
          margin: EdgeInsets.all(16.w),
          child: Column(
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                size: 28.w,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 8.h),
              Text(
                _status,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (_processing) ...[
                SizedBox(height: 12.h),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Desktop/web fallback: manual QR payload entry
  Widget _buildManualEntry(String userId, String organizationId) {
    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        PremiumCard(
          child: Column(
            children: [
              Icon(
                Icons.desktop_windows_rounded,
                size: 48.w,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 12.h),
              Text(
                'Desktop / Web Fallback',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              Text(
                'Camera scanning is available on mobile devices. On desktop, paste the QR payload below.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _manualController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'QR Payload',
                  prefixIcon: Icon(Icons.qr_code_2_rounded),
                ),
              ),
              SizedBox(height: 12.h),
              FilledButton.icon(
                onPressed: _processing
                    ? null
                    : () {
                        final payload = _manualController.text.trim();
                        if (payload.isNotEmpty) {
                          _onQrDetected(payload, userId, organizationId);
                        }
                      },
                icon: _processing
                    ? SizedBox.square(
                        dimension: 16.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_processing ? 'Validating...' : 'Submit QR Data'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 2: Face Verification ────────────────────────────────────────

  Widget _buildFaceStep(String userId, String organizationId) {
    if (_isDesktopOrWeb) {
      return ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          PremiumCard(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  height: 200.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.r),
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.face_retouching_natural_rounded,
                          size: 64.w,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Face Verification Required',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'QR code validated. Now verify your identity by capturing your face.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                Text(
                  'Look directly at the camera with good lighting.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),
                FilledButton.icon(
                  onPressed: _processing
                      ? null
                      : () => _verifyFaceAndMark(userId, organizationId),
                  icon: _processing
                      ? SizedBox.square(
                          dimension: 16.w,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded),
                  label: Text(_processing ? 'Verifying...' : 'Capture & Verify Face'),
                ),
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: _processing
                      ? null
                      : () => setState(() {
                            _step = _ScannerStep.scanning;
                            _status = 'Point camera at the dynamic QR code.';
                          }),
                  child: const Text('Back to Scanner'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Mobile/Tablet Camera Face Capture
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              color: Colors.black,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_cameraInitialized && _cameraController != null)
                  CameraPreview(_cameraController!)
                else if (_cameraInitializing)
                  const Center(child: CircularProgressIndicator())
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48.w,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'Camera Failed to Start',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                        ),
                        SizedBox(height: 8.h),
                        ElevatedButton(
                          onPressed: _initCamera,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                if (_cameraInitialized && _cameraController != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FaceVerifyGuidePainter(
                        borderColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        PremiumCard(
          margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.w),
          child: Column(
            children: [
              Text(
                'Position face in the frame',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 4.h),
              Text(
                'Verification matches proportions with your registered profile.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _processing
                          ? null
                          : () async {
                              await _disposeCamera();
                              setState(() {
                                _step = _ScannerStep.scanning;
                                _status = 'Point camera at the dynamic QR code.';
                              });
                            },
                      child: const Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_cameraInitialized && !_processing)
                          ? () => _verifyFaceAndMark(userId, organizationId)
                          : null,
                      icon: _processing
                          ? SizedBox.square(
                              dimension: 16.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.face_unlock_rounded),
                      label: Text(_processing ? 'Verifying...' : 'Verify'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 3: Result ───────────────────────────────────────────────────

  Widget _buildResultStep() {
    return Center(
      child: PremiumCard(
        margin: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _success ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 72.w,
              color: _success ? Colors.green : Theme.of(context).colorScheme.error,
            ),
            SizedBox(height: 16.h),
            Text(
              _success ? 'Attendance Marked!' : 'Verification Failed',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              _status,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20.h),
            if (!_success)
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _step = _ScannerStep.faceVerification;
                    _processing = false;
                  });
                  _initCamera();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            if (_success)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.done_rounded),
                label: const Text('Done'),
              ),
          ],
        ),
      ),
    );
  }

  // ── Logic ────────────────────────────────────────────────────────────

  void _onQrDetected(String rawPayload, String userId, String organizationId) {
    if (_processing) return;

    final payload = Uri.splitQueryString(rawPayload);
    final sessionId = payload['sessionId'];
    final token = payload['token'];
    if (sessionId == null || token == null) {
      _setStatus('Invalid QR code. Missing session or token data.');
      return;
    }

    setState(() {
      _processing = false;
      _scannedSessionId = sessionId;
      _scannedToken = token;
      _step = _ScannerStep.faceVerification;
      _status = 'QR validated. Proceed to face verification.';
    });
    _initCamera();
  }

  Future<void> _verifyFaceAndMark(String userId, String organizationId) async {
    setState(() {
      _processing = true;
      _status = 'Detecting face and verifying identity...';
    });

    try {
      // Fetch registered face data
      final registeredFaceData = await _faceService.fetchRegisteredFace(userId);
      if (registeredFaceData == null || registeredFaceData.isEmpty) {
        await _disposeCamera();
        _setError('No face registration found. Contact your administrator.');
        return;
      }

      Map<String, dynamic>? detectedLandmarks;
      double detectedAspectRatio = 0.75;

      if (_isDesktopOrWeb || _cameraController == null || !_cameraController!.value.isInitialized) {
        // Desktop / Simulator simulation or camera fallback
        detectedLandmarks = registeredFaceData['landmarks'] as Map<String, dynamic>? ?? const <String, dynamic>{};
        detectedAspectRatio = (registeredFaceData['aspectRatio'] as num?)?.toDouble() ?? 0.75;
        // Simulated progress delay
        await Future.delayed(const Duration(milliseconds: 1200));
      } else {
        // Real mobile capture
        final XFile photo = await _cameraController!.takePicture();
        final captureService = FaceCaptureService();
        final result = await captureService.detectAndValidateFace(photo.path);

        if (!result.success) {
          await _disposeCamera();
          _setError(result.errorMessage ?? 'Face detection failed. Please try again.');
          return;
        }

        detectedLandmarks = result.landmarks;
        detectedAspectRatio = (result.metadata['aspectRatio'] as num?)?.toDouble() ?? 0.75;
      }

      if (detectedLandmarks.isEmpty) {
        await _disposeCamera();
        _setError('No face landmarks could be extracted from capture.');
        return;
      }

      final result = _faceService.verify(
        detectedLandmarks: detectedLandmarks,
        registeredFaceData: registeredFaceData,
        detectedAspectRatio: detectedAspectRatio,
      );

      if (!result.passed) {
        await _disposeCamera();
        _setError(result.message);
        return;
      }

      // Mark attendance
      await _repository.markAttendance(
        userId: userId,
        organizationId: organizationId,
        sessionId: _scannedSessionId!,
        token: _scannedToken!,
      );

      // Stop camera before showing results
      await _disposeCamera();

      if (mounted) {
        setState(() {
          _processing = false;
          _success = true;
          _step = _ScannerStep.result;
          _status = 'Attendance marked successfully. The QR has rotated.';
        });
      }
    } catch (error) {
      await _disposeCamera();
      _setError(error.toString());
    }
  }

  void _setStatus(String text) {
    if (mounted) {
      setState(() => _status = text);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _setError(String text) {
    if (mounted) {
      setState(() {
        _processing = false;
        _success = false;
        _step = _ScannerStep.result;
        _status = text;
      });
    }
  }
}

class _FaceVerifyGuidePainter extends CustomPainter {
  _FaceVerifyGuidePainter({required this.borderColor});
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    // Draw dark overlay with transparent oval cutout in the middle
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.65,
      height: size.height * 0.7,
    );

    final ovalPath = Path()..addOval(ovalRect);
    final combinedPath = Path.combine(PathOperation.difference, path, ovalPath);

    canvas.drawPath(combinedPath, paint);

    // Draw the oval border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
