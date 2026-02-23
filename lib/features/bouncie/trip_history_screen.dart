import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

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
      final bouncie = ref.read(bouncieServiceProvider);
      final imei = ref.read(bouncieVehicleImeiProvider);
      final token = await bouncie.getToken();

      // Fetch last 7 days of trips
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final startStr = weekAgo.toIso8601String();
      final endStr = now.toIso8601String();

      final response = await http.get(
        Uri.parse(
          'https://api.bouncie.dev/v1/vehicles/$imei/trips'
          '?starts-after=$startStr&ends-before=$endStr',
        ),
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        if (mounted) {
          setState(() {
            _trips = list.cast<Map<String, dynamic>>();
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
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _fetchTrips, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No trips in the last 7 days',
                style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchTrips,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        itemBuilder: (context, index) => _buildTripCard(_trips[index]),
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
    final hardBrakes = trip['hardBrakes'] as int? ?? 0;
    final hardAccels = trip['hardAccelerations'] as int? ?? 0;

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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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

            // Stats row
            Row(
              children: [
                _buildTripStat(Icons.straighten, '${distance.toStringAsFixed(1)} mi'),
                const SizedBox(width: 16),
                if (maxSpeed != null)
                  _buildTripStat(Icons.speed, '${maxSpeed.toStringAsFixed(0)} mph max'),
                const Spacer(),
                if (hardBrakes > 0)
                  _buildTripStat(Icons.warning_amber, '$hardBrakes brakes',
                      color: AppTheme.primaryOrange),
                if (hardAccels > 0) ...[
                  const SizedBox(width: 12),
                  _buildTripStat(Icons.bolt, '$hardAccels accels',
                      color: AppTheme.primaryOrange),
                ],
              ],
            ),
          ],
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
