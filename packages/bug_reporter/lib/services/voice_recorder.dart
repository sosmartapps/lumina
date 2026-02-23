import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class VoiceRecorder {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;

  String _currentTranscript = '';
  String get transcript => _currentTranscript;

  bool get isListening => _speech.isListening;

  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize(
      onError: (error) => _currentTranscript += ' [mic error]',
    );
    return _isAvailable;
  }

  Future<void> startListening({
    required void Function(String transcript) onResult,
  }) async {
    if (!_isAvailable) await initialize();
    _currentTranscript = '';

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        _currentTranscript = result.recognizedWords;
        onResult(_currentTranscript);
      },
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  Future<String> stopListening() async {
    await _speech.stop();
    return _currentTranscript;
  }

  void dispose() {
    _speech.cancel();
  }
}
