// screens/timer_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/preset_timers.dart';
import '../models/cooking_timer.dart';
import '../services/timer_service.dart';
import '../utils/app_colors.dart';

class TimerScreen extends StatelessWidget {
  final bool isPremium;

  const TimerScreen({
    super.key,
    this.isPremium = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Categories grouped by method
        ...PresetTimers.categoriesByMethod.entries.map((entry) {
            final method = entry.key;
            final categories = entry.value;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Method header with distinctive styling
                Container(
                  margin: const EdgeInsets.only(bottom: 12, top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _getMethodColor(method),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getMethodIcon(method),
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        method.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Categories
                ...categories.map((category) => _CategoryCard(
                  category: category,
                  isPremium: isPremium,
                )),

                const SizedBox(height: 20),
              ],
            );
          }),

          // Custom timer button with new design
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9B59B6), Color(0xFF8E44AD)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9B59B6).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showCustomTimerDialog(context),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_alarm, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Egyedi időzítő',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Adj meg saját időt',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Airfryer joke at the bottom
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade100,
                  Colors.orange.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade300, width: 2),
            ),
            child: Row(
              children: [
                const Text('🤖🍟', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    PresetTimers.airfryerJoke,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'Főzés':
        return AppColors.lavender; // Blue
      case 'Sütés':
        return AppColors.fire; // Orange
      case 'Párolás':
        return AppColors.sage; // Teal
      default:
        return const Color(0xFF95A5A6); // Gray
    }
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'Főzés':
        return Icons.soup_kitchen;
      case 'Sütés':
        return Icons.local_fire_department;
      case 'Párolás':
        return Icons.cloud;
      default:
        return Icons.timer;
    }
  }

  // PASTE THIS CODE into your timer_screen.dart
// Replace the _showCustomTimerDialog function

void _showCustomTimerDialog(BuildContext context) {
  final nameController = TextEditingController();
  final minutesController = TextEditingController();
  String selectedEmoji = '⏰';

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_alarm, color: Color(0xFF9B59B6)),
            SizedBox(width: 12),
            Text('Egyedi időzítő'),
          ],
        ),
        content: SingleChildScrollView( // ✅ MAKES IT SCROLLABLE
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji picker
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['⏰', '🍳', '🥘', '🍲', '🥗', '🍕', '🍝', '🥩', '🧁', '☕']
                    .map((emoji) => GestureDetector(
                          onTap: () => setState(() => selectedEmoji = emoji),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: selectedEmoji == emoji
                                  ? const Color(0xFF9B59B6).withOpacity(0.2)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selectedEmoji == emoji
                                    ? const Color(0xFF9B59B6)
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Text(emoji, style: const TextStyle(fontSize: 28)),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Név',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF9B59B6), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minutesController,
                decoration: InputDecoration(
                  labelText: 'Percek',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF9B59B6), width: 2),
                  ),
                  suffixText: 'perc',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8), // Extra padding
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégse'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty || minutesController.text.isEmpty) {
                return;
              }
              
              final timer = CookingTimer(
                name: nameController.text,
                emoji: selectedEmoji,
                durationMinutes: int.parse(minutesController.text),
                category: 'Egyedi',
              );
              
              context.read<TimerService>().startTimer(timer);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B59B6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Indítás'),
          ),
        ],
      ),
    ),
  );
}
}

class _CategoryCard extends StatelessWidget {
  final TimerCategory category;
  final bool isPremium;

  const _CategoryCard({
    required this.category,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              category.emoji,
              style: const TextStyle(fontSize: 28),
            ),
          ),
          title: Text(
            category.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: Color(0xFF2C3E50),
            ),
          ),
          subtitle: Text(
            '${category.presets.length} időzítő',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          children: [
            if (category.infoBox != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF3498DB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3498DB).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF3498DB), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.infoBox!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2C3E50),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          
            ...category.presets.map((preset) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${preset.minutes}\'',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              title: Text(
                preset.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: preset.description != null
                  ? Text(
                      preset.description!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    )
                  : null,
              trailing: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.play_arrow, color: Color(0xFF27AE60), size: 24),
              ),
              onTap: () => _startTimer(context, preset),
            )),
          ],
        ),
      ),
    );
  }

  void _startTimer(BuildContext context, TimerPreset preset) {
  final activeTimersCount = context.read<TimerService>().activeTimersCount;
  
  // Check PRO limit
  if (!isPremium && activeTimersCount >= 1) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text('PRO funkció'),
          ],
        ),
        content: const Text(
          'Egyszerre több időzítő csak PRO verzióban érhető el!\n\n'
          'Válts PRO verzióra a korlátlan időzítőkért!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Rendben'),
          ),
        ],
      ),
    );
    return;
  }

  final timer = CookingTimer(
    name: preset.name,
    emoji: category.emoji,
    durationMinutes: preset.minutes,
    category: '${category.method} - ${category.name}',
    description: preset.description,
  );
  
  context.read<TimerService>().startTimer(timer);
  // NO SNACKBAR - Just start the timer silently
}
}