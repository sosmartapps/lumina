import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_user.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_theme.dart';
import '../caregiver/add_patient_screen.dart';
import '../caregiver/invite_caregiver_screen.dart';
import '../caregiver/manage_contacts_screen.dart';
import '../caregiver/manage_medications_screen.dart';
import '../caregiver/manage_reminders_screen.dart';
import '../caregiver/manage_zones_screen.dart';
import '../caregiver/sundown_settings_screen.dart';
import '../bouncie/vehicle_tracking_screen.dart';
import '../pet_feeding/manage_pet_feeding_screen.dart';
import 'patient_device_guide_screen.dart';

/// One setup step: how it's detected and where it's done.
class OnboardingStep {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final bool optional;
  final Widget Function() screenBuilder;

  /// Steps with no data signal are marked done via a confirm after
  /// visiting the screen (flag stored in caregiver.onboardingProgress).
  final bool manualConfirm;

  const OnboardingStep({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.screenBuilder,
    this.optional = false,
    this.manualConfirm = false,
  });
}

/// Computes live completion status for every setup step. Data-backed
/// steps auto-complete from Firestore; the rest use flags on the
/// caregiver doc's `onboardingProgress` map.
class OnboardingStatus {
  static List<OnboardingStep> steps() => [
        OnboardingStep(
          key: 'patient',
          title: 'Add your patient',
          description: 'Name, phone, and home address',
          icon: Icons.person_add,
          screenBuilder: () => const AddPatientScreen(),
        ),
        OnboardingStep(
          key: 'contacts',
          title: 'Emergency contacts',
          description: 'One-tap calling for your loved one',
          icon: Icons.contact_phone,
          screenBuilder: () => const ManageContactsScreen(),
        ),
        OnboardingStep(
          key: 'medications',
          title: 'Medications',
          description: 'What they take and when',
          icon: Icons.medication,
          screenBuilder: () => const ManageMedicationsScreen(),
        ),
        OnboardingStep(
          key: 'reminders',
          title: 'Daily reminders',
          description: 'Tasks with photo proof and AI checking',
          icon: Icons.notifications_active,
          screenBuilder: () => const ManageRemindersScreen(),
        ),
        OnboardingStep(
          key: 'safe_zones',
          title: 'Safe zones',
          description: 'Get alerted if they wander',
          icon: Icons.shield,
          screenBuilder: () => const ManageZonesScreen(),
        ),
        OnboardingStep(
          key: 'sundown',
          title: 'Sundown alerts',
          description: 'Guide them home before dark',
          icon: Icons.wb_twilight,
          manualConfirm: true,
          screenBuilder: () => const SundownSettingsScreen(),
        ),
        OnboardingStep(
          key: 'invite',
          title: 'Invite family',
          description: 'Share care with one code',
          icon: Icons.group_add,
          screenBuilder: () => const InviteCaregiverScreen(),
        ),
        OnboardingStep(
          key: 'patient_device',
          title: "Set up their phone",
          description: 'Install Lumina on the patient\'s device',
          icon: Icons.phone_iphone,
          manualConfirm: true,
          screenBuilder: () => const PatientDeviceGuideScreen(),
        ),
        OnboardingStep(
          key: 'pets',
          title: 'Pet feeding',
          description: 'Feeding times become patient reminders',
          icon: Icons.pets,
          optional: true,
          screenBuilder: () => const ManagePetFeedingScreen(),
        ),
        OnboardingStep(
          key: 'vehicle',
          title: 'Vehicle tracking',
          description: 'Connect a Bouncie GPS adapter',
          icon: Icons.directions_car,
          optional: true,
          screenBuilder: () => const VehicleTrackingScreen(),
        ),
      ];

  /// Returns step key → done. Cheap: limit(1) existence probes.
  static Future<Map<String, bool>> compute({
    required String caregiverId,
    required AppUser? patient,
  }) async {
    final db = FirebaseFirestore.instance;
    final result = <String, bool>{};

    // Flags for manual-confirm steps (and overrides)
    Map<String, dynamic> flags = {};
    try {
      final doc = await db.collection('caregivers').doc(caregiverId).get();
      flags = (doc.data()?['onboardingProgress'] as Map<String, dynamic>?) ??
          {};
    } catch (_) {}

    Future<bool> any(Query q) async {
      try {
        return (await q.limit(1).get()).docs.isNotEmpty;
      } catch (_) {
        return false;
      }
    }

    result['patient'] = patient != null;
    result['contacts'] = patient?.emergencyContacts.isNotEmpty ?? false;
    if (patient == null) {
      for (final k in [
        'medications', 'reminders', 'safe_zones', 'invite', 'pets', 'vehicle'
      ]) {
        result[k] = false;
      }
    } else {
      result['medications'] = await any(db
          .collection('medications')
          .where('userId', isEqualTo: patient.id));
      result['reminders'] = await any(
          db.collection('reminders').where('userId', isEqualTo: patient.id));
      result['safe_zones'] = await any(
          db.collection('geo_zones').where('userId', isEqualTo: patient.id));
      result['invite'] = patient.caregiverIds.length > 1 ||
          await any(db
              .collection('invite_codes')
              .where('createdBy', isEqualTo: caregiverId));
      result['pets'] = await any(db
          .collection('pet_feedings')
          .where('userId', isEqualTo: patient.id));
      result['vehicle'] = (await db
              .collection('bouncie_connections')
              .doc(patient.id)
              .get())
          .exists;
    }
    result['sundown'] = flags['sundown'] == true;
    result['patient_device'] = flags['patient_device'] == true;

    return result;
  }

