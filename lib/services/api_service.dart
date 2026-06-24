import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  ApiService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'http://10.0.2.2:5255',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Content-Type': 'application/json'},
            ),
          );

  final Dio _dio;

  Dio get client => _dio;

  Future<List<dynamic>> getSuppliers() async {
    try {
      final response = await _dio.get('/api/Suppliers');
      return _readList(response.data);
    } catch (error) {
      debugPrint('API getSuppliers error: $error');
      return [];
    }
  }

  Future<List<dynamic>> getTodaySuppliers() async {
    try {
      final response = await _dio.get('/api/Suppliers/today');
      return _readList(response.data);
    } catch (error) {
      debugPrint('API getTodaySuppliers error: $error');
      return [];
    }
  }

  Future<List<dynamic>> getCollections() async {
    try {
      final response = await _dio.get('/api/Collections');
      return _readList(response.data);
    } catch (error) {
      debugPrint('API getCollections error: $error');
      return [];
    }
  }

  Future<Map<String, dynamic>> getReport() async {
    try {
      final response = await _dio.get('/api/Report');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    } catch (error) {
      debugPrint('API getReport error: $error');
      return {};
    }
  }

  Future<Map<String, dynamic>> getTodayRoute() async {
    try {
      final response = await _dio.get('/api/Routes/today');

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }

      return Map<String, dynamic>.from(response.data);
    } catch (error) {
      debugPrint('API getTodayRoute error: $error');
      return {};
    }
  }

  Future<Map<String, dynamic>> getRouteByDate(String date) async {
    try {
      final response = await _dio.get('/api/Routes/date/$date');

      if (response.data is Map<String, dynamic>) {
        return response.data;
      }

      return Map<String, dynamic>.from(response.data);
    } catch (error) {
      debugPrint('API getRouteByDate error: $error');
      return {};
    }
  }

  Future<bool> createCollection({
    required String supplierId,
    required double clearKg,
    required double coloredKg,
    required String condition,
  }) async {
    try {
      final response = await _dio.post(
        '/api/Collections',
        data: {
          'supplierId': supplierId,
          'clearKg': clearKg,
          'coloredKg': coloredKg,
          'condition': condition,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (error) {
      debugPrint('API createCollection error: $error');
      return false;
    }
  }

  List<dynamic> _readList(dynamic data) {
    if (data is List) {
      return data;
    }
    return [];
  }
}
