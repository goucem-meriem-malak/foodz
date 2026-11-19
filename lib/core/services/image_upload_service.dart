import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/env.dart';

class ImageUploadException implements Exception {
  const ImageUploadException();
}

/// Sends a dish photo to the "upload-image" server function, which checks that
/// the caller is an admin or the owner before storing it. Returns the public link.
class ImageUploadService {
  ImageUploadService(this._auth);
  final FirebaseAuth _auth;

  bool get isConfigured => Env.uploadUrl.isNotEmpty;

  /// The server accepts only these three types and checks the first bytes too.
  static String? sniffMime(Uint8List b) {
    if (b.length > 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) return 'image/jpeg';
    if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4e && b[3] == 0x47) return 'image/png';
    if (b.length > 12 && String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  Future<String> upload(Uint8List bytes) async {
    final mime = sniffMime(bytes);
    final token = await _auth.currentUser?.getIdToken();
    if (mime == null || token == null) throw const ImageUploadException();
    final res = await http
        .post(
          Uri.parse(Env.uploadUrl),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': mime},
          body: bytes,
        )
        .timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) throw const ImageUploadException();
    final url = (jsonDecode(res.body) as Map<String, dynamic>)['url'];
    if (url is! String || !url.startsWith('https://')) throw const ImageUploadException();
    return url;
  }
}
