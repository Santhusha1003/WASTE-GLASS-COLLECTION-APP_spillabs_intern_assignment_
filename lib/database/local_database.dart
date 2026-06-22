import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/collection.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'waste_glass.db');
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE collections(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplierId TEXT NOT NULL,
            clearKg REAL NOT NULL,
            coloredKg REAL NOT NULL,
            condition TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  Future<int> insertCollection({
    required String supplierId,
    required double clearKg,
    required double coloredKg,
    required String condition,
    required String timestamp,
  }) async {
    final db = await database;
    final collection = CollectionModel(
      supplierId: supplierId,
      clearKg: clearKg,
      coloredKg: coloredKg,
      condition: condition,
      timestamp: timestamp,
    );

    return db.insert('collections', collection.toMap());
  }

  Future<List<CollectionModel>> getCollections() async {
    final db = await database;
    final rows = await db.query('collections', orderBy: 'timestamp DESC');
    return rows.map(CollectionModel.fromMap).toList();
  }

  Future<int> deleteCollections() async {
    final db = await database;
    return db.delete('collections');
  }
}
