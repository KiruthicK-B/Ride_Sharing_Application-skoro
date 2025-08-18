import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'providers/simple_auth_provider.dart';
import 'providers/ride_provider.dart';
import 'providers/location_provider.dart';
import 'screens/auth/new_login_screen.dart';
import 'screens/auth/new_signup_screen.dart';
import 'screens/auth/user_type_selection_screen.dart';
import 'screens/rider/rider_home_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/rider/book_ride_screen.dart';
import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SkoroApp());
}

class SkoroApp extends StatelessWidget {
  const SkoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SimpleAuthProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return MaterialApp.router(
            title: 'Skoro - Ride Sharing',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              primaryColor: AppColors.primary,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              fontFamily: 'Roboto',
            ),
            routerConfig: _router,
          );
        },
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/user-type',
  routes: [
    GoRoute(
      path: '/user-type',
      builder: (context, state) => const UserTypeSelectionScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final userType = state.uri.queryParameters['userType'] ?? 'rider';
        return LoginScreen(userType: userType);
      },
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) {
        final userType = state.uri.queryParameters['userType'] ?? 'rider';
        return SignupScreen(userType: userType);
      },
    ),
    GoRoute(
      path: '/rider-home',
      builder: (context, state) => const RiderHomeScreen(),
    ),
    GoRoute(
      path: '/driver-home',
      builder: (context, state) => const DriverHomeScreen(),
    ),
    GoRoute(
      path: '/book-ride',
      builder: (context, state) => const BookRideScreen(),
    ),
  ],
);
