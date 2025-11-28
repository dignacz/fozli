// data/preset_timers.dart

class TimerPreset {
  final String name;
  final int minutes;
  final String? description;

  const TimerPreset({
    required this.name,
    required this.minutes,
    this.description,
  });
}

class TimerCategory {
  final String name;
  final String emoji;
  final String method; // főzés, sütés, párolás
  final List<TimerPreset> presets;
  final String? infoBox;

  const TimerCategory({
    required this.name,
    required this.emoji,
    required this.method,
    required this.presets,
    this.infoBox,
  });
}

class PresetTimers {
  static const categories = [
    // 🥚 TOJÁS - Főzés
    TimerCategory(
      name: 'Tojás',
      emoji: '🥚',
      method: 'Főzés',
      presets: [
        TimerPreset(name: 'Folyós lágytojás', minutes: 4, description: 'Nagyon puha'),
        TimerPreset(name: 'Krémes lágytojás', minutes: 6, description: 'Krémes sárga'),
        TimerPreset(name: 'Majdnem szilárd', minutes: 8, description: 'Szinte kemény'),
        TimerPreset(name: 'Keménytojás', minutes: 10, description: 'Jó kemény'),
        TimerPreset(name: 'Keménytojás', minutes: 12, description: 'Teljesen kemény'),
        TimerPreset(name: 'Keménytojás extra', minutes: 14, description: 'Biztosan kemény'),
      ],
      infoBox: 'Forrástól számítva',
    ),

    // 🥦 ZÖLDSÉG - Főzés
    TimerCategory(
      name: 'Zöldség',
      emoji: '🥦',
      method: 'Főzés',
      presets: [
        TimerPreset(name: 'Borsó', minutes: 3, description: 'Forrásban levő vízbe'),
        TimerPreset(name: 'Brokkoli', minutes: 5, description: 'Forrásban levő vízbe'),
        TimerPreset(name: 'Karfiol', minutes: 8, description: 'Forrásban levő vízbe'),
        TimerPreset(name: 'Kukorica (cső)', minutes: 8, description: 'Forrásban levő vízbe'),
        TimerPreset(name: 'Sárgarépa (karika)', minutes: 10, description: 'Forrásban levő vízbe'),
        TimerPreset(name: 'Burgonya (kocka)', minutes: 10, description: 'Forrásban levő vízbe'),
        TimerPreset(name: 'Burgonya (egész)', minutes: 20, description: 'Forrásban levő vízbe'),
        TimerPreset(name: 'Cékla (egész)', minutes: 45, description: 'Forrásban levő vízbe'),
      ],
      infoBox: 'Forrásban levő vízbe bedobod, nem kell vele foglalkozni',
    ),

    // 🍖 HÚS - Főzés (leveshez)
    TimerCategory(
      name: 'Hús',
      emoji: '🍖',
      method: 'Főzés',
      presets: [
        TimerPreset(name: 'Csirkemell', minutes: 25, description: 'Leveshez'),
        TimerPreset(name: 'Csirkecomb', minutes: 35, description: 'Leveshez'),
        TimerPreset(name: 'Sertéslapocka', minutes: 90, description: 'Leveshez'),
        TimerPreset(name: 'Marhapofa', minutes: 150, description: 'Leveshez'),
        TimerPreset(name: 'Marhalábszár', minutes: 180, description: 'Leveshez'),
      ],
      infoBox: 'Leveshez / főzéshez',
    ),

    // 🍗 HÚS - Sütés
    TimerCategory(
      name: 'Hús',
      emoji: '🥩',
      method: 'Sütés',
      presets: [
        TimerPreset(name: 'Csirkeszárny', minutes: 35, description: 'Sütőben'),
        TimerPreset(name: 'Csirkecomb', minutes: 40, description: 'Sütőben'),
        TimerPreset(name: 'Hússzelet tepsiben', minutes: 45, description: 'Sütőben'),
        TimerPreset(name: 'Sertéssült', minutes: 80, description: 'Sütőben'),
        TimerPreset(name: 'Egész csirke', minutes: 85, description: 'Sütőben'),
      ],
      infoBox: 'Betolod, becsukod, békén hagyod',
    ),

    // 🥦 ZÖLDSÉG - Sütés
    TimerCategory(
      name: 'Zöldség',
      emoji: '🥔',
      method: 'Sütés',
      presets: [
        TimerPreset(name: 'Brokkoli sütve', minutes: 20, description: 'Sütőben'),
        TimerPreset(name: 'Karfiol sütve', minutes: 25, description: 'Sütőben'),
        TimerPreset(name: 'Tök / Cukkini sütve', minutes: 25, description: 'Sütőben'),
        TimerPreset(name: 'Sült krumpli (tepsi)', minutes: 35, description: 'Sütőben'),
        TimerPreset(name: 'Cékla sütve', minutes: 45, description: 'Sütőben'),
      ],
      infoBox: 'Betolod, becsukod, békén hagyod',
    ),

    // 🌫️ ZÖLDSÉG - Párolás
    TimerCategory(
      name: 'Zöldség',
      emoji: '🥕',
      method: 'Párolás',
      presets: [
        TimerPreset(name: 'Brokkoli párolva', minutes: 7, description: 'Fedő alatt'),
        TimerPreset(name: 'Spárga', minutes: 7, description: 'Fedő alatt'),
        TimerPreset(name: 'Zöldbab párolva', minutes: 9, description: 'Fedő alatt'),
        TimerPreset(name: 'Karfiol párolva', minutes: 9, description: 'Fedő alatt'),
        TimerPreset(name: 'Répa párolva', minutes: 11, description: 'Fedő alatt'),
      ],
      infoBox: 'Fedő alatt, kis vízzel',
    ),

    // 🍖 HÚS - Párolás
    TimerCategory(
      name: 'Hús',
      emoji: '🍗',
      method: 'Párolás',
      presets: [
        TimerPreset(name: 'Csirkecsíkok', minutes: 20, description: 'Fedő alatt'),
        TimerPreset(name: 'Pulykamell', minutes: 40, description: 'Fedő alatt'),
        TimerPreset(name: 'Csirkecomb', minutes: 45, description: 'Fedő alatt'),
      ],
      infoBox: 'Fedő alatt, kis vízzel',
    ),
  ];

  // Group by method for easier display
  static Map<String, List<TimerCategory>> get categoriesByMethod {
    final map = <String, List<TimerCategory>>{};
    for (final category in categories) {
      map[category.method] = [...(map[category.method] ?? []), category];
    }
    return map;
  }

  // Airfryer joke
  static const String airfryerJoke = 
      'Airfryer-hez nem adunk időzítőt: úgyis jobban számol, mint mi.';
}