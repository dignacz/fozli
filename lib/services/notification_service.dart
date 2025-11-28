// services/notification_service.dart
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/cooking_timer.dart';
import '../utils/app_colors.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  
  // CRITICAL: Static callback for notification tap
  static void Function()? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;

    await Permission.notification.request();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // CRITICAL: Set up notification tap handler
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('📱 Notification response received: ${response.id}');
        print('📱 Action: ${response.actionId}');
        print('📱 Input: ${response.input}');
        
        // Call the callback
        if (onNotificationTap != null) {
          print('✅ Calling onNotificationTap callback');
          onNotificationTap!();
        } else {
          print('❌ onNotificationTap is NULL!');
        }
      },
    );

    _initialized = true;
    print('✅ NotificationService initialized');
  }

  Future<void> showTimerNotification(CookingTimer timer) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'cooking_timers',
      'Kitchen Timers',
      channelDescription: 'Active cooking timers',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: timer.durationMinutes * 60,
      progress: (timer.durationMinutes * 60) - timer.remainingSeconds,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      icon: '@mipmap/ic_launcher',
      color: AppColors.coral,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      timer.id.hashCode,
      '${timer.emoji} ${timer.name}',
      timer.timeDisplay,
      details,
    );
  }

  Future<void> updateTimerNotification(CookingTimer timer) async {
    if (!_initialized) return;
    await showTimerNotification(timer);
  }

  Future<void> cancelTimerNotification(String timerId) async {
    if (!_initialized) return;
    await _notifications.cancel(timerId.hashCode);
  }

  Future<void> showTimerCompletedNotification(CookingTimer timer) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'timer_completed',
      'Timer Completed',
      channelDescription: 'Alerts when cooking timers finish',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      icon: '@mipmap/ic_launcher',
      color: AppColors.sage,
      // CRITICAL: Action button
      actions: const [
        AndroidNotificationAction(
          'view',
          'Megnézem',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999999 + timer.id.hashCode,
      '🎉 ${timer.name} - KÉSZ!',
      'Az időzítő lejárt! Ellenőrizd az ételedet!',
      details,
    );
    
    print('✅ Completion notification shown for: ${timer.name}');
  }

  Future<void> cancelAllTimerNotifications() async {
    if (!_initialized) return;
    await _notifications.cancelAll();
  }
}