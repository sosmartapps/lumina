import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/models/caregiver.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Screen for viewing and managing caregivers linked to the selected patient
class ManageCaregiversScreen extends ConsumerStatefulWidget {
  const ManageCaregiversScreen({super.key});

  @override
  ConsumerState<ManageCaregiversScreen> createState() => _ManageCaregiversScreenState();
}

class _ManageCaregiversScreenState extends ConsumerState<ManageCaregiversScreen> {
  final _firestore = FirebaseFirestore.instance;

  Future<List<Caregiver>> _loadCaregivers() async {
    final patient = ref.read(caregiverNotifierProvider).selectedUser;
    if (patient == null) return [];

    final caregivers = <Caregiver>[];
    for (final id in patient.caregiverIds) {
      final doc = await _firestore.collection('caregivers').doc(id).get();
      if (doc.exists) {
        caregivers.add(Caregiver.fromFirestore(doc));
      }
    }
    return caregivers;
  }

  Future<void> _changeRole(Caregiver caregiver, CaregiverRole newRole) async {
    final patient = ref.read(caregiverNotifierProvider).selectedUser;
    if (patient == null) return;

    await _firestore.collection('caregivers').doc(caregiver.id).update({
      'roleOverrides.${patient.id}': newRole.value,
    });
    setState(() {});
  }

  Future<void> _removeCaregiver(Caregiver caregiver) async {
    final patient = ref.read(caregiverNotifierProvider).selectedUser;
    if (patient == null) return;

    // Don't allow removing the primary caregiver
    if (patient.primaryCaregiverId == caregiver.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove the primary caregiver'),
          backgroundColor: AppTheme.primaryRed,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Caregiver'),
        content: Text('Remove ${caregiver.name} as a caregiver for ${patient.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Batch write: remove bidirectional link
    final batch = _firestore.batch();

    batch.update(
      _firestore.collection('users').doc(patient.id),
      {'caregiverIds': FieldValue.arrayRemove([caregiver.id])},
    );

    batch.update(
      _firestore.collection('caregivers').doc(caregiver.id),
      {'managedUserIds': FieldValue.arrayRemove([patient.id])},
    );

    await batch.commit();

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final patient = ref.read(caregiverNotifierProvider).selectedUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Caregivers'),
      ),
      body: FutureBuilder<List<Caregiver>>(
        future: _loadCaregivers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final caregivers = snapshot.data ?? [];
          if (caregivers.isEmpty) {
            return const Center(child: Text('No caregivers linked'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: caregivers.length,
            itemBuilder: (context, index) {
              final cg = caregivers[index];
              final isPrimary = patient?.primaryCaregiverId == cg.id;
              final role = cg.roleForPatient(patient?.id ?? '');

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: isPrimary
                        ? AppTheme.primaryPurple
                        : AppTheme.primaryBlue.withValues(alpha: 0.2),
                    child: Text(
                      cg.name.isNotEmpty ? cg.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPrimary ? Colors.white : AppTheme.primaryBlue,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          cg.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Primary',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(cg.email),
                      const SizedBox(height: 2),
                      Text(
                        role.displayName,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  trailing: isPrimary
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'remove') {
                              _removeCaregiver(cg);
                            } else {
                              _changeRole(cg, CaregiverRole.fromString(value));
                            }
                          },
                          itemBuilder: (context) => [
                            ...CaregiverRole.values
                                .where((r) => r != CaregiverRole.primaryCaregiver)
                                .map((r) => PopupMenuItem(
                                      value: r.value,
                                      child: Row(
                                        children: [
                                          if (r == role)
                                            const Icon(Icons.check, size: 18, color: AppTheme.primaryGreen)
                                          else
                                            const SizedBox(width: 18),
                                          const SizedBox(width: 8),
                                          Text(r.displayName),
                                        ],
                                      ),
                                    )),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'remove',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove, size: 18, color: AppTheme.primaryRed),
                                  SizedBox(width: 8),
                                  Text('Remove', style: TextStyle(color: AppTheme.primaryRed)),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
