import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Step-by-step instructions for setting up the PATIENT's phone.
/// Part of the caregiver Setup Guide (onboarding wizard, 2026-07-13).
class PatientDeviceGuideScreen extends StatelessWidget {
  const PatientDeviceGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text("Patient's Device"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _step(
            1,
            'Install Lumina on their phone',
            'Download Lumina from the App Store (iPhone) or Play Store '
                '(Android) on the phone your loved one will carry.',
            Icons.download,
          ),
          _step(
            2,
            'Open the app — no sign-in needed',
            'The patient side uses the phone itself as identity. On first '
                'launch, choose the patient setup path and select or create '
                'their profile.',
            Icons.person,
          ),
          _step(
            3,
            'Allow location — "Always"',
            'Location powers safe zones, the Go Home button, and sundown '
                'alerts. When asked, choose "Allow While Using", then in '
                'Settings change it to "Always".',
            Icons.location_on,
          ),
          _step(
            4,
            'Allow notifications',
            'Reminders appear as full-screen prompts with voice. '
                'Notifications must be allowed for them to work when the '
                'app is in the background.',
            Icons.notifications_active,
          ),
          _step(
            5,
            'Keep the app easy to find',
            'Place Lumina alone on the home screen dock. On iPhone, '
                'consider Guided Access (Settings → Accessibility) to keep '
                'the phone in Lumina. On Android, Lumina can be set as a '
                'launcher for kiosk-style use.',
            Icons.push_pin,
          ),
          _step(
            6,
            'Do a test together',
            'Create a reminder for a few minutes from now and let your '
                'loved one complete it — including taking the photo — so '
                'the first real one is familiar.',
            Icons.check_circle,
          ),
          const SizedBox(height: 24),
          Material(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates,
                      color: AppTheme.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: the patient app is designed for large text and '
                      'simple taps — everything important is one button.',
                      style: TextStyle(color: Colors.grey.shade800),
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

  Widget _step(int n, String title, String body, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryPurple,
                child: Text('$n',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: AppTheme.primaryPurple),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(body,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
