import 'package:flutter/material.dart';
import 'package:metermate_frontend/widgets/auth_wrapper.dart';
import 'package:metermate_frontend/screens/login_screen.dart';
import 'package:metermate_frontend/screens/signup_screen.dart';
import 'package:metermate_frontend/screens/home_screen.dart';
import 'package:metermate_frontend/screens/jobs_screen.dart';
import 'package:metermate_frontend/screens/todays_jobs_screen.dart';
import 'package:metermate_frontend/screens/meter_reading_screen.dart';
import 'package:metermate_frontend/screens/messages_screen.dart';
import 'package:metermate_frontend/screens/settings_screen.dart';
import 'package:metermate_frontend/screens/contacts_screen.dart';
import 'package:metermate_frontend/screens/vehicle_check_screen.dart';
import 'package:metermate_frontend/services/config_service.dart';
import 'package:metermate_frontend/services/settings_service.dart';
import 'package:metermate_frontend/services/connectivity_service.dart';
import 'package:metermate_frontend/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.initialize();
  
  // Initialize connectivity and sync services
  await ConnectivityService().initialize();
  await SyncService().startAutoSync();
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _themeMode = 'light';

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final themeMode = await SettingsService.getThemeMode();
    setState(() {
      _themeMode = themeMode;
    });
  }

  ThemeMode get _themeModeEnum {
    switch (_themeMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeterMate',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF75D4ED),
          brightness: Brightness.light,
          primary: const Color(0xFF10133D),
          secondary: const Color(0xFF8DCC6F),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8FB),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE4EE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE4EE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF75D4ED), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF5B6380)),
        ),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF75D4ED),
          brightness: Brightness.dark,
          primary: const Color(0xFF75D4ED),
          secondary: const Color(0xFF8DCC6F),
        ),
        scaffoldBackgroundColor: Colors.grey[900],
        brightness: Brightness.dark,
        cardColor: Colors.grey[800],
      ),
      themeMode: _themeModeEnum,
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/jobs': (context) => const JobsScreen(),
        '/todays-jobs': (context) => const TodaysJobsScreen(),
        '/messages': (context) => const MessagesScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/contacts': (context) => const ContactsScreen(),
        '/meter-reading': (context) {
          final job = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return MeterReadingScreen(job: job);
        },
        '/vehicle-check': (context) => const VehicleCheckScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
} 