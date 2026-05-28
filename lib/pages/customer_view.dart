import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../providers/hotel_provider.dart';
import '../components/hotel_card.dart';
import '../components/room_card.dart';

class CustomerView extends StatefulWidget {
  const CustomerView({super.key});

  @override
  State<CustomerView> createState() => _CustomerViewState();
}

class _CustomerViewState extends State<CustomerView> {
  Hotel? selectedHotel;
  List<int> selectedRoomIds = [];

  // Form state
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? checkIn;
  DateTime? checkOut;
  bool datesConfirmed = false;
  bool showBookingForm = false;
  List<int>? availableRoomIds;
  bool loadingRooms = false;
  bool showPayment = false;
  bool paymentComplete = false;
  bool bookingFailed = false;
  String? _bookingError;

  // Payment form
  final _cardNumberController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cardNumberController.dispose();
    _cardNameController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  int get billingDays {
    if (checkIn == null || checkOut == null) return 0;
    final minutes = checkOut!.difference(checkIn!).inMinutes;
    if (minutes <= 0) return 0;
    return (minutes / (24 * 60)).ceil();
  }

  double getTotalPrice(HotelProvider provider) {
    if (checkIn == null || checkOut == null) return 0;
    final selectedRooms = provider.rooms.where((r) => selectedRoomIds.contains(r.id)).toList();
    double sum = 0;
    for (var r in selectedRooms) {
      try {
        final roomType = provider.roomTypes.firstWhere((t) => t.id == r.typeId);
        sum += roomType.price * billingDays;
      } catch (e) {}
    }
    return sum;
  }

  String get _loggedInEmail => Supabase.instance.client.auth.currentUser?.email ?? '';
  bool get _isLoggedIn => Supabase.instance.client.auth.currentUser != null;

  String _guestName(HotelProvider provider) {
    if (_isLoggedIn) {
      try {
        return provider.customers.firstWhere((c) => c.email == _loggedInEmail).name;
      } catch (_) {}
      return _loggedInEmail;
    }
    return _nameController.text;
  }

  String _guestEmail(HotelProvider provider) {
    if (_isLoggedIn) return _loggedInEmail;
    return _emailController.text;
  }

  Future<void> _handlePayment() async {
    if (selectedHotel == null) return;

    final provider = context.read<HotelProvider>();
    final totalPrice = getTotalPrice(provider);

    try {
      await provider.bookRoom(
        hotelId: selectedHotel!.id,
        roomIds: selectedRoomIds,
        guestName: _guestName(provider),
        guestEmail: _guestEmail(provider),
        checkIn: checkIn!,
        checkOut: checkOut!,
        status: 'Approved',
        totalPrice: totalPrice,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful! Booking approved.')),
      );

      setState(() {
        paymentComplete = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        bookingFailed = true;
        _bookingError = e.toString();
      });
    }
  }

  void _handleStartNewBooking() {
    setState(() {
      selectedRoomIds.clear();
      _nameController.clear();
      _emailController.clear();
      checkIn = null;
      checkOut = null;
      datesConfirmed = false;
      showBookingForm = false;
      showPayment = false;
      paymentComplete = false;
      bookingFailed = false;
      _bookingError = null;
      selectedHotel = null;
      _cardNumberController.clear();
      _cardNameController.clear();
      _expiryDateController.clear();
      _cvvController.clear();
    });
  }

  void _handleSelectHotel(Hotel hotel) {
    setState(() {
      selectedHotel = hotel;
      datesConfirmed = false;
      selectedRoomIds.clear();
      checkIn = null;
      checkOut = null;
    });
  }

  void _selectDateTime(BuildContext context, bool isCheckIn) async {
    final now = DateTime.now();
    final initial = isCheckIn ? (checkIn ?? now) : (checkOut ?? checkIn?.add(const Duration(hours: 3)) ?? now);
    final firstDate = isCheckIn ? now : (checkIn ?? now);
    final lastDate = now.add(const Duration(days: 365));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;

    final picked = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);

