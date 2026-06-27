import 'dart:convert';
import 'package:http/http.dart' as http;

class SwarmSpaceException implements Exception {
  final String message;
  const SwarmSpaceException(this.message);
  @override
  String toString() => 'SwarmSpaceException: $message';
}

class SwarmSpaceService {
  static const _endpoint =
      'https://swarmspace-mcp-server.orbitalai.workers.dev/mcp';

  const SwarmSpaceService({required this.apiKey});
  final String apiKey;

  Future<String> deepResearch(String query) async {
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'id': '1',
      'method': 'tools/call',
      'params': {
        'name': 'deep_research',
        'arguments': {'query': query},
      },
    });

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw SwarmSpaceException(
          'HTTP ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final error = json['error'];
    if (error != null) {
      throw SwarmSpaceException(
          error['message'] as String? ?? 'Unknown JSON-RPC error');
    }

    final result = json['result'] as Map<String, dynamic>?;
    final content = result?['content'] as List<dynamic>?;
    final text = content?.firstOrNull?['text'] as String?;
    if (text == null) {
      throw const SwarmSpaceException('No text content in response');
    }
    return text;
  }
}
