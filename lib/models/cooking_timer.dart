// models/cooking_timer.dart
import 'package:uuid/uuid.dart';

class CookingTimer {
  final String id;
  final String name;
  final String emoji;
  final int durationMinutes;
  final DateTime startTime;
  final String category;
  final String? description;

  CookingTimer({
    String? id,
    required this.name,
    required this.emoji,
    required this.durationMinutes,
    DateTime? startTime,
    required this.category,
    this.description,
  })  : id = id ?? const Uuid().v4(),
        startTime = startTime ?? DateTime.now();

  int get remainingSeconds {
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    final total = durationMinutes * 60;
    return (total - elapsed).clamp(0, total);
  }

  bool get isFinished => remainingSeconds == 0;

  double get progress {
    final total = durationMinutes * 60;
    return (total - remainingSeconds) / total;
  }

  String get timeDisplay {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  CookingTimer copyWith({
    String? id,
    String? name,
    String? emoji,
    int? durationMinutes,
    DateTime? startTime,
    String? category,
    String? description,
  }) {
    return CookingTimer(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startTime: startTime ?? this.startTime,
      category: category ?? this.category,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'durationMinutes': durationMinutes,
      'startTime': startTime.toIso8601String(),
      'category': category,
      'description': description,
    };
  }

  factory CookingTimer.fromMap(Map<String, dynamic> map) {
    return CookingTimer(
      id: map['id'],
      name: map['name'],
      emoji: map['emoji'],
      durationMinutes: map['durationMinutes'],
      startTime: DateTime.parse(map['startTime']),
      category: map['category'],
      description: map['description'],
    );
  }
}