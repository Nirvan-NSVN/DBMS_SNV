import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/hotel_provider.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';
import '../components/room_card.dart';

class ReceptionistDashboard extends StatefulWidget {
  const ReceptionistDashboard({super.key});

  @override
  State<ReceptionistDashboard> createState() => _ReceptionistDashboardState();
}

class _ReceptionistDashboardState extends State<ReceptionistDashboard> {
  Hotel? selectedHotel;
  RoomStatus? filterStatus;
  Room? selectedRoom;

  bool showBookingModal = false;
  bool showRoomDetails = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? checkIn;
  DateTime? checkOut;
  String _selectedPaymentMode = 'cash'; // 'cash' | 'online' | 'cheque'

  // Email lookup state
  bool _emailChecked = false;
  bool _customerFound = false;
  bool _bookingInProgress = false;
  String? _bookingError;

  DateTime? filterAvailabilityCheckIn;
  DateTime? filterAvailabilityCheckOut;
  Set<int>? _availableRoomIds;
  bool _filterLoading = false;

  void _lookupEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    final provider = context.read<HotelProvider>();
    try {
      final customer = provider.customers.firstWhere((c) => c.email == email);
      setState(() {
        _emailChecked = true;
        _customerFound = true;
        _nameController.text = customer.name;
        _phoneController.text = customer.phoneNumber.toString();
      });
    } catch (_) {
      setState(() {
        _emailChecked = true;
        _customerFound = false;
        _nameController.clear();
        _phoneController.clear();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (selectedHotel == null) {
      final provider = context.read<HotelProvider>();
      if (provider.hotels.isNotEmpty) {
        selectedHotel = provider.hotels.first;
        _fetchFilteredAvailability();
      }
    }
  }

  // ── Helper look-ups bridging the normalized Supabase schema ──

  /// Room IDs linked to a booking via the Reservation table.
  List<int> _roomIdsForBooking(int bookingId, HotelProvider provider) {
    return provider.reservations
        .where((r) => r.bookingId == bookingId)
        .map((r) => r.roomId)
        .toList();
  }

  /// Hotel ID for a booking (derived through Reservation → Room).
  int? _hotelIdForBooking(Booking booking, HotelProvider provider) {
    final roomIds = _roomIdsForBooking(booking.id, provider);
    if (roomIds.isEmpty) return null;
    try {
      return provider.rooms.firstWhere((r) => r.id == roomIds.first).hotelId;
    } catch (_) {
      return null;
    }
  }

  /// Customer record for a booking.
  Customer? _customerForBooking(Booking booking, HotelProvider provider) {
    try {
      return provider.customers.firstWhere((c) => c.id == booking.customerId);
    } catch (_) {
      return null;
    }
  }

  /// Payment record for a booking.
  Payment? _paymentForBooking(Booking booking, HotelProvider provider) {
    try {
      return provider.payments.firstWhere((p) => p.transactionId == booking.paymentId);
    } catch (_) {
      return null;
    }
  }

  /// RoomType (and therefore price) for a room.
  RoomType _roomTypeForRoom(Room room, HotelProvider provider) {
    try {
      return provider.roomTypes.firstWhere((t) => t.id == room.typeId);
    } catch (_) {
      return RoomType(id: 0, hotelId: 0, category: 'Unknown', price: 0);
    }
  }

  double _priceForRoom(Room room, HotelProvider provider) {
    return _roomTypeForRoom(room, provider).price;
  }

  // ── Actions ──

  Future<void> _handleDirectBooking() async {
    if (selectedRoom == null || checkIn == null || checkOut == null) return;
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter guest email')),
      );
      return;
    }
    if (!_emailChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please look up the email first')),
      );
      return;
    }
    if (!_customerFound && (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in name and phone for the new customer')),
      );
      return;
    }

    setState(() { _bookingInProgress = true; _bookingError = null; });

