import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'https://example.com/api/'});

  Future<dynamic> getRequest(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.get(uri);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('GET $uri failed: ${res.statusCode}');
  }

  Future<dynamic> postRequest(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(uri, body: jsonEncode(body), headers: {
      'Content-Type': 'application/json',
    });
    if (res.statusCode == 200 || res.statusCode == 201)
      return jsonDecode(res.body);
    throw Exception('POST $uri failed: ${res.statusCode}');
  }
}
