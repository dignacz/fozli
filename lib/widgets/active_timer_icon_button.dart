// widgets/active_timer_icon_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/timer_service.dart';
import '../screens/active_timers_screen.dart';

/// Reusable active timer icon button with badge
/// Shows count of active timers and navigates to ActiveTimersScreen when tapped
/// Only visible when there are active timers
class ActiveTimerIconButton extends StatelessWidget {
  final Color? iconColor;
  final Color? badgeColor;
  final double iconSize;

  const ActiveTimerIconButton({
    super.key,
    this.iconColor,
    this.badgeColor,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerService>(
      builder: (context, timerService, _) {
        if (!timerService.hasActiveTimers) {
          return const SizedBox.shrink();
        }
        
        return Stack(
          children: [
            IconButton(
              icon: Icon(Icons.timer, size: iconSize),
              color: iconColor,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ActiveTimersScreen(),
                  ),
                );
              },
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor ?? const Color(0xFFE74C3C),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 22,
                  minHeight: 22,
                ),
                child: Text(
                  '${timerService.activeTimersCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}