    try {
      // If customer doesn't exist, create via create-user-admin edge function
      if (!_customerFound) {
        final token = await AuthService().getAccessToken();
        final client = AuthService().client;
        await client.functions.invoke(
          'create-user-admin',
          body: {
            'email': _emailController.text.trim(),
            'password': 'password',
            'targetRole': 'customer',
            'metadata': {
              'name': _nameController.text.trim(),
              'phone': int.tryParse(_phoneController.text.trim()) ?? 0,
              'address': 'N/A',
            },
          },
          headers: {'Authorization': 'Bearer $token'},
        );
        // Refresh data so the new customer is available
        final provider = context.read<HotelProvider>();
        await provider.refreshData();
      }

      final diff = checkOut!.difference(checkIn!).inDays;
      final nights = diff > 0 ? diff : 1;
      final provider = context.read<HotelProvider>();
      final totalPrice = _priceForRoom(selectedRoom!, provider) * nights;

      await SupabaseService().bookRoom(
        hotelId: selectedHotel!.id,
        roomIds: [selectedRoom!.id],
        guestName: _nameController.text.trim(),
        guestEmail: _emailController.text.trim(),
        checkIn: checkIn!,
        checkOut: checkOut!,
        status: 'Approved',
        totalPrice: totalPrice,
        paymentMode: _selectedPaymentMode,
      );

      // Refresh provider data after successful booking
      await provider.refreshData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking submitted successfully')),
      );

      setState(() {
        showBookingModal = false;
        selectedRoom = null;
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
        checkIn = null;
        checkOut = null;
        _selectedPaymentMode = 'cash';
        _emailChecked = false;
        _customerFound = false;
        _bookingInProgress = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bookingInProgress = false;
        _bookingError = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _handleRoomClick(Room room) {
    if (room.status == RoomStatus.occupied || room.status == RoomStatus.reserved) {
      setState(() {
        selectedRoom = room;
        showRoomDetails = true;
      });
    }
  }

  Booking? _getRoomBooking(int roomId, HotelProvider provider) {
    // Find reservation rows that reference this room → get booking IDs
    final bookingIds = provider.reservations
        .where((r) => r.roomId == roomId)
        .map((r) => r.bookingId)
        .toSet();

    final activeBookings = provider.bookings.where(
      (b) => bookingIds.contains(b.id) &&
          (b.status.toLowerCase() == 'approved' ||
           b.status.toLowerCase() == 'pending' ||
           b.status.toLowerCase() == 'paid'),
    ).toList();

    // If filter dates are set, find the booking that conflicts with those dates
    if (filterAvailabilityCheckIn != null && filterAvailabilityCheckOut != null) {
      final conflicting = activeBookings.where((b) =>
        b.checkIn.isBefore(filterAvailabilityCheckOut!) &&
        b.checkOut.isAfter(filterAvailabilityCheckIn!),
      ).toList();
      return conflicting.isNotEmpty ? conflicting.first : null;
    }

    // No filter: return the first active booking
    return activeBookings.isNotEmpty ? activeBookings.first : null;
  }

  void _handleCheckOut(Room room) async {
    final provider = context.read<HotelProvider>();
    final booking = _getRoomBooking(room.id, provider);
    
    if (booking != null) {
      try {
        await provider.updateBookingCheckout(booking.id, DateTime.now());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guest checked out successfully (Checkout time updated to now)')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during checkout: $e'), backgroundColor: Colors.red),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active booking found for this room to check out')),
      );
    }
    setState(() {
      showRoomDetails = false;
      selectedRoom = null;
    });
  }

