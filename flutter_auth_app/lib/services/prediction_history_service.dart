import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';

class PredictionHistoryService {
  static String get _baseUrl => backendUrl;

  // Save a prediction with image to history (multipart + auth)
  static Future<void> savePrediction({
    required File image,
    required String prediction,
    required double confidence,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/history');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('image', image.path))
      ..fields['prediction'] = prediction
      ..fields['confidence'] = confidence.toString();

    final res = await req.send();
    if (res.statusCode != 201) {
      final body = await res.stream.bytesToString();
      throw Exception('Failed to save history (${res.statusCode}): $body');
    }
  }

  // Fetch authenticated user's history
  static Future<List<Map<String, dynamic>>> fetchHistory({
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl/history');
    final res = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    });
    if (res.statusCode != 200) {
      throw Exception('Failed to load history: ${res.statusCode}');
    }
    final List<dynamic> data = json.decode(res.body);
    return data.cast<Map<String, dynamic>>();
  }
}
