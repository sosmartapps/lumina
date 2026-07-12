import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
  // People can hold multiple roles at once (e.g. Family Member + Fiduciary)
  final Set<CaregiverRole> _selectedRoles = {CaregiverRole.familyMember};
  final _phoneController = TextEditingController();
  InviteCode? _generatedInvite;
  bool _isLoading = false;
  String? _errorMessage;

  /// One code covering every patient this caregiver manages (2026-07-12).
  bool _shareAllPatients = false;
  int _sharedPatientCount = 1;

  static const _invitableRoles = [
    CaregiverRole.caregiver,
    CaregiverRole.familyMember,
    CaregiverRole.healthcare,
    CaregiverRole.financeManager,
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

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
      // "Share all" only covers patients where THIS caregiver is the
      // primary (firestore.rules rejects invite docs for the rest).
      final patientIds = _shareAllPatients
          ? caregiverProvider.managedUsers
              .where((u) =>
                  u.primaryCaregiverId == null ||
                  u.primaryCaregiverId == caregiver.id)
              .map((u) => u.id)
              .toList()
          : [patient.id];
      final inviteService = ref.read(inviteServiceProvider);
      final result = await inviteService.createInviteCode(
        patientIds: patientIds.isEmpty ? [patient.id] : patientIds,
        caregiverId: caregiver.id,
        assignedRoles: _selectedRoles.toList(),
      );
      setState(() {
        _generatedInvite = result.invite;
        _sharedPatientCount = (patientIds.isEmpty ? 1 : patientIds.length) -
            result.skippedPatientIds.length;
      });
      if (result.skippedPatientIds.isNotEmpty && mounted) {
        final names = caregiverProvider.managedUsers
            .where((u) => result.skippedPatientIds.contains(u.id))
            .map((u) => u.name)
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryOrange,
            duration: const Duration(seconds: 6),
            content: Text(
                'Code does NOT cover: $names (Premium required, or you '
                'are not their primary caregiver)'),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _shareInvite() {
    if (_generatedInvite == null) return;
    SharePlus.instance.share(ShareParams(text: _inviteMessage()));
  }

  String _inviteMessage() {
    final inviteService = ref.read(inviteServiceProvider);
    final link = inviteService.generateShareLink(_generatedInvite!);
    final patient = ref.read(caregiverNotifierProvider).selectedUser;
    final who = _sharedPatientCount > 1
        ? 'my $_sharedPatientCount patients'
        : (patient?.name ?? 'my loved one');
    return 'Join me as a caregiver for $who on Lumina!\n\n'
        'Use invite code: ${_generatedInvite!.code}\n'
        'Or open this link: $link\n\n'
        'The code expires in 24 hours.';
  }

  /// Opens Messages with the invite prefilled to the entered phone number.
  Future<void> _textInvite() async {
    if (_generatedInvite == null) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a phone number first')),
      );
      return;
    }
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': _inviteMessage()},
    );
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Messages')),
      );
    }
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
            const SizedBox(height: 12),

            // Share every managed patient with one code
            if (caregiverProvider.managedUsers.length > 1)
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: SwitchListTile(
                  value: _shareAllPatients,
                  onChanged: (v) => setState(() => _shareAllPatients = v),
                  title: const Text('Share all my patients'),
                  subtitle: Text(
                    'One code adds them to all '
                    '${caregiverProvider.managedUsers.length} patients '
                    'you manage',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Role tickboxes — one person can hold several roles
            const Text(
              'Assign Roles',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tick every role this person will have',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _invitableRoles.map((role) {
                  return CheckboxListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(role.displayName),
                    value: _selectedRoles.contains(role),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _selectedRoles.add(role);
                      } else if (_selectedRoles.length > 1) {
                        // Keep at least one role ticked
                        _selectedRoles.remove(role);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Optional: text the invite straight to their phone
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number (optional)',
                hintText: 'To text them the invite',
                prefixIcon: Icon(Icons.phone),
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
                      'Roles: ${_generatedInvite!.rolesLabel}',
                      textAlign: TextAlign.center,
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _textInvite,
                        icon: const Icon(Icons.sms, color: Colors.white),
                        label: const Text(
                          'Text Invite',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                        ),
                      ),
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
                  '${invite.rolesLabel} · Expires ${DateFormat('MMM d, h:mm a').format(invite.expiresAt)}',
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
