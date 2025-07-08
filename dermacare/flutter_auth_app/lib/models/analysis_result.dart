class AnalysisResult {
  final String condition;
  final String severity;
  final double confidence;
  final String? description;
  final List<String>? features;
  final List<String>? recommendations;
  final DateTime timestamp;
  final String? modelVersion;

  AnalysisResult({
    required this.condition,
    required this.severity,
    required this.confidence,
    this.description,
    this.features,
    this.recommendations,
    required this.timestamp,
    this.modelVersion,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      condition: json['condition'] ?? 'Unknown',
      severity: json['severity'] ?? 'Unknown',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      description: json['description'],
      features: json['features'] != null 
          ? List<String>.from(json['features'])
          : null,
      recommendations: json['recommendations'] != null
          ? List<String>.from(json['recommendations'])
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      modelVersion: json['model_version'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'condition': condition,
      'severity': severity,
      'confidence': confidence,
      'description': description,
      'features': features,
      'recommendations': recommendations,
      'timestamp': timestamp.toIso8601String(),
      'model_version': modelVersion,
    };
  }

  @override
  String toString() {
    return 'AnalysisResult(condition: $condition, severity: $severity, confidence: $confidence)';
  }
}
