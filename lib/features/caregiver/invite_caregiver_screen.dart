import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../../core/models/caregiver.dart';
import '../../core/models/invite_code.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';

/// Screen for inviting additional caregivers to a patient
class InviteCaregiverScreen extends ConsumerStatefulWidget {
  const InviteCaregiverScreen({super.key});

  @override
  ConsumerState<InviteCaregiverScreen> createState() => _InviteCaregiverScreenState();
}

class _InviteCaregiverScreenState extends ConsumerState<InviteCaregiverScreen> {
  CaregiverRole _selectedRole = CaregiverRole.familyMember;
  InviteCode? _generatedInvite;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _generateCode() async {
    final caregiverProvider = ref.read(caregiverNotifierProvider);
    final patient = caregiverProvider.selectedUser;
    final caregiver = caregiverProvider.caregiver;

    if (patient == null || caregiver == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final inviteService = ref.read(inviteServiceProvider);
      final invite = await inviteService.createInviteCode(
        patientId: patient.id,
        caregiverId: caregiver.id,
        assignedRole: _selectedRole,
      );
      setState(() => _generatedInvite = invite);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _shareInvite() {
    if (_generatedInvite == null) return;
    final inviteService = ref.read(inviteServiceProvider);
    final link = inviteService.generateShareLink(_generatedInvite!);
    final patient = ref.read(caregiverNotifierProvider).selectedUser;
    SharePlus.instance.share(
      ShareParams(
        text: 'Join me as a caregiver for ${patient?.name ?? 'my loved one'} on Lumina!\n\n'
            'Use invite code: ${_generatedInvite!.code}\n'
            'Or open this link: $link\n\n'
            'The code expires in 24 hours.',
      ),
    );
  }

  void _copyCode() {
    if (_generatedInvite == null) return;
    Clipboard.setData(ClipboardData(text: _generatedInvite!.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caregiverProvider = ref.read(caregiverNotifierProvider);
    final patient = caregiverProvider.selectedUser;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Invite Caregiver'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invite someone to help care for ${patient?.name ?? 'your patient'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),

            // Role picker
            const Text(
              'Assign a Role',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<CaregiverRole>(
              initialValue: _selectedRole,
              onChanged: (role) {
                if (role != null) setState(() => _selectedRole = role);
              },
              items: [
                CaregiverRole.caregiver,
                CaregiverRole.familyMember,
                CaregiverRole.healthcare,
              ]
                  .map((role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.displayName),
                      ))
                  .toList(),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 24),

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _generateCode,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.vpn_key, color: Colors.white),
                label: Text(
                  _generatedInvite == null ? 'GENERATE INVITE CODE' : 'GENERATE NEW CODE',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.primaryRed),
                ),
              ),
            ],

            // Generated code display
            if (_generatedInvite != null) ...[
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Invite Code',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _copyCode,
                      child: Text(
                        _generatedInvite!.code,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Expires ${DateFormat('MMM d, h:mm a').format(_generatedInvite!.expiresAt)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    Text(
                      'Role: ${_selectedRole.displayName}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyCode,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareInvite,
                            icon: const Icon(Icons.share, color: Colors.white),
                            label: const Text(
                              'Share',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Active invites
            const Text(
              'Active Invites',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActiveInvitesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveInvitesList() {
    final patient = ref.read(caregiverNotifierProvider).selectedUser;
    if (patient == null) return const SizedBox.shrink();

    final inviteService = ref.read(inviteServiceProvider);
    return StreamBuilder<List<InviteCode>>(
      stream: inviteService.getActiveInvites(patient.id),
      builder: (context, snapshot) {
        final invites = snapshot.data ?? [];
        if (invites.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('No active invites')),
          );
        }

        return Column(
          children: invites.map((invite) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.vpn_key, color: AppTheme.primaryPurple),
                title: Text(
                  invite.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                subtitle: Text(
                  '${invite.assignedRole.displayName} · Expires ${DateFormat('MMM d, h:mm a').format(invite.expiresAt)}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () async {
                    await inviteService.revokeInviteCode(invite.id);
                  },
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
