enum RoomStatus { available, occupied, maintenance, reserved }

class Customer {
  final int id;
  final String name;
  final num phoneNumber;
  final String address;
  final String email;

  Customer({required this.id, required this.name, required this.phoneNumber, required this.address, required this.email});
}

class Payment {
  final String transactionId;
  final DateTime received;
  final num amount;
  final String mode;

  Payment({required this.transactionId, required this.received, required this.amount, required this.mode});
}

class Booking {
  final int id;
  final DateTime bookingDate;
  final DateTime checkIn;
  final DateTime checkOut;
  final String status;
  final int customerId;
  final String paymentId;

  Booking({
    required this.id,
    required this.bookingDate,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    required this.customerId,
    required this.paymentId,
  });
}

class Reservation {
  final int bookingId;
  final int roomId;

  Reservation({required this.bookingId, required this.roomId});
}

class Hotel {
  final int id;
  final String name;
  final String address;
  final num phoneNumber;
  final String email;

  Hotel({
    required this.id,
    required this.name,
    required this.address,
    required this.phoneNumber,
    required this.email,
  });
}

class RoomType {
  final int id;
  final int hotelId;
  final String category;
  final double price;

  RoomType({required this.id, required this.hotelId, required this.category, required this.price});
}

class Room {
  final int id;
  final int hotelId;
  RoomStatus status;
  final int roomNumber;
  final int typeId;
  
  // Optional Transient UI fields (to keep UI compiling temporarily or permanently if needed)
  String? currentGuest;

  Room({
    required this.id,
    required this.hotelId,
    required this.status,
    required this.roomNumber,
    required this.typeId,
    this.currentGuest,
  });
}

class Staff {
  final int id;
  final DateTime joiningDate;
  final String name;
  final num phoneNumber;
  final String email;
  final num salary;
  final String role;
  final int hotelId;
  final String userId;

  Staff({
    required this.id,
    required this.joiningDate,
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.salary,
    required this.role,
    required this.hotelId,
    required this.userId,
  });
}
