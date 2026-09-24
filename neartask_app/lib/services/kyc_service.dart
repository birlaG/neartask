import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class KycSubmission {
  final String id;
  final String status;
  final String idDocumentUrl;
  final String selfieUrl;
  final String? adminNote;
  final String createdAt;

  KycSubmission({
    required this.id,
    required this.status,
    required this.idDocumentUrl,
    required this.selfieUrl,
    this.adminNote,
    required this.createdAt,
  });

  factory KycSubmission.fromJson(Map<String, dynamic> json) => KycSubmission(
        id: json['id'],
        status: json['status'],
        idDocumentUrl: json['idDocumentUrl'],
        selfieUrl: json['selfieUrl'],
        adminNote: json['adminNote'],
        createdAt: json['createdAt'],
      );
}

/// Separate from ApiClient because this needs multipart/form-data, not JSON.
class KycService {
  final String? token;
  KycService(this.token);

  Future<KycSubmission> submit({required File idDocument, required File selfie}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/kyc/submit');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('idDocument', idDocument.path));
    request.files.add(await http.MultipartFile.fromPath('selfie', selfie.path));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final body = res.body.isNotEmpty ? jsonDecode(res.body) : {};
      throw Exception(body['message'] ?? 'KYC submission failed (${streamed.statusCode})');
    }
    return KycSubmission.fromJson(jsonDecode(res.body));
  }

  Future<KycSubmission?> latest() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/kyc/me'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200 || res.body.isEmpty || res.body == 'null') return null;
    return KycSubmission.fromJson(jsonDecode(res.body));
  }
}
