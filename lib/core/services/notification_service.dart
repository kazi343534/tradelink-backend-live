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

    // Show a test notification after 3s to verify the plugin works
    Future.delayed(const Duration(seconds: 3), () async {
      await _showLocal('TradeLink', 'Notifications are active');
    });

    // Delay first poll by 5s to let permission dialog complete
    Future.delayed(const Duration(seconds: 5), () async {
      await _checkAndNotify();
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkAndNotify());
    });
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
    if (kDebugMode) print('[NotificationService] initialized');
  }

  /// Request notification permission (call after user logs in).
  Future<void> requestPermission() async {
    // iOS
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final iosResult = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    if (kDebugMode) print('[NotificationService] iOS permission: $iosResult');
    // Android 13+
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final androidResult = await android?.requestNotificationsPermission();
    if (kDebugMode) print('[NotificationService] Android permission: $androidResult');
  }

  Future<void> _loadSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('notif_seen_ids') ?? [];
    _seenIds.addAll(stored);
    if (kDebugMode) print('[NotificationService] loaded ${_seenIds.length} seen IDs');
  }

  Future<void> _persistSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = _seenIds.toList()..removeRange(0, (_seenIds.length - 200).clamp(0, _seenIds.length));
    _seenIds.clear();
    _seenIds.addAll(trimmed);
    await prefs.setStringList('notif_seen_ids', trimmed);
  }

  Future<void> _checkAndNotify() async {
    try {
      final data = await ApiService.get('/notifications');
      if (data == null) {
        if (kDebugMode) print('[NotificationService] poll: no data returned');
        return;
      }

      final notifications = List<Map<String, dynamic>>.from(data);
      if (kDebugMode) print('[NotificationService] poll: ${notifications.length} notifications, ${_seenIds.length} already seen');

      int newCount = 0;
      for (final notif in notifications) {
        final id = notif['id']?.toString();
        if (id == null || _seenIds.contains(id)) continue;

        _seenIds.add(id);
        newCount++;

        final title = notif['title'] as String? ?? 'TradeLink';
        final subtitle = notif['subtitle'] as String? ?? '';

        if (kDebugMode) print('[NotificationService] NEW: $title - $subtitle');
        await _showLocal(title, subtitle);
      }

      if (kDebugMode && newCount > 0) print('[NotificationService] showed $newCount new notifications');

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

    try {
      await _plugin.show(_notifCounter, title, body.isNotEmpty ? body : null, details);
      if (kDebugMode) print('[NotificationService] shown: #$notifCounter $title');
    } catch (e) {
      if (kDebugMode) print('[NotificationService] show error: $e');
    }
  }
}
