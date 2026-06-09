import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_task_manager/pages/home_page.dart';
import 'package:student_task_manager/pages/login_page.dart';
import 'package:student_task_manager/utils/constants.dart';

void main() {
  runApp(const MyApp());
}

// ROOT APP ─────────────────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Task Mate',
      theme: ThemeData(
        useMaterial3: true,
        // ── Use a plain seed so AppColors.primary stays in control ──────────
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,       // AppColors is imported from constnts
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardBg,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

// SPLASH SCREEN  ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ── Animation fields ──────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();

    // Build controller
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Fade: 0 → 1
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    // Scale: 0.7 → 1  (elastic bounce)
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    _animController.forward();

    // Only ONE navigation method, using PrefKeys
    _whereToGo();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Navigation logic ──────────────────────────────────────────────────────
  Future<void> _whereToGo() async {
    final prefs      = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(PrefKeys.isLoggedIn) ?? false; // PrefKeys is now imported ✅

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => isLoggedIn ? const HomePage() :  LoginPage(),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,   //  now assigned
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon container
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // App name
                  const Text(
                    'Student Task Manager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    'Stay organised. Stay ahead.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Loading spinner
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}