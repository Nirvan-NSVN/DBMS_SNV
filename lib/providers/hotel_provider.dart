import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class HotelProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<Room> _rooms = [];
  List<Booking> _bookings = [];
  List<Hotel> _hotels = [];
  List<RoomType> _roomTypes = [];
  List<Customer> _customers = [];
  List<Reservation> _reservations = [];
  List<Payment> _payments = [];
  
  bool _isLoading = false;

  List<Room> get rooms => _rooms;
  List<Booking> get bookings => _bookings;
  List<Hotel> get hotels => _hotels;
  List<RoomType> get roomTypes => _roomTypes;
  List<Customer> get customers => _customers;
  List<Reservation> get reservations => _reservations;
  List<Payment> get payments => _payments;
  bool get isLoading => _isLoading;

  HotelProvider() {
    refreshData();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _hotels = await _supabaseService.fetchHotels();
      _roomTypes = await _supabaseService.fetchRoomTypes();
      _rooms = await _supabaseService.fetchRooms();
      _bookings = await _supabaseService.fetchBookings();
      _customers = await _supabaseService.fetchCustomers();
      _reservations = await _supabaseService.fetchReservations();
      _payments = await _supabaseService.fetchPayments();
      try {
        final statuses = await _supabaseService.fetchRoomStatuses();
        for (var room in _rooms) {
          if (statuses.containsKey(room.id)) {
            room.status = RoomStatus.available;
          } else {
            room.status = RoomStatus.occupied;
          }
        }
      } catch (e) {
        debugPrint("View read failed: $e");
      }
    } catch (e) {
      debugPrint("Error fetching Supabase data: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<int>> fetchAvailableRooms({
    required int hotelId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    return _supabaseService.fetchAvailableRooms(
      hotelId: hotelId,
      checkIn: checkIn,
      checkOut: checkOut,
    );
  }

  Future<void> updateRoomStatus(int roomId, RoomStatus newStatus) async {
    try {
      await _supabaseService.updateRoom(roomId, status: newStatus.name);
      await refreshData();
    } catch (e) {
      debugPrint("Update room status err: $e");
    }
  }

  Future<void> updateRoom(int roomId, {RoomStatus? status, String? currentGuest}) async {
    try {
      await _supabaseService.updateRoom(roomId, status: status?.name, currentGuest: currentGuest);
      await refreshData();
    } catch (e) {
      debugPrint("Update room err: $e");
    }
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
    String paymentMode = 'cash',
  }) async {
    try {
      await _supabaseService.bookRoom(
        hotelId: hotelId,
        roomIds: roomIds,
        guestName: guestName,
        guestEmail: guestEmail,
        checkIn: checkIn,
        checkOut: checkOut,
        status: status,
        totalPrice: totalPrice,
        paymentMode: paymentMode,
      );
      await refreshData();
    } catch (e) {
      debugPrint("Book room err: $e");
      rethrow;
    }
  }
  Future<void> updateBookingCheckout(int bookingId, DateTime newCheckout) async {
    try {
      await _supabaseService.updateBookingCheckout(bookingId, newCheckout);
      await refreshData();
    } catch (e) {
      debugPrint("Update booking checkout err: $e");
      rethrow;
    }
  }
}
