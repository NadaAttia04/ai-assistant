import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AIModelsService {
  AIModelsService._();

  static Uri _uri(String path) {
    final base =
        AppConfig.aiBaseUrl.endsWith('/')
            ? AppConfig.aiBaseUrl.substring(0, AppConfig.aiBaseUrl.length - 1)
            : AppConfig.aiBaseUrl;
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$base/$normalizedPath');
  }

  static Future<AIModelsAvailability> getModelsStatus() async {
    final request = http.Request('GET', _uri('/models/status'));
    final response = await _send(request);
    final data = _decodeBody(response.body);
    return AIModelsAvailability.fromJson(data);
  }

  static Future<AIModelPrediction> predictColonImage(File image) {
    return _predictImage('/predict-pathology', image);
  }

  static Future<AIModelPrediction> predictBreastImage(File image) {
    return _predictImage('/predict-breast', image);
  }

  static Future<AIModelPrediction> _predictImage(
    String endpoint,
    File image,
  ) async {
    final request = http.MultipartRequest('POST', _uri(endpoint))
      ..files.add(await http.MultipartFile.fromPath('file', image.path));
    final response = await _send(request);
    final data = _decodeBody(response.body);
    return AIModelPrediction.fromJson(data);
  }

  static Future<http.Response> _send(http.BaseRequest request) async {
    final client = http.Client();
    try {
      final streamed = await client
          .send(request)
          .timeout(AppConfig.connectTimeout);
      return http.Response.fromStream(
        streamed,
      ).timeout(AppConfig.receiveTimeout);
    } on TimeoutException {
      rethrow;
    } finally {
      client.close();
    }
  }

  static Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
  }
}

class AIModelsAvailability {
  final bool? colonPathologyReady;
  final bool? breastCancerReady;

  const AIModelsAvailability({
    required this.colonPathologyReady,
    required this.breastCancerReady,
  });

  factory AIModelsAvailability.fromJson(Map<String, dynamic> json) {
    final models = json['models'];
    final colon =
        models is Map<String, dynamic> ? models['colon_pathology'] : null;
    final breast =
        models is Map<String, dynamic> ? models['breast_cancer'] : null;

    return AIModelsAvailability(
      colonPathologyReady: _readReady(colon),
      breastCancerReady: _readReady(breast),
    );
  }

  static bool? _readReady(Object? modelJson) {
    if (modelJson is! Map<String, dynamic>) return null;
    final ready = modelJson['ready'];
    return ready is bool ? ready : null;
  }
}

class AIModelPrediction {
  final bool success;
  final String? predictedClass;
  final double confidence;
  final List<AITopPrediction> topPredictions;
  final String message;

  const AIModelPrediction({
    required this.success,
    required this.predictedClass,
    required this.confidence,
    required this.topPredictions,
    required this.message,
  });

  factory AIModelPrediction.fromJson(Map<String, dynamic> json) {
    final predictions = json['top_predictions'];
    return AIModelPrediction(
      success: json['success'] == true,
      predictedClass: json['predicted_class']?.toString(),
      confidence: _asDouble(json['confidence']),
      topPredictions:
          predictions is List
              ? predictions
                  .whereType<Map<String, dynamic>>()
                  .map(AITopPrediction.fromJson)
                  .toList()
              : const <AITopPrediction>[],
      message: json['message']?.toString() ?? '',
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class AITopPrediction {
  final String className;
  final double confidence;

  const AITopPrediction({required this.className, required this.confidence});

  factory AITopPrediction.fromJson(Map<String, dynamic> json) {
    return AITopPrediction(
      className: json['class']?.toString() ?? 'Unknown',
      confidence: AIModelPrediction._asDouble(json['confidence']),
    );
  }
}
