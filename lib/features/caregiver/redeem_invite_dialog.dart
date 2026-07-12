import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Redeem an invite code as the ALREADY-SIGNED-IN caregiver (any auth
/// provider). The login-screen redeem dialog is email/password-only, so
/// OAuth caregivers on a second device had no way to join a family
/// (found 2026-07-12: Google-on-Android vs Apple-on-iPhone split).
///
/// Shared by the caregiver dashboard empty state and All Patients screen.
void showRedeemInviteDialog(BuildContext context, WidgetRef ref) {
  final codeController = TextEditingController();
  String? dialogError;
  var redeeming = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Enter Invite Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Invite Code',
                errorText: dialogError,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: redeeming
                ? null
                : () async {
                    final code = codeController.text.trim();
                    if (code.length != 6) {
                      setDialogState(
                          () => dialogError = 'Code must be 6 characters');
                      return;
                    }
                    final uid =
                        ref.read(authServiceProvider).currentUser?.uid;
                    if (uid == null) {
                      setDialogState(() => dialogError = 'Not signed in');
                      return;
                    }
                    setDialogState(() {
                      redeeming = true;
                      dialogError = null;
                    });
                    try {
                      final patients = await ref
                          .read(inviteServiceProvider)
                          .redeemInviteCode(code: code, caregiverId: uid);
                      // Reload so the new patients show immediately.
                      await ref
                          .read(caregiverNotifierProvider)
                          .loadCaregiver(uid);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                      if (context.mounted) {
                        final label = patients.length == 1
                            ? "Joined ${patients.first.name}'s care team!"
                            : 'Joined ${patients.length} care teams!';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(label),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        redeeming = false;
                        dialogError =
                            e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  },
            child: redeeming
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Join'),
          ),
        ],
      ),
    ),
  );
}
