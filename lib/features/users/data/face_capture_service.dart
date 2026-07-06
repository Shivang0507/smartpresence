import 'dart:io' show Platform, File;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart' show decodeImageFromList;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Result of a face capture and validation operation.
class FaceCaptureResult {
  const FaceCaptureResult({
    required this.success,
    required this.qualityScore,
    required this.landmarks,
    required this.metadata,
    this.errorMessage,
  });

  /// Whether a valid face was detected and passed quality checks.
  final bool success;

  /// Quality score from 0.0 to 1.0 based on detection confidence,
  /// head pose, and face size.
  final double qualityScore;

  /// Normalized face landmark positions (0.0-1.0 relative to image).
  /// Keys: leftEye, rightEye, noseBase, mouthLeft, mouthRight, mouthBottom
  final Map<String, List<double>> landmarks;

  /// Additional metadata about the capture.
  final Map<String, dynamic> metadata;

  /// Error message when [success] is false.
  final String? errorMessage;

  /// Converts to a map suitable for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'provider': metadata['provider'] ?? 'google_mlkit_face_detection',
      'qualityScore': qualityScore,
      'landmarks': landmarks.map((key, value) => MapEntry(key, value)),
      'pose': metadata['pose'] ?? 'front',
      'liveness': success ? 'passed' : 'failed',
      'capturedAt': DateTime.now().toIso8601String(),
      'headEulerAngleY': metadata['headEulerAngleY'] ?? 0.0,
      'headEulerAngleZ': metadata['headEulerAngleZ'] ?? 0.0,
      'faceBoundsRatio': metadata['faceBoundsRatio'] ?? 0.0,
    };
  }
}

/// Service that encapsulates face capture, ML Kit detection, landmark
/// extraction, quality scoring, and validation.
///
/// ## MVP Scope
/// This service captures a photo and runs Google ML Kit Face Detection
/// to extract face landmarks and validate quality. It does NOT perform:
/// - Face embedding generation (FaceNet / ArcFace)
/// - Liveness detection beyond head pose analysis
/// - Anti-spoofing (photo-of-photo detection)
///
/// ## Architecture for Future Upgrade
/// The [FaceCaptureResult] includes a `provider` field and extensible
/// `landmarks` structure. A future upgrade can:
/// 1. Add a `tflite_embedding` field alongside landmarks
/// 2. Swap the comparison algorithm without changing the data schema
/// 3. Add liveness detection as a plugin
class FaceCaptureService {
  /// Minimum quality score to pass validation.
  static const double minQualityScore = 0.65;

  /// Maximum acceptable head yaw angle (degrees).
  static const double maxYawAngle = 25.0;

  /// Maximum acceptable head pitch angle (degrees).
  static const double maxPitchAngle = 15.0;

  /// Minimum face bounding box as fraction of frame area.
  static const double minFaceBoundsRatio = 0.08;

  /// Whether ML Kit is available on the current platform.
  static bool get isMlKitAvailable {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Captures a face from the camera and validates it using ML Kit.
  ///
  /// On platforms where ML Kit is not available (desktop, web), returns
  /// a result with `provider: 'manual_photo'` and basic metadata.
  ///
  /// On mobile, this will:
  /// 1. Use the camera to capture an image
  /// 2. Run ML Kit Face Detection
  /// 3. Validate: exactly 1 face, acceptable pose, sufficient size
  /// 4. Extract and normalize landmarks
  /// 5. Calculate quality score
  ///
  /// The actual camera preview widget is handled by the calling screen.
  /// This service processes the captured image data.
  Future<FaceCaptureResult> processCapture({
    required double? headEulerAngleY,
    required double? headEulerAngleZ,
    required Map<String, List<double>>? landmarks,
    required double? faceBoundsRatio,
    required int faceCount,
    double aspectRatio = 0.75,
  }) async {
    // No face detected
    if (faceCount == 0) {
      return const FaceCaptureResult(
        success: false,
        qualityScore: 0,
        landmarks: {},
        metadata: {'provider': 'google_mlkit_face_detection'},
        errorMessage: 'No face detected. Please position your face in the frame.',
      );
    }

    // Multiple faces
    if (faceCount > 1) {
      return FaceCaptureResult(
        success: false,
        qualityScore: 0,
        landmarks: const {},
        metadata: const {'provider': 'google_mlkit_face_detection'},
        errorMessage: 'Multiple faces detected ($faceCount). Only one face is allowed.',
      );
    }

    // Validate head pose
    final yaw = (headEulerAngleY ?? 0).abs();
    final pitch = (headEulerAngleZ ?? 0).abs();
    if (yaw > maxYawAngle) {
      return FaceCaptureResult(
        success: false,
        qualityScore: 0.3,
        landmarks: landmarks ?? const {},
        metadata: {
          'provider': 'google_mlkit_face_detection',
          'headEulerAngleY': headEulerAngleY,
          'headEulerAngleZ': headEulerAngleZ,
        },
        errorMessage:
            'Head turned too far (${yaw.round()}°). Please face the camera directly.',
      );
    }
    if (pitch > maxPitchAngle) {
      return FaceCaptureResult(
        success: false,
        qualityScore: 0.3,
        landmarks: landmarks ?? const {},
        metadata: {
          'provider': 'google_mlkit_face_detection',
          'headEulerAngleY': headEulerAngleY,
          'headEulerAngleZ': headEulerAngleZ,
        },
        errorMessage:
            'Head tilted too far (${pitch.round()}°). Please hold your head straight.',
      );
    }

    // Validate face size
    final boundsRatio = faceBoundsRatio ?? 0;
    if (boundsRatio < minFaceBoundsRatio) {
      return FaceCaptureResult(
        success: false,
        qualityScore: 0.4,
        landmarks: landmarks ?? const {},
        metadata: {
          'provider': 'google_mlkit_face_detection',
          'faceBoundsRatio': boundsRatio,
        },
        errorMessage: 'Face is too small. Please move closer to the camera.',
      );
    }

    // Calculate quality score
    final poseScore = 1.0 - (yaw / maxYawAngle + pitch / maxPitchAngle) / 2;
    final sizeScore = min(1.0, boundsRatio / 0.25); // 25% of frame = perfect
    final landmarkScore = (landmarks?.length ?? 0) >= 4 ? 1.0 : 0.6;
    final qualityScore = (poseScore * 0.4 + sizeScore * 0.3 + landmarkScore * 0.3);

    if (qualityScore < minQualityScore) {
      return FaceCaptureResult(
        success: false,
        qualityScore: qualityScore,
        landmarks: landmarks ?? const {},
        metadata: {
          'provider': 'google_mlkit_face_detection',
          'headEulerAngleY': headEulerAngleY,
          'headEulerAngleZ': headEulerAngleZ,
          'faceBoundsRatio': boundsRatio,
        },
        errorMessage:
            'Face quality too low (${(qualityScore * 100).round()}%). Improve lighting and position.',
      );
    }

    // Determine pose description
    String pose = 'front';
    if (yaw > 10) pose = 'slightly_turned';
    if (pitch > 8) pose = 'slightly_tilted';

    return FaceCaptureResult(
      success: true,
      qualityScore: qualityScore,
      landmarks: landmarks ?? const {},
      metadata: {
        'provider': 'google_mlkit_face_detection',
        'headEulerAngleY': headEulerAngleY ?? 0.0,
        'headEulerAngleZ': headEulerAngleZ ?? 0.0,
        'faceBoundsRatio': boundsRatio,
        'pose': pose,
        'aspectRatio': aspectRatio,
      },
    );
  }
  
  /// Detects and validates a face in a captured image file.
  Future<FaceCaptureResult> detectAndValidateFace(String filePath) async {
    if (!isMlKitAvailable) {
      return createDesktopFallback();
    }

    final options = FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    );
    final faceDetector = FaceDetector(options: options);

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final List<Face> faces = await faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        return const FaceCaptureResult(
          success: false,
          qualityScore: 0,
          landmarks: {},
          metadata: {'provider': 'google_mlkit_face_detection'},
          errorMessage: 'No face detected. Please position your face in the frame.',
        );
      }