  /// (done, total) over the CORE (non-optional) steps.
  static (int, int) coreProgress(Map<String, bool> status) {
    final core = steps().where((s) => !s.optional).toList();
    final done = core.where((s) => status[s.key] == true).length;
    return (done, core.length);
  }
}

/// Guided caregiver setup — a checklist that opens the app's real
/// screens as steps and auto-detects completion (2026-07-13).
class CaregiverOnboardingScreen extends ConsumerStatefulWidget {
  const CaregiverOnboardingScreen({super.key});

  @override
  ConsumerState<CaregiverOnboardingScreen> createState() =>
      _CaregiverOnboardingScreenState();
}

class _CaregiverOnboardingScreenState
    extends ConsumerState<CaregiverOnboardingScreen> {
  Map<String, bool> _status = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final caregiverId = ref.read(authServiceProvider).currentUser?.uid;
    if (caregiverId == null) return;
    final provider = ref.read(caregiverNotifierProvider);
    // Re-pull managed users so a just-added patient counts immediately
    await provider.loadCaregiver(caregiverId);
    final status = await OnboardingStatus.compute(
      caregiverId: caregiverId,
      patient: provider.selectedUser,
    );
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
    });
  }

  Future<void> _openStep(OnboardingStep step) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => step.screenBuilder()),
    );
    if (!mounted) return;
    if (step.manualConfirm && _status[step.key] != true) {
      final done = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(step.title),
          content: const Text('Mark this step as done?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Not yet')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Done')),
          ],
        ),
      );
      if (done == true) {
        final uid = ref.read(authServiceProvider).currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('caregivers')
              .doc(uid)
              .update({'onboardingProgress.${step.key}': true});
        }
      }
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final steps = OnboardingStatus.steps();
    final (done, total) = OnboardingStatus.coreProgress(_status);
    final complete = done == total;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        title: const Text('Setup Guide'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Progress header
                  Material(
                    color: complete ? AppTheme.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            complete
                                ? 'All set! Lumina is ready. 🎉'
                                : 'Let\'s get Lumina ready',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: complete ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : done / total,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                              color: complete
                                  ? Colors.white
                                  : AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$done of $total steps done',
                            style: TextStyle(
                              fontSize: 13,
                              color: complete
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...steps.where((s) => !s.optional).map(_tile),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('OPTIONAL',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                  ),
                  ...steps.where((s) => s.optional).map(_tile),
                ],
              ),
            ),
    );
  }

  Widget _tile(OnboardingStep step) {
    final done = _status[step.key] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          onTap: () => _openStep(step),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (done ? AppTheme.primaryGreen : AppTheme.primaryPurple)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(step.icon,
                color:
                    done ? AppTheme.primaryGreen : AppTheme.primaryPurple),
          ),
          title: Text(step.title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? Colors.grey : Colors.black87,
              )),
          subtitle: Text(step.description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          trailing: done
              ? const Icon(Icons.check_circle, color: AppTheme.primaryGreen)
              : const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

/// Compact "finish setting up" card for the dashboard overview.
/// Hidden once all core steps are done or the caregiver dismisses it.
class SetupProgressCard extends ConsumerStatefulWidget {
  const SetupProgressCard({super.key});

  @override
  ConsumerState<SetupProgressCard> createState() => _SetupProgressCardState();
}

class _SetupProgressCardState extends ConsumerState<SetupProgressCard> {
  int? _done;
  int? _total;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('caregivers')
          .doc(uid)
          .get();
      final flags =
          (doc.data()?['onboardingProgress'] as Map<String, dynamic>?) ?? {};
      if (flags['dismissed'] == true) {
        if (mounted) setState(() => _hidden = true);
        return;
      }
    } catch (_) {}
    final status = await OnboardingStatus.compute(
      caregiverId: uid,
      patient: ref.read(caregiverNotifierProvider).selectedUser,
    );
    final (done, total) = OnboardingStatus.coreProgress(status);
    if (!mounted) return;
    setState(() {
      _done = done;
      _total = total;
      _hidden = done >= total;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden || _done == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.primaryPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CaregiverOnboardingScreen()),
            );
            _load();
          },
          leading:
              const Icon(Icons.checklist, color: AppTheme.primaryPurple),
          title: Text('Finish setting up ($_done of $_total)',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Tap to continue the Setup Guide'),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Hide',
            onPressed: () async {
              final uid = ref.read(authServiceProvider).currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance
                    .collection('caregivers')
                    .doc(uid)
                    .update({'onboardingProgress.dismissed': true});
              }
              if (mounted) setState(() => _hidden = true);
            },
          ),
        ),
      ),
    );
  }
}
