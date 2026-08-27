import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Timer? _pollTimer;
  final Set<String> _seenIds = {};
  bool _initialized = false;
  String _status = 'not started';

  String get status => _status;

  Future<void> start() async {
    if (_initialized) return;
    _initialized = true;
    _status = 'initializing...';

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
      await _plugin.initialize(settings);
      _status = 'plugin ready';
      _log('plugin initialized');
    } catch (e) {
      _status = 'init error: $e';
      _log('INIT ERROR: $e');
      return;
    }

    await _loadSeenIds();
    _log('loaded ${_seenIds.length} seen IDs');

    // Test notification after 3s to prove plugin works
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        await _showLocal('TradeLink', 'Notifications active!');
        _status = 'test shown, polling in 5s...';
        _log('test notification sent');
      } catch (e) {
        _status = 'test error: $e';
        _log('TEST ERROR: $e');
      }
    });

    // First poll after 8s
    Future.delayed(const Duration(seconds: 8), () async {
      _status = 'polling...';
      await _checkAndNotify();
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkAndNotify());
    });
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _loadSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('notif_seen_ids') ?? [];
    _seenIds.addAll(stored);
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
        _log('API returned null');
        _status = 'API null';
        return;
      }

      final notifications = List<Map<String, dynamic>>.from(data);
      _log('poll: ${notifications.length} notifs, ${_seenIds.length} seen');

      int newCount = 0;
      for (final notif in notifications) {
        final id = notif['id']?.toString();
        if (id == null || _seenIds.contains(id)) continue;

        _seenIds.add(id);
        newCount++;

        final title = notif['title'] as String? ?? 'TradeLink';
        final subtitle = notif['subtitle'] as String? ?? '';

        await _showLocal(title, subtitle);
      }

      _status = '$newCount new (poll ok)';
      _log('$newCount new notifications shown');
      await _persistSeenIds();
    } catch (e) {
      _status = 'poll error: $e';
      _log('POLL ERROR: $e');
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
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.show(_notifCounter, title, body.isNotEmpty ? body : null, details);
      _log('SHOW #${_notifCounter}: "$title"');
    } catch (e) {
      _log('SHOW ERROR: $e');
    }
  }

  void _log(String msg) {
    // Always print so it's visible in release mode too
    // ignore: avoid_print
    print('[NotificationService] $msg');
  }
}
