import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final RoomType roomType;
  final VoidCallback? onSelect;
  final bool selected;
  final bool showStatus;

  const RoomCard({
    super.key,
    required this.room,
    required this.roomType,
    this.onSelect,
    this.selected = false,
    this.showStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    Color getStatusColor() {
      switch (room.status) {
        case RoomStatus.available:
          return Colors.green[100]!;
        case RoomStatus.occupied:
          return Colors.red[100]!;
        case RoomStatus.reserved:
          return Colors.blue[100]!;
        case RoomStatus.maintenance:
          return Colors.yellow[100]!;
      }
    }

    Color getStatusTextColor() {
      switch (room.status) {
        case RoomStatus.available:
          return Colors.green[800]!;
        case RoomStatus.occupied:
          return Colors.red[800]!;
        case RoomStatus.reserved:
          return Colors.blue[800]!;
        case RoomStatus.maintenance:
          return Colors.yellow[800]!;
      }
    }

    String getStatusText() {
      switch (room.status) {
        case RoomStatus.available:
          return 'Available';
        case RoomStatus.occupied:
          return 'Occupied';
        case RoomStatus.reserved:
          return 'Reserved';
        case RoomStatus.maintenance:
          return 'Maintenance';
      }
    }
    
    final List<String> fallbackAmenities = ['Wi-Fi', 'TV', 'AC', 'Room Service'];

    return Card(
      elevation: selected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? Colors.blue[600]! : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Room ${room.roomNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${roomType.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (showStatus)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: getStatusColor(),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      getStatusText(),
                      style: TextStyle(
                        color: getStatusTextColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  const Icon(LucideIcons.users, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Text(
                    'Up to 2 guests',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  const Icon(LucideIcons.bed, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    roomType.category[0].toUpperCase() + roomType.category.substring(1),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: fallbackAmenities.map((amenity) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      amenity,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
