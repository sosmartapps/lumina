import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/models/caregiver.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import 'invite_caregiver_screen.dart';

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

  /// Multi-role editor: tick every role this person holds for the patient.
  Future<void> _editRoles(Caregiver caregiver) async {
    final patient = ref.read(caregiverNotifierProvider).selectedUser;
    if (patient == null) return;

    const editableRoles = [
      CaregiverRole.caregiver,
      CaregiverRole.familyMember,
      CaregiverRole.healthcare,
      CaregiverRole.financeManager,
    ];
    final selected = <CaregiverRole>{
      ...caregiver
          .rolesForPatient(patient.id)
          .where((r) => r != CaregiverRole.primaryCaregiver),
    };
    if (selected.isEmpty) selected.add(CaregiverRole.caregiver);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Roles for ${caregiver.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: editableRoles.map((role) {
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(role.displayName),
                value: selected.contains(role),
                onChanged: (checked) => setDialogState(() {
                  if (checked == true) {
                    selected.add(role);
                  } else if (selected.length > 1) {
                    // Keep at least one role
                    selected.remove(role);
                  }
                }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;

    try {
      await _firestore.collection('caregivers').doc(caregiver.id).update({
        'roleOverrides.${patient.id}': selected.first.value,
        'multiRoleOverrides.${patient.id}':
            selected.map((r) => r.value).toList(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update roles: $e')),
        );
      }
    }
    if (mounted) setState(() {});
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InviteCaregiverScreen(),
            ),
          );
          if (mounted) setState(() {}); // refresh after invites redeemed
        },
        backgroundColor: AppTheme.primaryPurple,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text(
          'Invite Caregiver',
          style: TextStyle(color: Colors.white),
        ),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: caregivers.length,
            itemBuilder: (context, index) {
              final cg = caregivers[index];
              final isPrimary = patient?.primaryCaregiverId == cg.id;
              final roles = cg.rolesForPatient(patient?.id ?? '');
              final rolesLabel =
                  roles.map((r) => r.displayName).join(' + ');

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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                        rolesLabel,
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
                            } else if (value == 'roles') {
                              _editRoles(cg);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'roles',
                              child: Row(
                                children: [
                                  Icon(Icons.badge, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit Roles'),
                                ],
                              ),
                            ),
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
