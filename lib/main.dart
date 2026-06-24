import 'package:flutter/material.dart';

import 'screens/report_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/trip_screen.dart';
import 'utils/app_colors.dart';
import 'utils/app_route_observer.dart';

void main() {
  runApp(const WasteGlassCollectionApp());
}

class WasteGlassCollectionApp extends StatelessWidget {
  const WasteGlassCollectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waste Glass Collection App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.backgroundColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
          secondary: AppColors.darkGreen,
          surface: Colors.white,
          error: AppColors.warningRed,
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppColors.textDark,
          displayColor: AppColors.textDark,
          fontFamily: 'Roboto',
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primaryGreen,
              width: 1.5,
            ),
          ),
          labelStyle: const TextStyle(color: AppColors.mutedText),
          prefixIconColor: AppColors.primaryGreen,
        ),
      ),
      initialRoute: '/trip',
      navigatorObservers: [appRouteObserver],
      routes: {
        '/trip': (context) => const TripScreen(),
        '/scan': (context) => const ScanScreen(),
        '/report': (context) => const ReportScreen(),
      },
    );
  }
}
