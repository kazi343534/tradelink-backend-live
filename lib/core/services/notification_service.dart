import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Shows phone-system notifications when new in-app notifications arrive.
/// Polls the backend periodically and compares against previously seen IDs.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Timer? _pollTimer;
  final Set<String> _seenIds = {};
  bool _initialized = false;

  /// Start polling for new notifications and showing system notifications.
  Future<void> start() async {
    if (_initialized) return;
    _initialized = true;

    await _initNotifications();
    await _loadSeenIds();

    // Initial fetch
    await _checkAndNotify();

    // Poll every 15 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkAndNotify());
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
  }

  /// Request notification permission (call after user logs in).
  Future<void> requestPermission() async {
    // iOS
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    // Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _loadSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('notif_seen_ids') ?? [];
    _seenIds.addAll(stored);
  }

  Future<void> _persistSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    // Keep only last 200 IDs to avoid unbounded growth
    final trimmed = _seenIds.toList()..removeRange(0, (_seenIds.length - 200).clamp(0, _seenIds.length));
    _seenIds.clear();
    _seenIds.addAll(trimmed);
    await prefs.setStringList('notif_seen_ids', trimmed);
  }

  Future<void> _checkAndNotify() async {
    try {
      final data = await ApiService.get('/notifications');
      if (data == null) return;

      final notifications = List<Map<String, dynamic>>.from(data);

      for (final notif in notifications) {
        final id = notif['id']?.toString();
        if (id == null || _seenIds.contains(id)) continue;

        _seenIds.add(id);

        final title = notif['title'] as String? ?? 'TradeLink';
        final subtitle = notif['subtitle'] as String? ?? '';

        await _showLocal(title, subtitle);
      }

      await _persistSeenIds();
    } catch (e) {
      if (kDebugMode) print('[NotificationService] poll error: $e');
    }
  }

  int _notifCounter = 0;

  Future<void> _showLocal(String title, String body) async {
    _notifCounter++;

    const androidDetails = AndroidNotificationDetails(
      'tradelink_channel',
      'TradeLink Notifications',
      channelDescription: 'Alerts for orders, deliveries, and messages',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(_notifCounter, title, body.isNotEmpty ? body : null, details);
  }
}
