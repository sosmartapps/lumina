import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../setup/setup_screen.dart';

/// Caregiver account management — sign out and PERMANENT account
/// deletion (Apple Guideline 5.1.1(v): in-app account deletion is
/// mandatory for apps with account creation).
class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState
    extends ConsumerState<AccountSettingsScreen> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final caregiver = ref.read(caregiverNotifierProvider).caregiver;
    final authUser = ref.read(authServiceProvider).currentUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.person, color: AppTheme.primaryPurple),
                  title: Text(caregiver?.name ?? 'Caregiver'),
                  subtitle: Text(
                      caregiver?.email ?? authUser?.email ?? 'No email'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.primaryBlue),
              title: const Text('Sign Out'),
              onTap: () async {
                await ref
                    .read(appStateNotifierProvider)
                    .clear()
                    .catchError((_) {});
                ref.read(caregiverNotifierProvider).clear();
                await ref.read(authServiceProvider).signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SetupScreen()),
                  (_) => false,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              leading: _deleting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_forever,
                      color: AppTheme.primaryRed),
              title: const Text('Delete My Account',
                  style: TextStyle(color: AppTheme.primaryRed)),
              subtitle: const Text(
                  'Permanently removes your account and data'),
              onTap: _deleting ? null : _confirmDelete,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This PERMANENTLY deletes your caregiver account and its '
              'data.\n\n• Patients cared for ONLY by you are deleted, '
              'including their history.\n• Patients with other caregivers '
              'are kept and unlinked from you.\n\nThis cannot be undone. '
              'Type DELETE to confirm.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'DELETE'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.primaryRed),
            onPressed: () =>
                Navigator.pop(c, controller.text.trim() == 'DELETE'),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('deleteCaregiverAccount')
          .call();
      // Auth user is deleted server-side; drop ALL local session state —
      // stale SharedPreferences kept rendering the dead account's data
      // after deletion (2026-07-13).
      await ref.read(appStateNotifierProvider).clear().catchError((_) {});
      ref.read(caregiverNotifierProvider).clear();
      await ref.read(authServiceProvider).signOut().catchError((_) {});
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SetupScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
    }
  }
}