      if (faces.length > 1) {
        return FaceCaptureResult(
          success: false,
          qualityScore: 0,
          landmarks: const {},
          metadata: const {'provider': 'google_mlkit_face_detection'},
          errorMessage: 'Multiple faces detected (${faces.length}). Only one face is allowed.',
        );
      }

      final face = faces.first;

      // Read image dimensions
      final bytes = await File(filePath).readAsBytes();
      final image = await decodeImageFromList(bytes);
      double width = image.width.toDouble();
      double height = image.height.toDouble();

      // ML Kit coordinates are relative to the oriented image.
      // If the image is stored in landscape but oriented in portrait,
      // we must swap the dimensions to match the oriented space.
      if (width > height) {
        final faceBottom = face.boundingBox.bottom;
        final faceRight = face.boundingBox.right;
        if (faceRight > width || faceBottom > height || face.boundingBox.height > face.boundingBox.width) {
          final temp = width;
          width = height;
          height = temp;
        }
      }

      // Extract and normalize landmarks
      final Map<String, List<double>> landmarksMap = {};
      final landmarkTypes = {
        'leftEye': FaceLandmarkType.leftEye,
        'rightEye': FaceLandmarkType.rightEye,
        'noseBase': FaceLandmarkType.noseBase,
        'mouthLeft': FaceLandmarkType.leftMouth,
        'mouthRight': FaceLandmarkType.rightMouth,
        'mouthBottom': FaceLandmarkType.bottomMouth,
      };

      for (final entry in landmarkTypes.entries) {
        final landmark = face.landmarks[entry.value];
        if (landmark != null) {
          landmarksMap[entry.key] = [
            landmark.position.x / width,
            landmark.position.y / height,
          ];
        }
      }

      final double faceArea = face.boundingBox.width * face.boundingBox.height;
      final double imageArea = width * height;
      final double faceBoundsRatio = faceArea / imageArea;

      return await processCapture(
        headEulerAngleY: face.headEulerAngleY,
        headEulerAngleZ: face.headEulerAngleZ,
        landmarks: landmarksMap,
        faceBoundsRatio: faceBoundsRatio,
        faceCount: faces.length,
        aspectRatio: height > 0 ? width / height : 0.75,
      );
    } catch (e) {
      return FaceCaptureResult(
        success: false,
        qualityScore: 0,
        landmarks: const {},
        metadata: const {'provider': 'google_mlkit_face_detection'},
        errorMessage: 'Face processing error: $e',
      );
    } finally {
      await faceDetector.close();
    }
  }

  /// Creates a desktop/web fallback result with basic metadata.
  FaceCaptureResult createDesktopFallback() {
    return FaceCaptureResult(
      success: true,
      qualityScore: 0.7,
      landmarks: const {},
      metadata: {
        'provider': 'manual_photo',
        'capturedAt': DateTime.now().toIso8601String(),
        'note':
            'ML Kit unavailable on this platform. Photo stored as proof. '
            'Face landmarks not available.',
      },
    );
  }
}
