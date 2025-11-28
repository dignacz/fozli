import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'auth_wrapper.dart';
import 'utils/app_colors.dart';
import 'services/ai_import_service.dart';
import 'services/timer_service.dart';
import 'services/notification_service.dart'; // ✅ ADD THIS
import 'screens/active_timers_screen.dart'; // ✅ ADD THIS
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ✅ ADD THIS: Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // MUST be first!
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: ".env");
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set API key from .env
  final apiKey = dotenv.env['GEMINI_API_KEY'];
  if (apiKey != null) {
    AiImportService.setApiKey(apiKey);
  }
  
  // ✅✅✅ CRITICAL FIX: Initialize timer service and set callback
  print('🚀 Initializing TimerService...');
  await TimerService().initialize();
  print('✅ TimerService initialized');
  
  // ✅✅✅ CRITICAL FIX: Set up notification tap callback
  print('🔗 Setting up notification callback...');
  NotificationService.onNotificationTap = () async {
    print('');
    print('═══════════════════════════════════');
    print('🔔 NOTIFICATION TAPPED IN MAIN.DART!');
    print('═══════════════════════════════════');
    
    // Navigate to active timers
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => const ActiveTimersScreen(),
      ),
    );
    
    // Stop the alarm
    print('🔇 Calling TimerService().stopAlarm()...');
    await TimerService().stopAlarm();
    print('✅ stopAlarm() completed');
    print('═══════════════════════════════════');
    print('');
  };
  print('✅ Notification callback set');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TimerService(),
      child: MaterialApp(
        title: 'Főzli',
        navigatorKey: navigatorKey, // ✅ ADD THIS: So notifications can navigate
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('hu', 'HU'),
          Locale('en', 'US'),
        ],
        locale: const Locale('hu', 'HU'),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.coral,
            primary: AppColors.coral,
            secondary: AppColors.lavender,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.coral,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.coral,
            foregroundColor: Colors.white,
          ),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}