import 'package:flutter/material.dart';
import 'core/config/firebase_config.dart';
import 'core/config/supabase_config.dart';
import 'core/constants/app_colors.dart';
import 'features/auth/presentation/screens/login_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'features/auth/presentation/screens/shop_owner_home_screen.dart';
import 'features/auth/presentation/screens/stockholder_home_screen.dart';
import 'features/delivery/presentation/screens/delivery_man_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Tech Stack: Firebase Auth & Supabase (PostgreSQL)
  await FirebaseConfig.initialize();
  await SupabaseConfig.initialize();

  runApp(const TradelinkApp());
}

class TradelinkApp extends StatelessWidget {
  const TradelinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TradeLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryTeal),
        scaffoldBackgroundColor: AppColors.backgroundLight,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final role = prefs.getString('user_role');

    if (!mounted) return;

    if (userId != null && userId.isNotEmpty) {
      if (role == 'shop_owner') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ShopOwnerHomeScreen()),
        );
      } else if (role == 'delivery_man') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DeliveryManHomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StockholderHomeScreen()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primaryTeal),
      ),
    );
  }
}

class TechStackInitializedScreen extends StatelessWidget {
  const TechStackInitializedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1A29),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF666B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 64,
                      color: Color(0xFFFF666B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'TRADELINK',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Flutter Project & Tech Stack Initialized',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B253A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        _TechItem(name: 'Mobile Platforms', value: 'Android & iOS'),
                        Divider(color: Colors.white10),
                        _TechItem(name: 'PostgreSQL Database', value: 'Supabase (supabase_flutter)'),
                        Divider(color: Colors.white10),
                        _TechItem(name: 'User Authentication', value: 'Firebase (firebase_auth)'),
                      ],
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

class _TechItem extends StatelessWidget {
  final String name;
  final String value;

  const _TechItem({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
