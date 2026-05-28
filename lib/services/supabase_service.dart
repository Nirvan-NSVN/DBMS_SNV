import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'dart:math';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Fetch all hotels
  Future<List<Hotel>> fetchHotels() async {
    final response = await _client.from('hotel').select();
    return (response as List<dynamic>).map((json) => Hotel(
      id: json['Hotel ID'],
      name: json['Name'],
      address: json['Address'],
      phoneNumber: json['Phone Number'],
      email: json['Email'],
    )).toList();
  }

  // Fetch all room types
  Future<List<RoomType>> fetchRoomTypes() async {
    final response = await _client.from('rooms type').select();
    return (response as List<dynamic>).map((json) => RoomType(
      id: json['type id'],
      hotelId: json['Hotel id'],
      category: json['room category'],
      price: json['price'].toDouble(),
    )).toList();
  }

  // Fetch all rooms
  Future<List<Room>> fetchRooms() async {
    final response = await _client.from('rooms').select();
    return (response as List<dynamic>).map((json) => Room(
      id: json['Room ID'],
      hotelId: json['Hotel ID'],
      status: RoomStatus.available, // Schema removed 'Status' column
      roomNumber: json['Room Number'],
      typeId: json['room type'],
    )).toList();
  }

  // Fetch room statuses from view
  Future<Map<int, RoomStatus>> fetchRoomStatuses() async {
    final response = await _client.from('available_rooms').select();
    final map = <int, RoomStatus>{};
    for (var json in (response as List<dynamic>)) {
      final rawId = json['Room ID'] ?? json['room id'] ?? json['Room id'] ?? json['id'];
      if (rawId == null) continue;
      
      final id = rawId is int ? rawId : int.tryParse(rawId.toString());
      if (id == null) continue;

      final statusStr = (json['status'] ?? json['Status'])?.toString().toLowerCase();
      final status = RoomStatus.values.firstWhere(
        (e) => e.name == statusStr, 
        orElse: () => RoomStatus.available
      );
      map[id] = status;
    }
    return map;
  }

  // Fetch all bookings
  Future<List<Booking>> fetchBookings() async {
    final response = await _client.from('booking').select();
    return (response as List<dynamic>).map((json) => Booking(
      id: json['Booking ID'],
      bookingDate: DateTime.parse(json['Booking Date']),
      checkIn: json['CHECK IN'] != null ? DateTime.parse(json['CHECK IN']) : DateTime.parse(json['CHECK OUT']).subtract(const Duration(days: 1)),
      checkOut: DateTime.parse(json['CHECK OUT']),
      status: json['Booking Status'],
      customerId: json['Customer ID'],
      paymentId: json['Payment ID'],
    )).toList();
  }

  // Fetch all customers (required for dashboard name/email lookup)
  Future<List<Customer>> fetchCustomers() async {
    final response = await _client.from('customer').select();
    return (response as List<dynamic>).map((json) => Customer(
      id: json['Customer ID'],
      name: json['Name'],
      phoneNumber: json['Phone Number'],
      address: json['Address'],
      email: json['Email'],
    )).toList();
  }

  // Fetch all reservations (required for dashboard to map bookings to rooms)
  Future<List<Reservation>> fetchReservations() async {
    final response = await _client.from('reservation').select();
    return (response as List<dynamic>).map((json) => Reservation(
      bookingId: json['Booking ID'],
      roomId: json['Room ID'],
    )).toList();
  }

  // Fetch all payments (required for dashboard total price lookup)
  Future<List<Payment>> fetchPayments() async {
    final response = await _client.from('payment').select();
    return (response as List<dynamic>).map((json) => Payment(
      transactionId: json['Transaction ID'],
      received: DateTime.parse(json['Received']),
      amount: json['Amount'].toDouble(),
      mode: json['Mode'],
    )).toList();
  }

  Future<List<int>> fetchAvailableRooms({
    required int hotelId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    final res = await _client.functions.invoke(
      'get-available-rooms',
      // Switch to queryParameters if your function uses url.searchParams
      queryParameters: {
        'hotel_id': hotelId.toString(),
        'check_in': checkIn.toIso8601String(),
        'check_out': checkOut.toIso8601String(),
      },
      headers: {
        'Authorization': 'Bearer ${_client.auth.currentSession?.accessToken ?? dotenv.env['SUPABASE_ANON_KEY']}',
      },
    );

    // Check for 200 status or null data
    if (res.status != 200 || res.data == null) {
      print("Error fetching rooms: ${res.data}");
      return [];
    }

    // The 'rooms' key comes from your Edge Function's: return new Response(JSON.stringify({ rooms: data }))
    final Map<String, dynamic> responseData = res.data;
    final List<dynamic> roomsList = responseData['rooms'] ?? [];

    return roomsList.map<int>((r) {
      // If your RPC returns objects: r['room_id']
      // If your RPC returns raw integers: r as int
      if (r is Map) {
        return r['Room ID'] as int;
      }
      return r as int;
    }).toList();
  }
  // Update room status or guest info
  Future<void> updateRoom(int roomId, {String? status, String? currentGuest}) async {
    // The Rooms table no longer tracks 'Status'.
    // If future schema adds it back, we can re-enable this.
  }

  // Book a room via the create-booking Edge Function.
  // The edge function handles Payment + Booking + Reservation atomically.
  // We still upsert the Customer first since the function requires customer_id.
  // Fetch all staff
  Future<List<Staff>> fetchStaff() async {
    final response = await _client.from('staff').select();
    return (response as List<dynamic>).map((json) => Staff(
      id: json['Staff ID'],
      joiningDate: DateTime.parse(json['Joining Date']),
      name: json['Name'],
      phoneNumber: json['Phone Number'],
      email: json['Email'],
      salary: json['Salary'],
      role: json['Role'],
      hotelId: json['Hotel ID'],
      userId: json['User ID'] ?? '',
    )).toList();
  }

  // ── Admin CRUD ──

  Future<void> adminInsert(String table, Map<String, dynamic> data) async {
    await _client.from(table).insert(data);
  }

  Future<void> adminUpdate(String table, String pkCol, dynamic pkVal, Map<String, dynamic> data) async {
    await _client.from(table).update(data).eq(pkCol, pkVal);
  }

  Future<void> adminDelete(String table, String pkCol, dynamic pkVal) async {
    await _client.from(table).delete().eq(pkCol, pkVal);
  }

  Future<void> bookRoom({
    required int hotelId,
    required List<int> roomIds,
    required String guestName,
    required String guestEmail,
    required DateTime checkIn,
    required DateTime checkOut,
    required String status,
    required double totalPrice,
    String paymentMode = 'online', // 'online' | 'cash' | 'cheque'
  }) async {
    // 1. Upsert Customer (find by email or create)
    var customerRes = await _client
        .from('customer')
        .select()
        .eq('Email', guestEmail)
        .maybeSingle();

    if (customerRes == null) {
      final newId = DateTime.now().millisecondsSinceEpoch % 2147483647; // fits INT4
      final phone = 9000000000 + (newId % 999999999);
      customerRes = await _client.from('customer').insert({
        'Customer ID': newId,
        'Name': guestName,
        'Email': guestEmail,
        'Phone Number': phone,
        'Address': 'N/A',
      }).select().single();
    }
    final customerId = customerRes['Customer ID'] as int;

    // 2. Generate a unique transaction ID
    final random = Random();
    final transactionId =
        'TXN${DateTime.now().millisecondsSinceEpoch}${random.nextInt(9999)}';

    // 3. Call the create-booking Edge Function
    await _client.functions.invoke(
      'create-booking',
      body: {
        'booking_date': DateTime.now().toIso8601String(),
        'check_in': checkIn.toIso8601String(),
        'check_out': checkOut.toIso8601String(),
        'customer_id': customerId,
        'rooms': roomIds.map((id) => {'room_id': id}).toList(),
        'payment': {
          'transaction_id': transactionId,
          'amount': totalPrice,
          'mode': paymentMode,
        },
      },
      headers: {
        'Authorization': 'Bearer ${_client.auth.currentSession?.accessToken ?? dotenv.env['SUPABASE_ANON_KEY']! }',
      },
    );
  }
  Future<void> updateBookingCheckout(int bookingId, DateTime newCheckout) async {
    await _client.from('booking').update({
      'CHECK OUT': newCheckout.toIso8601String(),
    }).eq('Booking ID', bookingId);
  }
}
