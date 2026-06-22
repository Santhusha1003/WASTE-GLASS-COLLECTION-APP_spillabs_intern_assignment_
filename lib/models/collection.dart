class CollectionModel {
  const CollectionModel({
    this.id,
    required this.supplierId,
    required this.clearKg,
    required this.coloredKg,
    required this.condition,
    required this.timestamp,
  });

  final int? id;
  final String supplierId;
  final double clearKg;
  final double coloredKg;
  final String condition;
  final String timestamp;

  double get totalKg => clearKg + coloredKg;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'supplierId': supplierId,
      'clearKg': clearKg,
      'coloredKg': coloredKg,
      'condition': condition,
      'timestamp': timestamp,
    };
  }

  factory CollectionModel.fromMap(Map<String, Object?> map) {
    return CollectionModel(
      id: map['id'] as int?,
      supplierId: map['supplierId'] as String,
      clearKg: (map['clearKg'] as num).toDouble(),
      coloredKg: (map['coloredKg'] as num).toDouble(),
      condition: map['condition'] as String,
      timestamp: map['timestamp'] as String,
    );
  }
}
