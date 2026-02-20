import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/caregiver_provider.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/app_user.dart';

/// Screen for caregivers to manage emergency contacts
class ManageContactsScreen extends ConsumerWidget {
  const ManageContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGreen,
        title: const Text('Emergency Contacts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddContactDialog(context, ref),
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('Add Contact'),
      ),
      body: ListenableBuilder(
        listenable: ref.read(caregiverNotifierProvider),
        builder: (context, child) {
          final provider = ref.read(caregiverNotifierProvider);
          final user = provider.selectedUser;
          if (user == null) {
            return const Center(child: Text('No user selected'));
          }

          final contacts = user.emergencyContacts;
          if (contacts.isEmpty) {
            return _buildEmptyState();
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contacts.length,
            onReorder: (oldIndex, newIndex) =>
                _reorderContacts(context, provider, user, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return Card(
                key: ValueKey(contact.id),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        AppTheme.tileColors[index % AppTheme.tileColors.length],
                    child: Text(
                      contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    contact.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact.phoneNumber),
                      if (contact.relationship != null)
                        Text(
                          contact.relationship!,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _showEditContactDialog(context, contact, provider, user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _showDeleteConfirmation(context, contact, provider, user),
                      ),
                      const Icon(Icons.drag_handle),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contacts, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No contacts yet',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add emergency contacts for quick calling',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship (optional)',
                  prefixIcon: Icon(Icons.people),
                  hintText: 'e.g., Son, Daughter, Doctor',
                ),
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
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                final provider = ref.read(caregiverNotifierProvider);
                final user = provider.selectedUser!;

                final contact = EmergencyContact(
                  id: const Uuid().v4(),
                  name: nameController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
                  relationship: relationshipController.text.trim().isEmpty
                      ? null
                      : relationshipController.text.trim(),
                  orderIndex: user.emergencyContacts.length,
                );

                provider.addUserContact(user.id, contact);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditContactDialog(
    BuildContext context,
    EmergencyContact contact,
    CaregiverProvider provider,
    AppUser user,
  ) {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phoneNumber);
    final relationshipController =
        TextEditingController(text: contact.relationship ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: Icon(Icons.people),
                ),
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
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                final updatedContact = EmergencyContact(
                  id: contact.id,
                  name: nameController.text.trim(),
                  phoneNumber: phoneController.text.trim(),
                  relationship: relationshipController.text.trim().isEmpty
                      ? null
                      : relationshipController.text.trim(),
                  orderIndex: contact.orderIndex,
                );

                final updatedContacts = user.emergencyContacts.map((c) {
                  return c.id == contact.id ? updatedContact : c;
                }).toList();

                provider.updateManagedUser(
                  user.copyWith(emergencyContacts: updatedContacts),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    EmergencyContact contact,
    CaregiverProvider provider,
    AppUser user,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to remove ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedContacts =
                  user.emergencyContacts.where((c) => c.id != contact.id).toList();
              provider.updateManagedUser(
                user.copyWith(emergencyContacts: updatedContacts),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _reorderContacts(
    BuildContext context,
    CaregiverProvider provider,
    AppUser user,
    int oldIndex,
    int newIndex,
  ) {
    final contacts = List<EmergencyContact>.from(user.emergencyContacts);
    if (newIndex > oldIndex) newIndex--;

    final item = contacts.removeAt(oldIndex);
    contacts.insert(newIndex, item);

    // Update order indices
    final updatedContacts = contacts.asMap().entries.map((entry) {
      return EmergencyContact(
        id: entry.value.id,
        name: entry.value.name,
        phoneNumber: entry.value.phoneNumber,
        relationship: entry.value.relationship,
        photoUrl: entry.value.photoUrl,
        color: entry.value.color,
        orderIndex: entry.key,
      );
    }).toList();

    provider.updateManagedUser(user.copyWith(emergencyContacts: updatedContacts));
  }
}
