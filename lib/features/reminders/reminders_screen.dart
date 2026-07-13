import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/reminder.dart';
import '../../core/models/medication.dart';

/// Screen showing today's reminders and medications
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryOrange,
        title: const Text(
          'TODAY\'S TASKS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListenableBuilder(
        listenable: ref.read(userNotifierProvider),
        builder: (context, child) {
          final userProvider = ref.read(userNotifierProvider);
          final user = userProvider.user;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final reminders = userProvider.getTodayReminders();
          final medications = userProvider.getUpcomingMedications();

          if (reminders.isEmpty && medications.isEmpty) {
            return _buildEmptyState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medications section
                if (medications.isNotEmpty) ...[
                  _buildSectionHeader(
                    '💊 MEDICATIONS',
                    AppTheme.primaryOrange,
                  ),
                  const SizedBox(height: 12),
                  ...medications.map((med) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildMedicationCard(
                          ref,
                          med['medication'] as Medication,
                          med['schedule'] as MedicationSchedule,
                          med['scheduledTime'] as DateTime,
                        ),
                      )),
                  const SizedBox(height: 24),
                ],

                // Tasks section
                if (reminders.isNotEmpty) ...[
                  _buildSectionHeader(
                    '✅ TASKS',
                    AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 12),
                  ...reminders.map((reminder) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildReminderCard(ref, reminder),
                      )),
                ],

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(
    WidgetRef ref,
    Medication medication,
    MedicationSchedule schedule,
    DateTime scheduledTime,
  ) {
    final isPast = scheduledTime.isBefore(DateTime.now());
    final timeStr = DateFormat('h:mm a').format(scheduledTime);

    return GestureDetector(
      onTap: () => _speakMedication(ref, medication, schedule),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPast ? Colors.grey.shade200 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPast
                ? Colors.grey.shade400
                : AppTheme.primaryOrange.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Time badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isPast
                    ? Colors.grey.shade400
                    : AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    timeStr.split(' ').first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    timeStr.split(' ').last,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Medication info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isPast ? Colors.grey : Colors.black87,
                      decoration:
                          isPast ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (medication.dosage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      medication.dosage!,
                      style: TextStyle(
                        fontSize: 16,
                        color: isPast ? Colors.grey : Colors.black54,
                      ),
                    ),
                  ],
                  if (schedule.label != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      schedule.label!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isPast ? Colors.grey : AppTheme.primaryOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Status icon
            Icon(
              isPast ? Icons.check_circle : Icons.medication,
              size: 40,
              color: isPast ? Colors.grey : AppTheme.primaryOrange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderCard(WidgetRef ref, Reminder reminder) {
    final timeStr = DateFormat('h:mm a').format(reminder.scheduledTime);
    // Same-day semantics: yesterday's completion must not strike out a
    // recurring reminder today (2026-07-12).
    final isPast = reminder.isCompletedFor(DateTime.now());
    final color = _getReminderColor(reminder.type);
    final icon = _getReminderIcon(reminder.type);

    return GestureDetector(
      onTap: () => _speakReminder(ref, reminder),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPast ? Colors.grey.shade200 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPast ? Colors.grey.shade400 : color.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Time badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isPast ? Colors.grey.shade400 : color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    timeStr.split(' ').first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    timeStr.split(' ').last,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Reminder info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isPast ? Colors.grey : Colors.black87,
                      decoration:
                          isPast ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (reminder.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      reminder.description!,
                      style: TextStyle(
                        fontSize: 16,
                        color: isPast ? Colors.grey : Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Icon
            Icon(
              isPast ? Icons.check_circle : icon,
              size: 40,
              color: isPast ? Colors.grey : color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 100,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'All done for today!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No more tasks or medications\nfor today',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getReminderColor(ReminderType type) {
    switch (type) {
      case ReminderType.medication:
        return AppTheme.primaryOrange;
      case ReminderType.petCare:
        return AppTheme.primaryPurple;
      case ReminderType.mealTime:
        return AppTheme.primaryGreen;
      case ReminderType.hydration:
        return AppTheme.primaryTeal;
      case ReminderType.exercise:
        return Colors.pink;
      default:
        return AppTheme.primaryBlue;
    }
  }

  IconData _getReminderIcon(ReminderType type) {
    switch (type) {
      case ReminderType.medication:
        return Icons.medication;
      case ReminderType.petCare:
        return Icons.pets;
      case ReminderType.mealTime:
        return Icons.restaurant;
      case ReminderType.hydration:
        return Icons.water_drop;
      case ReminderType.exercise:
        return Icons.fitness_center;
      case ReminderType.appointment:
        return Icons.event;
      case ReminderType.task:
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  void _speakMedication(
    WidgetRef ref,
    Medication medication,
    MedicationSchedule schedule,
  ) {
    HapticFeedback.lightImpact();
    final tts = ref.read(ttsServiceProvider);

    String message = '${medication.name} at ${schedule.timeString}';
    if (medication.dosage != null) {
      message += '. Take ${medication.dosage}';
    }
    if (medication.instructions != null) {
      message += '. ${medication.instructions}';
    }

    tts.speak(message);
  }

  void _speakReminder(WidgetRef ref, Reminder reminder) {
    HapticFeedback.lightImpact();
    final tts = ref.read(ttsServiceProvider);

    String message = reminder.title;
    if (reminder.description != null) {
      message += '. ${reminder.description}';
    }

    tts.speak(message);
  }
}
