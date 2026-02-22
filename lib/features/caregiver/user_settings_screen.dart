import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_user.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Caregiver screen for configuring general user settings.
class UserSettingsScreen extends ConsumerStatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  ConsumerState<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends ConsumerState<UserSettingsScreen> {
  late bool _highContrastMode;
  late double _textScale;
  late bool _soundEnabled;
  late bool _vibrationEnabled;
  late bool _voicePromptsEnabled;
  late int _reminderVolume;
  late String _voiceLanguage;
  bool _hasChanges = false;

  static const _languages = {
    'en-US': 'English (US)',
    'en-GB': 'English (UK)',
    'es-ES': 'Spanish',
    'fr-FR': 'French',
    'de-DE': 'German',
    'pt-BR': 'Portuguese',
    'zh-CN': 'Chinese (Simplified)',
  };

  @override
  void initState() {
    super.initState();
    final user = ref.read(userNotifierProvider).user;
    final s = user?.settings ?? UserSettings();
    _highContrastMode = s.highContrastMode;
    _textScale = s.textScale;
    _soundEnabled = s.soundEnabled;
    _vibrationEnabled = s.vibrationEnabled;
    _voicePromptsEnabled = s.voicePromptsEnabled;
    _reminderVolume = s.reminderVolume;
    _voiceLanguage = s.voiceLanguage;
  }

  Future<void> _save() async {
    final userProvider = ref.read(userNotifierProvider);
    final user = userProvider.user;
    if (user == null) return;

    final updatedSettings = user.settings.copyWith(
      highContrastMode: _highContrastMode,
      textScale: _textScale,
      soundEnabled: _soundEnabled,
      vibrationEnabled: _vibrationEnabled,
      voicePromptsEnabled: _voicePromptsEnabled,
      reminderVolume: _reminderVolume,
      voiceLanguage: _voiceLanguage,
    );

    await userProvider.updateSettings(updatedSettings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      setState(() => _hasChanges = false);
    }
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Settings'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _save,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Display section ---
          _sectionHeader('Display'),
          SwitchListTile(
            title: const Text('High Contrast Mode'),
            subtitle: const Text('Increases contrast for better visibility'),
            value: _highContrastMode,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (v) {
              setState(() => _highContrastMode = v);
              _markChanged();
            },
          ),
          ListTile(
            title: const Text('Text Size'),
            subtitle: Text('Scale: ${_textScale.toStringAsFixed(1)}x'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: _textScale,
                min: 1.0,
                max: 2.0,
                divisions: 10,
                activeColor: AppTheme.primaryBlue,
                label: '${_textScale.toStringAsFixed(1)}x',
                onChanged: (v) {
                  setState(() => _textScale = v);
                  _markChanged();
                },
              ),
            ),
          ),

          const Divider(height: 32),

          // --- Audio section ---
          _sectionHeader('Audio & Alerts'),
          SwitchListTile(
            title: const Text('Sound Effects'),
            subtitle: const Text('Play sounds for reminders and alerts'),
            value: _soundEnabled,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (v) {
              setState(() => _soundEnabled = v);
              _markChanged();
            },
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            subtitle: const Text('Vibrate on reminders and alerts'),
            value: _vibrationEnabled,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (v) {
              setState(() => _vibrationEnabled = v);
              _markChanged();
            },
          ),
          SwitchListTile(
            title: const Text('Voice Prompts'),
            subtitle: const Text('Speak reminders aloud via text-to-speech'),
            value: _voicePromptsEnabled,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (v) {
              setState(() => _voicePromptsEnabled = v);
              _markChanged();
            },
          ),
          ListTile(
            title: const Text('Reminder Volume'),
            subtitle: Text('$_reminderVolume%'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: _reminderVolume.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: AppTheme.primaryBlue,
                label: '$_reminderVolume%',
                onChanged: _soundEnabled
                    ? (v) {
                        setState(() => _reminderVolume = v.round());
                        _markChanged();
                      }
                    : null,
              ),
            ),
          ),

          const Divider(height: 32),

          // --- Voice section ---
          _sectionHeader('Voice Language'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                initialValue: _voiceLanguage,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'TTS Language',
                ),
                items: _languages.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _voiceLanguage = v);
                    _markChanged();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }
}
