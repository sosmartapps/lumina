import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/pet_feeding.dart';

/// Chronological log of every time a pet was marked fed.
class FeedingHistoryScreen extends ConsumerWidget {
  final String userId;

  const FeedingHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(petFeedingServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        title: const Text('Feeding History'),
      ),
      body: StreamBuilder<List<FeedingLog>>(
        stream: service.getFeedingLogs(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final logs = snapshot.data ?? [];
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No feedings recorded yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          // Group logs by calendar day for readable section headers.
          final grouped = <String, List<FeedingLog>>{};
          for (final log in logs) {
            final key = DateFormat('EEEE, MMM d').format(log.fedAt);
            grouped.putIfAbsent(key, () => []).add(log);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  ...entry.value.map(_buildLogItem),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildLogItem(FeedingLog log) {
    final timeStr = DateFormat('h:mm a').format(log.fedAt);
    final details = [
      if (log.amount != null && log.amount!.isNotEmpty) log.amount!,
      if (log.foodType != null && log.foodType!.isNotEmpty) log.foodType!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: AppTheme.primaryGreen, width: 4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.petName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                if (log.fedByName != null && log.fedByName!.isNotEmpty)
                  Text(
                    'by ${log.fedByName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeStr,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
