// screens/import_shopping_list_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/fozli_import_service.dart';
import '../services/ai_import_service.dart';
import '../utils/app_colors.dart';

class ImportShoppingListDialog {
  static Future<void> show(BuildContext context, {required bool isPremium}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ImportShoppingListSheet(isPremium: isPremium),
    );
  }
}

class ImportShoppingListSheet extends StatelessWidget {
  final bool isPremium;

  const ImportShoppingListSheet({super.key, required this.isPremium});

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
                  'Lista importálása',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // .fozli file import
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: AppColors.coral),
              title: const Text('.fozli fájl'),
              subtitle: const Text('Importálj korábban mentett listát'),
              onTap: () {
                Navigator.pop(context);
                _importFromFile(context);
              },
            ),
            const Divider(),

            // AI text import
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
              subtitle: const Text('Másold be a bevásárlólista szövegét'),
              enabled: isPremium,
              onTap: isPremium
                  ? () {
                      Navigator.pop(context);
                      _importFromAiText(context);
                    }
                  : null,
            ),
            const Divider(),

            // AI image import
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
              subtitle: const Text('Fényképezz le vagy tölts fel listát'),
              enabled: isPremium,
              onTap: isPremium
                  ? () {
                      Navigator.pop(context);
                      _showImageImportOptions(context);
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
                      isFromFile ? 'Fájlból:' : 'Másold be a lista szövegét:',
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
                  hintText: 'Bevásárlólista szövege...',
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

    final importResult = await AiImportService.importShoppingListFromText(result);

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

    final importResult = await AiImportService.importShoppingListFromImage(image.path);

    if (context.mounted) {
      Navigator.pop(context); // Close loading
      _handleAiImportResult(context, importResult);
    }
  }

  static void _showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
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
    );
  }

  static void _handleImportResult(BuildContext context, ImportResult result) {
    if (result.importedType == 'recipe') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info, color: Colors.orange),
              SizedBox(width: 12),
              Text('Recept importálva'),
            ],
          ),
          content: const Text(
            'Ez egy recept volt, ezért a Receptek fülön lett hozzáadva.',
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
}