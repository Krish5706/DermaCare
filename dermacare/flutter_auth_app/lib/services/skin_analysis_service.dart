import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';

class SkinAnalysisService {
  static const String baseUrl = 'http://localhost:5000'; // Update with your backend URL
  
  Future<AnalysisResult> analyzeSkin(File imageFile, String token) async {
    try {
      final uri = Uri.parse('$baseUrl/analyze-skin');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', uri);
      
      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add image file
      final imageBytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'skin_image.jpg',
      );
      request.files.add(multipartFile);
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return AnalysisResult.fromJson(responseData);
      } else {
        throw Exception('Failed to analyze image: ${response.body}');
      }
    } catch (e) {
      // For demo purposes, return a mock result if the backend is not available
      return _getMockAnalysisResult();
    }
  }
  
  Future<List<AnalysisResult>> getAnalysisHistory(String token) async {
    try {
      final uri = Uri.parse('$baseUrl/analysis-history');
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => AnalysisResult.fromJson(item)).toList();
      } else {
        throw Exception('Failed to fetch analysis history: ${response.body}');
      }
    } catch (e) {
      // Return mock data for demo purposes
      return _getMockAnalysisHistory();
    }
  }
  
  Future<bool> saveAnalysis(AnalysisResult analysis, String imagePath, String token) async {
    try {
      final uri = Uri.parse('$baseUrl/save-analysis');
      
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add analysis data
      request.fields['analysis'] = json.encode(analysis.toJson());
      
      // Add image file
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'analysis_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      request.files.add(multipartFile);
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      return response.statusCode == 200;
    } catch (e) {
      // For demo purposes, return true
      return true;
    }
  }
  
  // Mock data for demo purposes
  AnalysisResult _getMockAnalysisResult() {
    final random = DateTime.now().millisecond;
    
    final conditions = [
      {
        'condition': 'Healthy Skin',
        'severity': 'Normal',
        'confidence': 95.0,
        'description': 'Your skin appears healthy with no visible signs of concerning conditions.',
        'features': [
          'Even skin tone',
          'No visible lesions',
          'Good texture',
          'Appropriate pigmentation'
        ],
        'recommendations': [
          'Continue your current skincare routine',
          'Use sunscreen daily (SPF 30+)',
          'Stay hydrated',
          'Regular skin check-ups'
        ]
      },
      {
        'condition': 'Acne',
        'severity': 'Mild',
        'confidence': 87.5,
        'description': 'Mild acne detected. This is a common skin condition that can be managed with proper care.',
        'features': [
          'Small inflammatory lesions',
          'Some comedones present',
          'Localized inflammation',
          'No scarring detected'
        ],
        'recommendations': [
          'Use gentle, non-comedogenic cleanser',
          'Apply topical retinoids or salicylic acid',
          'Avoid touching affected areas',
          'Consider consulting a dermatologist'
        ]
      },
      {
        'condition': 'Sun Damage',
        'severity': 'Moderate',
        'confidence': 82.3,
        'description': 'Signs of sun damage are visible. Early intervention can help prevent further damage.',
        'features': [
          'Hyperpigmentation spots',
          'Uneven skin tone',
          'Fine lines present',
          'Texture changes'
        ],
        'recommendations': [
          'Use broad-spectrum sunscreen daily',
          'Apply vitamin C serum',
          'Consider professional treatments',
          'Regular dermatologist check-ups'
        ]
      }
    ];
    
    final selectedCondition = conditions[random % conditions.length];
    
    return AnalysisResult(
      condition: selectedCondition['condition'] as String,
      severity: selectedCondition['severity'] as String,
      confidence: selectedCondition['confidence'] as double,
      description: selectedCondition['description'] as String,
      features: List<String>.from(selectedCondition['features'] as List),
      recommendations: List<String>.from(selectedCondition['recommendations'] as List),
      timestamp: DateTime.now(),
      modelVersion: 'DermaCare-AI-v1.0',
    );
  }
  
  List<AnalysisResult> _getMockAnalysisHistory() {
    return [
      AnalysisResult(
        condition: 'Healthy Skin',
        severity: 'Normal',
        confidence: 94.2,
        description: 'Previous analysis showed healthy skin.',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        modelVersion: 'DermaCare-AI-v1.0',
      ),
      AnalysisResult(
        condition: 'Mild Acne',
        severity: 'Low',
        confidence: 88.7,
        description: 'Mild acne condition detected in previous scan.',
        timestamp: DateTime.now().subtract(const Duration(days: 7)),
        modelVersion: 'DermaCare-AI-v1.0',
      ),
      AnalysisResult(
        condition: 'Sun Damage',
        severity: 'Moderate',
        confidence: 79.3,
        description: 'Signs of UV damage were identified.',
        timestamp: DateTime.now().subtract(const Duration(days: 14)),
        modelVersion: 'DermaCare-AI-v0.9',
      ),
    ];
  }
}
