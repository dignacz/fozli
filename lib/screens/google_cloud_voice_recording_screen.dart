// screens/google_cloud_voice_recording_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/google_cloud_voice_service.dart';
import '../utils/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';

class GoogleCloudVoiceRecordingScreen extends StatefulWidget {
  final String apiKey;
  
  const GoogleCloudVoiceRecordingScreen({
    super.key,
    required this.apiKey,
  });

  @override
  State<GoogleCloudVoiceRecordingScreen> createState() => _GoogleCloudVoiceRecordingScreenState();
}

class _GoogleCloudVoiceRecordingScreenState extends State<GoogleCloudVoiceRecordingScreen>
    with SingleTickerProviderStateMixin {
  String _transcription = '';
  bool _isRecording = false;
  bool _isProcessing = false;
  int _recordingSeconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  String? _audioFilePath;
  late TextEditingController _textController; // ✅ Add controller

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(); // ✅ Initialize
    _textController.addListener(() {
      // Update UI when text changes (for button enable/disable)
      if (mounted) setState(() {});
    });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose(); // ✅ Dispose controller
    _pulseController.dispose();
    GoogleCloudVoiceService.dispose();
    super.dispose();
  }

  void _startTimer() {
    _recordingSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingSeconds++;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _startRecording() async {
    setState(() {
      _isProcessing = true;
      _transcription = '';
    });

    final permissionResult = await GoogleCloudVoiceService.checkPermission();
    if (permissionResult == PermissionResult.permanentlyDenied) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showPermissionDialog();
      }
      return;
    } else if (permissionResult != PermissionResult.granted) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Mikrofon hozzáférés szükséges');
      }
      return;
    }

    final started = await GoogleCloudVoiceService.startRecording();
    if (!started) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Nem sikerült elindítani a felvételt');
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _isProcessing = false;
    });
    _startTimer();
  }

  Future<void> _stopRecording() async {
    _stopTimer();
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    _audioFilePath = await GoogleCloudVoiceService.stopRecording();
    
    if (_audioFilePath == null) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Nem sikerült menteni a felvételt');
      }
      return;
    }

    // Transcribe immediately
    await _transcribeAudio();
  }

  Future<void> _transcribeAudio() async {
    if (_audioFilePath == null) return;

    setState(() => _isProcessing = true);

    try {
      final transcription = await GoogleCloudVoiceService.transcribeAudio(
        audioFilePath: _audioFilePath!,
        apiKey: widget.apiKey,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          if (transcription != null && transcription.isNotEmpty) {
            _transcription = transcription;
            _textController.text = transcription; // ✅ Update text field
          } else {
            _showError('Nem sikerült felismerni a beszédet. Próbáld újra!');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('Hiba történt: $e');
      }
    }
  }

  Future<void> _restart() async {
    // Cancel current recording
    if (_isRecording) {
      await GoogleCloudVoiceService.cancelRecording();
    }
    
    // Delete old recording
    if (_audioFilePath != null) {
      await GoogleCloudVoiceService.deleteRecording(_audioFilePath!);
    }

    setState(() {
      _transcription = '';
      _textController.clear(); // ✅ Clear text field
      _recordingSeconds = 0;
      _audioFilePath = null;
    });
    
    await _startRecording();
  }

  void _finish() {
    final text = _textController.text.trim(); // ✅ Get text from controller
    if (text.isEmpty) {
      _showError('Nem sikerült felismerni a beszédet. Próbáld újra!');
      return;
    }
    
    // Clean up recording file
    if (_audioFilePath != null) {
      GoogleCloudVoiceService.deleteRecording(_audioFilePath!);
    }
    
    Navigator.pop(context, text); // ✅ Return edited text
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mikrofon hozzáférés szükséges'),
        content: const Text(
          'A beszédfelismeréshez engedélyezned kell a mikrofon hozzáférést a Beállításokban.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégse'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Beállítások'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // ✅ Make room for keyboard
      appBar: AppBar(
        title: const Text('Hangfelvétel'),
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView( // ✅ Add scroll view
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 32),

              // Microphone icon with pulse animation
              Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseController.value * 0.2);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording
                              ? AppColors.coral.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.1),
                        ),
                        child: Icon(
                          Icons.mic,
                          size: 60,
                          color: _isRecording ? Colors.red : Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Status text
              Text(
                _isRecording
                    ? 'Felvétel...'
                    : _isProcessing
                        ? 'Feldolgozás...'
                        : 'Kész',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isRecording
                      ? Colors.red
                      : _isProcessing
                          ? Colors.orange
                          : Colors.grey,
                ),
              ),

              const SizedBox(height: 32),

              // Timer
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.coral.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatDuration(_recordingSeconds),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.coral,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Transcription box - EDITABLE! ✅
              Container(
                width: double.infinity,
                height: 200, // ✅ Fixed height instead of Expanded
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: _transcription.isEmpty
                    ? Center(
                        child: Text(
                          _isRecording
                              ? 'Beszélj a mikrofonba...\n\nMagyar nyelven!\n\nPélda: "Tej egy liter, kenyér, három tojás"'
                              : _isProcessing
                                  ? 'Beszéd feldolgozása...'
                                  : 'Kattints az "Újra" gombra a felvétel megkezdéséhez',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : TextField(
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Szerkeszd a szöveget...',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _restart,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Újra'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.coral,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.coral),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRecording
                          ? () => _stopRecording()
                          : (_isProcessing || _textController.text.trim().isEmpty) // ✅ Check controller
                              ? null
                              : _finish,
                      icon: Icon(_isRecording ? Icons.stop : Icons.check),
                      label: Text(_isRecording ? 'Megállít' : 'Kész'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Hint text
              Text(
                '🇭🇺 Magyar nyelv\n✏️ Szerkesztheted a szöveget a feltöltés előtt!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ], // Close children array
          ), // Close Column
        ), // Close Padding
      ), // Close SingleChildScrollView
    ), // Close SafeArea  
  ); // Close Scaffold
  }
}