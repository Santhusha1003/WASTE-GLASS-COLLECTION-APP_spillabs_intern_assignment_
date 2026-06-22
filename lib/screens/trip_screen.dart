import 'package:flutter/material.dart';

import '../models/supplier.dart';
import '../widgets/custom_button.dart';
import '../widgets/summary_card.dart';
import '../widgets/supplier_card.dart';

class TripScreen extends StatelessWidget {
  const TripScreen({super.key});

  static const List<Supplier> suppliers = [
    Supplier(
      id: 1,
      name: 'ABC Glass Supplier',
      latitude: 6.9271,
      longitude: 79.8612,
      expectedKg: 30,
      status: 'NEXT',
      location: 'Kandy Road',
      distance: '2.4 km',
    ),
    Supplier(
      id: 2,
      name: 'XYZ Glass Center',
      latitude: 6.9147,
      longitude: 79.9732,
      expectedKg: 25,
      status: 'PENDING',
      location: 'Matale Road',
      distance: '3.7 km',
    ),
    Supplier(
      id: 3,
      name: 'Green Glass Hub',
      latitude: 6.8531,
      longitude: 79.8655,
      expectedKg: 35,
      status: 'PENDING',
      location: 'Dambulla',
      distance: '4.1 km',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waste Glass Collection')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Route",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Plan the most efficient glass collection route for today.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Row(
                children: [
                  SummaryCard(
                    title: 'Total Distance',
                    value: '15.8 km',
                    icon: Icons.map_outlined,
                  ),
                  SizedBox(width: 12),
                  SummaryCard(
                    title: 'Remaining Stops',
                    value: '4',
                    icon: Icons.location_on_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Stop Sequence',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    return SupplierCard(
                      supplier: suppliers[index],
                      sequenceNumber: index + 1,
                    );
                  },
                ),
              ),
              CustomButton(
                label: 'Start Collection',
                icon: Icons.play_arrow,
                onPressed: () => Navigator.pushNamed(context, '/scan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
