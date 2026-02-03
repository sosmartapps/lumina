import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/providers/caregiver_provider.dart';
import '../../core/services/reminder_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/reminder.dart';

/// Screen for caregivers to manage reminders and tasks
class ManageRemindersScreen extends StatefulWidget {
  const ManageRemindersScreen({super.key});

  @override
  State<ManageRemindersScreen> createState() => _ManageRemindersScreenState();
}

class _ManageRemindersScreenState extends State<ManageRemindersScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Reminders & Tasks'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReminderDialog(context),
        backgroundColor: AppTheme.primaryPurple,
        icon: const Icon(Icons.add),
        label: const Text('Add Reminder'),
      ),
      body: Consumer<CaregiverProvider>(
        builder: (context, provider, child) {
          final user = provider.selectedUser;
          if (user == null) {
            return const Center(child: Text('No user selected'));
          }

          final reminderService =
              Provider.of<ReminderService>(context, listen: false);

          return StreamBuilder<List<Reminder>>(
            stream: reminderService.getReminders(user.id),
            builder: (context, snapshot) {
              final reminders = snapshot.data ?? [];

              if (reminders.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final reminder = reminders[index];
                  return _buildReminderCard(reminder, provider);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No reminders set up',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add tasks like "Feed the dog" or "Take vitamins"',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder, CaregiverProvider provider) {
    final color = _getReminderColor(reminder.type);
    final icon = _getReminderIcon(reminder.type);
    final timeStr = DateFormat('h:mm a').format(reminder.scheduledTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          reminder.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reminder.description != null) Text(reminder.description!),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    reminder.repeatFrequency.displayName,
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditReminderDialog(reminder, provider);
            } else if (value == 'delete') {
              _showDeleteConfirmation(reminder, provider);
            }
          },
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

  void _showAddReminderDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final spokenMessageController = TextEditingController();
    ReminderType selectedType = ReminderType.task;
    TimeOfDay selectedTime = TimeOfDay.now();
    RepeatFrequency repeatFrequency = RepeatFrequency.daily;
    bool requiresPhoto = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    prefixIcon: Icon(Icons.title),
                    hintText: 'e.g., Feed the dog',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: spokenMessageController,
                  decoration: const InputDecoration(
                    labelText: 'Spoken Message (optional)',
                    prefixIcon: Icon(Icons.record_voice_over),
                    hintText: 'Use {name} for user\'s name',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ReminderType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: ReminderType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text('Time: ${selectedTime.format(context)}'),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setState(() => selectedTime = time);
                    }
                  },
                ),
                DropdownButtonFormField<RepeatFrequency>(
                  initialValue: repeatFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Repeat',
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: RepeatFrequency.values.map((freq) {
                    return DropdownMenuItem(
                      value: freq,
                      child: Text(freq.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => repeatFrequency = value);
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require photo confirmation'),
                  value: requiresPhoto,
                  onChanged: (value) => setState(() => requiresPhoto = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;

                final provider =
                    Provider.of<CaregiverProvider>(context, listen: false);
                final reminderService =
                    Provider.of<ReminderService>(context, listen: false);
                final user = provider.selectedUser!;

                final now = DateTime.now();
                final scheduledTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final reminder = Reminder(
                  id: '',
                  userId: user.id,
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  spokenMessage: spokenMessageController.text.trim().isEmpty
                      ? null
                      : spokenMessageController.text.trim(),
                  type: selectedType,
                  scheduledTime: scheduledTime,
                  repeatFrequency: repeatFrequency,
                  requiresPhoto: requiresPhoto,
                  createdBy: provider.caregiver!.id,
                );

                await reminderService.createReminder(reminder);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditReminderDialog(Reminder reminder, CaregiverProvider provider) {
    final titleController = TextEditingController(text: reminder.title);
    final descriptionController =
        TextEditingController(text: reminder.description ?? '');
    final spokenMessageController =
        TextEditingController(text: reminder.spokenMessage ?? '');
    ReminderType selectedType = reminder.type;
    TimeOfDay selectedTime = TimeOfDay(
      hour: reminder.scheduledTime.hour,
      minute: reminder.scheduledTime.minute,
    );
    RepeatFrequency repeatFrequency = reminder.repeatFrequency;
    bool requiresPhoto = reminder.requiresPhoto;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: spokenMessageController,
                  decoration: const InputDecoration(
                    labelText: 'Spoken Message',
                    prefixIcon: Icon(Icons.record_voice_over),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ReminderType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: ReminderType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => selectedType = value);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time),
                  title: Text('Time: ${selectedTime.format(context)}'),
                  trailing: const Icon(Icons.edit),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setState(() => selectedTime = time);
                    }
                  },
                ),
                DropdownButtonFormField<RepeatFrequency>(
                  initialValue: repeatFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Repeat',
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: RepeatFrequency.values.map((freq) {
                    return DropdownMenuItem(
                      value: freq,
                      child: Text(freq.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => repeatFrequency = value);
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Require photo confirmation'),
                  value: requiresPhoto,
                  onChanged: (value) => setState(() => requiresPhoto = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;

                final reminderService =
                    Provider.of<ReminderService>(context, listen: false);

                final now = DateTime.now();
                final scheduledTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final updatedReminder = reminder.copyWith(
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  spokenMessage: spokenMessageController.text.trim().isEmpty
                      ? null
                      : spokenMessageController.text.trim(),
                  type: selectedType,
                  scheduledTime: scheduledTime,
                  repeatFrequency: repeatFrequency,
                  requiresPhoto: requiresPhoto,
                );

                await reminderService.updateReminder(updatedReminder);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Reminder reminder, CaregiverProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: Text('Are you sure you want to remove "${reminder.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reminderService =
                  Provider.of<ReminderService>(context, listen: false);
              await reminderService.deleteReminder(reminder.id);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