    if (isCheckIn) {
      if (picked.isBefore(now)) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check-in must be now or in the future')));
        return;
      }
      setState(() {
        checkIn = picked;
        if (checkOut != null && checkOut!.difference(checkIn!).inMinutes < 180) checkOut = null;
      });
    } else {
      if (checkIn != null && picked.difference(checkIn!).inMinutes < 180) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum booking duration is 3 hours')));
        return;
      }
      setState(() => checkOut = picked);
    }
  }

  Widget _buildBookingFailed() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.xCircle, size: 64, color: Colors.red),
            ),
            const SizedBox(height: 24),
            const Text(
              'Booking Failed',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'We were unable to complete your booking. Please try again later.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            if (_bookingError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  _bookingError!,
                  style: TextStyle(fontSize: 13, color: Colors.red[700]),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.info, size: 20, color: Colors.amber[800]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'If any amount was deducted from your account, it will be refunded within 2–3 business days.',
                      style: TextStyle(fontSize: 14, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleStartNewBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Back to Home', style: TextStyle(color: Colors.grey[700])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentComplete() {
    final provider = context.watch<HotelProvider>();
    final totalPrice = getTotalPrice(provider);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.checkCircle, size: 64, color: Colors.green),
            ),
            const SizedBox(height: 24),
            const Text(
              'Booking Approved!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your reservation at ${selectedHotel?.name} has been approved.',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Booking Details', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildDetailRow('Guest:', _guestName(provider)),
                  _buildDetailRow('Email:', _guestEmail(provider)),
                  _buildDetailRow('Check-in:', DateFormat('MMM d, y  h:mm a').format(checkIn!)),
                  _buildDetailRow('Check-out:', DateFormat('MMM d, y  h:mm a').format(checkOut!)),
                  _buildDetailRow('Rooms:', '${selectedRoomIds.length}'),
                  const Divider(),
                  _buildDetailRow('Total Paid:', '₹${totalPrice.toStringAsFixed(2)}', isTotal: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'A confirmation email has been sent to ${_guestEmail(provider)}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleStartNewBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Make Another Booking'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text('Back to Home', style: TextStyle(color: Colors.grey[700])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (bookingFailed) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: _buildBookingFailed(),
      );
    }

    if (paymentComplete) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: _buildPaymentComplete(),
      );
    }

    final provider = context.watch<HotelProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        surfaceTintColor: Colors.transparent,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () {
            if (showPayment) {
              setState(() => showPayment = false);
            } else if (selectedHotel != null) {
              setState(() => selectedHotel = null);
            } else {
              context.go('/');
            }
          },
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black54),
          label: const Text('Back', style: TextStyle(color: Colors.black54)),
        ),
        title: Text(
          showPayment
              ? 'Payment'
              : selectedHotel != null
                  ? selectedHotel!.name
                  : 'Select a Hotel',
          style: const TextStyle(color: Colors.black87),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: _buildBody(provider),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(HotelProvider provider) {
    if (selectedHotel == null) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          childAspectRatio: 0.85,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
        ),
        itemCount: provider.hotels.length,
        itemBuilder: (context, index) {
          final hotel = provider.hotels[index];
          return HotelCard(
            hotel: hotel,
            onSelect: () => _handleSelectHotel(hotel),
          );
        },
      );
    }

    if (!datesConfirmed) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'When would you like to stay?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Text('Check-in Date & Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDateTime(context, true),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendar, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        checkIn != null ? DateFormat('MMM d, y  h:mm a').format(checkIn!) : 'Select date & time',
                        style: TextStyle(fontSize: 18, color: checkIn != null ? Colors.black : Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Check-out Date & Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDateTime(context, false),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendar, color: Colors.grey),
                      const SizedBox(width: 12),
                      Text(
                        checkOut != null ? DateFormat('MMM d, y  h:mm a').format(checkOut!) : 'Select date & time',
                        style: TextStyle(fontSize: 18, color: checkOut != null ? Colors.black : Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (checkIn != null && checkOut != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$billingDays ${billingDays == 1 ? "day" : "days"} (billed)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (checkIn == null || checkOut == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select both check-in and check-out date & time')),
                    );
                    return;
                  }
                  setState(() {
                    datesConfirmed = true;
                    availableRoomIds = null;
                    loadingRooms = true;
                  });
                  final provider = context.read<HotelProvider>();
                  final ids = await provider.fetchAvailableRooms(
                    hotelId: selectedHotel!.id,
                    checkIn: checkIn!,
                    checkOut: checkOut!,
                  );
                  if (mounted) setState(() { availableRoomIds = ids; loadingRooms = false; });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Search Available Rooms', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      );
    }

    if (showPayment) {
      return _buildPaymentScreen(provider);
    }

    return _buildRoomSelection(provider);
  }

  Widget _buildPaymentScreen(HotelProvider provider) {
    return LayoutBuilder(builder: (context, constraints) {
      bool isWide = constraints.maxWidth > 800;
      Widget leftPanel = Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.lock, color: Colors.green),
                const SizedBox(width: 12),
                const Text('Secure Payment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            _buildTextField('Card Number', _cardNumberController, keyboardType: TextInputType.number, icon: LucideIcons.creditCard),
            const SizedBox(height: 16),
            _buildTextField('Name on Card', _cardNameController),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Expiry Date (MM/YY)', _expiryDateController)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('CVV', _cvvController)),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount to Pay:'),
                Text('₹${getTotalPrice(provider)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handlePayment,
                icon: const Icon(LucideIcons.lock, size: 18),
                label: Text('Pay ₹${getTotalPrice(provider)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Your payment information is encrypted and secure',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
          ],
        ),
      );

      Widget rightPanel = Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Booking Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildSummaryItem('Hotel', selectedHotel?.name ?? ''),
            _buildSummaryItem('Guest Information', '${_guestName(provider)}\n${_guestEmail(provider)}'),
            _buildSummaryItem('Stay Duration', '${DateFormat('MMM d, y h:mm a').format(checkIn!)} →\n${DateFormat('MMM d, y h:mm a').format(checkOut!)}\n$billingDays ${billingDays == 1 ? "day" : "days"} (billed)'),
            const Text('Selected Rooms', style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 8),
            ...selectedRoomIds.map((id) {
              final room = provider.rooms.firstWhere((r) => r.id == id);
              RoomType roomType;
              try { roomType = provider.roomTypes.firstWhere((t) => t.id == room.typeId); } catch(e) { roomType = RoomType(id: 0, hotelId: 0, category: 'Unknown', price: 0); }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Room ${room.roomNumber} (${roomType.category})'),
                        Text('₹${roomType.price}/night'),
                      ],
                    ),
                    Text('$billingDays × ₹${roomType.price} = ₹${roomType.price * billingDays}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    const Divider(),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(fontSize: 18)),
                Text('₹${getTotalPrice(provider)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      );

      return isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: leftPanel),
                const SizedBox(width: 32),
                Expanded(child: rightPanel),
              ],
            )
          : Column(
              children: [
                leftPanel,
                const SizedBox(height: 32),
                rightPanel,
              ],
            );
    });
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? keyboardType, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildRoomSelection(HotelProvider provider) {
    if (loadingRooms) {
      return const Center(child: CircularProgressIndicator());
    }

    final availableRooms = availableRoomIds == null
        ? <Room>[]
        : provider.rooms.where((r) => availableRoomIds!.contains(r.id)).toList();
    final allRooms = provider.rooms;

    return LayoutBuilder(builder: (context, constraints) {
      bool isWide = constraints.maxWidth > 800;

      Widget leftPanel = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Your Stay', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('${DateFormat('MMM d, y h:mm a').format(checkIn!)} →', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    Text('${DateFormat('MMM d, y h:mm a').format(checkOut!)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    Text('$billingDays ${billingDays == 1 ? "day" : "days"} (billed)', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      datesConfirmed = false;
                      selectedRoomIds.clear();
                      showBookingForm = false;
                      availableRoomIds = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[600],
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    backgroundColor: Colors.blue[50], 
                  ),
                  child: const Text('Change Dates'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text('Available Rooms', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (availableRooms.isEmpty)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(
                child: Text('No rooms available for the selected dates', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = (constraints.maxWidth / 400).ceil();
                if (crossAxisCount < 1) crossAxisCount = 1;
                double width = (constraints.maxWidth - ((crossAxisCount - 1) * 16)) / crossAxisCount;
                width = width.floorToDouble();

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: availableRooms.map((room) {
                    return SizedBox(
                      width: width,
                      child: Column(
                        children: [
                          RoomCard(
                            room: room,
                            roomType: provider.roomTypes.firstWhere((t) => t.id == room.typeId, orElse: () => RoomType(id: 0, hotelId: 0, category: 'Unknown', price: 0)),
                            selected: selectedRoomIds.contains(room.id),
                            onSelect: () {
                              setState(() {
                                if (selectedRoomIds.contains(room.id)) {
                                  selectedRoomIds.remove(room.id);
                                } else {
                                  selectedRoomIds.add(room.id);
                                }
                              });
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Builder(
                              builder: (context) {
                                final rt = provider.roomTypes.firstWhere((t) => t.id == room.typeId, orElse: () => RoomType(id: 0, hotelId: 0, category: 'Unknown', price: 0));
                                return Text(
                                  '₹${rt.price} × $billingDays ${billingDays == 1 ? "day" : "days"} = ₹${rt.price * billingDays}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                );
                              }
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      );

      Widget rightPanel = Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Booking Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            if (selectedRoomIds.isEmpty)
              const Text('Select rooms to continue', style: TextStyle(color: Colors.grey))
            else if (!showBookingForm) ...[
              const Text('Selected Rooms:', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 12),
              ...selectedRoomIds.map((id) {
                final room = allRooms.firstWhere((r) => r.id == id);
                RoomType roomType;
                try { roomType = provider.roomTypes.firstWhere((t) => t.id == room.typeId); } catch(e) { roomType = RoomType(id: 0, hotelId: 0, category: 'Unknown', price: 0); }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Room ${room.roomNumber}'),
                          Text('₹${roomType.price}/night'),
                        ],
                      ),
                      Text('$billingDays ${billingDays == 1 ? "day" : "days"} × ₹${roomType.price} = ₹${roomType.price * billingDays}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      const Divider(),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:', style: TextStyle(fontSize: 18)),
                  Text('₹${getTotalPrice(provider)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => showBookingForm = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Continue to Book', style: TextStyle(fontSize: 16)),
                ),
              ),
            ] else ...[
              if (!_isLoggedIn) ...[
                _buildTextField('Full Name', _nameController, icon: LucideIcons.user),
                const SizedBox(height: 16),
                _buildTextField('Email', _emailController, icon: LucideIcons.mail, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 24),
              ],
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow('Check-in:', DateFormat('MMM d, y h:mm a').format(checkIn!)),
              _buildDetailRow('Check-out:', DateFormat('MMM d, y h:mm a').format(checkOut!)),
              _buildDetailRow('Days (billed):', '$billingDays'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Price:', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text('₹${getTotalPrice(provider)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_isLoggedIn && (_nameController.text.isEmpty || _emailController.text.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all details')));
                      return;
                    }
                    setState(() => showPayment = true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Continue to Payment', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => setState(() => showBookingForm = false),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[800],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Back', style: TextStyle(fontSize: 16)),
                ),
              ),
            ]
          ],
        ),
      );

      return isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: leftPanel),
                const SizedBox(width: 32),
                Expanded(flex: 1, child: rightPanel),
              ],
            )
          : Column(
              children: [
                leftPanel,
                const SizedBox(height: 32),
                rightPanel,
              ],
            );
    });
  }
}

