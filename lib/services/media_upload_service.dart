import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class UploadedMedia {
  const UploadedMedia({
    required this.secureUrl,
    required this.publicId,
    required this.deleteToken,
  });

  final String secureUrl;
  final String? publicId;
  final String? deleteToken;
}

class MediaUploadService {
  const MediaUploadService._();

  static const String _defaultCloudName = 'dq2mfprl4';

  // Provide these with --dart-define at run time.
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: _defaultCloudName,
  );
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'paradox_unsigned_upload',
  );

  static bool get isConfigured => cloudName.isNotEmpty && uploadPreset.isNotEmpty;

  static Future<UploadedMedia> uploadFile({required File file, required String mediaType}) async {
    if (!isConfigured) {
      throw Exception('Cloudinary not configured.');
    }

    final resourceType = mediaType == 'video' ? 'video' : 'image';
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Upload failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = data['secure_url'] as String?;
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('Upload failed: secure_url missing in response.');
    }

    return UploadedMedia(
      secureUrl: secureUrl,
      publicId: data['public_id'] as String?,
      deleteToken: data['delete_token'] as String?,
    );
  }

  static Future<void> deleteUploadedAsset(String deleteToken) async {
    if (deleteToken.trim().isEmpty) {
      return;
    }

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/delete_by_token');
    final response = await http.post(url, body: {'token': deleteToken});

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudinary delete failed (${response.statusCode}): ${response.body}');
    }
  }
}
