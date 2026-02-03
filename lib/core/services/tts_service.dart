import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';

/// Service for text-to-speech and audio playback
class TTSService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  /// Initialize the TTS engine
  Future<void> initialize({
    String language = 'en-US',
    double speechRate = 0.45, // Slower for better comprehension
    double volume = 1.0,
    double pitch = 1.0,
  }) async {
    if (_isInitialized) return;

    await _tts.setLanguage(language);
    await _tts.setSpeechRate(speechRate);
    await _tts.setVolume(volume);
    await _tts.setPitch(pitch);

    // Set up callbacks
    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('TTS Error: $msg');
    });

    _isInitialized = true;
  }

  /// Speak the given text
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Stop any current speech
    await stop();

    await _tts.speak(text);
  }

  /// Speak with custom settings
  Future<void> speakWithSettings({
    required String text,
    double? speechRate,
    double? volume,
    double? pitch,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Stop any current speech
    await stop();

    if (speechRate != null) {
      await _tts.setSpeechRate(speechRate);
    }
    if (volume != null) {
      await _tts.setVolume(volume);
    }
    if (pitch != null) {
      await _tts.setPitch(pitch);
    }

    await _tts.speak(text);

    // Reset to defaults
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  /// Speak a reminder message with name
  Future<void> speakReminder({
    required String userName,
    required String message,
    bool playAlertFirst = true,
  }) async {
    if (playAlertFirst) {
      await playAlertSound();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Speak the personalized message
    final personalizedMessage = message.replaceAll('{name}', userName);
    await speak(personalizedMessage);
  }

  /// Speak medication reminder
  Future<void> speakMedicationReminder({
    required String userName,
    required String medicationName,
    String? dosage,
  }) async {
    await playAlertSound();
    await Future.delayed(const Duration(milliseconds: 500));

    String message = '$userName, it\'s time to take your $medicationName';
    if (dosage != null && dosage.isNotEmpty) {
      message += '. Take $dosage';
    }
    message += '. Please take a photo of the empty container when you\'re done.';

    await speak(message);
  }

  /// Play a pre-recorded alert sound
  Future<void> playAlertSound({String? soundFile}) async {
    try {
      final source = soundFile != null
          ? AssetSource(soundFile)
          : AssetSource('sounds/alert.mp3');

      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(source);
    } catch (e) {
      debugPrint('Error playing alert sound: $e');
      // Fallback: play system sound if available
    }
  }

  /// Play success sound
  Future<void> playSuccessSound() async {
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    } catch (e) {
      debugPrint('Error playing success sound: $e');
    }
  }

  /// Play error sound
  Future<void> playErrorSound() async {
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/error.mp3'));
    } catch (e) {
      debugPrint('Error playing error sound: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Pause speaking (if supported)
  Future<void> pause() async {
    await _tts.pause();
  }

  /// Get available languages
  Future<List<dynamic>> getAvailableLanguages() async {
    return await _tts.getLanguages;
  }

  /// Get available voices
  Future<List<dynamic>> getAvailableVoices() async {
    return await _tts.getVoices;
  }

  /// Set voice
  Future<void> setVoice(Map<String, String> voice) async {
    await _tts.setVoice(voice);
  }

  /// Set language
  Future<void> setLanguage(String language) async {
    await _tts.setLanguage(language);
  }

  /// Set speech rate
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    await _tts.setVolume(volume);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    await _audioPlayer.dispose();
  }
}
