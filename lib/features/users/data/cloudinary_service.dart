import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CloudinaryService {
  static const String cloudName = 'dvc7rmdyt';
  static const String uploadPreset = 'smartpresence_upload';
  static const String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Compress an image using flutter_image_compress.
  /// If running on web or desktop (or compression fails), returns the original file.
  Future<String> compressImage(String filePath, {required int minSizeKb, required int maxSizeKb}) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File does not exist: $filePath');
    }

    final fileSizeKb = file.lengthSync() / 1024;
    debugPrint('COMPRESSION: Original file size: ${fileSizeKb.toStringAsFixed(1)} KB. Target range: $minSizeKb - $maxSizeKb KB');

    // If it's already in the target range or smaller, do not compress
    if (fileSizeKb <= maxSizeKb) {
      debugPrint('COMPRESSION: File is already within or below target size. Skipping.');
      return filePath;
    }

    // Check if platform supports flutter_image_compress (native plugin)
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      debugPrint('COMPRESSION: Native image compression not supported on this platform. Skipping.');
      return filePath;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      int quality = 85;
      File? compressedFile;

      while (quality >= 50) {
        debugPrint('COMPRESSION: Trying quality $quality');
        final result = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          quality: quality,
          format: CompressFormat.jpeg,
        );

        if (result != null) {
          compressedFile = File(result.path);
          final newSizeKb = compressedFile.lengthSync() / 1024;
          debugPrint('COMPRESSION: Quality $quality resulted in size: ${newSizeKb.toStringAsFixed(1)} KB');
          if (newSizeKb <= maxSizeKb) {
            return compressedFile.path;
          }
        }
        quality -= 15;
      }

      if (compressedFile != null) {
        return compressedFile.path;
      }
      return filePath;
    } catch (e) {
      debugPrint('COMPRESSION ERROR: $e. Returning original file.');
      return filePath;
    }
  }

  /// Upload a profile photo. Target size: 100KB - 300KB
  Future<String> uploadProfilePhoto(String filePath, String organizationId) async {
    final compressedPath = await compressImage(filePath, minSizeKb: 100, maxSizeKb: 300);
    return retryUpload(() async {
      return _uploadToCloudinary(
        filePath: compressedPath,
        folder: 'smartpresence/organizations/$organizationId/profiles',
      );
    });
  }

  /// Upload a face image. Target size: 150KB - 400KB
  Future<String> uploadFaceImage(String filePath, String organizationId) async {
    final compressedPath = await compressImage(filePath, minSizeKb: 150, maxSizeKb: 400);
    return retryUpload(() async {
      return _uploadToCloudinary(
        filePath: compressedPath,
        folder: 'smartpresence/organizations/$organizationId/faces',
      );
    });
  }

  /// Send Multipart request to Cloudinary.
  Future<String> _uploadToCloudinary({
    required String filePath,
    required String folder,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Upload file does not exist: $filePath');
    }

    final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = folder;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    debugPrint('CLOUDINARY: Uploading $filePath to folder $folder');
    final response = await request.send().timeout(const Duration(seconds: 30));
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> jsonResponse = jsonDecode(responseBody);
      final secureUrl = jsonResponse['secure_url'] as String?;
      if (secureUrl != null) {
        debugPrint('CLOUDINARY SUCCESS: $secureUrl');
        return secureUrl;
      } else {
        throw Exception('Cloudinary response missing secure_url: $responseBody');
      }
    } else {
      throw Exception('Cloudinary upload failed with status ${response.statusCode}: $responseBody');
    }
  }

  /// Retries the upload callback once in case of failure.
  Future<String> retryUpload(Future<String> Function() uploadCallback) async {
    try {
      return await uploadCallback();
    } catch (firstError) {
      debugPrint('CLOUDINARY WARNING: First upload attempt failed: $firstError. Retrying once...');
      try {
        await Future.delayed(const Duration(seconds: 1));
        return await uploadCallback();
      } catch (secondError) {
        debugPrint('CLOUDINARY ERROR: Second upload attempt failed: $secondError');
        throw Exception('Upload failed after retry. Primary error: $firstError. Secondary error: $secondError');
      }
    }
  }
}
