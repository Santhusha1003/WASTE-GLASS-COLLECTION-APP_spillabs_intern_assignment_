import 'package:dio/dio.dart';

import '../models/collection.dart';

class ApiService {
  ApiService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Dio get client => _dio;

  Future<void> syncCollections(List<CollectionModel> collections) async {
    // Placeholder for future backend sync.
    return Future<void>.value();
  }

  Future<void> fetchRoute() async {
    // Placeholder for future route API connection.
    return Future<void>.value();
  }
}
