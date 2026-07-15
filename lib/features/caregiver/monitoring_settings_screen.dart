import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/emergency_disclaimer_banner.dart';
import '../battery/battery_monitor.dart';
import '../fuel/fuel_monitor.dart';

/// Caregiver screen for configuring battery and fuel alert thresholds.
class MonitoringSettingsScreen extends ConsumerStatefulWidget {
  const MonitoringSettingsScreen({super.key});

  @override
  ConsumerState<MonitoringSettingsScreen> createState() =>
      _MonitoringSettingsScreenState();
}

class _MonitoringSettingsScreenState
    extends ConsumerState<MonitoringSettingsScreen> {
  final BatteryMonitor _batteryMonitor = BatteryMonitor();
  late final FuelMonitor _fuelMonitor;

  double _batteryThreshold = 0.20;
  double _fuelThreshold = 0.20;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Google Places key reused from Maps config — only needed for nearest-station lookup.
    _fuelMonitor = FuelMonitor(googlePlacesApiKey: '');
    _loadThresholds();
  }

  Future<void> _loadThresholds() async {
    final battery = await _batteryMonitor.getThreshold();
    final fuel = await _fuelMonitor.getThreshold();
    if (mounted) {
      setState(() {
        _batteryThreshold = battery;
        _fuelThreshold = fuel;
        _loading = false;
      });
    }
  }

  Future<void> _saveBatteryThreshold(double value) async {
    setState(() => _batteryThreshold = value);
    await _batteryMonitor.setThreshold(value);
  }

  Future<void> _saveFuelThreshold(double value) async {
    setState(() => _fuelThreshold = value);
    await _fuelMonitor.setThreshold(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Monitoring Settings'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Legal: point-of-use disclaimer (docs/legal/LEGAL-IMPLEMENTATION.md)
                const EmergencyDisclaimerBanner(
                  margin: EdgeInsets.only(bottom: 12),
                ),
                // ── Battery Section ──────────────────────────────────
                _buildSectionHeader(
                  icon: Icons.battery_alert,
                  color: AppTheme.primaryOrange,
                  title: 'Phone Battery Alerts',
                  subtitle:
                      'Alert the caregiver when the user\'s phone battery drops below this level.',
                ),
                const SizedBox(height: 8),
                _buildThresholdSlider(
                  value: _batteryThreshold,
                  onChanged: _saveBatteryThreshold,
                  color: AppTheme.primaryOrange,
                  unit: '%',
                ),
                const SizedBox(height: 8),
                Text(
                  'Current threshold: ${(_batteryThreshold * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const Divider(height: 40),

                // ── Fuel Section ─────────────────────────────────────
                _buildSectionHeader(
                  icon: Icons.local_gas_station,
                  color: AppTheme.primaryRed,
                  title: 'Vehicle Fuel Alerts',
                  subtitle:
                      'Alert when the vehicle fuel level drops below this level. '
                      'Also navigates to the nearest gas station.',
                ),
                const SizedBox(height: 8),
                _buildThresholdSlider(
                  value: _fuelThreshold,
                  onChanged: _saveFuelThreshold,
                  color: AppTheme.primaryRed,
                  unit: '%',
                ),
                const SizedBox(height: 8),
                Text(
                  'Current threshold: ${(_fuelThreshold * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const Divider(height: 40),

                // ── Info Card ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Alerts include a local notification on the user\'s phone '
                          'and a push notification to linked caregivers. '
                          'Cooldowns prevent repeated alerts (20 min for battery, 30 min for fuel).',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThresholdSlider({
    required double value,
    required ValueChanged<double> onChanged,
    required Color color,
    required String unit,
  }) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
            overlayColor: color.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value,
            min: 0.05,
            max: 0.50,
            divisions: 9,
            label: '${(value * 100).toStringAsFixed(0)}$unit',
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('5%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            Text('50%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }
}
