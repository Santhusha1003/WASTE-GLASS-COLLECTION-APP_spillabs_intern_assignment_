class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.expectedKg,
    required this.status,
    this.location = '',
    this.distance = '',
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final double expectedKg;
  final String status;
  final String location;
  final String distance;
}
