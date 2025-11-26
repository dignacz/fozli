// services/google_cloud_voice_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

class GoogleCloudVoiceService {
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  static String? _recordingPath;
  static bool _isRecording = false;
  static bool _isInitialized = false;

  /// Initialize the recorder
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _recorder.openRecorder();
      _isInitialized = true;
      debugPrint('Recorder initialized');
    } catch (e) {
      debugPrint('Error initializing recorder: $e');
    }
  }

  /// Check microphone permission
  static Future<PermissionResult> checkPermission() async {
    final status = await Permission.microphone.status;
    
    if (status.isGranted) {
      return PermissionResult.granted;
    }
    
    if (status.isDenied) {
      final result = await Permission.microphone.request();
      if (result.isGranted) {
        return PermissionResult.granted;
      } else if (result.isPermanentlyDenied) {
        return PermissionResult.permanentlyDenied;
      } else {
        return PermissionResult.denied;
      }
    }
    
    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }
    
    return PermissionResult.denied;
  }

  /// Start recording audio
  static Future<bool> startRecording() async {
    try {
      // Initialize if needed
      if (!_isInitialized) {
        await initialize();
      }

      // Check permission
      final permResult = await checkPermission();
      if (permResult != PermissionResult.granted) {
        debugPrint('Microphone permission not granted');
        return false;
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/voice_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      debugPrint('Starting recording to: $_recordingPath');

      // Start recording
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV, // WAV format for Google Cloud
        sampleRate: 16000, // 16kHz recommended by Google
        numChannels: 1, // Mono
      );

      _isRecording = true;
      debugPrint('Recording started successfully');
      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording and return the file path
  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording) {
        debugPrint('Not currently recording');
        return null;
      }

      final path = await _recorder.stopRecorder();
      _isRecording = false;
      
      debugPrint('Recording stopped. File: $path');
      return path ?? _recordingPath;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel recording
  static Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stopRecorder();
        _isRecording = false;
      }
      
      // Delete the recording file
      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('Error canceling recording: $e');
    }
  }

  /// Check if currently recording
  static bool get isRecording => _isRecording;

  /// Transcribe audio file using Google Cloud Speech-to-Text API
  static Future<String?> transcribeAudio({
    required String audioFilePath,
    required String apiKey,
  }) async {
    try {
      debugPrint('Starting transcription for: $audioFilePath');

      // Read audio file
      final audioFile = File(audioFilePath);
      if (!await audioFile.exists()) {
        debugPrint('Audio file does not exist');
        return null;
      }

      final audioBytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(audioBytes);

      debugPrint('Audio file size: ${audioBytes.length} bytes');

      // Prepare request
      final url = 'https://speech.googleapis.com/v1/speech:recognize?key=$apiKey';
      
      final requestBody = {
        'config': {
          'encoding': 'LINEAR16',
          'sampleRateHertz': 16000,
          'languageCode': 'hu-HU', // Hungarian ONLY
          // ✅ REMOVED alternative languages - they were confusing the detector!
          'enableAutomaticPunctuation': true,
          'model': 'default',
        },
        'audio': {
          'content': base64Audio,
        },
      };

      debugPrint('Sending request to Google Cloud Speech-to-Text');

      // Send request
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('Response: $responseData');

        if (responseData['results'] != null && responseData['results'].isNotEmpty) {
          final transcript = responseData['results'][0]['alternatives'][0]['transcript'] as String;
          debugPrint('Transcription: $transcript');
          return transcript;
        } else {
          debugPrint('No transcription results');
          return null;
        }
      } else {
        debugPrint('Error response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error during transcription: $e');
      return null;
    }
  }

  /// Clean up temporary recording file
  static Future<void> deleteRecording(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('Deleted recording: $filePath');
      }
    } catch (e) {
      debugPrint('Error deleting recording: $e');
    }
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      if (_isInitialized) {
        await _recorder.closeRecorder();
        _isInitialized = false;
      }
    } catch (e) {
      debugPrint('Error disposing recorder: $e');
    }
  }
}

enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
}