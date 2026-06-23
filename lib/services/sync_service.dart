import 'package:flutter/foundation.dart';

import '../database/local_database.dart';
import 'api_service.dart';

class SyncService {
  SyncService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<int> syncOfflineCollections() async {
    try {
      final collections = await LocalDatabase.instance.getCollections();
      var successfulUploads = 0;

      for (final collection in collections) {
        try {
          final uploaded = await _apiService.createCollection(
            supplierId: collection.supplierId,
            clearKg: collection.clearKg,
            coloredKg: collection.coloredKg,
            condition: collection.condition,
          );

          if (uploaded) {
            successfulUploads += 1;
          } else {
            debugPrint(
              'Sync failed for collection ${collection.id ?? collection.supplierId}',
            );
          }
        } catch (error) {
          debugPrint(
            'Sync error for collection ${collection.id ?? collection.supplierId}: $error',
          );
        }
      }

      if (collections.isNotEmpty && successfulUploads == collections.length) {
        await LocalDatabase.instance.deleteCollections();
      }

      return successfulUploads;
    } catch (error) {
      debugPrint('Sync offline collections error: $error');
      return 0;
    }
  }
}
