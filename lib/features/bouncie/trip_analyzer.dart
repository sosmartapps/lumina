import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Severity of a driving concern.
enum ConcernSeverity { warning, alert }

/// One evaluated concern about a trip (or a pattern across trips).
class TripConcern {
  final ConcernSeverity severity;
  final String title;
  final String detail;

  /// startTime string of the trip that triggered it (null for pattern-level
  /// concerns spanning several trips). Also used as the dedupe key by the
  /// server-side alerting.
  final String? tripStartTime;

  const TripConcern({
    required this.severity,
    required this.title,
    required this.detail,
    this.tripStartTime,
  });

  Color get color => severity == ConcernSeverity.alert
      ? AppTheme.primaryRed
      : AppTheme.primaryOrange;

  IconData get icon => severity == ConcernSeverity.alert
      ? Icons.error
      : Icons.warning_amber;
}

/// Heuristic evaluation of Bouncie trips for caregiver-relevant concerns.
///
/// Tuned for the Lumina context (older drivers / early cognitive decline):
/// night driving, harsh-driving events, speeding, and unusually long trips
/// are the patterns caregivers most need surfaced. The SAME thresholds are
/// mirrored in functions/src/index.ts (analyzeTripsAndAlert) — keep in sync.
class TripAnalyzer {
  /// Trips starting between this hour (inclusive) and [nightEndHour] are
  /// flagged as night driving.
  static const int nightStartHour = 22;
  static const int nightEndHour = 5;

  static const int harshEventsPerTripAlert = 3;
  static const double speedingWarnMph = 80;
  static const double speedingAlertMph = 90;
  static const int longTripMinutes = 90;

  /// Number of flagged trips in the window that escalates to a pattern alert.
  static const int patternThreshold = 3;

  /// Evaluate a list of Bouncie trip maps (as returned by /v1/trips).
  /// Returns concerns sorted most-severe first.
  static List<TripConcern> analyze(List<Map<String, dynamic>> trips) {
    final concerns = <TripConcern>[];
    var flaggedTrips = 0;

    for (final trip in trips) {
      final startRaw = trip['startTime']?.toString();
      final start =
          startRaw != null ? DateTime.tryParse(startRaw)?.toLocal() : null;
      final end = trip['endTime'] != null
          ? DateTime.tryParse(trip['endTime'].toString())?.toLocal()
          : null;
      final maxSpeed = (trip['maxSpeed'] as num?)?.toDouble() ?? 0;
      final hardBrakes =
          (trip['hardBrakingCount'] ?? trip['hardBrakes']) as int? ?? 0;
      final hardAccels = (trip['hardAccelerationCount'] ??
          trip['hardAccelerations']) as int? ??
          0;
      final harshEvents = hardBrakes + hardAccels;

      var flagged = false;
      final when = start != null
          ? '${start.month}/${start.day} '
              '${start.hour > 12 ? start.hour - 12 : (start.hour == 0 ? 12 : start.hour)}'
              ':${start.minute.toString().padLeft(2, '0')} '
              '${start.hour >= 12 ? 'PM' : 'AM'}'
          : 'recent trip';

      // Night driving — the highest-signal dementia concern.
      if (start != null &&
          (start.hour >= nightStartHour || start.hour < nightEndHour)) {
        concerns.add(TripConcern(
          severity: ConcernSeverity.alert,
          title: 'Night driving',
          detail: 'Trip started at $when — driving between '
              '$nightStartHour:00 and 0$nightEndHour:00.',
          tripStartTime: startRaw,
        ));
        flagged = true;
      }

      // Harsh driving events.
      if (harshEvents >= harshEventsPerTripAlert) {
        concerns.add(TripConcern(
          severity: ConcernSeverity.alert,
          title: 'Harsh driving',
          detail:
              '$hardBrakes hard brake${hardBrakes == 1 ? '' : 's'} and '
              '$hardAccels hard acceleration${hardAccels == 1 ? '' : 's'} '
              'on the trip at $when.',
          tripStartTime: startRaw,
        ));
        flagged = true;
      } else if (harshEvents > 0) {
        flagged = true; // counts toward the pattern, no standalone banner
      }

      // Speeding.
      if (maxSpeed >= speedingAlertMph) {
        concerns.add(TripConcern(
          severity: ConcernSeverity.alert,
          title: 'High speed',
          detail:
              'Reached ${maxSpeed.toStringAsFixed(0)} mph on the trip at $when.',
          tripStartTime: startRaw,
        ));
        flagged = true;
      } else if (maxSpeed >= speedingWarnMph) {
        concerns.add(TripConcern(
          severity: ConcernSeverity.warning,
          title: 'Elevated speed',
          detail:
              'Reached ${maxSpeed.toStringAsFixed(0)} mph on the trip at $when.',
          tripStartTime: startRaw,
        ));
        flagged = true;
      }

      // Unusually long trip (possible disorientation).
      if (start != null && end != null) {
        final minutes = end.difference(start).inMinutes;
        if (minutes >= longTripMinutes) {
          concerns.add(TripConcern(
            severity: ConcernSeverity.warning,
            title: 'Long trip',
            detail: 'The trip at $when lasted ${minutes ~/ 60}h '
                '${minutes % 60}m — unusually long.',
            tripStartTime: startRaw,
          ));
          flagged = true;
        }
      }

      if (flagged) flaggedTrips++;
    }

    // Pattern escalation across the window.
    if (flaggedTrips >= patternThreshold) {
      concerns.insert(
        0,
        TripConcern(
          severity: ConcernSeverity.alert,
          title: 'Driving pattern concern',
          detail: '$flaggedTrips trips in this period raised flags. '
              'Consider reviewing recent drives together.',
        ),
      );
    }

    concerns.sort((a, b) => a.severity == b.severity
        ? 0
        : (a.severity == ConcernSeverity.alert ? -1 : 1));
    return concerns;
  }

  /// True if this individual trip would be flagged (for card badges).
  static bool isTripConcerning(Map<String, dynamic> trip) {
    final start = trip['startTime'] != null
        ? DateTime.tryParse(trip['startTime'].toString())?.toLocal()
        : null;
    final end = trip['endTime'] != null
        ? DateTime.tryParse(trip['endTime'].toString())?.toLocal()
        : null;
    final maxSpeed = (trip['maxSpeed'] as num?)?.toDouble() ?? 0;
    final harsh = ((trip['hardBrakingCount'] ?? trip['hardBrakes']) as int? ??
            0) +
        ((trip['hardAccelerationCount'] ?? trip['hardAccelerations']) as int? ??
            0);

    if (start != null &&
        (start.hour >= nightStartHour || start.hour < nightEndHour)) {
      return true;
    }
    if (harsh >= harshEventsPerTripAlert) return true;
    if (maxSpeed >= speedingWarnMph) return true;
    if (start != null &&
        end != null &&
        end.difference(start).inMinutes >= longTripMinutes) {
      return true;
    }
    return false;
  }
}
