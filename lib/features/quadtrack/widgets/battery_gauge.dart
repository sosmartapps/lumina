import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/quadtrack_device.dart';

/// Reusable circular battery gauge widget
class BatteryGauge extends StatefulWidget {
  final int percentage;
  final String label;
  final ChargingState chargingState;
  final bool isPhoneBattery;

  const BatteryGauge({
    super.key,
    required this.percentage,
    required this.label,
    this.chargingState = ChargingState.unknown,
    this.isPhoneBattery = false,
  });

  @override
  State<BatteryGauge> createState() => _BatteryGaugeState();
}

class _BatteryGaugeState extends State<BatteryGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _animation =
        IntTween(begin: 0, end: widget.percentage).animate(_animationController);
    _animationController.forward();
  }

  @override
  void didUpdateWidget(BatteryGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _animation = IntTween(begin: oldWidget.percentage, end: widget.percentage)
          .animate(_animationController);
      _animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getBatteryColor(int percentage) {
    if (percentage > 50) {
      return AppTheme.primaryGreen;
    } else if (percentage > 20) {
      return AppTheme.primaryOrange;
    } else {
      return AppTheme.primaryRed;
    }
  }

  String _getChargingIcon() {
    switch (widget.chargingState) {
      case ChargingState.chargingQi:
        return '⚡'; // Lightning bolt for Wireless Charging
      case ChargingState.chargingReverse:
        return '🔌'; // Plug for Reverse Charging
      case ChargingState.chargingPogo:
        return '📌'; // Pin for Pogo Pin Charging
      case ChargingState.onBattery:
      case ChargingState.unknown:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final displayPercentage = _animation.value;
        final batteryColor = _getBatteryColor(displayPercentage);
        final chargingIcon = _getChargingIcon();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Circular progress indicator background
                  // (Positioned.fill so the ring fills the 120px box —
                  // unconstrained it renders at the 36px default and
                  // overlaps the percentage text)
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 8,
                      valueColor: AlwaysStoppedAnimation(
                          Colors.grey.withValues(alpha: 0.3)),
                    ),
                  ),
                  // Animated circular progress indicator
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      value: displayPercentage / 100.0,
                      strokeWidth: 8,
                      valueColor: AlwaysStoppedAnimation(batteryColor),
                    ),
                  ),
                  // Center percentage text
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$displayPercentage%',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: batteryColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (chargingIcon.isNotEmpty)
                        Text(
                          chargingIcon,
                          style: const TextStyle(fontSize: 20),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
            if (widget.chargingState != ChargingState.onBattery &&
                widget.chargingState != ChargingState.unknown)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  widget.chargingState.displayName,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
          ],
        );
      },
    );
  }
}
