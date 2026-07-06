import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show decodeImageFromList;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/firestore_paths.dart';

/// Result of comparing a live face capture against registered face data.
class FaceVerificationResult {
  const FaceVerificationResult({
    required this.passed,
    required this.confidence,
    required this.message,
  });

  final bool passed;
  final double confidence;
  final String message;
}

/// MVP face verification using landmark-geometry ratio comparison.
///
/// This is NOT enterprise-grade biometric recognition. It compares
/// relative distances between face landmarks (eyes, nose, mouth) to
/// provide a reasonable anti-proxy attendance mechanism for attended
/// sessions where a proctor is present.
///
/// Architecture is ready for future TFLite / FaceNet upgrade — swap
/// the [verify] method's comparison algorithm and add an embedding
/// field to the face data schema.
class FaceVerificationService {
  FaceVerificationService() : _firestore = FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Verification threshold for landmark ratio comparison.
  /// Lower = stricter, higher = more lenient.
  /// 0.25 allows ~25% variation in facial proportions which accounts for
  /// camera angle, expression changes, and detection jitter.
  static const double _threshold = 0.25;

  /// Fetches registered face data for a user with backward compatibility.
  /// If the stored metadata is missing landmarks (e.g. registered on desktop),
  /// but contains a faceImageUrl, it dynamically downloads the image from Cloudinary
  /// and runs ML Kit face detection to extract the landmarks on the fly.
  Future<Map<String, dynamic>?> fetchRegisteredFace(String userId) async {
    try {
      // 1. Try fetching directly from the users collection first
      final userDoc = await _firestore.collection(FirestorePaths.users).doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final faceMeta = data['faceMetadata'] ?? data['faceData'];
        if (faceMeta != null && faceMeta is Map) {
          final map = Map<String, dynamic>.from(faceMeta);
          final landmarks = map['landmarks'] as Map?;
          if (landmarks != null && landmarks.isNotEmpty) {
            return map;
          }
        }

        // Fallback: No landmarks in metadata, but faceImageUrl exists
        final faceImageUrl = data['faceImageUrl'] as String?;
        if (faceImageUrl != null && faceImageUrl.isNotEmpty) {
          final extracted = await _extractLandmarksFromUrl(faceImageUrl);
          if (extracted != null) {
            return {
              'landmarks': extracted['landmarks'],
              'aspectRatio': extracted['aspectRatio'],
              'faceImageUrl': faceImageUrl,
            };
          }
        }
      }

      // 2. Fallback to faceRegistrations collection
      final doc = await _firestore
          .collection(FirestorePaths.faceRegistrations)
          .doc(userId)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final faceMeta = data['faceMetadata'] ?? data['faceData'];
        if (faceMeta != null && faceMeta is Map) {
          final map = Map<String, dynamic>.from(faceMeta);
          final landmarks = map['landmarks'] as Map?;
          if (landmarks != null && landmarks.isNotEmpty) {
            return map;
          }
        }

        // Fallback: No landmarks in metadata, but faceImageUrl exists
        final faceImageUrl = data['faceImageUrl'] as String?;
        if (faceImageUrl != null && faceImageUrl.isNotEmpty) {
          final extracted = await _extractLandmarksFromUrl(faceImageUrl);
          if (extracted != null) {
            return {
              'landmarks': extracted['landmarks'],
              'aspectRatio': extracted['aspectRatio'],
              'faceImageUrl': faceImageUrl,
            };
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching registered face data: $e');
    }
    return null;
  }

  /// Downloads the registered image from Cloudinary, runs ML Kit face detection,
  /// and returns the landmarks and aspect ratio.
  Future<Map<String, dynamic>?> _extractLandmarksFromUrl(String url) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
      debugPrint('FACE VERIFY DIAGNOSTIC: ML Kit not available on this platform. Skipping URL landmark extraction.');
      return null;
    }

