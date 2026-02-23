import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Displays the user's phone battery level on the caregiver dashboard.
class BatteryStatusCard extends StatefulWidget {
  const BatteryStatusCard({super.key});

  @override
  State<BatteryStatusCard> createState() => _BatteryStatusCardState();
}

class _BatteryStatusCardState extends State<BatteryStatusCard> {
  final Battery _battery = Battery();
  int _level = -1;
  BatteryState _state = BatteryState.unknown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      if (mounted) setState(() { _level = level; _state = state; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_level < 0) return const SizedBox.shrink();

    final isCharging = _state == BatteryState.charging || _state == BatteryState.full;
    final color = _level <= 15
        ? AppTheme.primaryRed
        : _level <= 30
            ? AppTheme.primaryOrange
            : AppTheme.primaryGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isCharging ? Icons.battery_charging_full : Icons.battery_std,
            color: color,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Phone Battery',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _level / 100.0,
                    backgroundColor: Colors.grey.shade200,
                    color: color,
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$_level%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (isCharging) ...[
            const SizedBox(width: 4),
            Icon(Icons.bolt, color: Colors.amber.shade700, size: 18),
          ],
        ],
      ),
    );
  }
}
