// screens/active_timers_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cooking_timer.dart';
import '../services/timer_service.dart';
import '../utils/app_colors.dart';
import 'dart:async';

class ActiveTimersScreen extends StatelessWidget {
  const ActiveTimersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Row(
          children: [
            SizedBox(width: 8),
            Text('Aktív időzítők'),
          ],
        ),
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<TimerService>(
            builder: (context, timerService, _) {
              if (!timerService.hasActiveTimers) return const SizedBox.shrink();
              
              return IconButton(
                icon: const Icon(Icons.delete_sweep, size: 28),
                onPressed: () => _confirmClearAll(context),
              );
            },
          ),
        ],
      ),
      body: Consumer<TimerService>(
        builder: (context, timerService, _) {
          if (!timerService.hasActiveTimers) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.timer_off,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nincs aktív időzítő',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Indíts egyet az előző oldalon!',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: timerService.activeTimers.length,
            itemBuilder: (context, index) {
              final timer = timerService.activeTimers[index];
              return _TimerCard(timer: timer);
            },
          );
        },
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE74C3C)),
            SizedBox(width: 12),
            Text('Összes törlése'),
          ],
        ),
        content: const Text('Biztosan törölni szeretnéd az összes aktív időzítőt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégse'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<TimerService>().clearAllTimers();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Minden időzítő törölve'),
                  backgroundColor: Color(0xFFE74C3C),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );
  }
}

class _TimerCard extends StatefulWidget {
  final CookingTimer timer;

  const _TimerCard({required this.timer});

  @override
  State<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<_TimerCard> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Update UI every second to show live countdown
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFinished = widget.timer.isFinished;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: isFinished
            ? LinearGradient(
                colors: [Colors.green.shade50, Colors.green.shade100],
              )
            : const LinearGradient(
                colors: [Colors.white, Colors.white],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFinished ? Colors.green : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isFinished
                ? Colors.green.withOpacity(0.2)
                : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: isFinished
                          ? Colors.green.shade700
                          : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.timer.emoji,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.timer.name,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: isFinished ? Colors.green.shade900 : const Color(0xFF2C3E50),
                        ),
                      ),
                      if (widget.timer.description != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            widget.timer.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          widget.timer.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFE74C3C)),
                    onPressed: () {
                      context.read<TimerService>().removeTimer(widget.timer.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${widget.timer.emoji} ${widget.timer.name} törölve'),
                          backgroundColor: const Color(0xFFE74C3C),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: widget.timer.progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isFinished
                            ? [Colors.green, Colors.green.shade700]
                            : [const Color(0xFF3498DB), const Color(0xFF2980B9)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Time display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isFinished)
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        'KÉSZ! 🎉',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                        color: AppColors.coral,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.timer.timeDisplay,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.timer.durationMinutes} perc',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),

            if (isFinished) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.green, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kész! Ellenőrizd az ételedet!',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}