import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileLocalization extends ChangeNotifier {
  static const String _langKey = 'user_language';
  String _currentLanguage = 'en'; // 'en' or 'bn'

  String get currentLanguage => _currentLanguage;
  bool get isBangla => _currentLanguage == 'bn';

  static final ProfileLocalization _instance = ProfileLocalization._internal();
  factory ProfileLocalization() => _instance;
  ProfileLocalization._internal() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_langKey) ?? 'en';
    notifyListeners();
  }

  Future<void> toggleLanguage(String langCode) async {
    if (_currentLanguage == langCode) return;
    _currentLanguage = langCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, langCode);
    notifyListeners();
  }

  String translate(String key) {
    if (_currentLanguage == 'en') {
      return _en[key] ?? key;
    } else {
      return _bn[key] ?? _en[key] ?? key;
    }
  }

  // --- Dictionary ---
  static const Map<String, String> _en = {
    'profile': 'Profile',
    'good_morning': 'Good morning',
    'shop_owner': 'Shop Owner',
    'supplier': 'Supplier / Wholesaler',
    'personal_details': 'Personal Details',
    'full_name': 'Full Name',
    'phone': 'Phone',
    'email': 'Email',
    'shop_details': 'Shop Details',
    'business_name': 'Business Name',
    'category': 'Category',
    'address': 'Address',
    'business_hours': 'Business Hours',
    'tax_id': 'Tax ID / BIN',
    'description': 'Description',
    'settings': 'Settings',
    'notifications': 'Notifications',
    'language': 'Language',
    'support': 'Support',
    'help_center': 'Help Center',
    'privacy_policy': 'Privacy Policy',
    'log_out': 'Log out',
    'not_set': 'Not set',
    'edit': 'Edit',
    'save_changes': 'Save Changes',
    'success_update': 'Details updated successfully!',
    'failed_update': 'Failed to update details',
    'opening_time': 'Opening Time',
    'closing_time': 'Closing Time',
    'e_g_09_00': 'e.g. 09:00',
    'e_g_21_00': 'e.g. 21:00',
    'e_g_basmati': 'e.g. TradeLink Store',
  };

  static const Map<String, String> _bn = {
    'profile': 'প্রোফাইল',
    'good_morning': 'শুভ সকাল',
    'shop_owner': 'দোকান মালিক',
    'supplier': 'সরবরাহকারী / পাইকারি বিক্রেতা',
    'personal_details': 'ব্যক্তিগত তথ্য',
    'full_name': 'পুরো নাম',
    'phone': 'ফোন নম্বর',
    'email': 'ইমেইল',
    'shop_details': 'দোকানের তথ্য',
    'business_name': 'ব্যবসার নাম',
    'category': 'ক্যাটাগরি',
    'address': 'ঠিকানা',
    'business_hours': 'ব্যবসার সময়',
    'tax_id': 'ট্যাক্স আইডি / বিন',
    'description': 'বিবরণ',
    'settings': 'সেটিংস',
    'notifications': 'নোটিফিকেশন',
    'language': 'ভাষা (Language)',
    'support': 'সাপোর্ট',
    'help_center': 'হেল্প সেন্টার',
    'privacy_policy': 'গোপনীয়তা নীতি',
    'log_out': 'লগ আউট',
    'not_set': 'সেট করা নেই',
    'edit': 'সম্পাদনা করুন',
    'save_changes': 'সংরক্ষণ করুন',
    'success_update': 'তথ্য সফলভাবে আপডেট করা হয়েছে!',
    'failed_update': 'তথ্য আপডেট করতে ব্যর্থ হয়েছে',
    'opening_time': 'খোলার সময়',
    'closing_time': 'বন্ধের সময়',
    'e_g_09_00': 'যেমন ০৯:০০',
    'e_g_21_00': 'যেমন ২১:০০',
    'e_g_basmati': 'যেমন ট্রেডলিংক স্টোর',
  };
}
