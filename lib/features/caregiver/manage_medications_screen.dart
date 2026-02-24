import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/caregiver_provider.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/medication.dart';
import '../medication/scan_prescription_screen.dart';
import '../medication/manage_prescriptions_screen.dart';
import '../medication/pill_verification_screen.dart';

/// Screen for caregivers to manage medications
class ManageMedicationsScreen extends ConsumerStatefulWidget {
  const ManageMedicationsScreen({super.key});

  @override
  ConsumerState<ManageMedicationsScreen> createState() => _ManageMedicationsScreenState();
}

class _ManageMedicationsScreenState extends ConsumerState<ManageMedicationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryOrange,
        title: const Text('Medications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Scan Prescription',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanPrescriptionScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Prescriptions',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManagePrescriptionsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMedicationDialog(context),
        backgroundColor: AppTheme.primaryOrange,
        icon: const Icon(Icons.add),
        label: const Text('Add Medication'),
      ),
      body: ListenableBuilder(
        listenable: ref.read(caregiverNotifierProvider),
        builder: (context, child) {
          final provider = ref.read(caregiverNotifierProvider);
          final user = provider.selectedUser;
          if (user == null) {
            return const Center(child: Text('No user selected'));
          }

          final reminderService = ref.read(reminderServiceProvider);

          return StreamBuilder<List<Medication>>(
            stream: reminderService.getMedications(user.id),
            builder: (context, snapshot) {
              final medications = snapshot.data ?? [];

              if (medications.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: medications.length,
                itemBuilder: (context, index) {
                  final medication = medications[index];
                  return _buildMedicationCard(medication, provider);
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
          Icon(Icons.medication, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No medications set up',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add medications with schedules and reminders',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(Medication medication, CaregiverProvider provider) {
    final scheduleText = medication.schedules
        .map((s) => s.timeString)
        .join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.medication, color: AppTheme.primaryOrange),
        ),
        title: Text(
          medication.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (medication.dosage != null)
              Text(medication.dosage!),
            if (scheduleText.isNotEmpty)
              Text(
                'Times: $scheduleText',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (medication.instructions != null) ...[
                  const Text(
                    'Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(medication.instructions!),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Schedules:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...medication.schedules.map((schedule) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.access_time),
                    title: Text(schedule.timeString),
                    subtitle: schedule.label != null ? Text(schedule.label!) : null,
                  );
                }),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PillVerificationScreen(medication: medication),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt, color: AppTheme.primaryTeal),
                      label: const Text('Photos', style: TextStyle(color: AppTheme.primaryTeal)),
                    ),
                    TextButton.icon(
                      onPressed: () => _showEditMedicationDialog(medication, provider),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => _showDeleteConfirmation(medication, provider),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMedicationDialog(BuildContext context) {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final instructionsController = TextEditingController();
    final schedules = <MedicationSchedule>[];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Medication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Medication Name *',
                    prefixIcon: Icon(Icons.medication),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    prefixIcon: Icon(Icons.scale),
                    hintText: 'e.g., 1 pill, 10mg',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    prefixIcon: Icon(Icons.notes),
                    hintText: 'e.g., Take with food',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reminder Times',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            schedules.add(MedicationSchedule(
                              id: const Uuid().v4(),
                              hour: time.hour,
                              minute: time.minute,
                            ));
                          });
                        }
                      },
                      icon: const Icon(Icons.add_alarm),
                    ),
                  ],
                ),
                ...schedules.map((schedule) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.access_time),
                    title: Text(schedule.timeString),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        setState(() => schedules.remove(schedule));
                      },
                    ),
                  );
                }),
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
                if (nameController.text.isEmpty) return;

                final provider = ref.read(caregiverNotifierProvider);
                final reminderService = ref.read(reminderServiceProvider);
                final user = provider.selectedUser!;

                final medication = Medication(
                  id: '',
                  userId: user.id,
                  name: nameController.text.trim(),
                  dosage: dosageController.text.trim().isEmpty
                      ? null
                      : dosageController.text.trim(),
                  instructions: instructionsController.text.trim().isEmpty
                      ? null
                      : instructionsController.text.trim(),
                  schedules: schedules,
                  createdBy: provider.caregiver!.id,
                );

                await reminderService.createMedication(medication);
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

  void _showEditMedicationDialog(
    Medication medication,
    CaregiverProvider provider,
  ) {
    final nameController = TextEditingController(text: medication.name);
    final dosageController = TextEditingController(text: medication.dosage ?? '');
    final instructionsController =
        TextEditingController(text: medication.instructions ?? '');
    final schedules = List<MedicationSchedule>.from(medication.schedules);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Medication'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Medication Name',
                    prefixIcon: Icon(Icons.medication),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    prefixIcon: Icon(Icons.scale),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reminder Times',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setState(() {
                            schedules.add(MedicationSchedule(
                              id: const Uuid().v4(),
                              hour: time.hour,
                              minute: time.minute,
                            ));
                          });
                        }
                      },
                      icon: const Icon(Icons.add_alarm),
                    ),
                  ],
                ),
                ...schedules.map((schedule) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.access_time),
                    title: Text(schedule.timeString),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        setState(() => schedules.remove(schedule));
                      },
                    ),
                  );
                }),
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
                if (nameController.text.isEmpty) return;

                final reminderService = ref.read(reminderServiceProvider);

                final updatedMedication = medication.copyWith(
                  name: nameController.text.trim(),
                  dosage: dosageController.text.trim().isEmpty
                      ? null
                      : dosageController.text.trim(),
                  instructions: instructionsController.text.trim().isEmpty
                      ? null
                      : instructionsController.text.trim(),
                  schedules: schedules,
                );

                await reminderService.updateMedication(updatedMedication);
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

  void _showDeleteConfirmation(
    Medication medication,
    CaregiverProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content: Text('Are you sure you want to remove ${medication.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reminderService = ref.read(reminderServiceProvider);
              await reminderService.deleteMedication(medication.id);
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
