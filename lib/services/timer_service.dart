// services/timer_service.dart
// Copy this ENTIRE file to replace your timer_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/cooking_timer.dart';
import 'notification_service.dart';

class TimerService extends ChangeNotifier {
  static final TimerService _instance = TimerService._internal();
  factory TimerService() => _instance;
  TimerService._internal();

  final List<CookingTimer> _activeTimers = [];
  final NotificationService _notificationService = NotificationService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _updateTimer;
  Timer? _alarmStopTimer;

  List<CookingTimer> get activeTimers => List.unmodifiable(_activeTimers);
  int get activeTimersCount => _activeTimers.length;
  bool get hasActiveTimers => _activeTimers.isNotEmpty;

  Future<void> initialize() async {
    print('🚀 TimerService.initialize() called');
    await _notificationService.initialize();
    print('✅ TimerService initialized');
  }

  // ✅✅✅ PUBLIC METHOD - Can be called from main.dart
  Future<void> stopAlarm() async {
    print('');
    print('═══════════════════════════════════');
    print('🔇 stopAlarm() CALLED');
    print('═══════════════════════════════════');
    
    try {
      _alarmStopTimer?.cancel();
      _alarmStopTimer = null;
      print('✅ Timer cancelled');
      
      for (int i = 0; i < 5; i++) {
        print('🛑 Stopping alarm (attempt ${i + 1}/5)...');
        await _audioPlayer.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      print('🔄 Releasing audio player...');
      await _audioPlayer.release();
      
      print('');
      print('═══════════════════════════════════');
      print('✅✅✅ ALARM STOPPED ✅✅✅');
      print('═══════════════════════════════════');
      print('');
    } catch (e) {
      print('❌ ERROR: $e');
    }
  }

  Future<void> startTimer(CookingTimer timer) async {
    _activeTimers.add(timer);
    await _notificationService.showTimerNotification(timer);
    _startUpdateLoop();
    notifyListeners();
  }

  Future<void> removeTimer(String timerId) async {
    _activeTimers.removeWhere((t) => t.id == timerId);
    await _notificationService.cancelTimerNotification(timerId);
    await stopAlarm();
    if (_activeTimers.isEmpty) {
      _stopUpdateLoop();
    }
    notifyListeners();
  }

  Future<void> clearAllTimers() async {
    _activeTimers.clear();
    await _notificationService.cancelAllTimerNotifications();
    await stopAlarm();
    _stopUpdateLoop();
    notifyListeners();
  }

  void _startUpdateLoop() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      for (final timer in _activeTimers) {
        if (!timer.isFinished) {
          await _notificationService.updateTimerNotification(timer);
        }
      }
      
      final finished = _activeTimers.where((t) => t.isFinished).toList();
      for (final timer in finished) {
        await _onTimerFinished(timer);
        _activeTimers.remove(timer);
      }
      
      notifyListeners();
      
      if (_activeTimers.isEmpty) {
        _stopUpdateLoop();
      }
    });
  }

  void _stopUpdateLoop() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  Future<void> _onTimerFinished(CookingTimer timer) async {
    print('⏰ Timer finished: ${timer.name}');
    await _notificationService.cancelTimerNotification(timer.id);
    await _notificationService.showTimerCompletedNotification(timer);
    await _playAlarmSound();
  }

  Future<void> _playAlarmSound() async {
    print('🔊 Starting alarm...');
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/timer_complete.mp3'));
      
      _alarmStopTimer?.cancel();
      _alarmStopTimer = Timer(const Duration(seconds: 30), () {
        print('⏱️ 30s auto-stop');
        stopAlarm();
      });
      
      print('✅ Alarm playing');
    } catch (e) {
      print('❌ Alarm error: $e');
    }
  }

  @override
  void dispose() {
    _stopUpdateLoop();
    _alarmStopTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}