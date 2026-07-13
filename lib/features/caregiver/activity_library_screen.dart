import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/activity_templates.dart';
import '../../core/models/reminder.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Caregiver-facing library of evidence-based "purposeful activities"
/// (Montessori-method dementia care). One tap adds an activity to the
/// patient's daily schedule as a normal [Reminder], so the existing
/// popup/TTS/photo-verification pipeline handles the rest.
class ActivityLibraryScreen extends ConsumerStatefulWidget {
  const ActivityLibraryScreen({super.key});

  @override
  ConsumerState<ActivityLibraryScreen> createState() =>
      _ActivityLibraryScreenState();
}

class _ActivityLibraryScreenState extends ConsumerState<ActivityLibraryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryTeal,
        title: const Text('Daily Activities'),
      ),
      body: ListenableBuilder(
        listenable: ref.read(caregiverNotifierProvider),
        builder: (context, child) {
          final provider = ref.read(caregiverNotifierProvider);
          final user = provider.selectedUser;
          if (user == null) {
            return const Center(child: Text('No user selected'));
          }

          final firstName = user.name.split(' ').first;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildIntroCard(firstName),
              const SizedBox(height: 8),
              for (final category in activityCategories) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryLight,
                    ),
                  ),
                ),
                ...activityTemplates
                    .where((t) => t.category == category)
                    .map((t) => _buildTemplateCard(t, firstName)),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIntroCard(String firstName) {
    return Card(
      color: AppTheme.primaryTeal.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primaryTeal.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.spa, color: AppTheme.primaryTeal, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Familiar, purposeful activities help $firstName stay '
                'engaged and keep a comfortable routine through the day. '
                'Pick a few — each one becomes a gentle daily reminder '
                'with a spoken prompt.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(ActivityTemplate template, String firstName) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(template.icon, color: AppTheme.primaryTeal),
        ),
        title: Text(
          template.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            template.benefit,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        trailing: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.primaryTeal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: () => _showAddDialog(template, firstName),
          child: const Text('Add'),
        ),
        onTap: () => _showAddDialog(template, firstName),
      ),
    );
  }

  void _showAddDialog(ActivityTemplate template, String firstName) {
    TimeOfDay time = template.suggestedTime;
    RepeatFrequency frequency = RepeatFrequency.daily;
    final selectedDays = <int>{};
    bool requiresPhoto = template.suggestPhoto;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(template.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.description,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.access_time, color: AppTheme.primaryTeal),
                  title: const Text('Time'),
                  trailing: Text(
                    time.format(dialogContext),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: dialogContext,
                      initialTime: time,
                    );
                    if (picked != null) {
                      setDialogState(() => time = picked);
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<RepeatFrequency>(
                  initialValue: frequency,
                  decoration: const InputDecoration(
                    labelText: 'How often',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: RepeatFrequency.daily,
                      child: Text('Every Day'),
                    ),
                    DropdownMenuItem(
                      value: RepeatFrequency.custom,
                      child: Text('Certain Days'),
                    ),
                    DropdownMenuItem(
                      value: RepeatFrequency.once,
                      child: Text('Just Once'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => frequency = value);
                    }
                  },
                ),
                if (frequency == RepeatFrequency.custom) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: List.generate(7, (i) {
                      const names = [
                        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                      ];
                      final day = i + 1;
                      return FilterChip(
                        label: Text(names[i]),
                        selected: selectedDays.contains(day),
                        selectedColor:
                            AppTheme.primaryTeal.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          setDialogState(() {
                            selected
                                ? selectedDays.add(day)
                                : selectedDays.remove(day);
                          });
                        },
                      );
                    }),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ask for a photo when done'),
                  subtitle: Text(
                    'You\'ll see the photo and it\'s checked automatically',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                  value: requiresPhoto,
                  onChanged: (value) =>
                      setDialogState(() => requiresPhoto = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
              onPressed: () async {
                if (frequency == RepeatFrequency.custom &&
                    selectedDays.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Pick at least one day')),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                await _addActivity(
                  template: template,
                  time: time,
                  frequency: frequency,
                  repeatDays:
                      selectedDays.isEmpty ? null : (selectedDays.toList()..sort()),
                  requiresPhoto: requiresPhoto,
                  firstName: firstName,
                );
              },
              child: Text('Add to $firstName\'s Day'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addActivity({
    required ActivityTemplate template,
    required TimeOfDay time,
    required RepeatFrequency frequency,
    required List<int>? repeatDays,
    required bool requiresPhoto,
    required String firstName,
  }) async {
    final provider = ref.read(caregiverNotifierProvider);
    final user = provider.selectedUser;
    final caregiver = provider.caregiver;
    if (user == null || caregiver == null) return;

    final now = DateTime.now();
    final scheduledTime =
        DateTime(now.year, now.month, now.day, time.hour, time.minute);

    final reminder = Reminder(
      id: '',
      userId: user.id,
      title: template.title,
      description: template.description,
      spokenMessage: template.spokenMessage,
      type: template.type,
      scheduledTime: scheduledTime,
      repeatDays: repeatDays,
      repeatFrequency: frequency,
      requiresPhoto: requiresPhoto,
      iconName: template.iconName,
      homeOnly: template.homeOnly,
      createdBy: caregiver.id,
    );

    try {
      await ref.read(reminderServiceProvider).createReminder(reminder);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${template.title}" added to $firstName\'s day'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add activity: $e'),
            backgroundColor: AppTheme.primaryRed,
          ),
        );
      }
    }
  }
}
