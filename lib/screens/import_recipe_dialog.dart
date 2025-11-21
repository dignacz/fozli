// screens/import_recipe_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/fozli_import_service.dart';
import '../services/url_recipe_import_service.dart';
import '../services/ai_import_service.dart';
import '../utils/app_colors.dart';
import 'recipe_detail_screen.dart';
import 'add_recipe_screen.dart';

class ImportRecipeDialog {
  static Future<void> show(
    BuildContext context, {
    required bool isPremium,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ImportRecipeSheet(
        isPremium: isPremium,
        rootContext: context,   // 👈 EZ A FONTOS!
      ),
    );
  }
}

class ImportRecipeSheet extends StatelessWidget {
  final bool isPremium;
  final BuildContext rootContext; // 🔥 EZ AZ ÚJ

  const ImportRecipeSheet({
    super.key,
    required this.isPremium,
    required this.rootContext, // 🔥
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download, color: AppColors.coral),
                const SizedBox(width: 12),
                Text(
                  'Recept importálása',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ✨ NEW: Create recipe option
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.coral.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: AppColors.coral),
            ),
            title: const Text('Új recept létrehozása'),
            subtitle: const Text('Írj be egy saját receptet'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                rootContext,
                MaterialPageRoute(
                  builder: (context) => const AddRecipeScreen(),
                ),
              );
            },
          ),
          
          const Divider(height: 32),
          
          // Import section header
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'IMPORTÁLÁS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
          ),

            // 📁 .fozli file import
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: AppColors.coral),
              title: const Text('.fozli fájl'),
              subtitle: const Text('Importálj korábban mentett receptet'),
              onTap: () {
                Navigator.pop(context);             // sheet bezár
                _importFromFile(rootContext);       // ✅ NEM a sheet context
              },
            ),
            const Divider(),

            // 🔗 URL import
            ListTile(
              leading: const Icon(Icons.link, color: AppColors.coral),
              title: const Text('Weboldalról (URL)'),
              subtitle: const Text('Recept importálása webcímről'),
              onTap: () {
                Navigator.pop(context);
                _importFromUrl(rootContext);       // ✅ FONTOS
              },
            ),
            const Divider(),

            // 🤖 AI text import
            ListTile(
              leading: Icon(
                Icons.text_snippet,
                color: isPremium ? AppColors.coral : Colors.grey,
              ),
              title: Row(
                children: [
                  const Text('Szövegből (AI)'),
                  if (!isPremium) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: const Text('Másold be a recept szövegét'),
              enabled: isPremium,
              onTap: isPremium
                  ? () {
                      Navigator.pop(context);
                      _importFromAiText(rootContext);   // ✅
                    }
                  : null,
            ),
            const Divider(),

            // 📷 AI image import
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: isPremium ? AppColors.coral : Colors.grey,
              ),
              title: Row(
                children: [
                  const Text('Fotóból (AI)'),
                  if (!isPremium) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: const Text('Fényképezz le vagy tölts fel receptet'),
              enabled: isPremium,
              onTap: isPremium
                  ? () {
                      Navigator.pop(context);
                      _showImageImportOptions(rootContext);   // ✅
                    }
                  : null,
            ),

            if (!isPremium) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Válts PRO verzióra az AI-alapú importálásért!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  static Future<void> _importFromFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null) return;

      final filePath = result.files.single.path!;
      if (!filePath.endsWith('.fozli')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kérlek válassz egy .fozli fájlt!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        _showLoadingDialog(context);
      }

      final importResult = await FozliImportService.importFozliFile(filePath);

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        _handleImportResult(context, importResult);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e')),
        );
      }
    }
  }

  static Future<void> _importFromUrl(BuildContext context) async {
    final urlController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importálás URL-ről'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add meg a recept webcímét:'),
            const SizedBox(height: 8),
            Text(
              'Példa: https://www.allrecipes.com/recipe/...',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Csak schema.org/Recipe formátumot támogató oldalak működnek',
                      style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégse'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, urlController.text),
            child: const Text('Importálás'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    if (context.mounted) {
      _showLoadingDialog(context, message: 'Weboldal betöltése és elemzése...');
    }

    final importResult = await UrlRecipeImportService.importFromUrl(result);

    if (context.mounted) {
      Navigator.pop(context); // Close loading

      if (importResult.success && importResult.recipe != null) {
        _showSuccessDialog(
          context,
          importResult.message,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecipeDetailScreen(recipe: importResult.recipe!),
              ),
            );
          },
        );
      } else {
        // Show detailed error
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 12),
                Text('Import sikertelen'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(importResult.message),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tips_and_updates, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 8),
                            Text(
                              'Tippek:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Használj ismert recept oldalakat\n'
                          '• Próbáld a CookPad-ot vagy Mindmegettét\n'
                          '• Ellenőrizd, hogy a link recept oldalt mutat',
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Rendben'),
              ),
            ],
          ),
        );
      }
    }
  }

  static Future<void> _importFromAiText(BuildContext context) async {
    final textController = TextEditingController();
    bool isFromFile = false;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('AI Importálás - Szöveg'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isFromFile ? 'Fájlból:' : 'Másold be a recept szövegét:',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['txt'],
                      );
                      if (result != null) {
                        final file = result.files.single;
                        if (file.path != null) {
                          final content = await File(file.path!).readAsString();
                          textController.text = content;
                          setState(() => isFromFile = true);
                        }
                      }
                    },
                    icon: const Icon(Icons.file_upload, size: 16),
                    label: const Text('txt fájl', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Recept szövege...',
                ),
                maxLines: 10,
                autofocus: !isFromFile,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mégse'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, textController.text),
              child: const Text('Importálás'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.isEmpty) return;

    if (context.mounted) {
      _showLoadingDialog(context, message: 'AI feldolgozás...');
    }

    final importResult = await AiImportService.importRecipeFromText(result);

    if (context.mounted) {
      Navigator.pop(context); // Close loading
      _handleAiImportResult(context, importResult);
    }
  }

  static Future<void> _showImageImportOptions(BuildContext context) async {
    final option = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.coral),
              title: const Text('Fényképezés'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.coral),
              title: const Text('Galéria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (option == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: option);

    if (image == null) return;

    if (context.mounted) {
      _showLoadingDialog(context, message: 'AI feldolgozás...');
    }

    final importResult = await AiImportService.importRecipeFromImage(image.path);

    if (context.mounted) {
      Navigator.pop(context); // Close loading
      _handleAiImportResult(context, importResult);
    }
  }

  static void _showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.coral),
                  const SizedBox(height: 16),
                  Text(message ?? 'Importálás...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _showSuccessDialog(
    BuildContext context,
    String message,
    VoidCallback onView,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Text('Sikeres!'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bezárás'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onView();
            },
            child: const Text('Megnézem'),
          ),
        ],
      ),
    );
  }

  static void _handleImportResult(BuildContext context, ImportResult result) {
    if (result.importedType == 'shopping_list') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info, color: Colors.orange),
              SizedBox(width: 12),
              Text('Bevásárlólista importálva'),
            ],
          ),
          content: const Text(
            'Ez egy bevásárlólista volt, ezért a Bevásárlólista fülön lett hozzáadva.',
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error,
              color: result.success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Text(result.success ? 'Sikeres!' : 'Hiba'),
          ],
        ),
        content: Text(result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Rendben'),
          ),
        ],
      ),
    );
  }

  static void _handleAiImportResult(BuildContext context, AiImportResult result) {
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (result.importedType == 'recipe' && result.importedData != null) {
      _showSuccessDialog(
        context,
        result.message,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailScreen(recipe: result.importedData),
            ),
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}