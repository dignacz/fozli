import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_wrapper.dart';
import 'utils/app_colors.dart';
import 'services/ai_import_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // MUST be first!
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: ".env");
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set API key from .env
  final apiKey = dotenv.env['GEMINI_API_KEY']; // ← ADD THIS
  if (apiKey != null) {
    AiImportService.setApiKey(apiKey);
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Főzli',
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
    );
  }
}