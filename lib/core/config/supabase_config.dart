import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration helper for Supabase (PostgreSQL) initialization & access
class SupabaseConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Initialize Supabase Flutter SDK
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      // iignore: deprecated_member_use
      anonKey: supabaseAnonKey,
    );
  }

  /// Helper to obtain Supabase Client
  static SupabaseClient get client => Supabase.instance.client;

  // Supabase Database Table Names matching PDF Class Diagram
  static const String tableUsers = 'users';
  static const String tableProducts = 'products';
  static const String tableDemands = 'demands';
  static const String tableStocks = 'stocks';
  static const String tableOrders = 'orders';
  static const String tableOtps = 'otps';
  static const String tableRatings = 'ratings';
  static const String tableNotifications = 'notifications';
}
