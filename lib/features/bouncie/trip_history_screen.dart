import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import 'trip_analyzer.dart';
import 'trip_detail_screen.dart';

/// Displays Bouncie trip history for the tracked vehicle.
class TripHistoryScreen extends ConsumerStatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  ConsumerState<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends ConsumerState<TripHistoryScreen> {
  List<Map<String, dynamic>> _trips = [];
  bool _loading = true;
  String? _error;
  int _days = 7; // 7 / 30 / 90 day window

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final patientId =
          ref.read(caregiverNotifierProvider).selectedUser?.id;
      if (patientId == null) {
        throw Exception('No patient selected');
      }
      final connection =
          await ref.read(bouncieConnectionProvider(patientId).future);
      if (connection == null) {
        throw Exception('No vehicle connected — link one in Manage → '
            'Vehicle Tracking');
      }
      final bouncie = bouncieServiceForConnection(
          ref.read(bouncieAppConfigProvider), connection);
      final imei = connection.imei;
      final token = await bouncie.getToken();

      // Fetch the selected window of trips
      final now = DateTime.now();
      final windowStart = now.subtract(Duration(days: _days));
      final startStr = windowStart.toIso8601String();
      final endStr = now.toIso8601String();

      // Bouncie trips endpoint is /trips with an imei query param
      // (NOT /vehicles/{imei}/trips — that 404s).
      final response = await http.get(
        Uri.parse(
          'https://api.bouncie.dev/v1/trips'
          '?imei=$imei&gps-format=polyline'
          '&starts-after=$startStr&ends-before=$endStr',
        ),
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        final trips = list.cast<Map<String, dynamic>>()
          ..sort((a, b) =>
              (b['startTime'] ?? '').toString().compareTo((a['startTime'] ?? '').toString()));
        if (mounted) {
          setState(() {
            _trips = trips;
            _loading = false;
          });
        }
      } else {
        throw Exception('API returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Trip History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTrips,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.primaryRed, size: 48),
              const SizedBox(height: 12),
              Text('Could not load trips',
                  style: TextStyle(color: Colors.grey.shade600)),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!.replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _fetchTrips, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_trips.isEmpty) {
      return Column(
        children: [
          _buildRangeSelector(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No trips in the last $_days days',
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final concerns = TripAnalyzer.analyze(_trips);

    return Column(
      children: [
        _buildRangeSelector(),
        if (concerns.isNotEmpty) _buildConcernsBanner(concerns),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchTrips,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _trips.length,
              itemBuilder: (context, index) => _buildTripCard(_trips[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRangeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 7, label: Text('7 days')),
          ButtonSegment(value: 30, label: Text('30 days')),
          ButtonSegment(value: 90, label: Text('90 days')),
        ],
        selected: {_days},
        onSelectionChanged: (selection) {
          setState(() => _days = selection.first);
          _fetchTrips();
        },
      ),
    );
  }

  Widget _buildConcernsBanner(List<TripConcern> concerns) {
    final worst = concerns.first.severity;
    final color = worst == ConcernSeverity.alert
        ? AppTheme.primaryRed
        : AppTheme.primaryOrange;
    final shown = concerns.take(4).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(concerns.first.icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Driving concerns (${concerns.length})',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...shown.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(c.icon, size: 15, color: c.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: '${c.title}: ',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: c.detail),
                        ]),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              )),
          if (concerns.length > shown.length)
            Text(
              '+ ${concerns.length - shown.length} more',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final startTime = _parseTime(trip['startTime']);
    final endTime = _parseTime(trip['endTime']);
    final distance = (trip['distance'] as num?)?.toDouble() ?? 0.0;
    final maxSpeed = (trip['maxSpeed'] as num?)?.toDouble();
    final startAddress = trip['startAddress'] as String?;
    final endAddress = trip['endAddress'] as String?;
    final hardBrakes =
        (trip['hardBrakingCount'] ?? trip['hardBrakes']) as int? ?? 0;
    final hardAccels =
        (trip['hardAccelerationCount'] ?? trip['hardAccelerations']) as int? ?? 0;

    final dateStr = startTime != null
        ? DateFormat('EEE, MMM d').format(startTime)
        : '--';
    final startStr =
        startTime != null ? DateFormat('h:mm a').format(startTime) : '--';
    final endStr =
        endTime != null ? DateFormat('h:mm a').format(endTime) : '--';
    final durationStr = (startTime != null && endTime != null)
        ? _formatDuration(endTime.difference(startTime))
        : '--';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TripDetailScreen(trip: trip)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: TripAnalyzer.isTripConcerning(trip)
            ? Border.all(
                color: AppTheme.primaryOrange.withValues(alpha: 0.6),
                width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & duration header
            Row(
              children: [
                Text(dateStr,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(durationStr,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlue)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 10),

            // Start → End
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.trip_origin,
                        color: AppTheme.primaryGreen, size: 18),
                    Container(
                        width: 2, height: 20, color: Colors.grey.shade300),
                    const Icon(Icons.location_on,
                        color: AppTheme.primaryRed, size: 18),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(startStr,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (startAddress != null)
                        Text(startAddress,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Text(endStr,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (endAddress != null)
                        Text(endAddress,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats row — Wrap instead of Row so up to four stats flow to a
            // second line rather than overflowing on narrow screens.
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                _buildTripStat(Icons.straighten, '${distance.toStringAsFixed(1)} mi'),
                if (maxSpeed != null)
                  _buildTripStat(Icons.speed, '${maxSpeed.toStringAsFixed(0)} mph max'),
                if (hardBrakes > 0)
                  _buildTripStat(Icons.warning_amber, '$hardBrakes brakes',
                      color: AppTheme.primaryOrange),
                if (hardAccels > 0)
                  _buildTripStat(Icons.bolt, '$hardAccels accels',
                      color: AppTheme.primaryOrange),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTripStat(IconData icon, String label, {Color? color}) {
    final c = color ?? Colors.grey.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }

  DateTime? _parseTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }
}