  void _selectDates(BuildContext context, bool isCheckIn) async {
    final now = DateTime.now();
    final initialDate = isCheckIn ? (checkIn ?? now) : (checkOut ?? checkIn ?? now);
    final firstDate = isCheckIn ? now : (checkIn ?? now);
    final lastDate = now.add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          checkIn = picked;
          if (checkOut != null && checkOut!.isBefore(checkIn!)) {
            checkOut = null;
          }
        } else {
          checkOut = picked;
        }
      });
    }
  }

  Future<void> _fetchFilteredAvailability() async {
    if (selectedHotel == null) return;
    
    final start = filterAvailabilityCheckIn ?? DateTime.now();
    final end = filterAvailabilityCheckOut ?? start.add(const Duration(hours: 1));

    setState(() => _filterLoading = true);
    try {
      final ids = await SupabaseService().fetchAvailableRooms(
        hotelId: selectedHotel!.id,
        checkIn: start,
        checkOut: end,
      );
      setState(() => _availableRoomIds = ids.toSet());
    } catch (e) {
      debugPrint('Error fetching available rooms: $e');
    } finally {
      setState(() => _filterLoading = false);
    }
  }

  void _selectFilterDates(BuildContext context, bool isCheckIn) async {
    final now = DateTime.now();
    final initialDate = isCheckIn ? (filterAvailabilityCheckIn ?? now) : (filterAvailabilityCheckOut ?? filterAvailabilityCheckIn ?? now);
    final firstDate = isCheckIn ? now : (filterAvailabilityCheckIn ?? now);
    final lastDate = now.add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          // Default check-in at 14:00 (2 PM)
          filterAvailabilityCheckIn = DateTime(picked.year, picked.month, picked.day, 14, 0);
          if (filterAvailabilityCheckOut != null && filterAvailabilityCheckOut!.isBefore(filterAvailabilityCheckIn!)) {
            filterAvailabilityCheckOut = null;
            _availableRoomIds = null;
          }
        } else {
          // Default check-out at 11:00 (11 AM)
          filterAvailabilityCheckOut = DateTime(picked.year, picked.month, picked.day, 11, 0);
        }
      });
      // Trigger fetch when both dates are set
      if (filterAvailabilityCheckIn != null && filterAvailabilityCheckOut != null) {
        _fetchFilteredAvailability();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HotelProvider>();

    // Re-sync selectedHotel with provider's list after refreshData
    if (selectedHotel != null) {
      final match = provider.hotels.where((h) => h.id == selectedHotel!.id);
      if (match.isNotEmpty) {
        selectedHotel = match.first;
      } else if (provider.hotels.isNotEmpty) {
        selectedHotel = provider.hotels.first;
      }
    }

    if (selectedHotel == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    List<Room> baseRooms = provider.rooms.where((r) => r.hotelId == selectedHotel!.id).toList();

    // Dynamically update room status based on real-time availability from edge function
    if (_availableRoomIds != null) {
      baseRooms = baseRooms.map((r) {
        final isAvailable = _availableRoomIds!.contains(r.id);
        return Room(
          id: r.id,
          hotelId: r.hotelId,
          status: isAvailable ? RoomStatus.available : RoomStatus.occupied,
          roomNumber: r.roomNumber,
          typeId: r.typeId,
          currentGuest: isAvailable ? null : r.currentGuest,
        );
      }).toList();

      // Sort: Available first, then by room number
      baseRooms.sort((a, b) {
        if (a.status == RoomStatus.available && b.status != RoomStatus.available) return -1;
        if (a.status != RoomStatus.available && b.status == RoomStatus.available) return 1;
        return a.roomNumber.compareTo(b.roomNumber);
      });
    } else {
      // Fallback/Loading state: simple sort
      baseRooms.sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
    }

    final filteredRooms = filterStatus == null
        ? baseRooms
        : baseRooms.where((r) => r.status == filterStatus).toList();

    int count(RoomStatus status) => baseRooms.where((r) => r.status == status).length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        surfaceTintColor: Colors.transparent,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black54),
          label: const Text('Back', style: TextStyle(color: Colors.black54)),
        ),
        title: const Text('Receptionist Dashboard', style: TextStyle(color: Colors.black87)),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Hotel>(
                  value: selectedHotel,
                  isDense: true,
                  focusColor: Colors.transparent,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  items: provider.hotels
                      .map((h) => DropdownMenuItem(value: h, child: Text(h.name)))
                      .toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      setState(() => selectedHotel = val);
                      await provider.refreshData();
                      if (filterAvailabilityCheckIn != null && filterAvailabilityCheckOut != null) {
                        _fetchFilteredAvailability();
                      }
                    }
                  },
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Colors.indigo),
            tooltip: 'Refresh Dashboard',
            onPressed: () async {
              await provider.refreshData();
              if (filterAvailabilityCheckIn != null && filterAvailabilityCheckOut != null) {
                _fetchFilteredAvailability();
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dashboard refreshed')),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Statistics
                    LayoutBuilder(builder: (context, constraints) {
                      bool isSmall = constraints.maxWidth < 600;
                      return GridView.count(
                        crossAxisCount: isSmall ? 2 : 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.5,
                        children: [
                          _buildStatCard('Available', count(RoomStatus.available), Colors.green),
                          _buildStatCard('Occupied', count(RoomStatus.occupied), Colors.red),
                          _buildStatCard('Reserved', count(RoomStatus.reserved), Colors.blue),
                          _buildStatCard('Maintenance', count(RoomStatus.maintenance), Colors.amber),
                        ],
                      );
                    }),
                    const SizedBox(height: 32),

                    // Recent Approved Bookings
                    _buildRecentBookings(provider),

                    // Date Availability Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Icon(LucideIcons.calendar, color: Colors.grey),
                          const SizedBox(width: 16),
                          const Text('Availability:', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () => _selectFilterDates(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                              child: Text(filterAvailabilityCheckIn != null ? DateFormat.yMMMd().format(filterAvailabilityCheckIn!) : 'Check-in'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => _selectFilterDates(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                              child: Text(filterAvailabilityCheckOut != null ? DateFormat.yMMMd().format(filterAvailabilityCheckOut!) : 'Check-out'),
                            ),
                          ),
                          if (_filterLoading)
                            const Padding(
                              padding: EdgeInsets.only(left: 16),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                          if (filterAvailabilityCheckIn != null || filterAvailabilityCheckOut != null) ...[
                            const SizedBox(width: 16),
                            TextButton.icon(
                              onPressed: () => setState(() {
                                filterAvailabilityCheckIn = null;
                                filterAvailabilityCheckOut = null;
                                _availableRoomIds = null;
                              }),
                              icon: const Icon(LucideIcons.xCircle, size: 16),
                              label: const Text('Clear Filter'),
                              style: TextButton.styleFrom(foregroundColor: Colors.red[600]),
                            ),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Status Filters
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Icon(LucideIcons.filter, color: Colors.grey),
                          const SizedBox(width: 16),
                          _buildFilterBtn('All (${baseRooms.length})', null, Colors.indigo),
                          const SizedBox(width: 8),
                          _buildFilterBtn('Available (${count(RoomStatus.available)})', RoomStatus.available, Colors.green),
                          const SizedBox(width: 8),
                          _buildFilterBtn('Occupied (${count(RoomStatus.occupied)})', RoomStatus.occupied, Colors.red),
                          const SizedBox(width: 8),
                          _buildFilterBtn('Reserved (${count(RoomStatus.reserved)})', RoomStatus.reserved, Colors.blue),
                          const SizedBox(width: 8),
                          _buildFilterBtn('Maintenance (${count(RoomStatus.maintenance)})', RoomStatus.maintenance, Colors.amber),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Rooms Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = (constraints.maxWidth / 400).ceil();
                        if (crossAxisCount < 1) crossAxisCount = 1;
                        double width = (constraints.maxWidth - ((crossAxisCount - 1) * 16)) / crossAxisCount;
                        width = width.floorToDouble();

                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: filteredRooms.map((room) {
                            final roomType = _roomTypeForRoom(room, provider);
                            return SizedBox(
                              width: width,
                              child: Column(
                                children: [
                                  RoomCard(room: room, roomType: roomType, showStatus: true, onSelect: () => _handleRoomClick(room)),
                                  const SizedBox(height: 8),
                                  if (room.status == RoomStatus.available)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            selectedRoom = room;
                                            showBookingModal = true;
                                          });
                                        },
                                        icon: const Icon(LucideIcons.plus, size: 16),
                                        label: const Text('Book Room'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigo[600],
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    )
                                  else if (room.status == RoomStatus.occupied || room.status == RoomStatus.reserved)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => _handleRoomClick(room),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[700],
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: const Text('View Details'),
                                      ),
                                    )
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showBookingModal) _buildBookingModal(provider),
          if (showRoomDetails) _buildRoomDetailsModal(provider),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text('$value', style: TextStyle(color: color[600], fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilterBtn(String label, RoomStatus? status, MaterialColor color) {
    bool isSelected = filterStatus == status;
    return ElevatedButton(
      onPressed: () => setState(() => filterStatus = status),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color[600] : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.grey[800],
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  Widget _buildRecentBookings(HotelProvider provider) {
    // Filter bookings belonging to this hotel via Reservation → Room → hotelId
    final recentBookings = provider.bookings
        .where((b) {
          if (b.status.toLowerCase() != 'approved') return false;
          final hid = _hotelIdForBooking(b, provider);
          return hid == selectedHotel!.id;
        })
        .take(5)
        .toList();

    if (recentBookings.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          border: Border.all(color: Colors.green[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Approved Bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            ...recentBookings.map((b) {
              final customer = _customerForBooking(b, provider);
              final payment = _paymentForBooking(b, provider);
              final roomIds = _roomIdsForBooking(b.id, provider);
              final roomNumbers = roomIds.map((id) {
                try {
                  return provider.rooms.firstWhere((r) => r.id == id).roomNumber.toString();
                } catch (_) {
                  return '?';
                }
              }).join(', ');

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${customer?.name ?? 'N/A'} - ${customer?.email ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${DateFormat.yMMMd().format(b.checkIn)} to ${DateFormat.yMMMd().format(b.checkOut)} - ₹${payment?.amount ?? 'N/A'}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          Text('Room(s): $roomNumbers', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(16)),
                      child: Text('Approved', style: TextStyle(color: Colors.green[800], fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingModal(HotelProvider provider) {
    final roomPrice = selectedRoom != null ? _priceForRoom(selectedRoom!, provider) : 0.0;

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Material(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Book Room ${selectedRoom?.roomNumber}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_bookingError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_bookingError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      enabled: !_customerFound,
                      decoration: InputDecoration(
                        labelText: 'Guest Email',
                        prefixIcon: const Icon(LucideIcons.mail),
                        border: const OutlineInputBorder(),
                        suffixIcon: _emailChecked
                            ? Icon(
                                _customerFound ? LucideIcons.checkCircle : LucideIcons.alertCircle,
                                color: _customerFound ? Colors.green : Colors.orange,
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _lookupEmail(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _customerFound ? () {
                      setState(() {
                        _emailChecked = false;
                        _customerFound = false;
                        _nameController.clear();
                        _phoneController.clear();
                        _emailController.clear();
                      });
                    } : _lookupEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _customerFound ? Colors.grey[600] : Colors.indigo[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                    child: Text(_customerFound ? 'Change' : 'Look Up'),
                  ),
                ],
              ),
              if (_emailChecked && _customerFound)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.userCheck, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text('Customer found: ${_nameController.text}', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              if (_emailChecked && !_customerFound) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.userPlus, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Expanded(child: Text('New customer — please fill in details below', style: TextStyle(color: Colors.orange[700], fontSize: 13))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Guest Name', prefixIcon: Icon(LucideIcons.user), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(LucideIcons.phone), border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDates(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.calendar, size: 18),
                            const SizedBox(width: 8),
                            Text(checkIn != null ? DateFormat.yMMMd().format(checkIn!) : 'Check-in'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDates(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.calendar, size: 18),
                            const SizedBox(width: 8),
                            Text(checkOut != null ? DateFormat.yMMMd().format(checkOut!) : 'Check-out'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Payment Mode
              DropdownButtonFormField<String>(
                value: _selectedPaymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  prefixIcon: Icon(LucideIcons.creditCard),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPaymentMode = val);
                },
              ),
              if (checkIn != null && checkOut != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Price (${checkOut!.difference(checkIn!).inDays > 0 ? checkOut!.difference(checkIn!).inDays : 1} nights):'),
                    Text('₹${roomPrice * (checkOut!.difference(checkIn!).inDays > 0 ? checkOut!.difference(checkIn!).inDays : 1)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _bookingInProgress ? null : _handleDirectBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _bookingInProgress
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Confirm Booking'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          showBookingModal = false;
                          selectedRoom = null;
                        });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomDetailsModal(HotelProvider provider) {
    final booking = _getRoomBooking(selectedRoom!.id, provider);
    final customer = booking != null ? _customerForBooking(booking, provider) : null;

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Material(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Room ${selectedRoom!.roomNumber} Details', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildDetailRow(LucideIcons.user, 'Guest Name', customer?.name ?? selectedRoom!.currentGuest ?? 'N/A'),
              const SizedBox(height: 16),
              _buildDetailRow(LucideIcons.mail, 'Guest Email', customer?.email ?? 'N/A'),
              const SizedBox(height: 16),
              _buildDetailRow(LucideIcons.calendar, 'Check-in Date', booking != null ? DateFormat('MMM d, y  h:mm a').format(booking.checkIn) : 'N/A'),
              const SizedBox(height: 16),
              _buildDetailRow(LucideIcons.calendar, 'Check-out Date', booking != null ? DateFormat('MMM d, y  h:mm a').format(booking.checkOut) : 'N/A'),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleCheckOut(selectedRoom!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Check Out'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          showRoomDetails = false;
                          selectedRoom = null;
                        });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Close', style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16)),
      ],
    );
  }
}