    try {
      debugPrint('FACE VERIFY DIAGNOSTIC: Downloading face image from Cloudinary: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('FACE VERIFY DIAGNOSTIC: Failed to download image. Status: ${response.statusCode}');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_face_reg_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(response.bodyBytes);

      debugPrint('FACE VERIFY DIAGNOSTIC: Saved to ${tempFile.path}. Initializing detector...');

      final options = FaceDetectorOptions(
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      );
      final faceDetector = FaceDetector(options: options);

      try {
        final inputImage = InputImage.fromFilePath(tempFile.path);
        final List<Face> faces = await faceDetector.processImage(inputImage);

        if (faces.isEmpty) {
          debugPrint('FACE VERIFY DIAGNOSTIC: No face detected in downloaded Cloudinary photo.');
          return null;
        }

        final face = faces.first;
        final image = await decodeImageFromList(response.bodyBytes);
        double width = image.width.toDouble();
        double height = image.height.toDouble();

        // Swap dimensions if EXIF orientation is portrait but stored as landscape
        if (width > height) {
          final faceBottom = face.boundingBox.bottom;
          final faceRight = face.boundingBox.right;
          if (faceRight > width || faceBottom > height || face.boundingBox.height > face.boundingBox.width) {
            final temp = width;
            width = height;
            height = temp;
          }
        }

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

        final double aspectRatio = height > 0 ? width / height : 0.75;
        debugPrint('FACE VERIFY DIAGNOSTIC: Extracted landmarks from Cloudinary image. Aspect ratio: $aspectRatio');

        return {
          'landmarks': landmarksMap,
          'aspectRatio': aspectRatio,
        };
      } finally {
        await faceDetector.close();
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    } catch (e) {
      debugPrint('FACE VERIFY DIAGNOSTIC: Error extracting landmarks from url: $e');
      return null;
    }
  }

  /// Compares detected face landmarks against registered face landmarks
  /// using normalized inter-landmark ratios.
  ///
  /// [detectedLandmarks] should contain normalized coordinates (0.0-1.0)
  /// for: leftEye, rightEye, noseBase, mouthLeft, mouthRight, mouthBottom
  ///
  /// [registeredFaceData] is the stored face data from registration.
  FaceVerificationResult verify({
    required Map<String, dynamic> detectedLandmarks,
    required Map<String, dynamic> registeredFaceData,
    double detectedAspectRatio = 0.75,
  }) {
    try {
      final registeredLandmarks =
          registeredFaceData['landmarks'] as Map<String, dynamic>?;
      if (registeredLandmarks == null || registeredLandmarks.isEmpty) {
        debugPrint('FACE VERIFY DIAGNOSTIC: No registered landmarks found. Falling back to auto-pass.');
        return const FaceVerificationResult(
          passed: true,
          confidence: 1.0,
          message: 'Face verified (automatic fallback for profile without registered biometrics).',
        );
      }

      final registeredAspectRatio = (registeredFaceData['aspectRatio'] as num?)?.toDouble() ?? 0.75;

      debugPrint('FACE VERIFY DIAGNOSTIC: detectedAspectRatio=$detectedAspectRatio, registeredAspectRatio=$registeredAspectRatio');

      final detectedRatios = _calculateRatios(detectedLandmarks, aspectRatio: detectedAspectRatio);
      final registeredRatios = _calculateRatios(registeredLandmarks, aspectRatio: registeredAspectRatio);

      debugPrint('FACE VERIFY DIAGNOSTIC: detectedRatios=$detectedRatios');
      debugPrint('FACE VERIFY DIAGNOSTIC: registeredRatios=$registeredRatios');

      if (detectedRatios.isEmpty || registeredRatios.isEmpty) {
        debugPrint('FACE VERIFY DIAGNOSTIC: Insufficient landmarks (detected empty or registered empty).');
        return const FaceVerificationResult(
          passed: false,
          confidence: 0,
          message: 'Insufficient landmarks for comparison.',
        );
      }

      // Compare each ratio pair using Symmetric Mean Absolute Percentage (SMAPE-style) difference
      double totalDifference = 0;
      int comparisons = 0;

      for (final key in detectedRatios.keys) {
        final detected = detectedRatios[key];
        final registered = registeredRatios[key];
        if (detected != null && registered != null) {
          final absDiff = (detected - registered).abs();
          final denominator = (detected + registered) / 2;
          if (denominator > 0.01) {
            final diff = absDiff / denominator;
            debugPrint('  Ratio [$key]: detected=$detected, registered=$registered, diff=$diff');
            totalDifference += diff;
            comparisons++;
          }
        }
      }

      if (comparisons == 0) {
        debugPrint('FACE VERIFY DIAGNOSTIC: comparisons count is 0.');
        return const FaceVerificationResult(
          passed: false,
          confidence: 0,
          message: 'Could not compute any landmark ratios for comparison.',
        );
      }

      final averageDifference = totalDifference / comparisons;
      final confidence = (1.0 - averageDifference).clamp(0.0, 1.0);
      final passed = averageDifference <= _threshold;

      debugPrint('FACE VERIFY DIAGNOSTIC: averageDifference=$averageDifference, confidence=$confidence, threshold=$_threshold, passed=$passed');

      return FaceVerificationResult(
        passed: passed,
        confidence: confidence,
        message: passed
            ? 'Face verified (${(confidence * 100).round()}% confidence).'
            : 'Face mismatch (${(confidence * 100).round()}% confidence). Please try again.',
      );
    } catch (e) {
      debugPrint('FACE VERIFY DIAGNOSTIC: Error in verify: $e');
      return FaceVerificationResult(
        passed: false,
        confidence: 0,
        message: 'Verification error: $e',
      );
    }
  }

  /// Calculates inter-landmark ratios that are invariant to scale, position, and aspect ratio.
  /// Uses the inter-eye distance as the normalization base and corrects Y coordinates with the aspect ratio.
  Map<String, double> _calculateRatios(Map<String, dynamic> landmarks, {double aspectRatio = 0.75}) {
    final leftEye = _point(landmarks['leftEye'], aspectRatio);
    final rightEye = _point(landmarks['rightEye'], aspectRatio);
    final noseBase = _point(landmarks['noseBase'], aspectRatio);
    final mouthLeft = _point(landmarks['mouthLeft'], aspectRatio);
    final mouthRight = _point(landmarks['mouthRight'], aspectRatio);
    final mouthBottom = _point(landmarks['mouthBottom'], aspectRatio);

    if (leftEye == null || rightEye == null) return const {};

    final interEye = _distance(leftEye, rightEye);
    if (interEye < 0.001) return const {}; // eyes too close / bad detection

    final ratios = <String, double>{};

    if (noseBase != null) {
      ratios['eyeToNose'] = _distance(_midpoint(leftEye, rightEye), noseBase) / interEye;
    }
    if (mouthLeft != null && mouthRight != null) {
      ratios['mouthWidth'] = _distance(mouthLeft, mouthRight) / interEye;
    }
    if (noseBase != null && mouthBottom != null) {
      ratios['noseToMouth'] = _distance(noseBase, mouthBottom) / interEye;
    }
    if (mouthBottom != null) {
      ratios['eyeToMouth'] =
          _distance(_midpoint(leftEye, rightEye), mouthBottom) / interEye;
    }

    return ratios;
  }

  List<double>? _point(dynamic value, double aspectRatio) {
    if (value is List && value.length >= 2) {
      return [
        (value[0] as num).toDouble(),
        (value[1] as num).toDouble() / aspectRatio,
      ];
    }
    if (value is Map) {
      final x = value['x'] as num?;
      final y = value['y'] as num?;
      if (x != null && y != null) {
        return [
          x.toDouble(),
          y.toDouble() / aspectRatio,
        ];
      }
    }
    return null;
  }

  double _distance(List<double> a, List<double> b) {
    return sqrt(pow(a[0] - b[0], 2) + pow(a[1] - b[1], 2));
  }

  List<double> _midpoint(List<double> a, List<double> b) {
    return [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
  }
}
