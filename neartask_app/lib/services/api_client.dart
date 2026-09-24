import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) => Uri.parse(
        '${ApiConfig.baseUrl}$path',
      ).replace(queryParameters: query?.map((k, v) => MapEntry(k, v.toString())));

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await http.get(_uri(path, query), headers: _headers);
    return _handle(res);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final res = await http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {}));
    return _handle(res);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) async {
    final res = await http.patch(_uri(path), headers: _headers, body: jsonEncode(body ?? {}));
    return _handle(res);
  }

  dynamic _handle(http.Response res) {
    final decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 200 && res.statusCode < 300) return decoded;
    final message = (decoded is Map && decoded['message'] != null)
        ? (decoded['message'] is List ? decoded['message'].join(', ') : decoded['message'].toString())
        : 'Request failed (${res.statusCode})';
    throw ApiException(message);
  }
}
