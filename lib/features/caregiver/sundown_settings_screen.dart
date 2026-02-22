import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Caregiver screen for configuring sundown return-home alerts.
class SundownSettingsScreen extends ConsumerStatefulWidget {
  const SundownSettingsScreen({super.key});

  @override
  ConsumerState<SundownSettingsScreen> createState() =>
      _SundownSettingsScreenState();
}

class _SundownSettingsScreenState extends ConsumerState<SundownSettingsScreen> {
  late bool _enabled;
  late int _bufferMinutes;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userNotifierProvider).user;
    _enabled = user?.settings.sundownAlertEnabled ?? true;
    _bufferMinutes = user?.settings.sundownBufferMinutes ?? 30;
  }

  Future<void> _save() async {
    final userProvider = ref.read(userNotifierProvider);
    final user = userProvider.user;
    if (user == null) return;

    final updatedSettings = user.settings.copyWith(
      sundownAlertEnabled: _enabled,
      sundownBufferMinutes: _bufferMinutes,
    );

    await userProvider.updateSettings(updatedSettings);

    // Update the running sundown service
    final sundownService = ref.read(sundownServiceProvider);
    sundownService.updateSettings(
      enabled: _enabled,
      bufferMinutes: _bufferMinutes,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sundown alert settings saved'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      setState(() => _hasChanges = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sundown Alerts'),
        backgroundColor: AppTheme.primaryOrange,
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
          // Info card
          Card(
            color: AppTheme.primaryOrange.withValues(alpha: 0.1),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.wb_twilight, color: AppTheme.primaryOrange, size: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'When enabled, the app will alert the user to head home '
                      'before sunset based on their distance and travel time.',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Enable toggle
          SwitchListTile(
            title: const Text(
              'Sundown Return Home Alert',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _enabled ? 'Alert is active' : 'Alert is disabled',
              style: TextStyle(
                color: _enabled ? AppTheme.primaryGreen : Colors.grey,
              ),
            ),
            value: _enabled,
            activeThumbColor: AppTheme.primaryGreen,
            onChanged: (value) {
              setState(() {
                _enabled = value;
                _hasChanges = true;
              });
            },
          ),

          const Divider(height: 32),

          // Buffer time slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buffer Time Before Sunset',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alert $_bufferMinutes minutes before they need to leave',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('15', style: TextStyle(color: Colors.grey)),
                    Expanded(
                      child: Slider(
                        value: _bufferMinutes.toDouble(),
                        min: 15,
                        max: 60,
                        divisions: 9,
                        activeColor: AppTheme.primaryOrange,
                        label: '$_bufferMinutes min',
                        onChanged: _enabled
                            ? (value) {
                                setState(() {
                                  _bufferMinutes = value.round();
                                  _hasChanges = true;
                                });
                              }
                            : null,
                      ),
                    ),
                    const Text('60', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          // How it works section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How It Works',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.location_on,
                  text: 'Checks distance from home every 5 minutes',
                ),
                SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.wb_twilight,
                  text: 'Calculates local sunset time automatically',
                ),
                SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.directions_car,
                  text: 'Detects if driving or walking for travel time',
                ),
                SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.notifications_active,
                  text: 'Shows persistent full-screen alert with voice',
                ),
                SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.sms,
                  text: 'Sends text message to primary caregiver',
                ),
                SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.repeat,
                  text: 'Re-alerts every 2 minutes until heading home',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryOrange),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 15)),
        ),
      ],
    );
  }
}
