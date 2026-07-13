import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/app_user.dart';
import '../../core/models/expense.dart';
import '../../core/models/medication.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import 'add_patient_screen.dart';
import 'redeem_invite_dialog.dart';

/// One page to watch every patient a caregiver manages: live status card
/// per patient (activity, today's meds, pending expenses, driving alerts).
/// Tapping a card switches the dashboard to that patient.
class PatientsOverviewScreen extends ConsumerWidget {
  const PatientsOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(caregiverNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('All Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: 'Redeem invite code',
            onPressed: () => showRedeemInviteDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddPatientScreen()),
        ),
        backgroundColor: AppTheme.primaryPurple,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Patient'),
      ),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, child) {
          final patients = provider.managedUsers;
          if (patients.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_outlined,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('No patients yet',
                      style:
                          TextStyle(fontSize: 18, color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: patients.length,
            itemBuilder: (context, index) => _PatientCard(
              patient: patients[index],
              isSelected: patients[index].id == provider.selectedUser?.id,
              onTap: () {
                provider.selectUserById(patients[index].id);
                ref
                    .read(appStateNotifierProvider)
                    .setCurrentUserId(patients[index].id);
                Navigator.pop(context);
              },
              onLongPress: () =>
                  _showPatientActions(context, ref, patients[index]),
            ),
          );
        },
      ),
    );
  }
}

/// Long-press actions: unlink ("Remove from my care") for any caregiver,
/// full delete for the primary caregiver (server-side recursive wipe).
/// No remove/delete path existed at all before 2026-07-13.
void _showPatientActions(BuildContext context, WidgetRef ref, AppUser patient) {
  final uid = ref.read(authServiceProvider).currentUser?.uid;
  final isPrimary =
      patient.primaryCaregiverId == null || patient.primaryCaregiverId == uid;
  showModalBottomSheet(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person_remove),
            title: Text('Remove ${patient.name} from my care'),
            subtitle: const Text(
                'Unlinks them from your account; their data is kept'),
            onTap: () async {
              Navigator.pop(sheetContext);
              if (uid == null) return;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(patient.id)
                  .update({
                'caregiverIds': FieldValue.arrayRemove([uid]),
              });
              await FirebaseFirestore.instance
                  .collection('caregivers')
                  .doc(uid)
                  .update({
                'managedUserIds': FieldValue.arrayRemove([patient.id]),
              });
              await ref.read(caregiverNotifierProvider).loadCaregiver(uid);
            },
          ),
          if (isPrimary)
            ListTile(
              leading:
                  const Icon(Icons.delete_forever, color: AppTheme.primaryRed),
              title: Text('Delete ${patient.name} permanently',
                  style: const TextStyle(color: AppTheme.primaryRed)),
              subtitle: const Text(
                  'Erases the patient and ALL their data for everyone'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text('Delete ${patient.name}?'),
                    content: const Text(
                        'This permanently erases this patient and all their '
                        'history (locations, medications, tasks, photos) for '
                        'EVERY caregiver. This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancel')),
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryRed),
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Delete Forever'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || uid == null) return;
                try {
                  await FirebaseFunctions.instance
                      .httpsCallable('deletePatient')
                      .call({'patientId': patient.id});
                  await ref
                      .read(caregiverNotifierProvider)
                      .loadCaregiver(uid);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Delete failed: $e')),
                    );
                  }
                }
              },
            ),
        ],
      ),
    ),
  );
}

class _PatientCard extends ConsumerWidget {
  final AppUser patient;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PatientCard({
    required this.patient,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = FirebaseFirestore.instance;
    final todayStart = DateTime.now().copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: AppTheme.primaryPurple, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      AppTheme.primaryPurple.withValues(alpha: 0.15),
                  child: Text(
                    patient.name.isNotEmpty
                        ? patient.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      // Live "last active" badge
                      StreamBuilder<DocumentSnapshot>(
                        stream: firestore
                            .collection('users')
                            .doc(patient.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          String label = 'Activity unknown';
                          Color color = Colors.grey;
                          final data = snapshot.data?.data()
                              as Map<String, dynamic>?;
                          final lastActive =
                              (data?['lastActiveAt'] as Timestamp?)?.toDate();
                          if (lastActive != null) {
                            final diff =
                                DateTime.now().difference(lastActive);
                            if (diff.inMinutes < 5) {
                              label = 'Active now';
                              color = AppTheme.primaryGreen;
                            } else if (diff.inHours < 1) {
                              label = 'Active ${diff.inMinutes}m ago';
                              color = AppTheme.primaryGreen;
                            } else if (diff.inHours < 24) {
                              label = 'Active ${diff.inHours}h ago';
                              color = AppTheme.primaryOrange;
                            } else {
                              label =
                                  'Last active ${DateFormat.MMMd().format(lastActive)}';
                              color = Colors.grey;
                            }
                          }
                          return Row(
                            children: [
                              Icon(Icons.circle, size: 9, color: color),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Viewing',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPurple),
                    ),
                  )
                else
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
            const SizedBox(height: 12),

            // Live status chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Medications today
                StreamBuilder<QuerySnapshot>(
                  stream: firestore
                      .collection('medication_logs')
                      .where('userId', isEqualTo: patient.id)
                      .where('scheduledTime',
                          isGreaterThanOrEqualTo:
                              Timestamp.fromDate(todayStart))
                      .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    int taken = 0, missed = 0;
                    for (final d in docs) {
                      final status = (d.data()
                          as Map<String, dynamic>)['status'] as String?;
                      if (status == MedicationLogStatus.taken.value) taken++;
                      if (status == MedicationLogStatus.missed.value) missed++;
                    }
                    return _chip(
                      Icons.medication,
                      'Meds $taken✓${missed > 0 ? ' $missed✗' : ''}',
                      missed > 0
                          ? AppTheme.primaryRed
                          : AppTheme.primaryGreen,
                    );
                  },
                ),

                // Pending expense approvals
                StreamBuilder<QuerySnapshot>(
                  stream: firestore
                      .collection('expenses')
                      .where('userId', isEqualTo: patient.id)
                      .where('status',
                          isEqualTo: ExpenseStatus.submitted.value)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return _chip(Icons.receipt_long, '$count expense approval${count == 1 ? '' : 's'}',
                        AppTheme.primaryOrange);
                  },
                ),

                // Recent driving alert (last 48h)
                StreamBuilder<DocumentSnapshot>(
                  stream: firestore
                      .collection('trip_alerts')
                      .doc(patient.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final data =
                        snapshot.data?.data() as Map<String, dynamic>?;
                    final lastAlert =
                        (data?['lastAlertAt'] as Timestamp?)?.toDate();
                    if (lastAlert == null ||
                        DateTime.now().difference(lastAlert).inHours > 48) {
                      return const SizedBox.shrink();
                    }
                    return _chip(Icons.directions_car, 'Driving alert',
                        AppTheme.primaryRed);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
