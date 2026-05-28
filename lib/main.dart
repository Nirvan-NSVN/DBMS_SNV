import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'providers/hotel_provider.dart';
import 'services/auth_service.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/customer_view.dart';
import 'pages/signup_page.dart';
import 'pages/receptionist_dashboard.dart';
import 'pages/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

final _authService = AuthService();

final _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) async {
    final isLoggedIn = _authService.isLoggedIn;
    final isReceptionistRoute = state.matchedLocation == '/receptionist';
    final isAdminRoute = state.matchedLocation == '/admin';
    final isCustomerRoute = state.matchedLocation == '/customer';
    final isHomeRoute = state.matchedLocation == '/';

    if (isLoggedIn) {
      final admin = await _authService.isAdmin();
      final staff = await _authService.isStaff();

      // Block admin/staff from customer portal
      if (isCustomerRoute && (admin || staff)) {
        return admin ? '/admin' : '/receptionist';
      }

      // Block non-staff from receptionist dashboard
      if (isReceptionistRoute && !staff) return admin ? '/admin' : '/customer';

      // Block non-admin from admin dashboard
      if (isAdminRoute && !admin) return staff ? '/receptionist' : '/customer';
    } else {
      if (isReceptionistRoute || isAdminRoute || isHomeRoute) return '/login';
    }

    return null; // No redirect
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupPage(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/customer',
      builder: (context, state) => const CustomerView(),
    ),
    GoRoute(
      path: '/receptionist',
      builder: (context, state) => const ReceptionistDashboard(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboard(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HotelProvider()),
      ],
      child: MaterialApp.router(
        title: 'Hotel Management System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            primary: Colors.blue[600],
            secondary: Colors.indigo[600],
            surface: Colors.grey[50]!,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: AppBarTheme(
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            centerTitle: false,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        routerConfig: _router,
      ),
    );
  }
}
