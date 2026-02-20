import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/services/app_protection_service.dart';
import '../../core/theme/app_theme.dart';

/// Screen for caregivers to manage app protection settings
/// Prevents accidental app deletion by users
class AppProtectionScreen extends ConsumerStatefulWidget {
  const AppProtectionScreen({super.key});

  @override
  ConsumerState<AppProtectionScreen> createState() => _AppProtectionScreenState();
}

class _AppProtectionScreenState extends ConsumerState<AppProtectionScreen> {
  bool _isLoading = true;
  bool _deviceAdminEnabled = false;
  bool _kioskModeEnabled = false;
  bool _screenPinningEnabled = false;
  bool _hasCaregiverPin = false;

  @override
  void initState() {
    super.initState();
    _loadProtectionStatus();
  }

  Future<void> _loadProtectionStatus() async {
    setState(() => _isLoading = true);

    await AppProtectionService.initialize();

    if (!mounted) return;

    final provider = ref.read(caregiverNotifierProvider);
    final user = provider.selectedUser;

    if (user != null) {
      final settings = await AppProtectionService.getProtectionSettings(user.id);
      if (settings != null) {
        setState(() {
          _hasCaregiverPin = settings['caregiverPinHash'] != null;
        });
      }
    }

    final status = AppProtectionService.getProtectionStatus();
    setState(() {
      _deviceAdminEnabled = status['deviceAdmin'] ?? false;
      _kioskModeEnabled = status['kioskMode'] ?? false;
      _screenPinningEnabled = status['screenPinning'] ?? false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryRed,
        title: const Text('App Protection'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header info
                  _buildInfoCard(),
                  const SizedBox(height: 24),

                  // Platform check
                  if (!Platform.isAndroid) ...[
                    _buildIOSInstructions(),
                  ] else ...[
                    // Android protection options
                    _buildSectionHeader('ANDROID PROTECTION'),
                    const SizedBox(height: 12),

                    // Device Admin
                    _buildProtectionOption(
                      title: 'Prevent App Deletion',
                      subtitle: 'Enable device administrator to prevent uninstallation',
                      icon: Icons.security,
                      isEnabled: _deviceAdminEnabled,
                      onToggle: _toggleDeviceAdmin,
                      helpText: 'When enabled, the app cannot be uninstalled without first removing device admin access.',
                    ),
                    const SizedBox(height: 12),

                    // Kiosk Mode
                    _buildProtectionOption(
                      title: 'Kiosk Mode',
                      subtitle: 'Lock device to this app only',
                      icon: Icons.phonelink_lock,
                      isEnabled: _kioskModeEnabled,
                      onToggle: _toggleKioskMode,
                      helpText: 'In kiosk mode, the user cannot access other apps or the home screen. Only use if needed.',
                    ),
                    const SizedBox(height: 12),

                    // Screen Pinning
                    _buildProtectionOption(
                      title: 'Screen Pinning',
                      subtitle: 'Pin app to screen (user can unpin with gesture)',
                      icon: Icons.push_pin,
                      isEnabled: _screenPinningEnabled,
                      onToggle: _toggleScreenPinning,
                      helpText: 'A lighter option that pins the app. User can unpin by holding Back + Recent buttons.',
                    ),
                  ],

                  const SizedBox(height: 24),
                  _buildSectionHeader('CAREGIVER PIN'),
                  const SizedBox(height: 12),

                  // Caregiver PIN
                  _buildPinSection(),

                  const SizedBox(height: 24),

                  // Emergency disable info
                  _buildEmergencyInfo(),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: AppTheme.primaryBlue, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Protection',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prevent accidental deletion or exit from the app. Only caregivers can disable these protections.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildProtectionOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isEnabled,
    required Future<void> Function() onToggle,
    required String helpText,
  }) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isEnabled
                    ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isEnabled ? AppTheme.primaryGreen : Colors.grey,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(subtitle),
            trailing: Switch(
              value: isEnabled,
              activeThumbColor: AppTheme.primaryGreen,
              onChanged: (_) => onToggle(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      helpText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _hasCaregiverPin
                        ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                        : AppTheme.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.pin,
                    color: _hasCaregiverPin ? AppTheme.primaryGreen : AppTheme.primaryOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Caregiver PIN',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _hasCaregiverPin
                            ? 'PIN is set - required to disable protections'
                            : 'No PIN set - anyone can disable protections',
                        style: TextStyle(
                          fontSize: 12,
                          color: _hasCaregiverPin ? Colors.grey : AppTheme.primaryOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showSetPinDialog,
                    icon: Icon(_hasCaregiverPin ? Icons.edit : Icons.add),
                    label: Text(_hasCaregiverPin ? 'Change PIN' : 'Set PIN'),
                  ),
                ),
                if (_hasCaregiverPin) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _showRemovePinDialog,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Remove', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSInstructions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.phone_iphone, color: AppTheme.primaryBlue),
                ),
                const SizedBox(width: 12),
                const Text(
                  'iOS Protection',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'On iOS, use these built-in features to protect the app:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            _buildIOSStep(
              '1',
              'Guided Access',
              'Go to Settings > Accessibility > Guided Access. Enable it and set a passcode. Triple-click the side button in the app to lock to it.',
            ),
            _buildIOSStep(
              '2',
              'Screen Time',
              'Go to Settings > Screen Time > Content & Privacy Restrictions. Set "Deleting Apps" to Don\'t Allow.',
            ),
            _buildIOSStep(
              '3',
              'Restrictions Passcode',
              'Use a passcode the user doesn\'t know to prevent them from changing these settings.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppTheme.primaryOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Remember your passcodes! Apple cannot recover them.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: AppTheme.primaryRed),
              SizedBox(width: 8),
              Text(
                'Emergency Disable',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'If you need to disable protection in an emergency:\n'
            '• Device Admin: Go to Settings > Security > Device Admin Apps and deactivate Lumina\n'
            '• Kiosk Mode: Contact support or factory reset the device',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDeviceAdmin() async {
    if (_deviceAdminEnabled) {
      // Disable - verify PIN first
      if (_hasCaregiverPin) {
        final verified = await _showPinVerificationDialog();
        if (!verified) return;
      }

      final success = await AppProtectionService.removeDeviceAdmin();
      if (success) {
        setState(() => _deviceAdminEnabled = false);
        _showMessage('App deletion protection disabled');
      }
    } else {
      // Enable
      final success = await AppProtectionService.requestDeviceAdmin();
      setState(() => _deviceAdminEnabled = success);
      if (success) {
        _showMessage('App deletion protection enabled');
        _saveSettings();
      }
    }
  }

  Future<void> _toggleKioskMode() async {
    if (_kioskModeEnabled) {
      // Disable - verify PIN first
      if (_hasCaregiverPin) {
        final verified = await _showPinVerificationDialog();
        if (!verified) return;
      }

      final success = await AppProtectionService.disableKioskMode();
      if (success) {
        setState(() => _kioskModeEnabled = false);
        _showMessage('Kiosk mode disabled');
      }
    } else {
      // Enable
      final success = await AppProtectionService.enableKioskMode();
      setState(() => _kioskModeEnabled = success);
      if (success) {
        _showMessage('Kiosk mode enabled');
        _saveSettings();
      }
    }
  }

  Future<void> _toggleScreenPinning() async {
    if (_screenPinningEnabled) {
      // Disable
      final success = await AppProtectionService.stopScreenPinning();
      if (success) {
        setState(() => _screenPinningEnabled = false);
        _showMessage('Screen pinning stopped');
      }
    } else {
      // Enable
      final success = await AppProtectionService.startScreenPinning();
      setState(() => _screenPinningEnabled = success);
      if (success) {
        _showMessage('Screen pinning started');
        _saveSettings();
      }
    }
  }

  Future<bool> _showPinVerificationDialog() async {
    final pinController = TextEditingController();
    bool verified = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Caregiver PIN'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'PIN',
            prefixIcon: Icon(Icons.pin),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider =
                  ref.read(caregiverNotifierProvider);
              final user = provider.selectedUser;
              if (user != null) {
                verified = await AppProtectionService.verifyCaregiverPin(
                  user.id,
                  pinController.text,
                );
                if (!context.mounted) return;
                if (!verified) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incorrect PIN')),
                  );
                } else {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    return verified;
  }

  void _showSetPinDialog() {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_hasCaregiverPin ? 'Change PIN' : 'Set Caregiver PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'New PIN (4-6 digits)',
                prefixIcon: Icon(Icons.pin),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                prefixIcon: Icon(Icons.pin),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pinController.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be at least 4 digits')),
                );
                return;
              }
              if (pinController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match')),
                );
                return;
              }

              final provider =
                  ref.read(caregiverNotifierProvider);
              final user = provider.selectedUser;
              if (user != null) {
                await AppProtectionService.setCaregiverPin(
                  user.id,
                  pinController.text,
                );
                if (!context.mounted) return;
                setState(() => _hasCaregiverPin = true);
                Navigator.pop(context);
                _showMessage('PIN set successfully');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRemovePinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove PIN'),
        content: const Text(
          'Are you sure you want to remove the caregiver PIN? '
          'This will allow anyone to disable app protections.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider =
                  ref.read(caregiverNotifierProvider);
              final user = provider.selectedUser;
              if (user != null) {
                await AppProtectionService.saveProtectionSettings(
                  userId: user.id,
                  deviceAdminEnabled: _deviceAdminEnabled,
                  kioskModeEnabled: _kioskModeEnabled,
                  screenPinningEnabled: _screenPinningEnabled,
                  caregiverPin: null,
                );
                if (!context.mounted) return;
                setState(() => _hasCaregiverPin = false);
                Navigator.pop(context);
                _showMessage('PIN removed');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    final provider = ref.read(caregiverNotifierProvider);
    final user = provider.selectedUser;
    if (user != null) {
      await AppProtectionService.saveProtectionSettings(
        userId: user.id,
        deviceAdminEnabled: _deviceAdminEnabled,
        kioskModeEnabled: _kioskModeEnabled,
        screenPinningEnabled: _screenPinningEnabled,
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
