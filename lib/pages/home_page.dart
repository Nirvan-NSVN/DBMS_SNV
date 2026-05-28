import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  bool _isStaff = false;
  bool _isAdmin = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final staff = await _authService.isStaff();
    final admin = await _authService.isAdmin();
    if (mounted) {
      setState(() {
        _isStaff = staff;
        _isAdmin = admin;
        _isChecking = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue[50]!,
              Colors.indigo[100]!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with user info & logout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(LucideIcons.userCheck, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      _authService.currentUser?.email ?? '',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: _handleLogout,
                      icon: Icon(LucideIcons.logOut, size: 16, color: Colors.red[600]),
                      label: Text('Logout', style: TextStyle(color: Colors.red[600])),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Hotel Management System',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Choose your portal to continue',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 48),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              bool isWide = constraints.maxWidth > 700;

                              final showCustomer = !_isStaff && !_isAdmin;
                              final cards = [
                                if (showCustomer)
                                  _buildPortalCard(
                                    context,
                                    title: 'Customer Portal',
                                    description: 'Browse hotels, view available rooms, and make room requests',
                                    buttonText: 'Enter as Customer',
                                    icon: LucideIcons.hotel,
                                    iconColor: Colors.blue[600]!,
                                    iconBgColor: Colors.blue[100]!,
                                    onTap: () => context.go('/customer'),
                                  ),
                                if (_isStaff)
                                  _buildPortalCard(
                                    context,
                                    title: 'Receptionist Portal',
                                    description: 'Manage rooms, view status, and handle bookings',
                                    buttonText: 'Enter as Receptionist',
                                    icon: LucideIcons.userCog,
                                    iconColor: Colors.indigo[600]!,
                                    iconBgColor: Colors.indigo[100]!,
                                    onTap: () => context.go('/receptionist'),
                                  ),
                                if (_isAdmin)
                                  _buildPortalCard(
                                    context,
                                    title: 'Admin Portal',
                                    description: 'Full database access — manage all tables and records',
                                    buttonText: 'Enter as Admin',
                                    icon: LucideIcons.shieldCheck,
                                    iconColor: Colors.purple[600]!,
                                    iconBgColor: Colors.purple[100]!,
                                    onTap: () => context.go('/admin'),
                                  ),
                              ];

                              if (isWide && cards.length > 1) {
                                return IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      for (int i = 0; i < cards.length; i++) ...[
                                        if (i > 0) const SizedBox(width: 32),
                                        Expanded(child: cards[i]),
                                      ],
                                    ],
                                  ),
                                );
                              } else {
                                return Wrap(
                                  spacing: 32,
                                  runSpacing: 32,
                                  alignment: WrapAlignment.center,
                                  children: cards
                                      .map((c) => SizedBox(
                                            width: isWide && cards.length == 1 ? 400 : double.infinity,
                                            child: c,
                                          ))
                                      .toList(),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortalCard(
    BuildContext context, {
    required String title,
    required String description,
    required String buttonText,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 64, color: iconColor),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
